-- v24: get_provider يعيد svc_jobs = عدد الخدمات المكتملة (بتأكيد الطرفين) لكل مهارة
create or replace function get_provider(p_id uuid, p_lat double precision, p_lng double precision) returns jsonb
language plpgsql stable security definer set search_path to 'public' as $function$
declare pr providers; res jsonb;
begin
  select * into pr from providers where id = p_id and status = 'approved';
  if not found then return null; end if;
  res := provider_public(pr, case when p_lat is null then null else haversine_km(p_lat, p_lng, pr.lat, pr.lng) end);
  res := res || jsonb_build_object('reviews', coalesce((
    select jsonb_agg(jsonb_build_object('stars', stars, 'comment', comment, 'success', success, 'ts', (extract(epoch from created_at) * 1000)::bigint) order by created_at desc)
    from (select * from reviews where provider_id = p_id order by created_at desc limit 5) r), '[]'));
  res := res || jsonb_build_object('history', coalesce((
    select jsonb_agg(jsonb_build_object('service', coalesce(s.name, 'خدمة'), 'icon', coalesce(s.icon, '🔧'),
      'state', case when q.status = 'done' and q.prov_confirm = 'done' then 'done'
                    when q.status = 'done' and q.prov_confirm = 'not_done' then 'disputed' when q.status = 'failed' then 'failed' else 'open' end,
      'ts', (extract(epoch from q.created_at) * 1000)::bigint) order by q.created_at desc)
    from (select * from requests where provider_id = p_id and accept_status = 'accepted' and status <> 'not_agreed' order by created_at desc limit 12) q left join services s on s.id = q.service), '[]'));
  res := res || jsonb_build_object('svc_jobs', coalesce((
    select jsonb_object_agg(service, n) from (select service, count(*)::int n from requests
      where provider_id = p_id and status = 'done' and prov_confirm = 'done' group by service) x), '{}'::jsonb));
  return res;
end $function$;
