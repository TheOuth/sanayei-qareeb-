-- ===== v9: تاريخ الميلاد (18+) =====
-- آمن لإعادة التشغيل. يُشغَّل بعد v8. التسجيل الجديد يشترط 18 سنة فأكثر؛ الحسابات القديمة تُطالَب بإضافته.
alter table providers add column if not exists birth_date date;

create or replace function check_birth(p text, p_required boolean) returns date language plpgsql immutable set search_path = public as $$
declare d date;
begin
  if nullif(trim(coalesce(p, '')), '') is null then
    if p_required then raise exception 'birth_required'; end if;
    return null;
  end if;
  begin d := trim(p)::date; exception when others then raise exception 'invalid_birth'; end;
  if d > current_date or d < date '1930-01-01' then raise exception 'invalid_birth'; end if;
  if date_part('year', age(d)) < 18 then raise exception 'underage'; end if;
  return d;
end $$;

create or replace function register_provider(p jsonb) returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare pid uuid; tk text; ph text := norm_phone(p->>'phone'); wa text := coalesce(norm_phone(nullif(p->>'whatsapp', '')), norm_phone(p->>'phone')); bd date;
begin
  if ph is null or wa is null then raise exception 'invalid_phone'; end if;
  if length(coalesce(p->>'password', '')) < 6 then raise exception 'weak'; end if;
  if jsonb_typeof(p->'services') is distinct from 'array' or jsonb_array_length(p->'services') = 0 then raise exception 'invalid'; end if;
  perform check_photo(p->>'photo');
  bd := check_birth(p->>'birth_date', true);
  insert into providers(name, phone, whatsapp, state_id, city_id, hood, lat, lng, radius, services, experience, price, bio, work_from, work_to, password_hash, photo, birth_date)
  values (left(p->>'name', 80), ph, wa, p->>'state_id', p->>'city_id', left(coalesce(p->>'hood',''), 60),
          (p->>'lat')::double precision, (p->>'lng')::double precision, p->>'radius',
          array(select jsonb_array_elements_text(p->'services')), (p->>'experience')::int, (p->>'price')::int,
          left(coalesce(p->>'bio',''), 200), p->>'from', p->>'to', crypt(p->>'password', gen_salt('bf')), coalesce(p->>'photo', ''), bd)
  returning id, token into pid, tk;
  return jsonb_build_object('id', pid, 'token', tk);
end $$;

create or replace function apply_profile(p_id uuid, p jsonb, p_admin boolean) returns void language plpgsql security definer set search_path = public as $$
declare wa text; ph text; bd date;
begin
  if p ? 'services' and (jsonb_typeof(p->'services') is distinct from 'array' or jsonb_array_length(p->'services') = 0) then raise exception 'invalid'; end if;
  if nullif(p->>'whatsapp', '') is not null then wa := norm_phone(p->>'whatsapp'); if wa is null then raise exception 'invalid_phone'; end if; end if;
  if p_admin and nullif(p->>'phone', '') is not null then ph := norm_phone(p->>'phone'); if ph is null then raise exception 'invalid_phone'; end if; end if;
  if p ? 'photo' then perform check_photo(p->>'photo'); end if;
  if nullif(p->>'birth_date', '') is not null then bd := check_birth(p->>'birth_date', true); end if;
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
    birth_date = coalesce(bd, birth_date),
    work_from = coalesce(nullif(p->>'from', ''), work_from),
    work_to = coalesce(nullif(p->>'to', ''), work_to),
    admin_note = case when p_admin and p ? 'admin_note' then left(coalesce(p->>'admin_note', ''), 500) else admin_note end
  where id = p_id;
end $$;

create or replace function admin_create_provider(p_code text, p jsonb) returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare pid uuid; ph text := norm_phone(p->>'phone'); wa text := coalesce(norm_phone(nullif(p->>'whatsapp', '')), norm_phone(p->>'phone')); bd date;
begin
  perform assert_admin(p_code);
  if ph is null or wa is null then raise exception 'invalid_phone'; end if;
  if length(coalesce(p->>'password', '')) < 6 then raise exception 'weak'; end if;
  if jsonb_typeof(p->'services') is distinct from 'array' or jsonb_array_length(p->'services') = 0 then raise exception 'invalid'; end if;
  perform check_photo(p->>'photo');
  bd := check_birth(p->>'birth_date', false);
  insert into providers(name, phone, whatsapp, state_id, city_id, hood, lat, lng, radius, services, experience, price, bio, work_from, work_to, status, password_hash, admin_note, photo, birth_date)
  values (left(p->>'name', 80), ph, wa, p->>'state_id', p->>'city_id', left(coalesce(p->>'hood', ''), 60),
          (p->>'lat')::double precision, (p->>'lng')::double precision, coalesce(nullif(p->>'radius', ''), '10'),
          array(select jsonb_array_elements_text(p->'services')), coalesce((p->>'experience')::int, 0), coalesce((p->>'price')::int, 0),
          left(coalesce(p->>'bio', ''), 200), coalesce(nullif(p->>'from', ''), '08:00'), coalesce(nullif(p->>'to', ''), '20:00'),
          'approved', crypt(p->>'password', gen_salt('bf')), left(coalesce(p->>'admin_note', ''), 500), coalesce(p->>'photo', ''), bd)
  returning id into pid;
  return jsonb_build_object('id', pid);
end $$;

create or replace function provider_self(p_id uuid, p_token text) returns jsonb language plpgsql security definer set search_path = public as $$
declare pr providers; res jsonb;
begin
  select * into pr from providers where id = p_id and token = p_token;
  if not found then raise exception 'forbidden'; end if;
  update providers set last_seen = now() where id = p_id;
  select * into pr from providers where id = p_id;
  res := provider_public(pr, null) || jsonb_build_object('status', pr.status, 'flag', pr.available, 'in_hours', in_hours(pr),
    'radius', pr.radius, 'has_password', pr.password_hash is not null, 'pct', profile_pct(pr), 'verified', pr.verified, 'birth_date', pr.birth_date,
    'requests_week', (select count(*) from requests where provider_id = p_id and created_at > now() - interval '7 days'));
  return res;
end $$;

create or replace function provider_public(p providers, p_dist double precision) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', p.id, 'name', p.name, 'services', to_jsonb(p.services), 'state_id', p.state_id, 'city_id', p.city_id,
    'hood', p.hood, 'experience', p.experience, 'price', p.price, 'bio', p.bio, 'from', p.work_from, 'to', p.work_to,
    'available', is_available(p), 'photo', p.photo, 'verified', p.verified, 'jobs', job_count(p.id), 'age', case when p.birth_date is null then null else date_part('year', age(p.birth_date))::int end,
    'distance_km', case when p_dist is null then null else round(p_dist::numeric, 1) end,
    'rating', case when s.n >= 3 then round(s.avg::numeric, 1) else null end,
    'rating_n', s.n, 'ok', s.ok, 'fail', s.fail,
    'phone', p.phone, 'whatsapp', p.whatsapp, 'demo', false)
  from (select count(*)::int n, coalesce(avg(stars), 0) avg,
               count(*) filter (where success)::int ok, count(*) filter (where not success)::int fail
        from reviews where provider_id = p.id) s;
$$;

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
      'photo', f.photo, 'verified', f.verified, 'birth_date', f.birth_date, 'age', case when f.birth_date is null then null else date_part('year', age(f.birth_date))::int end, 'verify_doc', f.verify_doc, 'verified_at', (extract(epoch from f.verified_at) * 1000)::bigint, 'pct', f.pct_now, 'status', f.status, 'available', f.av_now, 'flag', f.available, 'has_password', f.password_hash is not null, 'admin_note', f.admin_note,
      'last_seen', (extract(epoch from f.last_seen) * 1000)::bigint, 'created', (extract(epoch from f.created_at) * 1000)::bigint,
      'requests_total', rq.rt, 'requests_week', rq.rw, 'rating_n', rv.n, 'rating', case when rv.n > 0 then round(rv.av::numeric, 1) else null end, 'ok', rv.ok, 'fail', rv.fail
    ) order by f.rn), '[]'::jsonb) into items
  from f
  left join lateral (select count(*)::int rt, (count(*) filter (where r.created_at > now() - interval '7 days'))::int rw from requests r where r.provider_id = f.id) rq on true
  left join lateral (select count(*)::int n, coalesce(avg(v.stars), 0) av, (count(*) filter (where v.success))::int ok, (count(*) filter (where not v.success))::int fail from reviews v where v.provider_id = f.id) rv on true
  where f.rn > off and f.rn <= off + lim;
  return jsonb_build_object('total', total, 'items', items);
end $$;

revoke execute on function check_birth(text, boolean) from public, anon, authenticated;
