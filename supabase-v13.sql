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
