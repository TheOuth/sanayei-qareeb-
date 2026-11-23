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

-- ===== v1.1: ساعات العمل وحالة "متاح" =====
create or replace function in_hours(p providers) returns boolean language sql stable set search_path = public as $$
  select p.work_from is null or p.work_to is null or
    case when p.work_from <= p.work_to
      then (now() at time zone 'Africa/Khartoum')::time between p.work_from::time and p.work_to::time
      else (now() at time zone 'Africa/Khartoum')::time >= p.work_from::time
        or (now() at time zone 'Africa/Khartoum')::time <= p.work_to::time end;
$$;

create or replace function set_hours(p_id uuid, p_token text, p_from text, p_to text) returns boolean language plpgsql security definer set search_path = public as $$
begin
  if p_from !~ '^\d{2}:\d{2}$' or p_to !~ '^\d{2}:\d{2}$' then raise exception 'forbidden'; end if;
  update providers set work_from = p_from, work_to = p_to, last_seen = now() where id = p_id and token = p_token;
  if not found then raise exception 'forbidden'; end if;
  return true;
end $$;

-- منع التخمين: أي رمز مدير خاطئ يتأخر ثانية ونصف
create or replace function assert_admin(p_code text) returns void language plpgsql security definer set search_path = public as $$
begin
  if p_code is null or p_code <> (select value from app_settings where key = 'admin_code') then
    perform pg_sleep(1.5);
    raise exception 'forbidden';
  end if;
end $$;
alter function haversine_km(double precision, double precision, double precision, double precision) set search_path = public;
alter function is_available(providers) set search_path = public;

-- ===== v2: خدمات يديرها المدير + حسابات الصنايعية + إدارة موسعة =====
-- آمن لإعادة التشغيل (idempotent).
create extension if not exists pgcrypto;

alter table providers add column if not exists password_hash text;
alter table providers add column if not exists login_fails int not null default 0;
alter table providers add column if not exists locked_until timestamptz;
alter table providers add column if not exists admin_note text not null default '';

-- ===== الخدمات =====
create table if not exists services (
  id text primary key,
  name text not null,
  icon text not null default '🔧',
  sort int not null default 0,
  active boolean not null default true
);
alter table services enable row level security;
revoke all on services from anon, authenticated;

insert into services (id, name, icon, sort) values
  ('plumbing','سباكة','🔧',10), ('electric','كهرباء','⚡',20), ('solar','طاقة شمسية وبطاريات','☀️',30),
  ('ac','تكييف وتبريد','❄️',40), ('carpentry','نجارة','📐',50), ('blacksmith','حدادة','🔨',60),
  ('paint','نقاشة ودهان','🎨',70), ('building','بناء وسيراميك','🧱',80), ('generator','مولدات','⚙️',90),
  ('water','مضخات ومياه وآبار','💧',100), ('mobile','صيانة موبايلات','📱',110), ('appliance','صيانة أجهزة كهربائية','🔌',120),
  ('transport','توصيل ونقل','🚚',130), ('cleaning','نظافة منزلية','🧹',140), ('tailor','خياطة','🧵',150),
  ('barber','حلاقة وتجميل منزلي','💈',160), ('locks','أقفال ومفاتيح','🔑',170), ('other','أخرى','➕',180)
on conflict (id) do nothing;

create or replace function list_services() returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'name', name, 'icon', icon, 'active', active) order by sort, name), '[]'::jsonb) from services;
$$;

create or replace function app_config() returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'support_whatsapp', coalesce((select value from app_settings where key = 'support_whatsapp'), ''),
    'support_email', coalesce((select value from app_settings where key = 'support_email'), ''));
$$;

-- ===== حسابات الصنايعية =====
create or replace function register_provider(p jsonb) returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare pid uuid; tk text;
begin
  if length(coalesce(p->>'password', '')) < 6 then raise exception 'weak'; end if;
  if jsonb_typeof(p->'services') is distinct from 'array' or jsonb_array_length(p->'services') = 0 then raise exception 'invalid'; end if;
  insert into providers(name, phone, whatsapp, state_id, city_id, hood, lat, lng, radius, services, experience, price, bio, work_from, work_to, password_hash)
  values (left(p->>'name', 80), p->>'phone', p->>'whatsapp', p->>'state_id', p->>'city_id', left(coalesce(p->>'hood',''), 60),
          (p->>'lat')::double precision, (p->>'lng')::double precision, p->>'radius',
          array(select jsonb_array_elements_text(p->'services')), (p->>'experience')::int, (p->>'price')::int,
          left(coalesce(p->>'bio',''), 200), p->>'from', p->>'to', crypt(p->>'password', gen_salt('bf')))
  returning id, token into pid, tk;
  return jsonb_build_object('id', pid, 'token', tk);
end $$;

-- الدخول يرجع ok=false بدل الاستثناء حتى تُحفظ محاولات الفشل (5 محاولات = قفل 15 دقيقة)
create or replace function provider_login(p_phone text, p_password text) returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare pr providers;
begin
  select * into pr from providers where phone = p_phone;
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

create or replace function set_password(p_id uuid, p_token text, p_new text, p_old text default null) returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare pr providers; tk text;
begin
  select * into pr from providers where id = p_id and token = p_token;
  if not found then raise exception 'forbidden'; end if;
  if length(coalesce(p_new, '')) < 6 then raise exception 'weak'; end if;
  if pr.password_hash is not null then
    if p_old is null or pr.password_hash <> crypt(p_old, pr.password_hash) then perform pg_sleep(1); raise exception 'wrong_password'; end if;
    tk := encode(gen_random_bytes(24), 'hex');   -- تغيير كلمة السر يُخرج الأجهزة الأخرى
  else
    tk := pr.token;
  end if;
  update providers set password_hash = crypt(p_new, gen_salt('bf')), token = tk where id = p_id;
  return jsonb_build_object('token', tk);
end $$;

create or replace function provider_self(p_id uuid, p_token text) returns jsonb language plpgsql security definer set search_path = public as $$
declare pr providers; res jsonb;
begin
  select * into pr from providers where id = p_id and token = p_token;
  if not found then raise exception 'forbidden'; end if;
  update providers set last_seen = now() where id = p_id;
  select * into pr from providers where id = p_id;
  res := provider_public(pr, null) || jsonb_build_object('status', pr.status, 'flag', pr.available, 'in_hours', in_hours(pr),
    'radius', pr.radius, 'has_password', pr.password_hash is not null,
    'requests_week', (select count(*) from requests where provider_id = p_id and created_at > now() - interval '7 days'));
  return res;
end $$;

-- تعديل الملف (داخلي): الصنايعي والمدير يستخدمانه
create or replace function apply_profile(p_id uuid, p jsonb, p_admin boolean) returns void language plpgsql security definer set search_path = public as $$
begin
  if p ? 'services' and (jsonb_typeof(p->'services') is distinct from 'array' or jsonb_array_length(p->'services') = 0) then raise exception 'invalid'; end if;
  update providers set
    name = coalesce(nullif(left(trim(p->>'name'), 80), ''), name),
    whatsapp = coalesce(nullif(p->>'whatsapp', ''), whatsapp),
    phone = case when p_admin and nullif(p->>'phone', '') is not null then p->>'phone' else phone end,
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
    work_from = coalesce(nullif(p->>'from', ''), work_from),
    work_to = coalesce(nullif(p->>'to', ''), work_to),
    admin_note = case when p_admin and p ? 'admin_note' then left(coalesce(p->>'admin_note', ''), 500) else admin_note end
  where id = p_id;
end $$;

create or replace function update_profile(p_id uuid, p_token text, p jsonb) returns boolean language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from providers where id = p_id and token = p_token) then raise exception 'forbidden'; end if;
  perform apply_profile(p_id, p, false);
  return true;
end $$;

-- ===== دوال المدير الموسعة =====
create or replace function admin_overview(p_code text) returns jsonb language plpgsql security definer set search_path = public as $$
declare today date := (now() at time zone 'Africa/Khartoum')::date;
begin
  perform assert_admin(p_code);
  return jsonb_build_object(
    'approved', (select count(*) from providers where status = 'approved'),
    'pending', (select count(*) from providers where status = 'pending'),
    'suspended', (select count(*) from providers where status = 'suspended'),
    'rejected', (select count(*) from providers where status = 'rejected'),
    'available_now', (select count(*) from providers p where p.status = 'approved' and is_available(p)),
    'requests_today', (select count(*) from requests where (created_at at time zone 'Africa/Khartoum')::date = today),
    'requests_week', (select count(*) from requests where created_at > now() - interval '7 days'),
    'requests_total', (select count(*) from requests),
    'reviews_total', (select count(*) from reviews),
    'avg_rating', (select round(coalesce(avg(stars), 0)::numeric, 1) from reviews),
    'reports_open', (select count(*) from reports where status = 'open'),
    'by_day', (select jsonb_agg(jsonb_build_object('d', to_char(g, 'MM-DD'), 'n', coalesce(c.n, 0)) order by g)
               from generate_series(today - 6, today, interval '1 day') g
               left join (select (created_at at time zone 'Africa/Khartoum')::date dd, count(*) n from requests group by 1) c on c.dd = g::date),
    'top_services', (select coalesce(jsonb_agg(t order by (t->>'requests_week')::int desc, (t->>'providers')::int desc), '[]'::jsonb) from (
        select jsonb_build_object('id', s.id, 'name', s.name, 'icon', s.icon,
          'providers', (select count(*) from providers p where p.status = 'approved' and s.id = any(p.services)),
          'requests_week', (select count(*) from requests r where r.service = s.id and r.created_at > now() - interval '7 days')) t
        from services s order by 1 limit 8) z),
    'by_city', (select coalesce(jsonb_agg(jsonb_build_object('city_id', city_id, 'n', n) order by n desc), '[]'::jsonb)
                from (select city_id, count(*) n from providers where status = 'approved' group by 1 order by 2 desc limit 8) y)
  );
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
    select p.*, is_available(p) as av_now, row_number() over (order by (p.status <> 'pending'), p.created_at desc) rn from providers p
    where (coalesce(p_status, '') = '' or p.status = p_status) and (coalesce(p_service, '') = '' or p_service = any(p.services))
      and (coalesce(p_city, '') = '' or p.city_id = p_city)
      and (coalesce(p_q, '') = '' or p.name ilike '%' || p_q || '%' or (qd <> '' and p.phone like '%' || qd || '%'))
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', f.id, 'name', f.name, 'phone', f.phone, 'whatsapp', f.whatsapp, 'services', to_jsonb(f.services), 'state_id', f.state_id, 'city_id', f.city_id,
      'hood', f.hood, 'radius', f.radius, 'experience', f.experience, 'price', f.price, 'bio', f.bio, 'from', f.work_from, 'to', f.work_to,
      'status', f.status, 'available', f.av_now, 'flag', f.available, 'has_password', f.password_hash is not null, 'admin_note', f.admin_note,
      'last_seen', (extract(epoch from f.last_seen) * 1000)::bigint, 'created', (extract(epoch from f.created_at) * 1000)::bigint,
      'requests_total', rq.rt, 'requests_week', rq.rw, 'rating_n', rv.n, 'rating', case when rv.n > 0 then round(rv.av::numeric, 1) else null end, 'ok', rv.ok, 'fail', rv.fail
    ) order by f.rn), '[]'::jsonb) into items
  from f
  left join lateral (select count(*)::int rt, (count(*) filter (where r.created_at > now() - interval '7 days'))::int rw from requests r where r.provider_id = f.id) rq on true
  left join lateral (select count(*)::int n, coalesce(avg(v.stars), 0) av, (count(*) filter (where v.success))::int ok, (count(*) filter (where not v.success))::int fail from reviews v where v.provider_id = f.id) rv on true
  where f.rn > off and f.rn <= off + lim;
  return jsonb_build_object('total', total, 'items', items);
end $$;

create or replace function admin_update_provider(p_code text, p_id uuid, p jsonb) returns boolean language plpgsql security definer set search_path = public as $$
begin
  perform assert_admin(p_code);
  perform apply_profile(p_id, p, true);
  return true;
end $$;

create or replace function admin_create_provider(p_code text, p jsonb) returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare pid uuid;
begin
  perform assert_admin(p_code);
  if length(coalesce(p->>'password', '')) < 6 then raise exception 'weak'; end if;
  if jsonb_typeof(p->'services') is distinct from 'array' or jsonb_array_length(p->'services') = 0 then raise exception 'invalid'; end if;
  insert into providers(name, phone, whatsapp, state_id, city_id, hood, lat, lng, radius, services, experience, price, bio, work_from, work_to, status, password_hash, admin_note)
  values (left(p->>'name', 80), p->>'phone', coalesce(nullif(p->>'whatsapp', ''), p->>'phone'), p->>'state_id', p->>'city_id', left(coalesce(p->>'hood', ''), 60),
          (p->>'lat')::double precision, (p->>'lng')::double precision, coalesce(nullif(p->>'radius', ''), '10'),
          array(select jsonb_array_elements_text(p->'services')), coalesce((p->>'experience')::int, 0), coalesce((p->>'price')::int, 0),
          left(coalesce(p->>'bio', ''), 200), coalesce(nullif(p->>'from', ''), '08:00'), coalesce(nullif(p->>'to', ''), '20:00'),
          'approved', crypt(p->>'password', gen_salt('bf')), left(coalesce(p->>'admin_note', ''), 500))
  returning id into pid;
  return jsonb_build_object('id', pid);
end $$;

create or replace function admin_reset_password(p_code text, p_id uuid, p_password text) returns boolean language plpgsql security definer set search_path = public, extensions as $$
begin
  perform assert_admin(p_code);
  if length(coalesce(p_password, '')) < 6 then raise exception 'weak'; end if;
  update providers set password_hash = crypt(p_password, gen_salt('bf')), token = encode(gen_random_bytes(24), 'hex'), login_fails = 0, locked_until = null where id = p_id;
  return true;
end $$;

create or replace function admin_delete_provider(p_code text, p_id uuid) returns boolean language plpgsql security definer set search_path = public as $$
begin perform assert_admin(p_code); delete from providers where id = p_id; return true; end $$;

create or replace function admin_requests(p_code text, p_limit int, p_status text) returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform assert_admin(p_code);
  return (select coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'provider_id', r.provider_id, 'provider_name', p.name, 'service', r.service, 'city_id', r.city_id,
      'channel', r.channel, 'status', r.status, 'ts', (extract(epoch from r.created_at) * 1000)::bigint) order by r.created_at desc), '[]'::jsonb)
    from (select * from requests where coalesce(p_status, '') = '' or status = p_status order by created_at desc limit greatest(1, least(coalesce(p_limit, 100), 500))) r
    join providers p on p.id = r.provider_id);
end $$;

-- ===== إدارة الخدمات =====
create or replace function admin_services(p_code text) returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform assert_admin(p_code);
  return (select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name, 'icon', s.icon, 'active', s.active, 'sort', s.sort,
      'providers', (select count(*) from providers p where s.id = any(p.services))) order by s.sort, s.name), '[]'::jsonb) from services s);
end $$;

create or replace function admin_save_service(p_code text, p_id text, p_name text, p_icon text, p_active boolean) returns text language plpgsql security definer set search_path = public as $$
declare sid text := nullif(p_id, '');
begin
  perform assert_admin(p_code);
  if length(trim(coalesce(p_name, ''))) < 2 then raise exception 'invalid'; end if;
  if sid is null then
    sid := 's' || substr(md5(random()::text || clock_timestamp()::text), 1, 8);
    insert into services(id, name, icon, sort, active)
      values (sid, left(trim(p_name), 40), left(coalesce(nullif(trim(p_icon), ''), '🔧'), 8), coalesce((select max(sort) from services), 0) + 10, coalesce(p_active, true));
  else
    update services set name = left(trim(p_name), 40), icon = left(coalesce(nullif(trim(p_icon), ''), icon), 8), active = coalesce(p_active, active) where id = sid;
    if not found then raise exception 'not_found'; end if;
  end if;
  return sid;
end $$;

create or replace function admin_reorder_services(p_code text, p_ids jsonb) returns boolean language plpgsql security definer set search_path = public as $$
declare i int := 0; sid text;
begin
  perform assert_admin(p_code);
  for sid in select jsonb_array_elements_text(p_ids) loop
    i := i + 10;
    update services set sort = i where id = sid;
  end loop;
  return true;
end $$;

create or replace function admin_delete_service(p_code text, p_id text) returns boolean language plpgsql security definer set search_path = public as $$
begin
  perform assert_admin(p_code);
  if exists (select 1 from providers where p_id = any(services)) then raise exception 'in_use'; end if;
  delete from services where id = p_id;
  return true;
end $$;

-- ===== إعدادات المدير =====
create or replace function admin_get_settings(p_code text) returns jsonb language plpgsql security definer set search_path = public as $$
begin perform assert_admin(p_code); return app_config(); end $$;

create or replace function admin_save_settings(p_code text, p jsonb) returns boolean language plpgsql security definer set search_path = public as $$
begin
  perform assert_admin(p_code);
  insert into app_settings(key, value) values ('support_whatsapp', left(coalesce(p->>'support_whatsapp', ''), 30)) on conflict (key) do nothing;
  insert into app_settings(key, value) values ('support_email', left(coalesce(p->>'support_email', ''), 100)) on conflict (key) do nothing;
  return true;
end $$;

create or replace function admin_change_code(p_code text, p_new text) returns boolean language plpgsql security definer set search_path = public as $$
begin
  perform assert_admin(p_code);
  if length(coalesce(p_new, '')) < 8 then raise exception 'weak'; end if;
  update app_settings set value = p_new where key = 'admin_code';
  return true;
end $$;

-- ===== الصلاحيات: فقط هذه الدوال العامة تُستدعى من التطبيق =====
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

-- ===== رمز المدير: غيّره قبل التشغيل =====
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

-- ===== v5: عرض الصنايعية في الرئيسية (شبكة) =====
-- آمن لإعادة التشغيل. يُشغَّل بعد v4.
create or replace function featured_providers(p_lat double precision, p_lng double precision, p_limit int, p_offset int)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare lim int := greatest(1, least(coalesce(p_limit, 12), 24)); off int := greatest(0, coalesce(p_offset, 0)); items jsonb; n int;
begin
  with c as (
    select p, case when p_lat is null or p_lng is null then null else haversine_km(p_lat, p_lng, p.lat, p.lng) end d,
           (select coalesce(avg(stars),0) from reviews r where r.provider_id = p.id) av,
           (select count(*) from reviews r where r.provider_id = p.id) rn,
           (select count(*) from reviews r where r.provider_id = p.id and success) ok,
           profile_pct(p) + (case when p.verified then 20 else 0 end)
             + least((select count(*) from requests q where q.provider_id = p.id and q.created_at > now() - interval '30 days'), 10)::int * 5 score,
           is_available(p) av_now
    from providers p where p.status = 'approved'
  ), o as (
    select *, coalesce(floor(d / 3), 0) band, case when rn >= 3 then av else 0 end sav from c
  ), pg as (
    select * from o order by av_now desc, band, score desc, sav desc, ok desc, d nulls last, (p).created_at limit lim + 1 offset off
  )
  select coalesce(jsonb_agg(provider_public(p, d) order by av_now desc, band, score desc, sav desc, ok desc, d nulls last), '[]'::jsonb), count(*) into items, n
  from (select * from pg limit lim) z;
  return jsonb_build_object('items', items,
    'more', exists (select 1 from providers where status = 'approved' offset off + lim));
end $$;
revoke execute on function featured_providers(double precision, double precision, int, int) from public;
grant execute on function featured_providers(double precision, double precision, int, int) to anon, authenticated;

insert into app_settings(key, value) values ('admin_code', 'CHANGE_ME_ADMIN_CODE')
on conflict (key) do nothing;
-- ===== v6: تأكيد الطلب من الطرفين (الزبون + الصنايعي) وتقرير الطلبات المؤكدة =====
-- آمن لإعادة التشغيل. يُشغَّل بعد v5.
alter table requests add column if not exists prov_confirm text check (prov_confirm in ('done', 'not_done'));
alter table requests add column if not exists prov_amount numeric(12, 0) check (prov_amount is null or (prov_amount >= 0 and prov_amount <= 1000000000));
alter table requests add column if not exists prov_at timestamptz;

-- طلبات الصنايعي (آخر 60 يوما). لا تكشف هوية الزبون.
create or replace function provider_requests(p_id uuid, p_token text) returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not exists (select 1 from providers where id = p_id and token = p_token) then raise exception 'forbidden'; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'service', r.service, 'channel', r.channel,
      'client', r.status, 'confirm', r.prov_confirm, 'amount', r.prov_amount,
      'ts', (extract(epoch from r.created_at) * 1000)::bigint) order by r.created_at desc), '[]'::jsonb)
    from (select * from requests where provider_id = p_id and created_at > now() - interval '60 days' order by created_at desc limit 40) r);
end $$;

create or replace function provider_confirm_request(p_id uuid, p_token text, p_request uuid, p_done boolean, p_amount numeric) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from providers where id = p_id and token = p_token) then raise exception 'forbidden'; end if;
  update requests set prov_confirm = case when p_done then 'done' else 'not_done' end,
      prov_amount = case when p_done and p_amount is not null and p_amount >= 0 then round(least(p_amount, 1000000000)) else null end,
      prov_at = now()
    where id = p_request and provider_id = p_id;
  if not found then raise exception 'not_found'; end if;
  return true;
end $$;

-- تقرير المدير: الطلبات حسب تأكيد الطرفين لكل صنايعي
create or replace function admin_confirm_report(p_code text, p_days int) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare d int := greatest(1, least(coalesce(p_days, 30), 365));
begin
  perform assert_admin(p_code);
  return (select coalesce(jsonb_agg(x order by (x->>'both')::int desc, (x->>'total')::int desc), '[]'::jsonb) from (
    select jsonb_build_object('provider_id', p.id, 'name', p.name, 'phone', p.phone, 'verified', p.verified,
      'total', count(*), 'client_done', count(*) filter (where r.status = 'done'), 'provider_done', count(*) filter (where r.prov_confirm = 'done'),
      'both', count(*) filter (where r.status = 'done' and r.prov_confirm = 'done'),
      'mismatch', count(*) filter (where (r.status = 'done' and r.prov_confirm = 'not_done') or (r.status in ('failed', 'not_agreed') and r.prov_confirm = 'done')),
      'amount', coalesce(sum(r.prov_amount) filter (where r.status = 'done' and r.prov_confirm = 'done'), 0)) x
    from requests r join providers p on p.id = r.provider_id
    where r.created_at > now() - make_interval(days => d)
    group by p.id, p.name, p.phone, p.verified) t);
end $$;

create or replace function admin_requests(p_code text, p_limit int, p_status text) returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform assert_admin(p_code);
  return (select coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'provider_id', r.provider_id, 'provider_name', p.name, 'service', r.service, 'city_id', r.city_id,
      'channel', r.channel, 'status', r.status, 'confirm', r.prov_confirm, 'amount', r.prov_amount, 'ts', (extract(epoch from r.created_at) * 1000)::bigint) order by r.created_at desc), '[]'::jsonb)
    from (select * from requests where coalesce(p_status, '') = '' or status = p_status order by created_at desc limit greatest(1, least(coalesce(p_limit, 100), 500))) r
    join providers p on p.id = r.provider_id);
end $$;

revoke execute on function provider_requests(uuid, text), provider_confirm_request(uuid, text, uuid, boolean, numeric), admin_confirm_report(text, int) from public, anon, authenticated;
grant execute on function provider_requests(uuid, text), provider_confirm_request(uuid, text, uuid, boolean, numeric), admin_confirm_report(text, int) to anon, authenticated;
-- ===== v7: ملاحظة التوثيق + شارات الإنجاز + عمولة الطلب =====
-- آمن لإعادة التشغيل. يُشغَّل بعد v6.
alter table providers add column if not exists verify_doc text not null default '';
alter table providers add column if not exists verified_at timestamptz;

-- الأعمال المؤكدة: عملاء مختلفون قالوا "تمت الخدمة" ولم يعترض الصنايعي (يمنع تكرار الطلبات من جهاز واحد)
create or replace function job_count(p_id uuid) returns int language sql stable security definer set search_path = public as $$
  select count(distinct anon_id)::int from requests where provider_id = p_id and status = 'done' and coalesce(prov_confirm, '') <> 'not_done';
$$;

create or replace function provider_public(p providers, p_dist double precision) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', p.id, 'name', p.name, 'services', to_jsonb(p.services), 'state_id', p.state_id, 'city_id', p.city_id,
    'hood', p.hood, 'experience', p.experience, 'price', p.price, 'bio', p.bio, 'from', p.work_from, 'to', p.work_to,
    'available', is_available(p), 'photo', p.photo, 'verified', p.verified, 'jobs', job_count(p.id),
    'distance_km', case when p_dist is null then null else round(p_dist::numeric, 1) end,
    'rating', case when s.n >= 3 then round(s.avg::numeric, 1) else null end,
    'rating_n', s.n, 'ok', s.ok, 'fail', s.fail,
    'phone', p.phone, 'whatsapp', p.whatsapp, 'demo', false)
  from (select count(*)::int n, coalesce(avg(stars), 0) avg,
               count(*) filter (where success)::int ok, count(*) filter (where not success)::int fail
        from reviews where provider_id = p.id) s;
$$;

drop function if exists admin_set_verified(text, uuid, boolean);
create or replace function admin_set_verified(p_code text, p_id uuid, p_value boolean, p_doc text default null) returns boolean language plpgsql security definer set search_path = public as $$
begin
  perform assert_admin(p_code);
  update providers set verified = coalesce(p_value, false),
    verify_doc = case when coalesce(p_value, false) then coalesce(left(p_doc, 200), verify_doc) else '' end,
    verified_at = case when coalesce(p_value, false) then coalesce(verified_at, now()) else null end
  where id = p_id;
  return true;
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
      'photo', f.photo, 'verified', f.verified, 'verify_doc', f.verify_doc, 'verified_at', (extract(epoch from f.verified_at) * 1000)::bigint, 'pct', f.pct_now, 'status', f.status, 'available', f.av_now, 'flag', f.available, 'has_password', f.password_hash is not null, 'admin_note', f.admin_note,
      'last_seen', (extract(epoch from f.last_seen) * 1000)::bigint, 'created', (extract(epoch from f.created_at) * 1000)::bigint,
      'requests_total', rq.rt, 'requests_week', rq.rw, 'rating_n', rv.n, 'rating', case when rv.n > 0 then round(rv.av::numeric, 1) else null end, 'ok', rv.ok, 'fail', rv.fail
    ) order by f.rn), '[]'::jsonb) into items
  from f
  left join lateral (select count(*)::int rt, (count(*) filter (where r.created_at > now() - interval '7 days'))::int rw from requests r where r.provider_id = f.id) rq on true
  left join lateral (select count(*)::int n, coalesce(avg(v.stars), 0) av, (count(*) filter (where v.success))::int ok, (count(*) filter (where not v.success))::int fail from reviews v where v.provider_id = f.id) rv on true
  where f.rn > off and f.rn <= off + lim;
  return jsonb_build_object('total', total, 'items', items);
end $$;

create or replace function app_config() returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'support_whatsapp', coalesce((select value from app_settings where key = 'support_whatsapp'), ''),
    'support_email', coalesce((select value from app_settings where key = 'support_email'), ''),
    'commission_pct', coalesce((select value from app_settings where key = 'commission_pct'), '0')::numeric,
    'commission_fixed', coalesce((select value from app_settings where key = 'commission_fixed'), '0')::numeric);
$$;

create or replace function admin_save_settings(p_code text, p jsonb) returns boolean language plpgsql security definer set search_path = public as $$
declare cp numeric := greatest(0, least(coalesce(nullif(p->>'commission_pct', '')::numeric, 0), 30)); cf numeric := greatest(0, least(coalesce(nullif(p->>'commission_fixed', '')::numeric, 0), 100000));
begin
  perform assert_admin(p_code);
  insert into app_settings(key, value) values ('support_whatsapp', left(coalesce(p->>'support_whatsapp', ''), 30)) on conflict (key) do update set value = excluded.value;
  insert into app_settings(key, value) values ('support_email', left(coalesce(p->>'support_email', ''), 100)) on conflict (key) do update set value = excluded.value;
  insert into app_settings(key, value) values ('commission_pct', cp::text) on conflict (key) do update set value = excluded.value;
  insert into app_settings(key, value) values ('commission_fixed', cf::text) on conflict (key) do update set value = excluded.value;
  return true;
end $$;

revoke execute on function job_count(uuid), admin_set_verified(text, uuid, boolean, text), app_config(), admin_save_settings(text, jsonb) from public, anon, authenticated;
grant execute on function admin_set_verified(text, uuid, boolean, text), app_config(), admin_save_settings(text, jsonb) to anon, authenticated;
-- ===== v8: سجل دفعيات العمولة =====
-- آمن لإعادة التشغيل. يُشغَّل بعد v7.
create table if not exists commission_payments (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references providers(id) on delete cascade,
  amount numeric(12, 0) not null check (amount > 0 and amount <= 100000000),
  note text not null default '',
  paid_at timestamptz not null default now()
);
create index if not exists commission_payments_provider on commission_payments(provider_id, paid_at desc);
alter table commission_payments enable row level security;
revoke all on commission_payments from anon, authenticated;

create or replace function admin_add_payment(p_code text, p_id uuid, p_amount numeric, p_note text) returns uuid language plpgsql security definer set search_path = public as $$
declare pid uuid;
begin
  perform assert_admin(p_code);
  if p_amount is null or p_amount <= 0 or p_amount > 100000000 then raise exception 'invalid'; end if;
  if not exists (select 1 from providers where id = p_id) then raise exception 'not_found'; end if;
  insert into commission_payments(provider_id, amount, note) values (p_id, round(p_amount), left(coalesce(p_note, ''), 200)) returning id into pid;
  return pid;
end $$;

create or replace function admin_delete_payment(p_code text, p_pid uuid) returns boolean language plpgsql security definer set search_path = public as $$
begin
  perform assert_admin(p_code);
  delete from commission_payments where id = p_pid;
  return true;
end $$;

create or replace function admin_commission_ledger(p_code text) returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform assert_admin(p_code);
  return (select coalesce(jsonb_agg(x order by (x->>'jobs')::int desc, x->>'name'), '[]'::jsonb) from (
    select jsonb_build_object('provider_id', p.id, 'name', p.name, 'phone', p.phone,
      'jobs', (select count(*) from requests r where r.provider_id = p.id and r.status = 'done' and r.prov_confirm = 'done'),
      'paid', coalesce((select sum(c.amount) from commission_payments c where c.provider_id = p.id), 0),
      'pay_count', (select count(*) from commission_payments c where c.provider_id = p.id),
      'last_paid', (select (extract(epoch from max(c.paid_at)) * 1000)::bigint from commission_payments c where c.provider_id = p.id),
      'payments', (select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'amount', c.amount, 'note', c.note, 'ts', (extract(epoch from c.paid_at) * 1000)::bigint) order by c.paid_at desc), '[]'::jsonb)
                   from (select * from commission_payments where provider_id = p.id order by paid_at desc limit 30) c)) x
    from providers p
    where exists (select 1 from requests r where r.provider_id = p.id and r.status = 'done' and r.prov_confirm = 'done')
       or exists (select 1 from commission_payments c where c.provider_id = p.id)) t);
end $$;

revoke execute on function admin_add_payment(text, uuid, numeric, text), admin_delete_payment(text, uuid), admin_commission_ledger(text) from public, anon, authenticated;
grant execute on function admin_add_payment(text, uuid, numeric, text), admin_delete_payment(text, uuid), admin_commission_ledger(text) to anon, authenticated;
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
-- ===== v10: اسم مستخدم تلقائي لكل صنايعي (رابط مشاركة قصير) =====
-- آمن لإعادة التشغيل. يُشغَّل بعد v9.
alter table providers add column if not exists username text;
alter table providers add column if not exists username_changed boolean not null default false;

create or replace function gen_username() returns text language plpgsql volatile set search_path = public as $$
declare u text; i int := 0;
begin
  loop
    u := 's' || substr(translate(md5(random()::text || clock_timestamp()::text), '0123456789abcdef', '2345679acdefghkm'), 1, 6);
    exit when not exists (select 1 from providers where username = u);
    i := i + 1; if i > 20 then u := 's' || substr(md5(random()::text), 1, 10); exit; end if;
  end loop;
  return u;
end $$;

update providers set username = gen_username() where username is null;
create unique index if not exists providers_username_uq on providers(lower(username));

create or replace function providers_set_username() returns trigger language plpgsql set search_path = public as $$
begin
  if new.username is null or new.username = '' then new.username := gen_username(); end if;
  return new;
end $$;
drop trigger if exists providers_username_bi on providers;
create trigger providers_username_bi before insert on providers for each row execute function providers_set_username();

create or replace function check_username(p text) returns text language plpgsql immutable set search_path = public as $$
declare u text := lower(trim(coalesce(p, '')));
begin
  if u !~ '^[a-z][a-z0-9_]{2,19}$' then raise exception 'invalid_username'; end if;
  if u = any(array['admin', 'support', 'sanayei', 'app', 'help', 'api', 'null', 'root', 'www']) then raise exception 'invalid_username'; end if;
  return u;
end $$;

-- يغيّره الصنايعي مرة واحدة فقط
create or replace function set_username(p_id uuid, p_token text, p_username text) returns text language plpgsql security definer set search_path = public as $$
declare u text; pr providers;
begin
  select * into pr from providers where id = p_id and token = p_token;
  if not found then raise exception 'forbidden'; end if;
  if pr.username_changed then raise exception 'already'; end if;
  u := check_username(p_username);
  if exists (select 1 from providers where lower(username) = u and id <> p_id) then raise exception 'taken'; end if;
  update providers set username = u, username_changed = true where id = p_id;
  return u;
end $$;

-- المدير يعدّله متى شاء (بلا استهلاك مرة الصنايعي)
create or replace function admin_set_username(p_code text, p_id uuid, p_username text) returns text language plpgsql security definer set search_path = public as $$
declare u text;
begin
  perform assert_admin(p_code);
  u := check_username(p_username);
  if exists (select 1 from providers where lower(username) = u and id <> p_id) then raise exception 'taken'; end if;
  update providers set username = u where id = p_id;
  return u;
end $$;

-- رابط المشاركة: اسم المستخدم -> معرّف الصنايعي (المعتمدون فقط)
create or replace function provider_id_by_username(p text) returns uuid language sql stable security definer set search_path = public as $$
  select id from providers where lower(username) = lower(trim(p)) and status = 'approved' limit 1;
$$;

create or replace function provider_public(p providers, p_dist double precision) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', p.id, 'name', p.name, 'services', to_jsonb(p.services), 'state_id', p.state_id, 'city_id', p.city_id,
    'hood', p.hood, 'experience', p.experience, 'price', p.price, 'bio', p.bio, 'from', p.work_from, 'to', p.work_to,
    'available', is_available(p), 'photo', p.photo, 'verified', p.verified, 'jobs', job_count(p.id), 'username', p.username, 'age', case when p.birth_date is null then null else date_part('year', age(p.birth_date))::int end,
    'distance_km', case when p_dist is null then null else round(p_dist::numeric, 1) end,
    'rating', case when s.n >= 3 then round(s.avg::numeric, 1) else null end,
    'rating_n', s.n, 'ok', s.ok, 'fail', s.fail,
    'phone', p.phone, 'whatsapp', p.whatsapp, 'demo', false)
  from (select count(*)::int n, coalesce(avg(stars), 0) avg,
               count(*) filter (where success)::int ok, count(*) filter (where not success)::int fail
        from reviews where provider_id = p.id) s;
$$;

create or replace function provider_self(p_id uuid, p_token text) returns jsonb language plpgsql security definer set search_path = public as $$
declare pr providers; res jsonb;
begin
  select * into pr from providers where id = p_id and token = p_token;
  if not found then raise exception 'forbidden'; end if;
  update providers set last_seen = now() where id = p_id;
  select * into pr from providers where id = p_id;
  res := provider_public(pr, null) || jsonb_build_object('status', pr.status, 'flag', pr.available, 'in_hours', in_hours(pr),
    'radius', pr.radius, 'has_password', pr.password_hash is not null, 'pct', profile_pct(pr), 'verified', pr.verified, 'birth_date', pr.birth_date, 'username_changed', pr.username_changed,
    'requests_week', (select count(*) from requests where provider_id = p_id and created_at > now() - interval '7 days'));
  return res;
end $$;

create or replace function admin_providers(p_code text, p_q text, p_status text, p_service text, p_city text, p_limit int, p_offset int) returns jsonb
language plpgsql security definer set search_path = public as $$
declare qd text := ltrim(regexp_replace(coalesce(p_q, ''), '\D', '', 'g'), '0'); total int; items jsonb; lim int := greatest(1, least(coalesce(p_limit, 30), 1000)); off int := greatest(0, coalesce(p_offset, 0));
begin
  perform assert_admin(p_code);
  select count(*) into total from providers p
    where (coalesce(p_status, '') = '' or p.status = p_status) and (coalesce(p_service, '') = '' or p_service = any(p.services))
      and (coalesce(p_city, '') = '' or p.city_id = p_city)
      and (coalesce(p_q, '') = '' or p.name ilike '%' || p_q || '%' or p.username ilike '%' || p_q || '%' or (qd <> '' and p.phone like '%' || qd || '%'));
  with f as (
    select p.*, is_available(p) as av_now, profile_pct(p) as pct_now, row_number() over (order by (p.status <> 'pending'), p.created_at desc) rn from providers p
    where (coalesce(p_status, '') = '' or p.status = p_status) and (coalesce(p_service, '') = '' or p_service = any(p.services))
      and (coalesce(p_city, '') = '' or p.city_id = p_city)
      and (coalesce(p_q, '') = '' or p.name ilike '%' || p_q || '%' or p.username ilike '%' || p_q || '%' or (qd <> '' and p.phone like '%' || qd || '%'))
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', f.id, 'name', f.name, 'phone', f.phone, 'whatsapp', f.whatsapp, 'services', to_jsonb(f.services), 'state_id', f.state_id, 'city_id', f.city_id,
      'hood', f.hood, 'radius', f.radius, 'experience', f.experience, 'price', f.price, 'bio', f.bio, 'from', f.work_from, 'to', f.work_to,
      'photo', f.photo, 'verified', f.verified, 'username', f.username, 'username_changed', f.username_changed, 'jobs', job_count(f.id), 'birth_date', f.birth_date, 'age', case when f.birth_date is null then null else date_part('year', age(f.birth_date))::int end, 'verify_doc', f.verify_doc, 'verified_at', (extract(epoch from f.verified_at) * 1000)::bigint, 'pct', f.pct_now, 'status', f.status, 'available', f.av_now, 'flag', f.available, 'has_password', f.password_hash is not null, 'admin_note', f.admin_note,
      'last_seen', (extract(epoch from f.last_seen) * 1000)::bigint, 'created', (extract(epoch from f.created_at) * 1000)::bigint,
      'requests_total', rq.rt, 'requests_week', rq.rw, 'rating_n', rv.n, 'rating', case when rv.n > 0 then round(rv.av::numeric, 1) else null end, 'ok', rv.ok, 'fail', rv.fail
    ) order by f.rn), '[]'::jsonb) into items
  from f
  left join lateral (select count(*)::int rt, (count(*) filter (where r.created_at > now() - interval '7 days'))::int rw from requests r where r.provider_id = f.id) rq on true
  left join lateral (select count(*)::int n, coalesce(avg(v.stars), 0) av, (count(*) filter (where v.success))::int ok, (count(*) filter (where not v.success))::int fail from reviews v where v.provider_id = f.id) rv on true
  where f.rn > off and f.rn <= off + lim;
  return jsonb_build_object('total', total, 'items', items);
end $$;

revoke execute on function gen_username(), providers_set_username(), check_username(text) from public, anon, authenticated;
revoke execute on function set_username(uuid, text, text), admin_set_username(text, uuid, text), provider_id_by_username(text) from public, anon, authenticated;
grant execute on function set_username(uuid, text, text), admin_set_username(text, uuid, text), provider_id_by_username(text) to anon, authenticated;
-- ===== v11: البريد الإلكتروني الاختياري (يُضاف من تعديل الملف، للرسائل اليدوية والتحقق لاحقًا) =====
alter table providers add column if not exists email text;
alter table providers add column if not exists email_verified boolean not null default false;

create or replace function check_email(p text) returns text language plpgsql immutable set search_path = public as $$
declare e text := lower(trim(coalesce(p, '')));
begin
  if e = '' then return null; end if;
  if length(e) > 120 or e !~ '^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$' then raise exception 'invalid_email'; end if;
  return e;
end $$;

create or replace function apply_profile(p_id uuid, p jsonb, p_admin boolean) returns void language plpgsql security definer set search_path = public as $$
declare wa text; ph text; bd date; em text;
begin
  if p ? 'services' and (jsonb_typeof(p->'services') is distinct from 'array' or jsonb_array_length(p->'services') = 0) then raise exception 'invalid'; end if;
  if nullif(p->>'whatsapp', '') is not null then wa := norm_phone(p->>'whatsapp'); if wa is null then raise exception 'invalid_phone'; end if; end if;
  if p_admin and nullif(p->>'phone', '') is not null then ph := norm_phone(p->>'phone'); if ph is null then raise exception 'invalid_phone'; end if; end if;
  if p ? 'email' then em := check_email(p->>'email'); end if;
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
    email = case when p ? 'email' then em else email end,
    work_from = coalesce(nullif(p->>'from', ''), work_from),
    work_to = coalesce(nullif(p->>'to', ''), work_to),
    admin_note = case when p_admin and p ? 'admin_note' then left(coalesce(p->>'admin_note', ''), 500) else admin_note end
  where id = p_id;
end $$;

create or replace function provider_self(p_id uuid, p_token text) returns jsonb language plpgsql security definer set search_path = public as $$
declare pr providers; res jsonb;
begin
  select * into pr from providers where id = p_id and token = p_token;
  if not found then raise exception 'forbidden'; end if;
  update providers set last_seen = now() where id = p_id;
  select * into pr from providers where id = p_id;
  res := provider_public(pr, null) || jsonb_build_object('status', pr.status, 'flag', pr.available, 'in_hours', in_hours(pr),
    'radius', pr.radius, 'has_password', pr.password_hash is not null, 'pct', profile_pct(pr), 'verified', pr.verified, 'birth_date', pr.birth_date, 'email', pr.email, 'username_changed', pr.username_changed,
    'requests_week', (select count(*) from requests where provider_id = p_id and created_at > now() - interval '7 days'));
  return res;
end $$;

create or replace function admin_providers(p_code text, p_q text, p_status text, p_service text, p_city text, p_limit int, p_offset int) returns jsonb
language plpgsql security definer set search_path = public as $$
declare qd text := ltrim(regexp_replace(coalesce(p_q, ''), '\D', '', 'g'), '0'); total int; items jsonb; lim int := greatest(1, least(coalesce(p_limit, 30), 1000)); off int := greatest(0, coalesce(p_offset, 0));
begin
  perform assert_admin(p_code);
  select count(*) into total from providers p
    where (coalesce(p_status, '') = '' or p.status = p_status) and (coalesce(p_service, '') = '' or p_service = any(p.services))
      and (coalesce(p_city, '') = '' or p.city_id = p_city)
      and (coalesce(p_q, '') = '' or p.name ilike '%' || p_q || '%' or p.username ilike '%' || p_q || '%' or p.email ilike '%' || p_q || '%' or (qd <> '' and p.phone like '%' || qd || '%'));
  with f as (
    select p.*, is_available(p) as av_now, profile_pct(p) as pct_now, row_number() over (order by (p.status <> 'pending'), p.created_at desc) rn from providers p
    where (coalesce(p_status, '') = '' or p.status = p_status) and (coalesce(p_service, '') = '' or p_service = any(p.services))
      and (coalesce(p_city, '') = '' or p.city_id = p_city)
      and (coalesce(p_q, '') = '' or p.name ilike '%' || p_q || '%' or p.username ilike '%' || p_q || '%' or p.email ilike '%' || p_q || '%' or (qd <> '' and p.phone like '%' || qd || '%'))
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', f.id, 'name', f.name, 'phone', f.phone, 'whatsapp', f.whatsapp, 'services', to_jsonb(f.services), 'state_id', f.state_id, 'city_id', f.city_id,
      'hood', f.hood, 'radius', f.radius, 'experience', f.experience, 'price', f.price, 'bio', f.bio, 'from', f.work_from, 'to', f.work_to,
      'photo', f.photo, 'verified', f.verified, 'username', f.username, 'username_changed', f.username_changed, 'jobs', job_count(f.id), 'birth_date', f.birth_date, 'email', f.email, 'age', case when f.birth_date is null then null else date_part('year', age(f.birth_date))::int end, 'verify_doc', f.verify_doc, 'verified_at', (extract(epoch from f.verified_at) * 1000)::bigint, 'pct', f.pct_now, 'status', f.status, 'available', f.av_now, 'flag', f.available, 'has_password', f.password_hash is not null, 'admin_note', f.admin_note,
      'last_seen', (extract(epoch from f.last_seen) * 1000)::bigint, 'created', (extract(epoch from f.created_at) * 1000)::bigint,
      'requests_total', rq.rt, 'requests_week', rq.rw, 'rating_n', rv.n, 'rating', case when rv.n > 0 then round(rv.av::numeric, 1) else null end, 'ok', rv.ok, 'fail', rv.fail
    ) order by f.rn), '[]'::jsonb) into items
  from f
  left join lateral (select count(*)::int rt, (count(*) filter (where r.created_at > now() - interval '7 days'))::int rw from requests r where r.provider_id = f.id) rq on true
  left join lateral (select count(*)::int n, coalesce(avg(v.stars), 0) av, (count(*) filter (where v.success))::int ok, (count(*) filter (where not v.success))::int fail from reviews v where v.provider_id = f.id) rv on true
  where f.rn > off and f.rn <= off + lim;
  return jsonb_build_object('total', total, 'items', items);
end $$;

revoke execute on function check_email(text) from public, anon, authenticated;
-- ===== v12: توثيق البريد برمز من 4 أرقام (يُرسل عبر Edge Function + Brevo) =====
create table if not exists email_codes (
  provider_id uuid primary key references providers(id) on delete cascade,
  email text not null, code_hash text not null, expires_at timestamptz not null,
  attempts int not null default 0, sent_at timestamptz not null default now(),
  day date not null default current_date, sent_today int not null default 1);
alter table email_codes enable row level security;
revoke all on email_codes from public, anon, authenticated;

-- تغيير البريد يلغي التوثيق والرمز القديم
create or replace function providers_email_reset() returns trigger language plpgsql set search_path = public as $$
begin
  if new.email is distinct from old.email then
    new.email_verified := false;
    delete from email_codes where provider_id = new.id;
  end if;
  return new;
end $$;
drop trigger if exists providers_email_bu on providers;
create trigger providers_email_bu before update of email on providers for each row execute function providers_email_reset();

-- تُستدعى من Edge Function فقط (service_role): تولّد الرمز وتحفظ بصمته وتعيد الرمز للإرسال
create or replace function issue_email_code(p_id uuid, p_token text) returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare pr providers; ec email_codes; code text; b bytea;
begin
  select * into pr from providers where id = p_id and token = p_token;
  if not found then raise exception 'forbidden'; end if;
  if pr.email is null then raise exception 'no_email'; end if;
  if pr.email_verified then raise exception 'already'; end if;
  select * into ec from email_codes where provider_id = p_id;
  if found then
    if ec.sent_at > now() - interval '60 seconds' then raise exception 'wait'; end if;
    if ec.day = current_date and ec.sent_today >= 5 then raise exception 'limit'; end if;
  end if;
  b := gen_random_bytes(2);
  code := lpad(((get_byte(b, 0) * 256 + get_byte(b, 1)) % 10000)::text, 4, '0');
  insert into email_codes(provider_id, email, code_hash, expires_at, attempts, sent_at, day, sent_today)
  values (p_id, pr.email, encode(digest(code || p_id::text, 'sha256'), 'hex'), now() + interval '10 minutes', 0, now(), current_date, 1)
  on conflict (provider_id) do update set email = excluded.email, code_hash = excluded.code_hash, expires_at = excluded.expires_at, attempts = 0, sent_at = now(),
    sent_today = case when email_codes.day = current_date then email_codes.sent_today + 1 else 1 end, day = current_date;
  return jsonb_build_object('email', pr.email, 'code', code);
end $$;

create or replace function verify_email_code(p_id uuid, p_token text, p_code text) returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare pr providers; ec email_codes;
begin
  select * into pr from providers where id = p_id and token = p_token;
  if not found then raise exception 'forbidden'; end if;
  select * into ec from email_codes where provider_id = p_id;
  if not found or ec.email is distinct from pr.email then return jsonb_build_object('ok', false, 'error', 'no_code'); end if;
  if ec.expires_at < now() then delete from email_codes where provider_id = p_id; return jsonb_build_object('ok', false, 'error', 'expired'); end if;
  if ec.attempts >= 3 then delete from email_codes where provider_id = p_id; return jsonb_build_object('ok', false, 'error', 'too_many'); end if;
  if ec.code_hash = encode(digest(trim(coalesce(p_code, '')) || p_id::text, 'sha256'), 'hex') then
    update providers set email_verified = true where id = p_id;
    delete from email_codes where provider_id = p_id;
    return jsonb_build_object('ok', true);
  end if;
  update email_codes set attempts = attempts + 1 where provider_id = p_id;
  return jsonb_build_object('ok', false, 'error', 'wrong', 'left', 2 - ec.attempts);
end $$;

create or replace function provider_self(p_id uuid, p_token text) returns jsonb language plpgsql security definer set search_path = public as $$
declare pr providers; res jsonb;
begin
  select * into pr from providers where id = p_id and token = p_token;
  if not found then raise exception 'forbidden'; end if;
  update providers set last_seen = now() where id = p_id;
  select * into pr from providers where id = p_id;
  res := provider_public(pr, null) || jsonb_build_object('status', pr.status, 'flag', pr.available, 'in_hours', in_hours(pr),
    'radius', pr.radius, 'has_password', pr.password_hash is not null, 'pct', profile_pct(pr), 'verified', pr.verified, 'birth_date', pr.birth_date, 'email', pr.email, 'email_verified', pr.email_verified, 'username_changed', pr.username_changed,
    'requests_week', (select count(*) from requests where provider_id = p_id and created_at > now() - interval '7 days'));
  return res;
end $$;

create or replace function admin_providers(p_code text, p_q text, p_status text, p_service text, p_city text, p_limit int, p_offset int) returns jsonb
language plpgsql security definer set search_path = public as $$
declare qd text := ltrim(regexp_replace(coalesce(p_q, ''), '\D', '', 'g'), '0'); total int; items jsonb; lim int := greatest(1, least(coalesce(p_limit, 30), 1000)); off int := greatest(0, coalesce(p_offset, 0));
begin
  perform assert_admin(p_code);
  select count(*) into total from providers p
    where (coalesce(p_status, '') = '' or p.status = p_status) and (coalesce(p_service, '') = '' or p_service = any(p.services))
      and (coalesce(p_city, '') = '' or p.city_id = p_city)
      and (coalesce(p_q, '') = '' or p.name ilike '%' || p_q || '%' or p.username ilike '%' || p_q || '%' or p.email ilike '%' || p_q || '%' or (qd <> '' and p.phone like '%' || qd || '%'));
  with f as (
    select p.*, is_available(p) as av_now, profile_pct(p) as pct_now, row_number() over (order by (p.status <> 'pending'), p.created_at desc) rn from providers p
    where (coalesce(p_status, '') = '' or p.status = p_status) and (coalesce(p_service, '') = '' or p_service = any(p.services))
      and (coalesce(p_city, '') = '' or p.city_id = p_city)
      and (coalesce(p_q, '') = '' or p.name ilike '%' || p_q || '%' or p.username ilike '%' || p_q || '%' or p.email ilike '%' || p_q || '%' or (qd <> '' and p.phone like '%' || qd || '%'))
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', f.id, 'name', f.name, 'phone', f.phone, 'whatsapp', f.whatsapp, 'services', to_jsonb(f.services), 'state_id', f.state_id, 'city_id', f.city_id,
      'hood', f.hood, 'radius', f.radius, 'experience', f.experience, 'price', f.price, 'bio', f.bio, 'from', f.work_from, 'to', f.work_to,
      'photo', f.photo, 'verified', f.verified, 'username', f.username, 'username_changed', f.username_changed, 'jobs', job_count(f.id), 'birth_date', f.birth_date, 'email', f.email, 'email_verified', f.email_verified, 'age', case when f.birth_date is null then null else date_part('year', age(f.birth_date))::int end, 'verify_doc', f.verify_doc, 'verified_at', (extract(epoch from f.verified_at) * 1000)::bigint, 'pct', f.pct_now, 'status', f.status, 'available', f.av_now, 'flag', f.available, 'has_password', f.password_hash is not null, 'admin_note', f.admin_note,
      'last_seen', (extract(epoch from f.last_seen) * 1000)::bigint, 'created', (extract(epoch from f.created_at) * 1000)::bigint,
      'requests_total', rq.rt, 'requests_week', rq.rw, 'rating_n', rv.n, 'rating', case when rv.n > 0 then round(rv.av::numeric, 1) else null end, 'ok', rv.ok, 'fail', rv.fail
    ) order by f.rn), '[]'::jsonb) into items
  from f
  left join lateral (select count(*)::int rt, (count(*) filter (where r.created_at > now() - interval '7 days'))::int rw from requests r where r.provider_id = f.id) rq on true
  left join lateral (select count(*)::int n, coalesce(avg(v.stars), 0) av, (count(*) filter (where v.success))::int ok, (count(*) filter (where not v.success))::int fail from reviews v where v.provider_id = f.id) rv on true
  where f.rn > off and f.rn <= off + lim;
  return jsonb_build_object('total', total, 'items', items);
end $$;

revoke execute on function providers_email_reset() from public, anon, authenticated;
revoke execute on function issue_email_code(uuid, text) from public, anon, authenticated;
grant execute on function issue_email_code(uuid, text) to service_role;
revoke execute on function verify_email_code(uuid, text, text) from public;
grant execute on function verify_email_code(uuid, text, text) to anon, authenticated;
-- ===== v13: صندوق إشعارات الصنايعي (طلبات، تأكيدات، تقييمات، حالة الحساب، رسائل الإدارة) =====
create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid references providers(id) on delete cascade, -- null = للجميع
  kind text not null, title text not null, body text not null default '',
  created_at timestamptz not null default now());
create index if not exists notifications_prov_idx on notifications(provider_id, created_at desc);
alter table notifications enable row level security;
revoke all on notifications from public, anon, authenticated;
alter table providers add column if not exists notif_read_at timestamptz not null default now();

create or replace function notif_add(p_prov uuid, p_kind text, p_title text, p_body text) returns void language sql security definer set search_path = public as $$
  insert into notifications(provider_id, kind, title, body) values (p_prov, p_kind, left(p_title, 120), left(coalesce(p_body, ''), 600));
$$;

-- طلب جديد
create or replace function trg_notif_request() returns trigger language plpgsql security definer set search_path = public as $$
declare sn text;
begin
  select name into sn from services where id = new.service;
  perform notif_add(new.provider_id, 'request', 'طلب جديد', 'عميل تواصل معك عبر ' || case when new.channel = 'call' then 'الاتصال' else 'الواتساب' end || coalesce(' بخصوص ' || sn, '') || '. بعد إنجاز الخدمة أكّدها من لوحتك.');
  return new;
end $$;
drop trigger if exists notif_request_ai on requests;
create trigger notif_request_ai after insert on requests for each row execute function trg_notif_request();

-- العميل أكّد إتمام الخدمة + الحصول على شارة
create or replace function trg_notif_done() returns trigger language plpgsql security definer set search_path = public as $$
declare sn text; jc int; tname text;
begin
  if new.status = 'done' and old.status is distinct from 'done' then
    select name into sn from services where id = new.service;
    perform notif_add(new.provider_id, 'confirm', 'العميل أكّد إتمام الخدمة', 'أكّد العميل أنك أنجزت' || coalesce(' خدمة ' || sn, ' الخدمة') || '. ادخل لوحتك وأكّد العمل وأدخل المبلغ ليُحتسب في شارتك.');
  end if;
  if new.prov_confirm = 'done' and old.prov_confirm is distinct from 'done' then
    jc := job_count(new.provider_id);
    if jc in (3, 10, 25) then
      tname := case jc when 3 then 'منجز' when 10 then 'متميز' else 'ذهبي' end;
      if not exists (select 1 from notifications where provider_id = new.provider_id and kind = 'badge' and title = 'مبروك شارة ' || tname) then
        perform notif_add(new.provider_id, 'badge', 'مبروك شارة ' || tname, 'وصلت إلى ' || jc || ' أعمال مؤكدة وحصلت على شارة «' || tname || '». استمر!');
      end if;
    end if;
  end if;
  return new;
end $$;
drop trigger if exists notif_done_au on requests;
create trigger notif_done_au after update of status, prov_confirm on requests for each row execute function trg_notif_done();

-- تقييم جديد
create or replace function trg_notif_review() returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform notif_add(new.provider_id, 'review', 'تقييم جديد', case when new.stars is null then 'سجّل عميل أن الاتفاق لم يتم.' else 'حصلت على ' || new.stars || ' من 5 نجوم' || case when coalesce(new.comment, '') <> '' then ': «' || left(new.comment, 120) || '»' else '.' end end);
  return new;
end $$;
drop trigger if exists notif_review_ai on reviews;
create trigger notif_review_ai after insert on reviews for each row execute function trg_notif_review();

-- حالة الحساب والتوثيق
create or replace function trg_notif_provider() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status is distinct from old.status then
    if new.status = 'approved' then perform notif_add(new.id, 'account', 'تم قبول حسابك', 'أهلًا بك! ملفك ظاهر الآن للزبائن. فعّل "أنا متاح الآن" لتصلك الطلبات.');
    elsif new.status = 'rejected' then perform notif_add(new.id, 'account', 'لم يُقبل حسابك', 'تواصل مع الدعم لمعرفة السبب وتصحيح بياناتك.');
    elsif new.status = 'suspended' then perform notif_add(new.id, 'account', 'تم إيقاف حسابك مؤقتًا', 'تواصل مع الدعم لمعرفة التفاصيل.');
    end if;
  end if;
  if new.verified and not old.verified then
    perform notif_add(new.id, 'verify', 'تم توثيق هويتك', 'حصلت على علامة التوثيق. سيراها الزبائن بجانب اسمك.');
  end if;
  return new;
end $$;
drop trigger if exists notif_provider_au on providers;
create trigger notif_provider_au after update of status, verified on providers for each row execute function trg_notif_provider();

-- قراءة الإشعارات (وتعيينها كمقروءة عند الطلب)
create or replace function provider_notifications(p_id uuid, p_token text, p_mark boolean default false) returns jsonb language plpgsql security definer set search_path = public as $$
declare pr providers; res jsonb;
begin
  select * into pr from providers where id = p_id and token = p_token;
  if not found then raise exception 'forbidden'; end if;
  select jsonb_build_object(
    'unread', (select count(*) from notifications n where (n.provider_id = p_id or n.provider_id is null) and n.created_at > pr.notif_read_at and n.created_at > pr.created_at),
    'items', coalesce((select jsonb_agg(x order by x.ts desc) from (
        select n.id, n.kind, n.title, n.body, (extract(epoch from n.created_at) * 1000)::bigint ts, (n.created_at > pr.notif_read_at) as unread
        from notifications n where (n.provider_id = p_id or n.provider_id is null) and n.created_at > pr.created_at
        order by n.created_at desc limit 60) x), '[]'::jsonb)) into res;
  if p_mark then update providers set notif_read_at = now() where id = p_id; end if;
  return res;
end $$;

create or replace function provider_notif_count(p_id uuid, p_token text) returns int language plpgsql security definer set search_path = public as $$
declare pr providers; c int;
begin
  select * into pr from providers where id = p_id and token = p_token;
  if not found then raise exception 'forbidden'; end if;
  select count(*)::int into c from notifications n where (n.provider_id = p_id or n.provider_id is null) and n.created_at > pr.notif_read_at and n.created_at > pr.created_at;
  return c;
end $$;

-- إرسال من المدير: p_id = null يعني لجميع الصنايعية
create or replace function admin_send_notification(p_code text, p_id uuid, p_title text, p_body text) returns boolean language plpgsql security definer set search_path = public as $$
begin
  perform assert_admin(p_code);
  if coalesce(trim(p_title), '') = '' then raise exception 'invalid'; end if;
  perform notif_add(p_id, case when p_id is null then 'broadcast' else 'admin' end, trim(p_title), p_body);
  return true;
end $$;

revoke execute on function notif_add(uuid, text, text, text), trg_notif_request(), trg_notif_done(), trg_notif_review(), trg_notif_provider() from public, anon, authenticated;
revoke execute on function provider_notifications(uuid, text, boolean), provider_notif_count(uuid, text), admin_send_notification(text, uuid, text, text) from public, anon, authenticated;
grant execute on function provider_notifications(uuid, text, boolean), provider_notif_count(uuid, text), admin_send_notification(text, uuid, text, text) to anon, authenticated;

-- v14: حذف حساب آمن (كلمة السر + رمز بريد)
create table if not exists delete_codes (
  provider_id uuid primary key references providers(id) on delete cascade,
  code_hash text not null, expires_at timestamptz not null, attempts int not null default 0,
  sent_at timestamptz not null default now(), day date not null default current_date, sent_today int not null default 1
);
alter table delete_codes enable row level security;
revoke all on delete_codes from anon, authenticated;
-- issue_delete_code (service_role فقط) و delete_account(p_id,p_token,p_password,p_code) و revoke delete_provider
-- التعريف الكامل مطبّق على القاعدة الحية (migration v14_secure_delete_account).
-- v15: فهارس + bucket الصور + حدود الطلبات + سجل نشاط المدير
-- (التعريف الكامل مطبّق على القاعدة الحية: migration v15_scale_hardening)
create index if not exists providers_approved_city on providers (city_id) where status = 'approved';
create index if not exists providers_services_gin on providers using gin (services);
create index if not exists providers_status on providers (status, created_at desc);
create index if not exists requests_created on requests (created_at desc);
create index if not exists reports_prov_status on reports (provider_id, status);
-- storage bucket avatars (عام، jpeg، 200KB) + check_photo يقبل رابط avatars
-- جداول: rate_limits, audit_log + دوال rate_hit, client_ip, admin_audit + triggers
