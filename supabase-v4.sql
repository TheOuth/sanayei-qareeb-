-- ===== v4: تصنيفات الخدمات + توثيق الصنايعي بعد التأكيد على واتساب =====
-- آمن لإعادة التشغيل. يُشغَّل بعد v3.
alter table services add column if not exists cat text not null default '';
alter table providers add column if not exists verified boolean not null default false;

update services set cat = case id
  when 'plumbing' then 'home' when 'electric' then 'home' when 'ac' then 'home' when 'carpentry' then 'home' when 'blacksmith' then 'home'
  when 'paint' then 'home' when 'building' then 'home' when 'locks' then 'home'
  when 'solar' then 'energy' when 'generator' then 'energy' when 'water' then 'energy'
  when 'mobile' then 'devices' when 'appliance' then 'devices'
  when 'cleaning' then 'personal' when 'tailor' then 'personal' when 'barber' then 'personal' when 'transport' then 'personal'
  else 'other' end
where cat = '';

create or replace function list_services() returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'name', name, 'icon', icon, 'active', active, 'cat', cat) order by sort, name), '[]'::jsonb) from services;
$$;

create or replace function admin_services(p_code text) returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform assert_admin(p_code);
  return (select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name, 'icon', s.icon, 'active', s.active, 'sort', s.sort, 'cat', s.cat,
      'providers', (select count(*) from providers p where s.id = any(p.services))) order by s.sort, s.name), '[]'::jsonb) from services s);
end $$;

drop function if exists admin_save_service(text, text, text, text, boolean);
create or replace function admin_save_service(p_code text, p_id text, p_name text, p_icon text, p_active boolean, p_cat text default null) returns text language plpgsql security definer set search_path = public as $$
declare sid text := nullif(p_id, ''); c text := left(coalesce(p_cat, ''), 20);
begin
  perform assert_admin(p_code);
  if length(trim(coalesce(p_name, ''))) < 2 then raise exception 'invalid'; end if;
  if sid is null then
    sid := 's' || substr(md5(random()::text || clock_timestamp()::text), 1, 8);
    insert into services(id, name, icon, sort, active, cat)
      values (sid, left(trim(p_name), 40), left(coalesce(nullif(trim(p_icon), ''), '🔧'), 8), coalesce((select max(sort) from services), 0) + 10, coalesce(p_active, true), c);
  else
    update services set name = left(trim(p_name), 40), icon = left(coalesce(nullif(trim(p_icon), ''), icon), 8), active = coalesce(p_active, active),
      cat = case when p_cat is null then cat else c end where id = sid;
    if not found then raise exception 'not_found'; end if;
  end if;
  return sid;
end $$;

create or replace function admin_set_verified(p_code text, p_id uuid, p_value boolean) returns boolean language plpgsql security definer set search_path = public as $$
begin
  perform assert_admin(p_code);
  update providers set verified = coalesce(p_value, false) where id = p_id;
  return true;
end $$;

create or replace function provider_public(p providers, p_dist double precision) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', p.id, 'name', p.name, 'services', to_jsonb(p.services), 'state_id', p.state_id, 'city_id', p.city_id,
    'hood', p.hood, 'experience', p.experience, 'price', p.price, 'bio', p.bio, 'from', p.work_from, 'to', p.work_to,
    'available', is_available(p), 'photo', p.photo, 'verified', p.verified,
    'distance_km', case when p_dist is null then null else round(p_dist::numeric, 1) end,
    'rating', case when s.n >= 3 then round(s.avg::numeric, 1) else null end,
    'rating_n', s.n, 'ok', s.ok, 'fail', s.fail,
    'phone', p.phone, 'whatsapp', p.whatsapp, 'demo', false)
  from (select count(*)::int n, coalesce(avg(stars), 0) avg,
               count(*) filter (where success)::int ok, count(*) filter (where not success)::int fail
        from reviews where provider_id = p.id) s;
$$;

create or replace function nearby_providers(p_lat double precision, p_lng double precision, p_service text, p_city text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare inr jsonb; cty jsonb; oth jsonb;
begin
  with c as (
    select p, haversine_km(p_lat, p_lng, p.lat, p.lng) d,
           (select coalesce(avg(stars),0) from reviews r where r.provider_id = p.id) av,
           (select count(*) from reviews r where r.provider_id = p.id) n,
           (select count(*) from reviews r where r.provider_id = p.id and success) ok,
           profile_pct(p) + (case when p.verified then 20 else 0 end) + least((select count(*) from requests q where q.provider_id = p.id and q.created_at > now() - interval '30 days'), 10)::int * 5 score
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
      'photo', f.photo, 'verified', f.verified, 'pct', f.pct_now, 'status', f.status, 'available', f.av_now, 'flag', f.available, 'has_password', f.password_hash is not null, 'admin_note', f.admin_note,
      'last_seen', (extract(epoch from f.last_seen) * 1000)::bigint, 'created', (extract(epoch from f.created_at) * 1000)::bigint,
      'requests_total', rq.rt, 'requests_week', rq.rw, 'rating_n', rv.n, 'rating', case when rv.n > 0 then round(rv.av::numeric, 1) else null end, 'ok', rv.ok, 'fail', rv.fail
    ) order by f.rn), '[]'::jsonb) into items
  from f
  left join lateral (select count(*)::int rt, (count(*) filter (where r.created_at > now() - interval '7 days'))::int rw from requests r where r.provider_id = f.id) rq on true
  left join lateral (select count(*)::int n, coalesce(avg(v.stars), 0) av, (count(*) filter (where v.success))::int ok, (count(*) filter (where not v.success))::int fail from reviews v where v.provider_id = f.id) rv on true
  where f.rn > off and f.rn <= off + lim;
  return jsonb_build_object('total', total, 'items', items);
end $$;

create or replace function provider_self(p_id uuid, p_token text) returns jsonb language plpgsql security definer set search_path = public as $$
declare pr providers; res jsonb;
begin
  select * into pr from providers where id = p_id and token = p_token;
  if not found then raise exception 'forbidden'; end if;
  update providers set last_seen = now() where id = p_id;
  select * into pr from providers where id = p_id;
  res := provider_public(pr, null) || jsonb_build_object('status', pr.status, 'flag', pr.available, 'in_hours', in_hours(pr),
    'radius', pr.radius, 'has_password', pr.password_hash is not null, 'pct', profile_pct(pr), 'verified', pr.verified,
    'requests_week', (select count(*) from requests where provider_id = p_id and created_at > now() - interval '7 days'));
  return res;
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
  admin_services(text), admin_save_service(text, text, text, text, boolean, text), admin_set_verified(text, uuid, boolean), admin_reorder_services(text, jsonb), admin_delete_service(text, text),
  admin_get_settings(text), admin_save_settings(text, jsonb), admin_change_code(text, text)
to anon, authenticated;
