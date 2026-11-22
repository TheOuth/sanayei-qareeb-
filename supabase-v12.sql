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
