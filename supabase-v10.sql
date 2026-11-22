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
