-- صنايعي قريب - قاعدة البيانات (Supabase / Postgres)
-- التشغيل: Supabase > SQL Editor > الصق الملف كله > Run
-- قبل التشغيل: غيّر رمز المدير في آخر الملف (السطر الذي يحتوي CHANGE_ME_ADMIN_CODE)

create extension if not exists pgcrypto;

-- ===== الجداول =====
create table if not exists providers (
  id uuid primary key default gen_random_uuid(),
  token text not null default encode(gen_random_bytes(24), 'hex'),
  name text not null,
  phone text not null unique,
  whatsapp text not null,
  state_id text not null,
  city_id text not null,
  hood text default '',
  lat double precision not null,
  lng double precision not null,
  radius text not null default '10',           -- 5 | 10 | 20 | all
  services text[] not null,
  experience int not null default 0,
  price int not null default 0,
  bio text default '',
  work_from text default '08:00',
  work_to text default '20:00',
  status text not null default 'pending' check (status in ('pending','approved','rejected','suspended')),
  available boolean not null default false,
  last_seen timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists requests (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references providers(id) on delete cascade,
  anon_id text not null,
  service text not null,
  city_id text,
  channel text not null check (channel in ('call','whatsapp')),
  status text not null default 'new' check (status in ('new','done','failed','not_agreed')),
  created_at timestamptz not null default now()
);
create index if not exists requests_anon on requests(anon_id);
create index if not exists requests_provider on requests(provider_id, created_at);

create table if not exists reviews (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique references requests(id) on delete cascade,   -- تقييم واحد لكل طلب
  provider_id uuid not null references providers(id) on delete cascade,
  stars int not null check (stars between 1 and 5),
  comment text default '',
  success boolean not null,
  created_at timestamptz not null default now()
);
create index if not exists reviews_provider on reviews(provider_id, created_at desc);

create table if not exists reports (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references providers(id) on delete cascade,
  anon_id text not null,
  reason text not null,
  status text not null default 'open' check (status in ('open','resolved')),
  created_at timestamptz not null default now()
);

create table if not exists app_settings (
  key text primary key,
  value text not null
);

-- ===== الأمان: لا أحد يقرأ الجداول مباشرة، كل شيء عبر الدوال أدناه =====
alter table providers enable row level security;
alter table requests enable row level security;
alter table reviews enable row level security;
alter table reports enable row level security;
alter table app_settings enable row level security;
revoke all on providers, requests, reviews, reports, app_settings from anon, authenticated;

-- ===== دوال مساعدة =====
create or replace function haversine_km(a double precision, b double precision, c double precision, d double precision)
returns double precision language sql immutable as $$
  select 2 * 6371 * asin(sqrt(
    power(sin(radians(c - a) / 2), 2) +
    cos(radians(a)) * cos(radians(c)) * power(sin(radians(d - b) / 2), 2)));
$$;

create or replace function is_available(p providers) returns boolean language sql stable as $$
  select p.available
    and p.last_seen > now() - interval '6 hours'
    and (
      p.work_from is null or p.work_to is null or
      case when p.work_from <= p.work_to
        then (now() at time zone 'Africa/Khartoum')::time between p.work_from::time and p.work_to::time
        else (now() at time zone 'Africa/Khartoum')::time >= p.work_from::time
          or (now() at time zone 'Africa/Khartoum')::time <= p.work_to::time end);
$$;

create or replace function assert_admin(p_code text) returns void language plpgsql security definer set search_path = public as $$
begin
  if p_code is null or p_code <> (select value from app_settings where key = 'admin_code') then
    raise exception 'forbidden';
  end if;
end $$;

create or replace function provider_public(p providers, p_dist double precision) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', p.id, 'name', p.name, 'services', to_jsonb(p.services), 'state_id', p.state_id, 'city_id', p.city_id,
    'hood', p.hood, 'experience', p.experience, 'price', p.price, 'bio', p.bio, 'from', p.work_from, 'to', p.work_to,
    'available', is_available(p),
    'distance_km', case when p_dist is null then null else round(p_dist::numeric, 1) end,
    'rating', case when s.n >= 3 then round(s.avg::numeric, 1) else null end,
    'rating_n', s.n, 'ok', s.ok, 'fail', s.fail,
    'phone', p.phone, 'whatsapp', p.whatsapp, 'demo', false)
  from (select count(*)::int n, coalesce(avg(stars), 0) avg,
               count(*) filter (where success)::int ok, count(*) filter (where not success)::int fail
        from reviews where provider_id = p.id) s;
$$;

-- ===== دوال الزبون (الإحداثيات الدقيقة للصنايعي لا تخرج أبدا) =====
create or replace function nearby_providers(p_lat double precision, p_lng double precision, p_service text, p_city text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare inr jsonb; cty jsonb; oth jsonb;
begin
  with c as (
    select p, haversine_km(p_lat, p_lng, p.lat, p.lng) d,
           (select coalesce(avg(stars),0) from reviews r where r.provider_id = p.id) av,
           (select count(*) from reviews r where r.provider_id = p.id) n,
           (select count(*) from reviews r where r.provider_id = p.id and success) ok
    from providers p
    where p.status = 'approved' and p_service = any(p.services) and is_available(p)
  ), o as (
    select *, floor(d) fd, case when n >= 3 then av else 0 end sav from c
  )
  select
    (select coalesce(jsonb_agg(provider_public(p, d) order by fd, sav desc, ok desc), '[]') from o
       where (p).city_id = p_city and ((p).radius = 'all' or d <= (p).radius::double precision)),
    (select coalesce(jsonb_agg(provider_public(p, d) order by fd, sav desc, ok desc), '[]') from o where (p).city_id = p_city),
    (select coalesce(jsonb_agg(x), '[]') from (select provider_public(p, d) x from o where (p).city_id <> p_city order by fd, sav desc, ok desc limit 10) z)
  into inr, cty, oth;
  if jsonb_array_length(inr) > 0 then return jsonb_build_object('tier','inrange','items',inr); end if;
  if jsonb_array_length(cty) > 0 then return jsonb_build_object('tier','nearest_city','items',cty); end if;
  if jsonb_array_length(oth) > 0 then return jsonb_build_object('tier','other_city','items',oth); end if;
  return jsonb_build_object('tier','none','items','[]'::jsonb);
end $$;

create or replace function get_provider(p_id uuid, p_lat double precision, p_lng double precision)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare pr providers; res jsonb;
begin
  select * into pr from providers where id = p_id and status = 'approved';
  if not found then return null; end if;
  res := provider_public(pr, case when p_lat is null then null else haversine_km(p_lat, p_lng, pr.lat, pr.lng) end);
  res := res || jsonb_build_object('reviews', coalesce((
    select jsonb_agg(jsonb_build_object('stars', stars, 'comment', comment, 'success', success, 'ts', (extract(epoch from created_at) * 1000)::bigint) order by created_at desc)
    from (select * from reviews where provider_id = p_id order by created_at desc limit 5) r), '[]'));
  return res;
end $$;

create or replace function create_request(p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare rid uuid;
begin
  if not exists (select 1 from providers where id = (p->>'provider_id')::uuid and status = 'approved') then raise exception 'not_found'; end if;
  select id into rid from requests
    where anon_id = p->>'anon_id' and provider_id = (p->>'provider_id')::uuid and created_at::date = now()::date limit 1;
  if rid is not null then return jsonb_build_object('id', rid, 'existing', true); end if;
  insert into requests(provider_id, anon_id, service, city_id, channel)
    values ((p->>'provider_id')::uuid, p->>'anon_id', p->>'service', p->>'city_id', p->>'channel') returning id into rid;
  return jsonb_build_object('id', rid);
end $$;

create or replace function my_requests(p_anon text) returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'provider_id', r.provider_id, 'provider_name', p.name, 'service', r.service,
    'channel', r.channel, 'status', r.status, 'ts', (extract(epoch from r.created_at) * 1000)::bigint) order by r.created_at desc), '[]')
  from requests r join providers p on p.id = r.provider_id where r.anon_id = p_anon;
$$;

create or replace function add_review(p_request uuid, p_anon text, p_outcome text, p_stars int, p_comment text)
returns boolean language plpgsql security definer set search_path = public as $$
declare rq requests;
begin
  select * into rq from requests where id = p_request and anon_id = p_anon;
  if not found then raise exception 'forbidden'; end if;
  if rq.status <> 'new' then raise exception 'already'; end if;
  if p_outcome = 'not_agreed' then update requests set status = 'not_agreed' where id = p_request; return true; end if;
  if p_outcome not in ('done','failed') then raise exception 'forbidden'; end if;
  update requests set status = p_outcome where id = p_request;
  insert into reviews(request_id, provider_id, stars, comment, success)
    values (p_request, rq.provider_id, greatest(1, least(5, coalesce(p_stars, 5))), left(coalesce(p_comment, ''), 300), p_outcome = 'done');
  return true;
end $$;

create or replace function report_provider(p_id uuid, p_anon text, p_reason text) returns boolean language plpgsql security definer set search_path = public as $$
begin
  insert into reports(provider_id, anon_id, reason) values (p_id, p_anon, left(p_reason, 100));
  -- ثلاثة بلاغات من أشخاص مختلفين = إيقاف مؤقت حتى يراجعه المدير
  if (select count(distinct anon_id) from reports where provider_id = p_id and status = 'open') >= 3 then
    update providers set status = 'suspended' where id = p_id and status = 'approved';
  end if;
  return true;
end $$;

-- ===== دوال الصنايعي (يعرف رقم حسابه والرمز السري المحفوظ في جهازه) =====
create or replace function register_provider(p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare pid uuid; tk text;
begin
  insert into providers(name, phone, whatsapp, state_id, city_id, hood, lat, lng, radius, services, experience, price, bio, work_from, work_to)
  values (left(p->>'name', 80), p->>'phone', p->>'whatsapp', p->>'state_id', p->>'city_id', left(coalesce(p->>'hood',''), 60),
          (p->>'lat')::double precision, (p->>'lng')::double precision, p->>'radius',
          array(select jsonb_array_elements_text(p->'services')), (p->>'experience')::int, (p->>'price')::int,
          left(coalesce(p->>'bio',''), 200), p->>'from', p->>'to')
  returning id, token into pid, tk;
  return jsonb_build_object('id', pid, 'token', tk);
end $$;

create or replace function provider_self(p_id uuid, p_token text) returns jsonb language plpgsql security definer set search_path = public as $$
declare pr providers; res jsonb;
begin
  select * into pr from providers where id = p_id and token = p_token;
  if not found then raise exception 'forbidden'; end if;
  update providers set last_seen = now() where id = p_id;
  select * into pr from providers where id = p_id;
  res := provider_public(pr, null) || jsonb_build_object('status', pr.status,
    'requests_week', (select count(*) from requests where provider_id = p_id and created_at > now() - interval '7 days'));
  return res;
end $$;

create or replace function set_available(p_id uuid, p_token text, p_value boolean) returns boolean language plpgsql security definer set search_path = public as $$
begin
  update providers set available = p_value, last_seen = now() where id = p_id and token = p_token;
  if not found then raise exception 'forbidden'; end if;
  return true;
end $$;

create or replace function delete_provider(p_id uuid, p_token text) returns boolean language plpgsql security definer set search_path = public as $$
begin
  delete from providers where id = p_id and token = p_token;
  if not found then raise exception 'forbidden'; end if;
  return true;
end $$;

-- ===== دوال المدير =====
create or replace function admin_check(p_code text) returns boolean language plpgsql security definer set search_path = public as $$
begin perform assert_admin(p_code); return true; end $$;

create or replace function admin_list(p_code text, p_status text) returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform assert_admin(p_code);
  return (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'name', name, 'phone', phone, 'whatsapp', whatsapp, 'services', to_jsonb(services),
    'state_id', state_id, 'city_id', city_id, 'hood', hood, 'experience', experience, 'price', price, 'bio', bio, 'status', status,
    'created', (extract(epoch from created_at) * 1000)::bigint) order by created_at desc), '[]') from providers where status = p_status);
end $$;

create or replace function admin_set_status(p_code text, p_id uuid, p_status text) returns boolean language plpgsql security definer set search_path = public as $$
begin
  perform assert_admin(p_code);
  if p_status not in ('pending','approved','rejected','suspended') then raise exception 'forbidden'; end if;
  update providers set status = p_status, last_seen = now() where id = p_id;
  return true;
end $$;

create or replace function admin_reports(p_code text) returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform assert_admin(p_code);
  return (select coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'provider_id', r.provider_id, 'provider_name', p.name, 'provider_status', p.status,
    'reason', r.reason, 'ts', (extract(epoch from r.created_at) * 1000)::bigint) order by r.created_at desc), '[]')
    from reports r join providers p on p.id = r.provider_id where r.status = 'open');
end $$;

create or replace function admin_resolve_report(p_code text, p_id uuid) returns boolean language plpgsql security definer set search_path = public as $$
begin perform assert_admin(p_code); update reports set status = 'resolved' where id = p_id; return true; end $$;

create or replace function admin_stats(p_code text) returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform assert_admin(p_code);
  return jsonb_build_object(
    'providers', (select count(*) from providers where status = 'approved'),
    'pending', (select count(*) from providers where status = 'pending'),
    'requests_week', (select count(*) from requests where created_at > now() - interval '7 days'),
    'reports', (select count(*) from reports where status = 'open'));
end $$;

-- السماح بتنفيذ الدوال العامة فقط (دوال assert_admin وprovider_public وغيرها داخلية)
revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function nearby_providers(double precision, double precision, text, text),
  get_provider(uuid, double precision, double precision), create_request(jsonb), my_requests(text),
  add_review(uuid, text, text, int, text), report_provider(uuid, text, text), register_provider(jsonb),
  provider_self(uuid, text), set_available(uuid, text, boolean), delete_provider(uuid, text),
  admin_check(text), admin_list(text, text), admin_set_status(text, uuid, text), admin_reports(text),
  admin_resolve_report(text, uuid), admin_stats(text) to anon, authenticated;

-- ===== رمز المدير: غيّره قبل التشغيل =====
insert into app_settings(key, value) values ('admin_code', 'CHANGE_ME_ADMIN_CODE')
on conflict (key) do update set value = excluded.value;
