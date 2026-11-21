/* صنايعي قريب - لوحة المدير (صفحة منفصلة، غير مرتبطة بالتطبيق العام) */
(function () {
  'use strict';
  var SQ = window.SQ, C = SQ.CONFIG, db = SQ.db, U = SQ.ui, esc = U.esc, toast = U.toast, on = U.on, modal = U.modal, closeModal = U.closeModal;
  var $app = document.getElementById('app');
  var code = '', tab = 'overview', ov = null;
  var pf = { q: '', status: '', service: '', city: '', limit: 30, offset: 0 }, rf = { status: '' };
  var rows = {}; // نسخة الصنايعية المعروضين حسب المعرّف
  try { code = sessionStorage.getItem('sq_admin') || ''; } catch (e) {}
  document.body.classList.add('admin');

  var TABS = [['overview', 'نظرة عامة'], ['providers', 'الصنايعية'], ['requests', 'الطلبات'], ['services', 'الخدمات'], ['reports', 'البلاغات'], ['settings', 'الإعدادات']];
  var STATUS = { pending: ['بانتظار الموافقة', 'warn'], approved: ['معتمد', ''], suspended: ['موقوف', 'bad'], rejected: ['مرفوض', 'bad'] };
  var REQ = { 'new': 'بانتظار رأي الزبون', done: 'ناجحة', failed: 'فاشلة', not_agreed: 'ما اتفقنا' };

  function refOf(p) { return String(p.id).replace(/-/g, '').slice(0, 4).toUpperCase(); }
  var SIGN = '\n\n— فريق *' + C.appName + '* 🛠️\n' + C.tagline;
  function waText(p) {
    var svcs = U.svcNames(p.services), city = SQ.cityName(p.city_id) || '', hi = 'السلام عليكم ورحمة الله وبركاته أخي/أختي ' + p.name + ' 🌿\n';
    if (p.status === 'pending') return hi + 'معك فريق *' + C.appName + '*، المنصة التي تربط الناس بأقرب صنايعي في السودان.\n\nاستلمنا طلب انضمامك كمقدم خدمة (' + svcs + ') في ' + city + '، ونحتاج لتأكيد بياناتك حتى يظهر ملفك للزبائن 👷\n\n' +
      '*للتأكيد رد على هذه الرسالة بـ:*\n1️⃣ رقم طلبك: *' + refOf(p) + '* (يظهر لك في التطبيق على صفحة "طلبك قيد المراجعة")\n2️⃣ كلمة *تأكيد* إن كانت بياناتك صحيحة (الاسم والخدمة والمنطقة)\n\n' +
      '💡 لتتقدم في ترتيب الظهور: أضف صورة شخصية ووصفا لمهارتك من ملفك الشخصي.' + SIGN;
    if (p.status === 'approved') return hi + 'يسعدنا إبلاغك بأنه تم *اعتماد حسابك* في ' + C.appName + ' ✅\nيمكنك الآن تفعيل زر "متاح" ليصلك الزبائن القريبون منك.\n\nالتطبيق: ' + appUrl() + '\n\n💡 الملفات المكتملة (صورة + وصف + حي) والأنشط تظهر أولا للزبائن.' + SIGN;
    if (p.status === 'rejected') return hi + 'شكرا لتسجيلك في ' + C.appName + '. لم نتمكن حاليا من اعتماد طلبك، وغالبا لأن بعض البيانات تحتاج استكمالا أو تأكيدا.\nيمكنك الرد هنا لنساعدك في تصحيح بياناتك وإعادة النظر في طلبك.' + SIGN;
    if (p.status === 'suspended') return hi + 'نود إبلاغك بأنه تم إيقاف ظهور حسابك في ' + C.appName + ' مؤقتا لمراجعته. يرجى الرد على هذه الرسالة لنتواصل معك ونحل الأمر سريعا.' + SIGN;
    return hi + 'معك فريق ' + C.appName + '.' + SIGN;
  }
  function appUrl() { return location.origin + location.pathname.replace(/admin\.html$/, ''); }
  function localPhone(p) { return SQ.util.localPhone(p); }
  function fmtDate(ts) { var d = new Date(ts); return d.getFullYear() + '-' + ('0' + (d.getMonth() + 1)).slice(-2) + '-' + ('0' + d.getDate()).slice(-2); }
  function pill(t, cls) { return '<span class="pill ' + (cls || '') + '">' + esc(t) + '</span>'; }
  function logout() { code = ''; try { sessionStorage.removeItem('sq_admin'); } catch (e) {} render(); }
  function guard(e) {
    if (e && /forbidden/i.test(e.message || '')) { toast('انتهت الجلسة، ادخل من جديد'); logout(); return true; }
    return false;
  }
  function fail(e) { if (!guard(e)) toast(U.errMsg(e)); }
  function copyText(t) {
    try { if (navigator.clipboard) return navigator.clipboard.writeText(t).then(function () { toast('تم النسخ'); }); } catch (e) {}
    var a = document.createElement('textarea'); a.value = t; document.body.appendChild(a); a.select();
    try { document.execCommand('copy'); toast('تم النسخ'); } catch (e) {} document.body.removeChild(a);
  }

  /* ---------- الدخول ---------- */
  function login() {
    $app.innerHTML = '<header class="top"><span class="back ghost"></span><h1>إدارة صنايعي قريب</h1><span class="back ghost"></span></header><main class="main" style="max-width:420px;margin:0 auto">' +
      '<div class="h2" style="margin-top:20px">دخول المدير</div>' + U.pwHtml('code', 'رمز المدير') +
      (SQ.demo ? '<p class="note">وضع تجريبي: الرمز ' + esc(C.adminCode) + '</p>' : '') + '<button class="btn primary" id="ok" style="width:100%">دخول</button></main>';
    var go = async function () {
      var v = document.getElementById('code').value.trim(); if (!v) return;
      var b = document.getElementById('ok'); b.disabled = true;
      try { await db.adminCheck(v); code = v; try { sessionStorage.setItem('sq_admin', v); } catch (e) {} render(); }
      catch (e) { b.disabled = false; toast('الرمز غير صحيح'); }
    };
    on('ok', 'click', go); on('code', 'keydown', function (e) { if (e.key === 'Enter') go(); });
  }

  /* ---------- الهيكل ---------- */
  function shell(inner) {
    var nav = TABS.map(function (t) {
      var n = t[0] === 'providers' && ov && ov.pending ? ov.pending : t[0] === 'reports' && ov && ov.reports_open ? ov.reports_open : 0;
      return '<button class="' + (tab === t[0] ? 'on' : '') + '" data-tab="' + t[0] + '">' + t[1] + (n ? '<span class="cnt">' + n + '</span>' : '') + '</button>';
    }).join('');
    $app.innerHTML = '<header class="top"><a class="back" href="' + esc(appUrl()) + '" title="فتح التطبيق" aria-label="التطبيق">' + SQ.I('home', 22) + '</a><h1>إدارة صنايعي قريب</h1><button class="back" id="out" title="خروج" aria-label="خروج">' + SQ.I('out', 22) + '</button></header>' +
      '<nav class="anav">' + nav + '</nav><main class="main">' + inner + '</main>';
    on('out', 'click', logout);
    U.each('.anav button', function (b) { b.addEventListener('click', function () { tab = b.getAttribute('data-tab'); render(); }); });
  }

  async function render() {
    if (!code) return login();
    try { ov = await db.adminOverview(code); } catch (e) { if (guard(e)) return; ov = null; }
    ({ overview: viewOverview, providers: viewProviders, requests: viewRequests, services: viewServices, reports: viewReports, settings: viewSettings })[tab]();
  }

  /* ---------- نظرة عامة ---------- */
  function viewOverview() {
    if (!ov) { shell('<div class="empty"><div class="big">📶</div>تعذر الاتصال<div class="mt"><button class="btn primary" id="retry">إعادة المحاولة</button></div></div>'); return on('retry', 'click', render); }
    var max = Math.max.apply(null, ov.by_day.map(function (d) { return d.n; }).concat([1]));
    var body = (ov.pending ? '<div class="banner">🔔 عندك <b>' + ov.pending + '</b> طلب انضمام بانتظار موافقتك.<br><button class="btn primary" id="goPending">راجع الطلبات الآن</button></div>' : '') +
      '<div class="sgrid">' + [
        ['معتمدون', ov.approved, ''], ['بانتظار الموافقة', ov.pending, ov.pending ? 'warn' : ''], ['متاحون الآن', ov.available_now, ''], ['موقوفون', ov.suspended, ''],
        ['طلبات اليوم', ov.requests_today, ''], ['طلبات الأسبوع', ov.requests_week, ''], ['إجمالي الطلبات', ov.requests_total, ''], ['متوسط التقييم', ov.reviews_total ? '★ ' + ov.avg_rating : '-', '']
      ].map(function (x) { return '<div class="sbox ' + x[2] + '"><b>' + x[1] + '</b><small>' + x[0] + '</small></div>'; }).join('') + '</div>' +
      '<div class="agrid"><div class="card"><b>الطلبات في آخر 7 أيام</b><div class="bars">' + ov.by_day.map(function (d) {
        return '<div class="bar"><b>' + d.n + '</b><i style="height:' + Math.round(d.n / max * 100) + '%"></i><small>' + esc(d.d) + '</small></div>';
      }).join('') + '</div></div>' +
      '<div class="card"><b>أكثر الخدمات طلبا</b><table class="tbl"><tr><th>الخدمة</th><th>صنايعية</th><th>طلبات الأسبوع</th></tr>' + ov.top_services.map(function (s) {
        return '<tr><td>' + esc(s.icon) + ' ' + esc(s.name) + '</td><td>' + s.providers + '</td><td>' + s.requests_week + '</td></tr>';
      }).join('') + '</table></div>' +
      '<div class="card"><b>الصنايعية حسب المدينة</b>' + (ov.by_city.length ? '<table class="tbl">' + ov.by_city.map(function (c) { return '<tr><td>' + esc(SQ.cityName(c.city_id) || c.city_id) + '</td><td>' + c.n + '</td></tr>'; }).join('') + '</table>' : '<p class="muted">لا يوجد بعد</p>') + '</div>' +
      '<div class="card"><b>إجراءات سريعة</b><div class="btnrow"><button class="btn primary" id="qAdd">➕ إضافة صنايعي</button><button class="btn ghost" id="qSvc">🧰 إدارة الخدمات</button><button class="btn ghost" id="qCsv">⬇ تصدير الصنايعية (CSV)</button></div></div></div>';
    shell(body);
    on('goPending', 'click', function () { pf.status = 'pending'; pf.offset = 0; tab = 'providers'; render(); });
    on('qAdd', 'click', function () { tab = 'providers'; render().then(function () { openProvForm(null); }); });
    on('qSvc', 'click', function () { tab = 'services'; render(); });
    on('qCsv', 'click', function () { exportCsv({}); });
  }

  /* ---------- الصنايعية ---------- */
  function cityFilterOptions(sel) {
    return '<option value="">كل المدن</option>' + SQ.COUNTRY.states.map(function (s) {
      return '<optgroup label="' + esc(s.name) + '">' + s.cities.map(function (c) { return '<option value="' + c.id + '"' + (c.id === sel ? ' selected' : '') + '>' + esc(c.name) + '</option>'; }).join('') + '</optgroup>';
    }).join('');
  }
  function viewProviders() {
    shell('<div class="toolbar"><input id="q" type="search" placeholder="🔍 ابحث بالاسم أو الهاتف" value="' + esc(pf.q) + '">' +
      '<select id="fs"><option value="">كل الحالات</option>' + Object.keys(STATUS).map(function (k) { return '<option value="' + k + '"' + (pf.status === k ? ' selected' : '') + '>' + STATUS[k][0] + '</option>'; }).join('') + '</select>' +
      '<select id="fv"><option value="">كل الخدمات</option>' + SQ.SERVICES.map(function (s) { return '<option value="' + s.id + '"' + (pf.service === s.id ? ' selected' : '') + '>' + esc(s.name) + '</option>'; }).join('') + '</select>' +
      '<select id="fc">' + cityFilterOptions(pf.city) + '</select>' +
      '<button class="btn primary" id="add">➕ إضافة صنايعي</button><button class="btn ghost" id="csv">⬇ CSV</button></div>' +
      '<div class="muted" id="pcount" style="margin-bottom:8px"></div><div id="plist" class="agrid"></div><div class="center mt" id="more"></div>');
    var t;
    on('q', 'input', function () { var v = this.value; clearTimeout(t); t = setTimeout(function () { pf.q = v.trim(); pf.offset = 0; loadProviders(true); }, 350); });
    [['fs', 'status'], ['fv', 'service'], ['fc', 'city']].forEach(function (x) { on(x[0], 'change', function () { pf[x[1]] = this.value; pf.offset = 0; loadProviders(true); }); });
    on('add', 'click', function () { openProvForm(null); });
    on('csv', 'click', function () { exportCsv(pf); });
    var list = document.getElementById('plist');
    list.addEventListener('click', function (e) {
      var b = e.target.closest('[data-act]'); if (!b) return;
      provAction(b.getAttribute('data-act'), rows[b.getAttribute('data-id')], b);
    });
    loadProviders(true);
  }

  async function loadProviders(reset) {
    var list = document.getElementById('plist'), cnt = document.getElementById('pcount'), more = document.getElementById('more');
    if (!list) return;
    if (reset) { pf.offset = 0; list.innerHTML = '<div class="spin">جاري التحميل...</div>'; more.innerHTML = ''; }
    var res;
    try { res = await db.adminProviders(code, pf); } catch (e) { return fail(e); }
    if (reset) list.innerHTML = '';
    res.items.forEach(function (p) { rows[p.id] = p; list.insertAdjacentHTML('beforeend', provCard(p)); });
    var shown = pf.offset + res.items.length;
    cnt.textContent = res.total ? 'عرض ' + shown + ' من ' + res.total : '';
    if (!res.total) list.innerHTML = '<div class="empty"><div class="big">🔎</div>لا توجد نتائج</div>';
    more.innerHTML = shown < res.total ? '<button class="btn ghost" id="moreBtn" style="width:100%">عرض المزيد</button>' : '';
    on('moreBtn', 'click', function () { pf.offset = shown; loadProviders(false); });
  }

  function provCard(p) {
    var st = STATUS[p.status] || ['—', ''];
    var wa = 'https://wa.me/' + SQ.util.digits(p.whatsapp || p.phone) + '?text=' + encodeURIComponent(waText(p));
    var act = [];
    if (p.status === 'pending') act.push('<button class="btn primary" data-act="approved" data-id="' + p.id + '">✔ موافقة</button><button class="btn danger" data-act="rejected" data-id="' + p.id + '">✖ رفض</button>');
    if (p.status === 'approved') act.push('<button class="btn danger" data-act="suspended" data-id="' + p.id + '">⛔ إيقاف</button>');
    if (p.status === 'suspended' || p.status === 'rejected') act.push('<button class="btn primary" data-act="approved" data-id="' + p.id + '">✔ اعتماد</button>');
    return '<div class="card acard"><div class="top2">' + U.avatar(p) + '<div class="pname">' + esc(p.name) + ' ' + pill(st[0], st[1]) + (p.status === 'approved' && p.available ? ' ' + pill('🟢 متاح الآن') : '') + (!p.has_password ? ' ' + pill('بلا كلمة سر', 'warn') : '') + ' ' + (p.verified ? '<span class="vtag">✔ موثّق</span>' : pill('غير موثّق', 'warn')) + ' ' + pill('ملف ' + p.pct + '%', p.pct >= 70 ? '' : 'warn') + '</div></div>' +
      '<div class="psvc">' + esc(U.svcNames(p.services)) + '</div>' +
      '<div class="meta"><span>📞 <span class="ltr">' + esc(p.phone) + '</span></span><span>📍 ' + esc((p.hood ? p.hood + '، ' : '') + (SQ.cityName(p.city_id) || p.city_id)) + '</span><span>' + p.experience + ' سنة</span><span>💰 ' + Number(p.price).toLocaleString('en') + '</span></div>' +
      '<div class="meta"><span>📨 ' + p.requests_week + ' هذا الأسبوع / ' + p.requests_total + '</span><span>' + (p.rating != null ? '<span class="star">★ ' + p.rating + '</span> (' + p.rating_n + ')' : 'بلا تقييم') + '</span><span>✔ ' + p.ok + ' ✖ ' + p.fail + '</span><span>🔖 رقم الطلب <b class="ltr">' + refOf(p) + '</b></span><span class="muted">سُجّل ' + fmtDate(p.created) + ' · ظهر ' + U.timeAgo(p.last_seen) + '</span></div>' +
      (p.bio ? '<p class="note">' + esc(p.bio) + '</p>' : '') + (p.admin_note ? '<p class="note">📝 ' + esc(p.admin_note) + '</p>' : '') +
      '<div class="btnrow">' + act.join('') + '<a class="btn wa" href="' + wa + '" target="_blank" rel="noopener">' + (p.status === 'pending' ? '💬 رسالة التأكيد' : 'واتساب') + '</a><button class="btn ghost" data-act="verify" data-id="' + p.id + '">' + (p.verified ? 'إلغاء التوثيق' : '✔ توثيق') + '</button><a class="btn ghost" href="tel:' + esc(p.phone) + '">📞</a>' +
      '<button class="btn ghost" data-act="edit" data-id="' + p.id + '">✏️ تعديل</button><button class="btn ghost" data-act="pw" data-id="' + p.id + '">🔑 كلمة سر</button><button class="btn danger" data-act="del" data-id="' + p.id + '">🗑</button></div></div>';
  }

  async function provAction(a, p, btn) {
    if (!p) return;
    if (a === 'edit') return openProvForm(p);
    if (a === 'pw') return openResetPw(p);
    if (a === 'verify') { try { await db.adminSetVerified(code, p.id, !p.verified); toast(p.verified ? 'أُلغي التوثيق' : 'تم توثيق الصنايعي ✔'); refreshAll(); } catch (e) { fail(e); } return; }
    if (a === 'del') {
      modal('<h3>حذف الصنايعي</h3><p>سيُحذف <b>' + esc(p.name) + '</b> وكل طلباته وتقييماته نهائيا. هذا لا يمكن التراجع عنه. يمكنك بدل ذلك <b>إيقافه</b>.</p><div class="row2 mt"><button class="btn ghost" id="dn">إلغاء</button><button class="btn danger" id="dy">نعم، احذف</button></div>');
      on('dn', 'click', closeModal);
      on('dy', 'click', async function () { try { await db.adminDeleteProvider(code, p.id); closeModal(); toast('تم الحذف'); refreshAll(); } catch (e) { fail(e); } });
      return;
    }
    var names = { approved: 'اعتماد', rejected: 'رفض', suspended: 'إيقاف' };
    if ((a === 'rejected' || a === 'suspended') && !confirm(names[a] + ' ' + p.name + '؟')) return;
    btn.disabled = true;
    try { await db.adminSetStatus(code, p.id, a); toast('تم'); refreshAll(); } catch (e) { btn.disabled = false; fail(e); }
  }
  async function refreshAll() { try { ov = await db.adminOverview(code); } catch (e) {} if (tab === 'providers') { shellKeep(); loadProviders(true); } else render(); }
  function shellKeep() { /* تحديث عدّاد الشريط فقط */
    var b = document.querySelector('.anav button[data-tab="providers"]'); if (!b || !ov) return;
    b.innerHTML = 'الصنايعية' + (ov.pending ? '<span class="cnt">' + ov.pending + '</span>' : '');
  }

  /* نموذج إضافة/تعديل صنايعي */
  function openProvForm(p) {
    var isNew = !p, d = p || { services: [], radius: '10', from: '08:00', to: '20:00', state_id: '', city_id: '' }, services = (d.services || []).slice();
    modal('<h3>' + (isNew ? 'إضافة صنايعي' : 'تعديل ' + esc(p.name)) + '</h3>' +
      '<label class="field"><span>الاسم الكامل</span><input id="f_nm" value="' + esc(d.name || '') + '"></label>' +
      U.photoHtml('f_ph_') +
      '<label class="field"><span>رقم الهاتف</span><div class="phone-wrap"><b>' + SQ.COUNTRY.dial + '</b><input id="f_ph" class="ltr" inputmode="tel" value="' + esc(localPhone(d.phone)) + '" placeholder="' + SQ.COUNTRY.phoneHint + '"></div></label>' +
      '<label class="field"><span>رقم الواتساب (اتركه فارغا إن كان نفس الهاتف)</span><div class="phone-wrap"><b>' + SQ.COUNTRY.dial + '</b><input id="f_wa" class="ltr" inputmode="tel" value="' + esc(d.whatsapp && d.whatsapp !== d.phone ? localPhone(d.whatsapp) : '') + '"></div></label>' +
      U.svcFieldHtml('f_sv') +
      '<div class="row2"><label class="field"><span>الولاية</span><select id="f_st">' + U.stateOptions(d.state_id) + '</select></label><label class="field"><span>المدينة</span><select id="f_ct">' + U.cityOptions(d.state_id, d.city_id) + '</select></label></div>' +
      '<label class="field"><span>الحي</span><input id="f_hd" value="' + esc(d.hood || '') + '"></label>' +
      '<div class="row2"><label class="field"><span>النطاق</span><select id="f_rd">' + [['5', '5 كم'], ['10', '10 كم'], ['20', '20 كم'], ['all', 'كل المدينة']].map(function (r) { return '<option value="' + r[0] + '"' + (String(d.radius) === r[0] ? ' selected' : '') + '>' + r[1] + '</option>'; }).join('') + '</select></label>' +
      '<label class="field"><span>الخبرة (سنة)</span><input id="f_ex" type="number" min="0" value="' + esc(d.experience == null ? '' : d.experience) + '"></label><label class="field"><span>سعر الكشف</span><input id="f_pr" type="number" min="0" value="' + esc(d.price == null ? '' : d.price) + '"></label></div>' +
      '<label class="field"><span>وصف المهارة</span><textarea id="f_bio" maxlength="200">' + esc(d.bio || '') + '</textarea></label>' +
      '<div class="row2"><label class="field"><span>من الساعة</span><input id="f_fr" type="time" class="ltr" value="' + esc(d.from) + '"></label><label class="field"><span>إلى الساعة</span><input id="f_to" type="time" class="ltr" value="' + esc(d.to) + '"></label></div>' +
      '<label class="field"><span>ملاحظة خاصة بك (لا يراها الصنايعي)</span><textarea id="f_nt" maxlength="500">' + esc(d.admin_note || '') + '</textarea></label>' +
      (isNew ? '<label class="field"><span>كلمة سر مؤقتة للصنايعي</span><div class="row2" style="gap:6px"><input id="f_pw" class="ltr" value="' + U.randomPassword() + '"><button type="button" class="btn ghost small" id="f_gen">🎲 جديدة</button></div><small>يغيرها بنفسه من ملفه الشخصي. يُنشأ حسابه معتمدا مباشرة.</small></label>' : '') +
      '<div class="row2"><button class="btn ghost" id="f_cancel">إلغاء</button><button class="btn primary" id="f_save">' + (isNew ? 'إنشاء الحساب' : 'حفظ') + '</button></div>');
    var photoSt = { name: d.name || '', photo: d.photo || '' };
    U.bindStateCity('f_st', 'f_ct'); U.bindSvcField('f_sv', services); U.bindPhoto('f_ph_', photoSt);
    on('f_gen', 'click', function () { document.getElementById('f_pw').value = U.randomPassword(); });
    on('f_cancel', 'click', closeModal);
    on('f_save', 'click', async function () {
      var g = function (id) { return document.getElementById(id).value; };
      var nm = g('f_nm').trim(), ph = SQ.util.normalizePhone(g('f_ph')), waRaw = g('f_wa').trim(), wa = waRaw ? SQ.util.normalizePhone(waRaw) : ph;
      var st = g('f_st'), ct = g('f_ct');
      if (nm.length < 3) return toast('اكتب الاسم الكامل');
      if (!ph) return toast('رقم الهاتف غير صحيح');
      if (!wa) return toast('رقم الواتساب غير صحيح');
      if (!services.length) return toast('اختر خدمة واحدة على الأقل');
      if (!st || !ct) return toast('اختر الولاية والمدينة');
      if (g('f_ex') === '' || g('f_pr') === '') return toast('اكتب الخبرة وسعر الكشف');
      var o = { name: nm, phone: ph, whatsapp: wa, services: services, state_id: st, city_id: ct, hood: g('f_hd').trim(), radius: g('f_rd'), experience: +g('f_ex'), price: +g('f_pr'),
        bio: g('f_bio').trim(), photo: photoSt.photo, from: g('f_fr') || '08:00', to: g('f_to') || '20:00', admin_note: g('f_nt').trim() };
      var cc = SQ.findCity(ct).city;
      if (isNew || ct !== d.city_id) { o.lat = cc.lat; o.lng = cc.lng; }
      var b = document.getElementById('f_save'); b.disabled = true;
      try {
        if (isNew) {
          o.password = g('f_pw').trim();
          if (o.password.length < 6) { b.disabled = false; return toast('كلمة السر 6 أحرف على الأقل'); }
          await db.adminCreateProvider(code, o); showCreds(nm, ph, o.password, 'تم إنشاء الحساب ✅');
        } else { await db.adminUpdateProvider(code, p.id, o); closeModal(); toast('تم الحفظ'); }
        refreshAll();
      } catch (e) { b.disabled = false; fail(e); }
    });
  }

  function showCreds(name, phone, pw, title) {
    var msg = 'السلام عليكم ورحمة الله وبركاته أخي/أختي ' + name + ' 🌿\nمعك فريق *' + C.appName + '*. تم تجهيز حسابك واعتماده ✅\n\nالتطبيق: ' + appUrl() + '\nالهاتف: ' + phone + '\nكلمة السر: ' + pw + '\n\n🔐 يمكنك تغيير كلمة السر من ملفك الشخصي.\n💡 أضف صورتك ووصفا لمهارتك ليتقدم ترتيبك أمام الزبائن.' + SIGN;
    modal('<h3>' + esc(title) + '</h3><p>أرسل هذه البيانات للصنايعي ليدخل بها التطبيق (لن تظهر لك كلمة السر مرة ثانية):</p><div class="copybox">' + esc(phone) + '<br>' + esc(pw) + '</div>' +
      '<div class="btnrow"><a class="btn wa" target="_blank" rel="noopener" href="https://wa.me/' + SQ.util.digits(phone) + '?text=' + encodeURIComponent(msg) + '">إرسال عبر واتساب</a><button class="btn ghost" id="cp">نسخ</button></div><button class="btn primary mt" id="cok" style="width:100%">تم</button>');
    on('cp', 'click', function () { copyText(msg); }); on('cok', 'click', closeModal);
  }

  function openResetPw(p) {
    modal('<h3>كلمة سر جديدة لـ ' + esc(p.name) + '</h3><p class="note">سيُسجَّل خروجه من كل الأجهزة. أرسل له الكلمة الجديدة.</p>' +
      '<label class="field"><span>كلمة السر الجديدة</span><div class="row2" style="gap:6px"><input id="r_pw" class="ltr" value="' + U.randomPassword() + '"><button type="button" class="btn ghost small" id="r_gen">🎲 جديدة</button></div></label>' +
      '<div class="row2"><button class="btn ghost" id="r_cancel">إلغاء</button><button class="btn primary" id="r_save">حفظ</button></div>');
    on('r_gen', 'click', function () { document.getElementById('r_pw').value = U.randomPassword(); });
    on('r_cancel', 'click', closeModal);
    on('r_save', 'click', async function () {
      var pw = document.getElementById('r_pw').value.trim();
      if (pw.length < 6) return toast('كلمة السر 6 أحرف على الأقل');
      try { await db.adminResetPassword(code, p.id, pw); showCreds(p.name, p.phone, pw, 'تم تعيين كلمة السر ✅'); loadProviders(true); } catch (e) { fail(e); }
    });
  }

  async function exportCsv(f) {
    var res;
    try { res = await db.adminProviders(code, { q: f.q || '', status: f.status || '', service: f.service || '', city: f.city || '', limit: 1000, offset: 0 }); } catch (e) { return fail(e); }
    var head = ['الاسم', 'الهاتف', 'الواتساب', 'الخدمات', 'الولاية', 'المدينة', 'الحي', 'الحالة', 'الخبرة', 'سعر الكشف', 'التقييم', 'عدد التقييمات', 'ناجحة', 'فاشلة', 'طلبات الأسبوع', 'إجمالي الطلبات', 'تاريخ التسجيل', 'ملاحظة'];
    var q = function (v) { return '"' + String(v == null ? '' : v).replace(/"/g, '""') + '"'; };
    var lines = [head.map(q).join(',')].concat(res.items.map(function (p) {
      return [p.name, p.phone, p.whatsapp, U.svcNames(p.services), SQ.stateName(p.state_id), SQ.cityName(p.city_id), p.hood, (STATUS[p.status] || [p.status])[0], p.experience, p.price, p.rating == null ? '' : p.rating, p.rating_n, p.ok, p.fail, p.requests_week, p.requests_total, fmtDate(p.created), p.admin_note].map(q).join(',');
    }));
    var blob = new Blob(['﻿' + lines.join('\r\n')], { type: 'text/csv;charset=utf-8' }), a = document.createElement('a');
    a.href = URL.createObjectURL(blob); a.download = 'sanayei-providers-' + fmtDate(Date.now()) + '.csv'; document.body.appendChild(a); a.click(); document.body.removeChild(a);
    toast('تم تنزيل ' + res.items.length + ' سجل');
  }

  /* ---------- الطلبات ---------- */
  async function viewRequests() {
    shell('<div class="toolbar"><select id="rs"><option value="">كل الحالات</option>' + Object.keys(REQ).map(function (k) { return '<option value="' + k + '"' + (rf.status === k ? ' selected' : '') + '>' + REQ[k] + '</option>'; }).join('') + '</select></div><div id="rlist" class="agrid"><div class="spin">جاري التحميل...</div></div>');
    on('rs', 'change', function () { rf.status = this.value; viewRequests(); });
    var list;
    try { list = await db.adminRequests(code, 100, rf.status); } catch (e) { return fail(e); }
    var el = document.getElementById('rlist'); if (!el) return;
    el.innerHTML = list.length ? list.map(function (r) {
      return '<div class="card"><div class="pname">' + esc(r.provider_name) + '</div><div class="psvc">' + esc(U.svc(r.service).icon + ' ' + U.svc(r.service).name) + ' · ' + esc(SQ.cityName(r.city_id) || '') + '</div><div class="meta"><span>' + (r.channel === 'call' ? '📞 اتصال' : '💬 واتساب') + '</span><span>' + pill(REQ[r.status] || r.status, r.status === 'done' ? '' : r.status === 'failed' ? 'bad' : 'warn') + '</span><span class="muted">' + U.timeAgo(r.ts) + '</span></div></div>';
    }).join('') : '<div class="empty"><div class="big">📋</div>لا توجد طلبات</div>';
  }

  /* ---------- الخدمات ---------- */
  async function viewServices() {
    shell('<div class="toolbar"><button class="btn primary" id="addSv">➕ إضافة خدمة</button></div><p class="note" style="margin:-4px 0 12px">رتّب الخدمات بالأسهم، وعدّل الاسم والأيقونة، أو أخفِ الخدمة (لا تظهر للزبائن ولا في التسجيل). لا تُحذف إلا الخدمة التي لا يستخدمها أي صنايعي. التغيير يظهر في التطبيق فورا.</p><div id="slist"><div class="spin">جاري التحميل...</div></div>');
    on('addSv', 'click', function () { openSvcForm(null); });
    var list;
    try { list = await db.adminServices(code); } catch (e) { return fail(e); }
    var el = document.getElementById('slist'); if (!el) return;
    el.innerHTML = list.map(function (s, i) {
      return '<div class="srv ' + (s.active ? '' : 'off') + '"><div><button class="mini" data-m="up" data-i="' + i + '"' + (i === 0 ? ' disabled' : '') + '>▲</button><br><button class="mini" data-m="dn" data-i="' + i + '"' + (i === list.length - 1 ? ' disabled' : '') + '>▼</button></div>' +
        '<div class="si">' + esc(s.icon) + '</div><div class="nm"><b>' + esc(s.name) + '</b><small>' + esc(SQ.catOf(s).icon + ' ' + SQ.catOf(s).name) + ' · ' + s.providers + ' صنايعي' + (s.active ? '' : ' · مخفية') + '</small></div>' +
        '<button class="mini" data-m="tg" data-i="' + i + '" title="' + (s.active ? 'إخفاء' : 'إظهار') + '">' + (s.active ? '👁' : '🚫') + '</button><button class="mini" data-m="ed" data-i="' + i + '" title="تعديل">✏️</button><button class="mini" data-m="del" data-i="' + i + '" title="حذف">🗑</button></div>';
    }).join('');
    el.onclick = async function (e) {
      var b = e.target.closest('[data-m]'); if (!b || b.disabled) return;
      var i = +b.getAttribute('data-i'), m = b.getAttribute('data-m'), s = list[i];
      try {
        if (m === 'up' || m === 'dn') {
          var j = m === 'up' ? i - 1 : i + 1, t = list[i]; list[i] = list[j]; list[j] = t;
          await db.adminReorderServices(code, list.map(function (x) { return x.id; })); await SQ.refreshServices(); viewServices();
        } else if (m === 'tg') { await db.adminSaveService(code, s.id, s.name, s.icon, !s.active, s.cat || SQ.catOf(s).id); await SQ.refreshServices(); viewServices(); }
        else if (m === 'ed') openSvcForm(s);
        else if (m === 'del') {
          modal('<h3>حذف الخدمة</h3><p>حذف <b>' + esc(s.name) + '</b> نهائيا؟' + (s.providers ? '<br><span class="dangertxt">يستخدمها ' + s.providers + ' صنايعي، فلن يُسمح بالحذف. أخفِها بدل ذلك.</span>' : '') + '</p><div class="row2 mt"><button class="btn ghost" id="dn">إلغاء</button><button class="btn danger" id="dy">حذف</button></div>');
          on('dn', 'click', closeModal);
          on('dy', 'click', async function () { try { await db.adminDeleteService(code, s.id); closeModal(); await SQ.refreshServices(); toast('تم الحذف'); viewServices(); } catch (x) { closeModal(); fail(x); } });
        }
      } catch (x) { fail(x); }
    };
  }

  function openSvcForm(s) {
    var EMO = ['🔧', '⚡', '☀️', '❄️', '📐', '🔨', '🎨', '🧱', '⚙️', '💧', '📱', '🔌', '🚚', '🧹', '🧵', '💈', '🔑', '🚗', '🛠️', '🪚', '🪟', '🌿', '🐑', '📷', '🍞', '💻', '🛢️', '➕'];
    modal('<h3>' + (s ? 'تعديل الخدمة' : 'إضافة خدمة') + '</h3><label class="field"><span>اسم الخدمة</span><input id="s_nm" maxlength="40" value="' + esc(s ? s.name : '') + '"></label>' +
      '<label class="field"><span>الأيقونة (اكتب أو اختر)</span><input id="s_ic" maxlength="8" value="' + esc(s ? s.icon : '🔧') + '" style="font-size:24px;text-align:center"></label>' +
      '<div class="emojis">' + EMO.map(function (e) { return '<button type="button" data-e="' + e + '">' + e + '</button>'; }).join('') + '</div>' +
      '<label class="field"><span>التصنيف</span><select id="s_ct">' + SQ.CATEGORIES.map(function (c) { return '<option value="' + c.id + '"' + ((s ? (s.cat || SQ.catOf(s).id) : 'home') === c.id ? ' selected' : '') + '>' + c.icon + ' ' + esc(c.name) + '</option>'; }).join('') + '</select></label>' +
      '<label class="check"><input type="checkbox" id="s_ac"' + (!s || s.active ? ' checked' : '') + '> ظاهرة للزبائن وفي التسجيل</label>' +
      '<div class="row2"><button class="btn ghost" id="s_cancel">إلغاء</button><button class="btn primary" id="s_save">حفظ</button></div>');
    U.each('.emojis button', function (b) { b.addEventListener('click', function () { document.getElementById('s_ic').value = b.getAttribute('data-e'); }); });
    on('s_cancel', 'click', closeModal);
    on('s_save', 'click', async function () {
      var nm = document.getElementById('s_nm').value.trim(), ic = document.getElementById('s_ic').value.trim() || '🔧';
      if (nm.length < 2) return toast('اكتب اسم الخدمة');
      try { await db.adminSaveService(code, s ? s.id : '', nm, ic, document.getElementById('s_ac').checked, document.getElementById('s_ct').value); closeModal(); await SQ.refreshServices(); toast('تم الحفظ'); viewServices(); } catch (e) { fail(e); }
    });
  }

  /* ---------- البلاغات ---------- */
  async function viewReports() {
    shell('<div id="rplist" class="agrid"><div class="spin">جاري التحميل...</div></div>');
    var reps;
    try { reps = await db.adminReports(code); } catch (e) { return fail(e); }
    var el = document.getElementById('rplist'); if (!el) return;
    el.innerHTML = reps.length ? reps.map(function (r) {
      return '<div class="card"><div class="pname">' + esc(r.provider_name) + ' ' + pill((STATUS[r.provider_status] || ['—'])[0], r.provider_status === 'approved' ? '' : 'bad') + '</div><div class="psvc">السبب: ' + esc(r.reason) + ' · ' + U.timeAgo(r.ts) + '</div><div class="btnrow">' +
        (r.provider_status === 'approved' ? '<button class="btn danger" data-act="suspend" data-id="' + r.provider_id + '">⛔ إيقاف الصنايعي</button>' : '') + '<button class="btn ghost" data-act="resolve" data-id="' + r.id + '">✔ تم الحل</button></div></div>';
    }).join('') : '<div class="empty"><div class="big">✔</div>لا توجد بلاغات</div>';
    el.onclick = async function (e) {
      var b = e.target.closest('[data-act]'); if (!b) return; b.disabled = true;
      try {
        if (b.getAttribute('data-act') === 'resolve') await db.adminResolveReport(code, b.getAttribute('data-id'));
        else await db.adminSetStatus(code, b.getAttribute('data-id'), 'suspended');
        toast('تم'); render();
      } catch (x) { b.disabled = false; fail(x); }
    };
  }

  /* ---------- الإعدادات ---------- */
  async function viewSettings() {
    var cfg = {};
    try { cfg = await db.adminGetSettings(code); } catch (e) { return fail(e); }
    shell('<div class="agrid"><div class="card"><b>بيانات الدعم</b><p class="note">تظهر للصنايعية والزبائن في زر "تواصل مع الدعم".</p>' +
      '<label class="field"><span>واتساب الدعم (بصيغة دولية بدون +)</span><input id="c_wa" class="ltr" inputmode="tel" placeholder="249912345678" value="' + esc(cfg.support_whatsapp || '') + '"></label>' +
      '<label class="field"><span>بريد الدعم</span><input id="c_em" class="ltr" type="email" value="' + esc(cfg.support_email || '') + '"></label><button class="btn primary" id="c_save" style="width:100%">حفظ</button></div>' +
      '<div class="card"><b>تغيير رمز المدير</b>' + U.pwHtml('k_new', 'الرمز الجديد', '8 أحرف على الأقل، لا تشاركه') + U.pwHtml('k_new2', 'أعد كتابته') + '<button class="btn primary" id="k_save" style="width:100%">تغيير الرمز</button></div>' +
      '<div class="card"><b>نسخة احتياطية</b><p class="note">نزّل بيانات كل الصنايعية في ملف يفتح في Excel. أنصح بفعل ذلك أسبوعيا.</p><button class="btn ghost" id="c_csv" style="width:100%">⬇ تنزيل كل الصنايعية (CSV)</button></div>' +
      '<div class="card"><b>روابط</b><div class="kv"><span>التطبيق</span><a href="' + esc(appUrl()) + '" target="_blank" rel="noopener">فتح</a></div><div class="kv"><span>سياسة الخصوصية</span><a href="' + esc(appUrl()) + 'privacy-policy.html" target="_blank" rel="noopener">فتح</a></div></div></div>');
    on('c_csv', 'click', function () { exportCsv({}); });
    on('c_save', 'click', async function () {
      try { await db.adminSaveSettings(code, { support_whatsapp: document.getElementById('c_wa').value.replace(/\D/g, ''), support_email: document.getElementById('c_em').value.trim() }); toast('تم الحفظ'); } catch (e) { fail(e); }
    });
    on('k_save', 'click', async function () {
      var a = document.getElementById('k_new').value, b = document.getElementById('k_new2').value;
      if (a.length < 8) return toast('الرمز 8 أحرف على الأقل');
      if (a !== b) return toast('الرمزان غير متطابقين');
      try { await db.adminChangeCode(code, a); code = a; try { sessionStorage.setItem('sq_admin', a); } catch (e) {} toast('تم تغيير الرمز. احفظه جيدا'); document.getElementById('k_new').value = ''; document.getElementById('k_new2').value = ''; } catch (e) { fail(e); }
    });
  }

  /* ---------- الإقلاع ---------- */
  (async function boot() {
    $app.innerHTML = '<div class="spin" style="margin-top:30vh">جاري التحميل...</div>';
    await SQ.refreshServices();
    render();
  })();
})();
