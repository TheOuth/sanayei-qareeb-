-- v19: طلب الخدمة / قبول الصنايعي / إخفاء الأرقام حتى القبول / سرعة الرد (دائرة مئوية) / تقييم اختياري
alter table requests drop constraint if exists requests_channel_check;
alter table requests add constraint requests_channel_check check (channel in ('call','whatsapp','app'));
alter table requests add column if not exists accept_status text not null default 'accepted';
alter table requests add column if not exists responded_at timestamptz;
alter table requests add column if not exists accepted_at timestamptz;
alter table requests drop constraint if exists requests_accept_status_check;
alter table requests add constraint requests_accept_status_check check (accept_status in ('pending','accepted','declined','taken','cancelled'));
alter table requests alter column accept_status set default 'pending';
create index if not exists requests_prov_chan_idx on requests(provider_id, channel, created_at desc);
create index if not exists requests_anon_idx on requests(anon_id, created_at desc);
alter table reviews alter column stars drop not null;

create table if not exists client_devices (fcm text primary key, anon_id text not null, updated_at timestamptz not null default now());
alter table client_devices enable row level security;
create index if not exists client_devices_anon_idx on client_devices(anon_id);

create or replace function req_state(r requests) returns text language sql stable set search_path = public as $$
  select case when r.accept_status = 'pending' and r.created_at < now() - interval '2 hours' then 'expired' else r.accept_status end $$;

create or replace function reply_stat(pid uuid) returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('n', count(*)::int,
    'fast', (count(*) filter (where responded_at is not null and responded_at - created_at <= interval '15 minutes'))::int)
  from requests where provider_id = pid and channel = 'app' and created_at > now() - interval '90 days'
    and (accept_status in ('accepted','declined') or (accept_status = 'pending' and created_at < now() - interval '2 hours')) $$;

create or replace function provider_public(p providers, p_dist double precision) returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', p.id, 'name', p.name, 'services', to_jsonb(p.services), 'state_id', p.state_id, 'city_id', p.city_id,
    'hood', p.hood, 'experience', p.experience, 'price', p.price, 'bio', p.bio, 'from', p.work_from, 'to', p.work_to,
    'available', is_available(p), 'photo', p.photo, 'verified', p.verified, 'jobs', job_count(p.id), 'tier', provider_tier(p), 'username', p.username, 'age', case when p.birth_date is null then null else date_part('year', age(p.birth_date))::int end,
    'distance_km', case when p_dist is null then null else round(p_dist::numeric, 1) end,
    'rating', case when s.n >= 3 then round(s.avg::numeric, 1) else null end,
    'rating_n', s.n, 'ok', s.ok, 'fail', s.fail,
    'reply_pct', case when (rs->>'n')::int >= 3 then round(100.0 * (rs->>'fast')::int / (rs->>'n')::int)::int else null end,
    'reply_n', (rs->>'n')::int, 'demo', false)
  from (select count(stars)::int n, coalesce(avg(stars), 0) avg,
               count(*) filter (where success)::int ok, count(*) filter (where not success)::int fail
        from reviews where provider_id = p.id) s, reply_stat(p.id) rs;
$$;

create or replace function provider_self(p_id uuid, p_token text) returns jsonb language plpgsql security definer set search_path = public as $$
declare pr providers; res jsonb;
begin
  select * into pr from providers where id = p_id and token = p_token;
  if not found then raise exception 'forbidden'; end if;
  update providers set last_seen = now() where id = p_id;
  select * into pr from providers where id = p_id;
  res := provider_public(pr, null) || jsonb_build_object('phone', pr.phone, 'whatsapp', pr.whatsapp, 'status', pr.status, 'flag', pr.available, 'in_hours', in_hours(pr),
    'radius', pr.radius, 'has_password', pr.password_hash is not null, 'pct', profile_pct(pr), 'verified', pr.verified, 'birth_date', pr.birth_date, 'email', pr.email, 'email_verified', pr.email_verified, 'username_changed', pr.username_changed,
    'gray_status', pr.gray_status, 'badge_reason', pr.badge_reason,
    'requests_week', (select count(*) from requests where provider_id = p_id and created_at > now() - interval '7 days'),
    'pending_n', (select count(*) from requests where provider_id = p_id and accept_status = 'pending' and created_at > now() - interval '2 hours'));
  return res;
end $$;

create or replace function get_provider(p_id uuid, p_lat double precision, p_lng double precision) returns jsonb language plpgsql stable security definer set search_path = public as $$
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
      'state', case when q.status = 'done' and coalesce(q.prov_confirm, '') <> 'not_done' then 'done'
                    when q.status = 'done' then 'disputed' when q.status = 'failed' then 'failed'
                    when q.status = 'not_agreed' then 'not_agreed' else 'open' end,
      'ts', (extract(epoch from q.created_at) * 1000)::bigint) order by q.created_at desc)
    from (select * from requests where provider_id = p_id and accept_status = 'accepted' order by created_at desc limit 12) q left join services s on s.id = q.service), '[]'));
  return res;
end $$;

create or replace function create_request(p jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare rid uuid; pr providers; an text := p->>'anon_id'; pid uuid := (p->>'provider_id')::uuid; sv text := p->>'service';
begin
  if an is null or length(an) < 8 then raise exception 'invalid'; end if;
  select * into pr from providers where id = pid and status = 'approved';
  if not found then raise exception 'not_found'; end if;
  if not is_available(pr) then raise exception 'unavailable'; end if;
  if sv is null or not (sv = any(pr.services)) then raise exception 'invalid'; end if;
  select id into rid from requests where anon_id = an and provider_id = pid and channel = 'app' and created_at > now() - interval '24 hours'
    and status = 'new' and (accept_status = 'accepted' or (accept_status = 'pending' and created_at > now() - interval '2 hours')) limit 1;
  if rid is not null then return jsonb_build_object('id', rid, 'existing', true); end if;
  if exists (select 1 from requests where anon_id = an and provider_id = pid and channel = 'app' and accept_status = 'declined' and created_at > now() - interval '24 hours') then raise exception 'already_today'; end if;
  if (select count(*) from requests where anon_id = an and accept_status = 'pending' and created_at > now() - interval '2 hours') >= 5 then raise exception 'too_many_pending'; end if;
  if (select count(*) from requests where anon_id = an and channel = 'app' and created_at > now() - interval '24 hours') >= 15 then raise exception 'daily_limit'; end if;
  insert into requests(provider_id, anon_id, service, city_id, channel, accept_status)
    values (pid, an, sv, p->>'city_id', 'app', 'pending') returning id into rid;
  return jsonb_build_object('id', rid);
end $$;

create or replace function cancel_request(p_request uuid, p_anon text) returns boolean language sql security definer set search_path = public as $$
  update requests set accept_status = 'cancelled' where id = p_request and anon_id = p_anon and accept_status = 'pending' returning true $$;

create or replace function provider_respond_request(p_id uuid, p_token text, p_request uuid, p_accept boolean) returns jsonb language plpgsql security definer set search_path = public as $$
declare rq requests;
begin
  if not exists (select 1 from providers where id = p_id and token = p_token) then raise exception 'forbidden'; end if;
  select * into rq from requests where id = p_request and provider_id = p_id for update;
  if not found then raise exception 'forbidden'; end if;
  if req_state(rq) <> 'pending' then return jsonb_build_object('ok', false, 'state', req_state(rq)); end if;
  if p_accept then
    update requests set accept_status = 'accepted', responded_at = now(), accepted_at = now() where id = rq.id;
    update requests set accept_status = 'taken' where anon_id = rq.anon_id and id <> rq.id and accept_status = 'pending'
      and service = rq.service and created_at > now() - interval '24 hours';
    return jsonb_build_object('ok', true, 'state', 'accepted');
  end if;
  update requests set accept_status = 'declined', responded_at = now() where id = rq.id;
  return jsonb_build_object('ok', true, 'state', 'declined');
end $$;

create or replace function provider_requests(p_id uuid, p_token text) returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not exists (select 1 from providers where id = p_id and token = p_token) then raise exception 'forbidden'; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'service', r.service, 'channel', r.channel, 'accept', req_state(r),
      'client', r.status, 'confirm', r.prov_confirm, 'amount', r.prov_amount,
      'ts', (extract(epoch from r.created_at) * 1000)::bigint) order by (req_state(r) = 'pending') desc, r.created_at desc), '[]'::jsonb)
    from (select * from requests where provider_id = p_id and created_at > now() - interval '60 days' and accept_status <> 'cancelled' order by created_at desc limit 40) r);
end $$;

create or replace function my_requests(p_anon text) returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'provider_id', r.provider_id, 'provider_name', p.name, 'service', r.service,
    'channel', r.channel, 'status', r.status, 'accept', req_state(r),
    'phone', case when r.accept_status = 'accepted' then p.phone end,
    'whatsapp', case when r.accept_status = 'accepted' then p.whatsapp end,
    'ts', (extract(epoch from r.created_at) * 1000)::bigint) order by r.created_at desc), '[]')
  from (select * from requests where anon_id = p_anon order by created_at desc limit 100) r join providers p on p.id = r.provider_id;
$$;

create or replace function add_review(p_request uuid, p_anon text, p_outcome text, p_stars integer, p_comment text) returns boolean language plpgsql security definer set search_path = public as $$
declare rq requests;
begin
  select * into rq from requests where id = p_request and anon_id = p_anon;
  if not found then raise exception 'forbidden'; end if;
  if rq.accept_status <> 'accepted' then raise exception 'not_accepted'; end if;
  if rq.status <> 'new' then raise exception 'already'; end if;
  if p_outcome = 'not_agreed' then update requests set status = 'not_agreed' where id = p_request; return true; end if;
  if p_outcome not in ('done','failed') then raise exception 'forbidden'; end if;
  update requests set status = p_outcome where id = p_request;
  insert into reviews(request_id, provider_id, stars, comment, success)
    values (p_request, rq.provider_id, case when p_stars is null then null else greatest(1, least(5, p_stars)) end, left(coalesce(p_comment, ''), 300), p_outcome = 'done');
  return true;
end $$;

create or replace function trg_notif_review() returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform notif_add(new.provider_id, 'review', case when new.stars is null then 'نتيجة طلب' else 'تقييم جديد' end,
    case when new.stars is null then case when new.success then 'أغلق العميل الطلب كمُنجَز.' else 'سجّل العميل أن الخدمة لم تُنجز.' end
         else 'حصلت على ' || new.stars || ' من 5 نجوم' || case when coalesce(new.comment, '') <> '' then ': «' || left(new.comment, 120) || '»' else '.' end end);
  return new;
end $$;

create or replace function trg_notif_request() returns trigger language plpgsql security definer set search_path = public as $$
declare sn text;
begin
  select name into sn from services where id = new.service;
  perform notif_add(new.provider_id, 'request', 'طلب خدمة جديد', 'عميل يطلب' || coalesce(' خدمة ' || sn, ' خدمة') || '. افتح طلباتك واضغط «قبول» ليصله رقمك، أو «اعتذار». سرعة ردك تظهر في ملفك.');
  return new;
end $$;

create or replace function register_client_device(p_anon text, p_fcm text) returns boolean language plpgsql security definer set search_path = public as $$
begin
  if length(coalesce(p_anon, '')) < 8 or length(coalesce(p_fcm, '')) < 20 or length(p_fcm) > 400 then raise exception 'invalid'; end if;
  perform rate_hit('cdev:' || p_anon, 20, 3600);
  insert into client_devices(fcm, anon_id, updated_at) values (p_fcm, p_anon, now())
  on conflict (fcm) do update set anon_id = excluded.anon_id, updated_at = now();
  return true;
end $$;

create or replace function trg_push_client_accept() returns trigger language plpgsql security definer set search_path = public, extensions as $$
declare sec text; pn text; sn text;
begin
  select v into sec from push_cfg where k = 'secret';
  select name into pn from providers where id = new.provider_id;
  select name into sn from services where id = new.service;
  perform net.http_post(
    url := 'https://pwqtvixjkpvyajqmfqpa.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-secret', sec),
    body := jsonb_build_object('anon_id', new.anon_id, 'title', 'قبل ' || coalesce(pn, 'الصنايعي') || ' طلبك', 'body', 'تواصل معه الآن للاتفاق على السعر والموعد' || coalesce(' (' || sn || ')', '') || '.', 'kind', 'client_accept'),
    timeout_milliseconds := 5000);
  return new;
exception when others then
  return new;
end $$;
drop trigger if exists push_client_accept on requests;
create trigger push_client_accept after update of accept_status on requests for each row
  when (new.accept_status = 'accepted' and old.accept_status = 'pending') execute function trg_push_client_accept();

create or replace function admin_requests(p_code text, p_limit integer, p_status text) returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform assert_admin(p_code);
  return (select coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'provider_id', r.provider_id, 'provider_name', p.name, 'service', r.service, 'city_id', r.city_id,
      'channel', r.channel, 'accept', req_state(r), 'reply_secs', case when r.responded_at is null then null else extract(epoch from r.responded_at - r.created_at)::int end,
      'status', r.status, 'confirm', r.prov_confirm, 'amount', r.prov_amount, 'ts', (extract(epoch from r.created_at) * 1000)::bigint) order by r.created_at desc), '[]'::jsonb)
    from (select * from requests where coalesce(p_status, '') = '' or status = p_status order by created_at desc limit greatest(1, least(coalesce(p_limit, 100), 500))) r
    join providers p on p.id = r.provider_id);
end $$;
