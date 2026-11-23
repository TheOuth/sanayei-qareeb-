-- v15: فهارس + bucket الصور + حدود الطلبات + سجل نشاط المدير
-- (التعريف الكامل مطبّق على القاعدة الحية: migration v15_scale_hardening)
create index if not exists providers_approved_city on providers (city_id) where status = 'approved';
create index if not exists providers_services_gin on providers using gin (services);
create index if not exists providers_status on providers (status, created_at desc);
create index if not exists requests_created on requests (created_at desc);
create index if not exists reports_prov_status on reports (provider_id, status);
-- storage bucket avatars (عام، jpeg، 200KB) + check_photo يقبل رابط avatars
-- جداول: rate_limits, audit_log + دوال rate_hit, client_ip, admin_audit + triggers
