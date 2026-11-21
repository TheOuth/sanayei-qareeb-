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
