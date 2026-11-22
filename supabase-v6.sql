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
