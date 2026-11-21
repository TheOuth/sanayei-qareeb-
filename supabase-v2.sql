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
  insert into app_settings(key, value) values ('support_whatsapp', left(coalesce(p->>'support_whatsapp', ''), 30)) on conflict (key) do update set value = excluded.value;
  insert into app_settings(key, value) values ('support_email', left(coalesce(p->>'support_email', ''), 100)) on conflict (key) do update set value = excluded.value;
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
