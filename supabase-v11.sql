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
