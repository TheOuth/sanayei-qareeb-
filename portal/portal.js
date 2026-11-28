/* حساب سبيل على الموقع: دخول/تسجيل، ويشارك الجلسة مع تطبيق صنايعي قريب (نفس الموقع) */
var Sabil = (function () {
  var URL = 'https://pwqtvixjkpvyajqmfqpa.supabase.co', KEY = 'sb_publishable_sFHW2864oPilfQvjs3txaA__QjKY0sG';
  var FK = ['aid', 'atoken', 'a_name', 'a_phone', 'a_email', 'a_everified', 'a_birth', 'pid', 'token', 'me_name', 'me_photo'];
  var ERR = {
    invalid: 'البيانات أو كلمة السر غير صحيحة', locked: 'محاولات كثيرة. حاول بعد 15 دقيقة', no_password: 'هذا الحساب بلا كلمة سر',
    phone_taken: 'هذا الرقم مسجّل من قبل. سجّل الدخول', email_taken: 'هذا البريد مسجّل من قبل. سجّل الدخول',
    invalid_phone: 'رقم الهاتف غير صحيح', invalid_email: 'البريد الإلكتروني غير صحيح', weak: 'كلمة السر 6 أحرف على الأقل',
    invalid: 'تحقق من البيانات المدخلة', wrong_password: 'كلمة السر غير صحيحة', no_code: 'اضغط «إرسال الرمز» أولًا', expired: 'انتهت صلاحية الرمز. أرسل رمزًا جديدًا', too_many: 'محاولات كثيرة. أرسل رمزًا جديدًا', wrong_code: 'الرمز غير صحيح', wait: 'انتظر دقيقة قبل إعادة الإرسال', limit: 'وصلت للحد اليومي لإرسال الرموز', no_verified_email: 'لا يوجد بريد مؤكَّد', not_configured: 'خدمة البريد غير مفعّلة بعد', send_failed: 'تعذّر إرسال البريد', rate_limited: 'محاولات كثيرة. حاول بعد قليل'
  };
  function get(k) { try { var v = localStorage.getItem('flutter.' + k); return v == null ? null : JSON.parse(v); } catch (e) { return null; } }
  function set(k, v) { try { if (v == null) localStorage.removeItem('flutter.' + k); else localStorage.setItem('flutter.' + k, JSON.stringify(String(v))); } catch (e) {} }
  function rpc(fn, args) {
    return fetch(URL + '/rest/v1/rpc/' + fn, { method: 'POST', headers: { 'Content-Type': 'application/json', apikey: KEY }, body: JSON.stringify(args || {}) })
      .then(function (r) { return r.json().catch(function () { return null; }).then(function (d) { if (!r.ok) { var m = (d && (d.message || d.hint || '')) + ''; var e = new Error(m); e.code = m; throw e; } return d; }); });
  }
  function msg(e) { var c = (e && (e.code || e.message)) || ''; for (var k in ERR) if (c.indexOf(k) >= 0) return ERR[k]; return 'تعذّر الاتصال. حاول مرة أخرى'; }
  function save(r) {
    set('aid', r.account_id); set('atoken', r.account_token); set('a_name', r.name || ''); set('a_phone', r.phone || ''); set('a_email', r.email || ''); set('a_everified', r.email_verified ? '1' : ''); set('a_birth', r.birth_date || '');
    if (r.provider_id && r.provider_token) { set('pid', r.provider_id); set('token', r.provider_token); } else { set('pid', null); set('token', null); }
  }
  function current() { var id = get('aid'); return id ? { id: id, name: get('a_name') || '', phone: get('a_phone') || '', email: get('a_email') || '', emailVerified: !!get('a_everified'), birth: get('a_birth') || '', provider: !!get('pid') } : null; }
  function logout() { FK.forEach(function (k) { set(k, null); }); }
  function anon() { return get('anon') || null; }
  return {
    rpc: rpc, msg: msg, current: current, logout: logout,
    login: function (login, pw) { return rpc('account_login', { p_login: login, p_password: pw, p_anon: anon() }).then(function (r) { if (!r || r.ok !== true) { var e = new Error((r && r.error) || 'invalid'); e.code = (r && r.error) || 'invalid'; throw e; } save(r); return r; }); },
    register: function (name, phone, email, pw) { return rpc('account_register', { p_name: name, p_phone: phone || '', p_email: email || '', p_password: pw, p_anon: anon() }).then(function (r) { save(r); return r; }); },
    sendCode: function () { var id = get('aid'), t = get('atoken'); return fetch(URL + '/functions/v1/send-email-code', { method: 'POST', headers: { 'Content-Type': 'application/json', apikey: KEY }, body: JSON.stringify({ id: id, token: t, purpose: 'delete', kind: 'account' }) })
      .then(function (r) { return r.json().catch(function () { return {}; }).then(function (d) { if (!r.ok) { var e = new Error(d.error || 'failed'); e.code = d.error || 'failed'; throw e; } return d; }); }); },
    del: function (pw, code) { return rpc('account_delete', { p_id: get('aid'), p_token: get('atoken'), p_password: pw, p_code: code || null }).then(function (r) { if (!r || r.ok !== true) { var e = new Error((r && r.error) || 'invalid'); e.code = (r && r.error) || 'invalid'; throw e; } logout(); return r; }); },
    refresh: function () { var id = get('aid'), t = get('atoken'); if (!id || !t) return Promise.resolve(null); return rpc('account_self', { p_id: id, p_token: t }).then(function (r) { save({ account_id: id, account_token: t, name: r.name, phone: r.phone, email: r.email, email_verified: r.email_verified, birth_date: r.birth_date, provider_id: r.provider_id, provider_token: r.provider_token }); return r; }).catch(function (e) { if (/forbidden/.test(e.code || '')) logout(); return null; }); }
  };
})();
