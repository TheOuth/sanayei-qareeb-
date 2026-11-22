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
