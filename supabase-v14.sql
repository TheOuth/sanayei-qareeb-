-- v14: حذف حساب آمن (كلمة السر + رمز بريد)
create table if not exists delete_codes (
  provider_id uuid primary key references providers(id) on delete cascade,
  code_hash text not null, expires_at timestamptz not null, attempts int not null default 0,
  sent_at timestamptz not null default now(), day date not null default current_date, sent_today int not null default 1
);
alter table delete_codes enable row level security;
revoke all on delete_codes from anon, authenticated;
-- issue_delete_code (service_role فقط) و delete_account(p_id,p_token,p_password,p_code) و revoke delete_provider
-- التعريف الكامل مطبّق على القاعدة الحية (migration v14_secure_delete_account).
