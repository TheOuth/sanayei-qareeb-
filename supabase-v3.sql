-- ===== v3: صورة شخصية، توحيد صيغ الأرقام، أولوية الملفات المكتملة والنشطة =====
-- آمن لإعادة التشغيل. يُشغَّل بعد v2.
create extension if not exists pgcrypto;
alter table providers add column if not exists photo text not null default '';

-- يوحّد أي صيغة (09x، 9x، 01x، 1x، +249، 249، 00249، أرقام عربية) إلى +249XXXXXXXXX أو null
create or replace function norm_phone(t text) returns text language plpgsql immutable set search_path = public as $$
declare d text := regexp_replace(translate(coalesce(t, ''), '٠١٢٣٤٥٦٧٨٩', '0123456789'), '\D', '', 'g');
begin
  if d like '00%' then d := substr(d, 3); end if;
  if d like '249%' then d := substr(d, 4); end if;
  if d like '0%' then d := substr(d, 2); end if;
  if d ~ '^[19][0-9]{8}$' then return '+249' || d; end if;
  return null;
end $$;

create or replace function check_photo(t text) returns void language plpgsql immutable set search_path = public as $$
begin
  if coalesce(t, '') <> '' and (t not like 'data:image/jpeg;base64,%' or length(t) > 60000) then raise exception 'invalid'; end if;
end $$;

-- نسبة اكتمال الملف (0..100): صورة 30، وصف 25، حي 15، سعر 10، خبرة 10، كلمة سر 10
create or replace function profile_pct(p providers) returns int language sql immutable set search_path = public as $$
  select (case when p.photo <> '' then 30 else 0 end) + (case when length(trim(p.bio)) >= 20 then 25 else 0 end)
       + (case when length(trim(p.hood)) > 0 then 15 else 0 end) + (case when p.price > 0 then 10 else 0 end)
       + (case when p.experience > 0 then 10 else 0 end) + (case when p.password_hash is not null then 10 else 0 end);
$$;

create or replace function provider_public(p providers, p_dist double precision) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', p.id, 'name', p.name, 'services', to_jsonb(p.services), 'state_id', p.state_id, 'city_id', p.city_id,
    'hood', p.hood, 'experience', p.experience, 'price', p.price, 'bio', p.bio, 'from', p.work_from, 'to', p.work_to,
    'available', is_available(p), 'photo', p.photo,
    'distance_km', case when p_dist is null then null else round(p_dist::numeric, 1) end,
    'rating', case when s.n >= 3 then round(s.avg::numeric, 1) else null end,
    'rating_n', s.n, 'ok', s.ok, 'fail', s.fail,
    'phone', p.phone, 'whatsapp', p.whatsapp, 'demo', false)
  from (select count(*)::int n, coalesce(avg(stars), 0) avg,
               count(*) filter (where success)::int ok, count(*) filter (where not success)::int fail
        from reviews where provider_id = p.id) s;
$$;

-- الترتيب: شرائح مسافة 3 كم، ثم الأعلى أولوية (اكتمال الملف + نشاط آخر 30 يوما)، ثم التقييم، ثم الأقرب
create or replace function nearby_providers(p_lat double precision, p_lng double precision, p_service text, p_city text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare inr jsonb; cty jsonb; oth jsonb;
begin
  with c as (
    select p, haversine_km(p_lat, p_lng, p.lat, p.lng) d,
           (select coalesce(avg(stars),0) from reviews r where r.provider_id = p.id) av,
           (select count(*) from reviews r where r.provider_id = p.id) n,
           (select count(*) from reviews r where r.provider_id = p.id and success) ok,
           profile_pct(p) + least((select count(*) from requests q where q.provider_id = p.id and q.created_at > now() - interval '30 days'), 10)::int * 5 score
    from providers p
    where p.status = 'approved' and p_service = any(p.services) and is_available(p)
  ), o as (
    select *, floor(d / 3) band, case when n >= 3 then av else 0 end sav from c
  )
  select
    (select coalesce(jsonb_agg(provider_public(p, d) order by band, score desc, sav desc, ok desc, d), '[]') from (select * from o
       where (p).city_id = p_city and ((p).radius = 'all' or d <= (p).radius::double precision) order by band, score desc, sav desc, ok desc, d limit 20) a),
    (select coalesce(jsonb_agg(provider_public(p, d) order by band, score desc, sav desc, ok desc, d), '[]') from (select * from o where (p).city_id = p_city order by band, score desc, sav desc, ok desc, d limit 20) b),
    (select coalesce(jsonb_agg(x), '[]') from (select provider_public(p, d) x from o where (p).city_id <> p_city order by band, score desc, sav desc, ok desc, d limit 10) z)
  into inr, cty, oth;
  if jsonb_array_length(inr) > 0 then return jsonb_build_object('tier','inrange','items',inr); end if;
  if jsonb_array_length(cty) > 0 then return jsonb_build_object('tier','nearest_city','items',cty); end if;
  if jsonb_array_length(oth) > 0 then return jsonb_build_object('tier','other_city','items',oth); end if;
  return jsonb_build_object('tier','none','items','[]'::jsonb);
end $$;

create or replace function register_provider(p jsonb) returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare pid uuid; tk text; ph text := norm_phone(p->>'phone'); wa text := coalesce(norm_phone(nullif(p->>'whatsapp', '')), norm_phone(p->>'phone'));
begin
  if ph is null or wa is null then raise exception 'invalid_phone'; end if;
  if length(coalesce(p->>'password', '')) < 6 then raise exception 'weak'; end if;
  if jsonb_typeof(p->'services') is distinct from 'array' or jsonb_array_length(p->'services') = 0 then raise exception 'invalid'; end if;
  perform check_photo(p->>'photo');
  insert into providers(name, phone, whatsapp, state_id, city_id, hood, lat, lng, radius, services, experience, price, bio, work_from, work_to, password_hash, photo)
  values (left(p->>'name', 80), ph, wa, p->>'state_id', p->>'city_id', left(coalesce(p->>'hood',''), 60),
          (p->>'lat')::double precision, (p->>'lng')::double precision, p->>'radius',
          array(select jsonb_array_elements_text(p->'services')), (p->>'experience')::int, (p->>'price')::int,
          left(coalesce(p->>'bio',''), 200), p->>'from', p->>'to', crypt(p->>'password', gen_salt('bf')), coalesce(p->>'photo', ''))
  returning id, token into pid, tk;
  return jsonb_build_object('id', pid, 'token', tk);
end $$;

create or replace function provider_login(p_phone text, p_password text) returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare pr providers; ph text := norm_phone(p_phone);
begin
  select * into pr from providers where phone = ph;
  if not found then perform pg_sleep(1.5); return jsonb_build_object('ok', false, 'error', 'invalid'); end if;
  if pr.locked_until is not null and pr.locked_until > now() then return jsonb_build_object('ok', false, 'error', 'locked'); end if;
  if pr.password_hash is null then return jsonb_build_object('ok', false, 'error', 'no_password'); end if;
  if pr.password_hash = crypt(coalesce(p_password, ''), pr.password_hash) then
    update providers set login_fails = 0, locked_until = null, last_seen = now() where id = pr.id;
    return jsonb_build_object('ok', true, 'id', pr.id, 'token', pr.token);
  end if;
  update providers set login_fails = case when login_fails + 1 >= 5 then 0 else login_fails + 1 end,
    locked_until = case when login_fails + 1 >= 5 then now() + interval '15 minutes' else locked_until end where id = pr.id;
  perform pg_sleep(1);
  return jsonb_build_object('ok', false, 'error', 'invalid');
end $$;

create or replace function provider_self(p_id uuid, p_token text) returns jsonb language plpgsql security definer set search_path = public as $$
declare pr providers; res jsonb;
begin
  select * into pr from providers where id = p_id and token = p_token;
  if not found then raise exception 'forbidden'; end if;
  update providers set last_seen = now() where id = p_id;
  select * into pr from providers where id = p_id;
  res := provider_public(pr, null) || jsonb_build_object('status', pr.status, 'flag', pr.available, 'in_hours', in_hours(pr),
    'radius', pr.radius, 'has_password', pr.password_hash is not null, 'pct', profile_pct(pr),
    'requests_week', (select count(*) from requests where provider_id = p_id and created_at > now() - interval '7 days'));
  return res;
end $$;

create or replace function apply_profile(p_id uuid, p jsonb, p_admin boolean) returns void language plpgsql security definer set search_path = public as $$
declare wa text; ph text;
begin
  if p ? 'services' and (jsonb_typeof(p->'services') is distinct from 'array' or jsonb_array_length(p->'services') = 0) then raise exception 'invalid'; end if;
  if nullif(p->>'whatsapp', '') is not null then wa := norm_phone(p->>'whatsapp'); if wa is null then raise exception 'invalid_phone'; end if; end if;
  if p_admin and nullif(p->>'phone', '') is not null then ph := norm_phone(p->>'phone'); if ph is null then raise exception 'invalid_phone'; end if; end if;
  if p ? 'photo' then perform check_photo(p->>'photo'); end if;
  update providers set
    name = coalesce(nullif(left(trim(p->>'name'), 80), ''), name),
    whatsapp = coalesce(wa, whatsapp),
    phone = coalesce(ph, phone),
    state_id = coalesce(nullif(p->>'state_id', ''), state_id),
    city_id = coalesce(nullif(p->>'city_id', ''), city_id),
    hood = case when p ? 'hood' then left(coalesce(p->>'hood', ''), 60) else hood end,
    lat = coalesce((p->>'lat')::double precision, lat),
    lng = coalesce((p->>'lng')::double precision, lng),
    radius = coalesce(nullif(p->>'radius', ''), radius),
    services = case when p ? 'services' then array(select jsonb_array_elements_text(p->'services')) else services end,
    experience = coalesce((p->>'experience')::int, experience),
    price = coalesce((p->>'price')::int, price),
    bio = case when p ? 'bio' then left(coalesce(p->>'bio', ''), 200) else bio end,
    photo = case when p ? 'photo' then coalesce(p->>'photo', '') else photo end,
    work_from = coalesce(nullif(p->>'from', ''), work_from),
    work_to = coalesce(nullif(p->>'to', ''), work_to),
    admin_note = case when p_admin and p ? 'admin_note' then left(coalesce(p->>'admin_note', ''), 500) else admin_note end
  where id = p_id;
end $$;

create or replace function admin_create_provider(p_code text, p jsonb) returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare pid uuid; ph text := norm_phone(p->>'phone'); wa text := coalesce(norm_phone(nullif(p->>'whatsapp', '')), norm_phone(p->>'phone'));
begin
  perform assert_admin(p_code);
  if ph is null or wa is null then raise exception 'invalid_phone'; end if;
  if length(coalesce(p->>'password', '')) < 6 then raise exception 'weak'; end if;
  if jsonb_typeof(p->'services') is distinct from 'array' or jsonb_array_length(p->'services') = 0 then raise exception 'invalid'; end if;
  perform check_photo(p->>'photo');
  insert into providers(name, phone, whatsapp, state_id, city_id, hood, lat, lng, radius, services, experience, price, bio, work_from, work_to, status, password_hash, admin_note, photo)
  values (left(p->>'name', 80), ph, wa, p->>'state_id', p->>'city_id', left(coalesce(p->>'hood', ''), 60),
          (p->>'lat')::double precision, (p->>'lng')::double precision, coalesce(nullif(p->>'radius', ''), '10'),
          array(select jsonb_array_elements_text(p->'services')), coalesce((p->>'experience')::int, 0), coalesce((p->>'price')::int, 0),
          left(coalesce(p->>'bio', ''), 200), coalesce(nullif(p->>'from', ''), '08:00'), coalesce(nullif(p->>'to', ''), '20:00'),
          'approved', crypt(p->>'password', gen_salt('bf')), left(coalesce(p->>'admin_note', ''), 500), coalesce(p->>'photo', ''))
  returning id into pid;
  return jsonb_build_object('id', pid);
end $$;

create or replace function admin_providers(p_code text, p_q text, p_status text, p_service text, p_city text, p_limit int, p_offset int) returns jsonb
language plpgsql security definer set search_path = public as $$
declare qd text := ltrim(regexp_replace(coalesce(p_q, ''), '\D', '', 'g'), '0'); total int; items jsonb; lim int := greatest(1, least(coalesce(p_limit, 30), 1000)); off int := greatest(0, coalesce(p_offset, 0));
begin
  perform assert_admin(p_code);
  select count(*) into total from providers p
    where (coalesce(p_status, '') = '' or p.status = p_status) and (coalesce(p_service, '') = '' or p_service = any(p.services))
      and (coalesce(p_city, '') = '' or p.city_id = p_city)
      and (coalesce(p_q, '') = '' or p.name ilike '%' || p_q || '%' or (qd <> '' and p.phone like '%' || qd || '%'));
  with f as (
    select p.*, is_available(p) as av_now, profile_pct(p) as pct_now, row_number() over (order by (p.status <> 'pending'), p.created_at desc) rn from providers p
    where (coalesce(p_status, '') = '' or p.status = p_status) and (coalesce(p_service, '') = '' or p_service = any(p.services))
      and (coalesce(p_city, '') = '' or p.city_id = p_city)
      and (coalesce(p_q, '') = '' or p.name ilike '%' || p_q || '%' or (qd <> '' and p.phone like '%' || qd || '%'))
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', f.id, 'name', f.name, 'phone', f.phone, 'whatsapp', f.whatsapp, 'services', to_jsonb(f.services), 'state_id', f.state_id, 'city_id', f.city_id,
      'hood', f.hood, 'radius', f.radius, 'experience', f.experience, 'price', f.price, 'bio', f.bio, 'from', f.work_from, 'to', f.work_to,
      'photo', f.photo, 'pct', f.pct_now, 'status', f.status, 'available', f.av_now, 'flag', f.available, 'has_password', f.password_hash is not null, 'admin_note', f.admin_note,
      'last_seen', (extract(epoch from f.last_seen) * 1000)::bigint, 'created', (extract(epoch from f.created_at) * 1000)::bigint,
      'requests_total', rq.rt, 'requests_week', rq.rw, 'rating_n', rv.n, 'rating', case when rv.n > 0 then round(rv.av::numeric, 1) else null end, 'ok', rv.ok, 'fail', rv.fail
    ) order by f.rn), '[]'::jsonb) into items
  from f
  left join lateral (select count(*)::int rt, (count(*) filter (where r.created_at > now() - interval '7 days'))::int rw from requests r where r.provider_id = f.id) rq on true
  left join lateral (select count(*)::int n, coalesce(avg(v.stars), 0) av, (count(*) filter (where v.success))::int ok, (count(*) filter (where not v.success))::int fail from reviews v where v.provider_id = f.id) rv on true
  where f.rn > off and f.rn <= off + lim;
  return jsonb_build_object('total', total, 'items', items);
end $$;

revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function
  nearby_providers(double precision, double precision, text, text), get_provider(uuid, double precision, double precision),
  create_request(jsonb), my_requests(text), add_review(uuid, text, text, int, text), report_provider(uuid, text, text),
  register_provider(jsonb), provider_self(uuid, text), set_available(uuid, text, boolean), set_hours(uuid, text, text, text), delete_provider(uuid, text),
  list_services(), app_config(), provider_login(text, text), set_password(uuid, text, text, text), update_profile(uuid, text, jsonb),
  admin_check(text), admin_list(text, text), admin_set_status(text, uuid, text), admin_reports(text), admin_resolve_report(text, uuid), admin_stats(text),
  admin_overview(text), admin_providers(text, text, text, text, text, int, int), admin_update_provider(text, uuid, jsonb), admin_create_provider(text, jsonb),
  admin_reset_password(text, uuid, text), admin_delete_provider(text, uuid), admin_requests(text, int, text),
  admin_services(text), admin_save_service(text, text, text, text, boolean), admin_reorder_services(text, jsonb), admin_delete_service(text, text),
  admin_get_settings(text), admin_save_settings(text, jsonb), admin_change_code(text, text)
to anon, authenticated;
