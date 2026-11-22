-- ===== v8: سجل دفعيات العمولة =====
-- آمن لإعادة التشغيل. يُشغَّل بعد v7.
create table if not exists commission_payments (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references providers(id) on delete cascade,
  amount numeric(12, 0) not null check (amount > 0 and amount <= 100000000),
  note text not null default '',
  paid_at timestamptz not null default now()
);
create index if not exists commission_payments_provider on commission_payments(provider_id, paid_at desc);
alter table commission_payments enable row level security;
revoke all on commission_payments from anon, authenticated;

create or replace function admin_add_payment(p_code text, p_id uuid, p_amount numeric, p_note text) returns uuid language plpgsql security definer set search_path = public as $$
declare pid uuid;
begin
  perform assert_admin(p_code);
  if p_amount is null or p_amount <= 0 or p_amount > 100000000 then raise exception 'invalid'; end if;
  if not exists (select 1 from providers where id = p_id) then raise exception 'not_found'; end if;
  insert into commission_payments(provider_id, amount, note) values (p_id, round(p_amount), left(coalesce(p_note, ''), 200)) returning id into pid;
  return pid;
end $$;

create or replace function admin_delete_payment(p_code text, p_pid uuid) returns boolean language plpgsql security definer set search_path = public as $$
begin
  perform assert_admin(p_code);
  delete from commission_payments where id = p_pid;
  return true;
end $$;

create or replace function admin_commission_ledger(p_code text) returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform assert_admin(p_code);
  return (select coalesce(jsonb_agg(x order by (x->>'jobs')::int desc, x->>'name'), '[]'::jsonb) from (
    select jsonb_build_object('provider_id', p.id, 'name', p.name, 'phone', p.phone,
      'jobs', (select count(*) from requests r where r.provider_id = p.id and r.status = 'done' and r.prov_confirm = 'done'),
      'paid', coalesce((select sum(c.amount) from commission_payments c where c.provider_id = p.id), 0),
      'pay_count', (select count(*) from commission_payments c where c.provider_id = p.id),
      'last_paid', (select (extract(epoch from max(c.paid_at)) * 1000)::bigint from commission_payments c where c.provider_id = p.id),
      'payments', (select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'amount', c.amount, 'note', c.note, 'ts', (extract(epoch from c.paid_at) * 1000)::bigint) order by c.paid_at desc), '[]'::jsonb)
                   from (select * from commission_payments where provider_id = p.id order by paid_at desc limit 30) c)) x
    from providers p
    where exists (select 1 from requests r where r.provider_id = p.id and r.status = 'done' and r.prov_confirm = 'done')
       or exists (select 1 from commission_payments c where c.provider_id = p.id)) t);
end $$;

revoke execute on function admin_add_payment(text, uuid, numeric, text), admin_delete_payment(text, uuid), admin_commission_ledger(text) from public, anon, authenticated;
grant execute on function admin_add_payment(text, uuid, numeric, text), admin_delete_payment(text, uuid), admin_commission_ledger(text) to anon, authenticated;
