/* صنايعي قريب - لوحة المدير (صفحة منفصلة، غير مرتبطة بالتطبيق العام) */
(function () {
  'use strict';
  var SQ = window.SQ, C = SQ.CONFIG, db = SQ.db, U = SQ.ui, esc = U.esc, toast = U.toast, on = U.on, modal = U.modal, closeModal = U.closeModal;
  var $app = document.getElementById('app');
  var code = '', tab = 'overview', ov = null, cn = { badges: 0, custom: 0 }, bf = { filter: 'pending', q: '' };
  var pf = { q: '', status: '', service: '', city: '', limit: 30, offset: 0 }, rf = { status: '' };
  var rows = {}; // نسخة الصنايعية المعروضين حسب المعرّف
  var mp = null, rng = '7d'; // الصنايعي المفتوح في صفحة الإدارة، وفترة الطلبات في النظرة العامة
  try { code = sessionStorage.getItem('sq_admin') || ''; } catch (e) {}
  document.body.classList.add('admin');

  var TABS = [['overview', 'نظرة عامة'], ['providers', 'الصنايعية'], ['reviews', 'التقييمات'], ['names', 'الأسماء المحجوزة'], ['requests', 'الطلبات'], ['stalled', 'معلّقة'], ['inactive', 'غير النشطة'], ['confirmed', 'المؤكدة'], ['payments', 'الدفعيات'], ['services', 'الخدمات'], ['custom', 'خدمات مقترحة'], ['bans', 'الحظر'], ['reports', 'البلاغات'], ['settings', 'الإعدادات']];
  var STATUS = { pending: ['بانتظار الموافقة', 'warn'], approved: ['معتمد', ''], suspended: ['موقوف', 'bad'], rejected: ['مرفوض', 'bad'], banned: ['محظور', 'bad'] };
  var REQ = { 'new': 'بانتظار رأي الزبون', done: 'ناجحة', failed: 'فاشلة', not_agreed: 'ما اتفقنا' };

  function refOf(p) { return String(p.id).replace(/-/g, '').slice(0, 4).toUpperCase(); }
  var SIGN = '\n\n— فريق ' + C.appName;
  function waText(p) {
    var svcs = U.svcNames(p.services), city = SQ.cityName(p.city_id) || '', hi = 'السلام عليكم أخي/أختي ' + p.name + '\n';
    if (p.status === 'pending') return hi + 'معك فريق ' + C.appName + '. استلمنا طلب انضمامك (' + svcs + ' - ' + city + ').\nللتأكيد رد برقم طلبك: ' + refOf(p) + ' وكلمة "تأكيد".\nلترتيب أفضل أضف صورة ووصفا من ملفك.' + SIGN;
    if (p.status === 'approved') return hi + 'تم اعتماد حسابك في ' + C.appName + '. فعّل زر "متاح" ليصلك الزبائن.\nالتطبيق: ' + appUrl() + SIGN;
    if (p.status === 'rejected') return hi + 'شكرا لتسجيلك في ' + C.appName + '. لم نتمكن من اعتماد طلبك حاليا لحاجة بياناتك للاستكمال. رد هنا لنساعدك.' + SIGN;
    if (p.status === 'suspended') return hi + 'تم إيقاف ظهور حسابك في ' + C.appName + ' مؤقتا للمراجعة. رد هنا لنحل الأمر سريعا.' + SIGN;
    return hi + 'معك فريق ' + C.appName + '.' + SIGN;
  }
  /* قوالب الرسائل اليدوية (واتساب / إيميل / نسخ): قصيرة وبلا رموز تعبيرية */
  function msgTemplates(x) {
    var hi = 'السلام عليكم أخي/أختي ' + x.name + '\n', t = SQ.tierOf(x.jobs), nx = SQ.nextTier(x.jobs), url = appUrl() + (x.username ? x.username : '');
    var next = nx ? ' باقي ' + (nx.min - x.jobs) + ' عمل لشارة «' + nx.name + '».' : ' وصلت لأعلى شارة، شكرا لتميزك.';
    return [
      { id: 'done', label: 'تهنئة بإتمام خدمة', subject: 'مبروك إتمام خدمة جديدة', body: hi + 'مبروك، تم تأكيد إتمامك خدمة جديدة. أعمالك المؤكدة: ' + x.jobs + (t ? '، شارتك: ' + t.name : '') + '.' + next + SIGN },
      { id: 'badge', label: 'تهنئة بشارة', subject: 'مبروك شارتك الجديدة', body: hi + (t ? 'مبروك، حصلت على شارة «' + t.name + '» بعد ' + x.jobs + ' عمل مؤكد. تزيد الشارة ثقة الزبائن وترفع ظهورك.' : 'أول شارة إنجاز تحصل عليها بعد ' + SQ.TIERS[SQ.TIERS.length - 1].min + ' أعمال مؤكدة ونحن معك.') + '\nرابط ملفك: ' + url + SIGN },
      { id: 'how', label: 'كيف أحصل على التوثيق', subject: 'كيف تحصل على علامة التوثيق', body: hi + 'للحصول على علامة التوثيق أرسل لنا صورة وثيقة سارية (بطاقة أو رخصة أو جواز) مع صورة لك تحملها، وسنحذف الصور بعد التحقق. شارات الإنجاز تظهر تلقائيا مع الأعمال المؤكدة من عملائك.' + SIGN }
    ];
  }
  function msgModal(x) {
    var T = msgTemplates(x), cur = 0;
    modal('<h3>رسالة إلى ' + esc(x.name) + '</h3><div class="seg" id="mt_t" style="flex-wrap:wrap;gap:6px">' + T.map(function (t, i) { return '<button class="chip' + (i === 0 ? ' on' : '') + '" data-i="' + i + '">' + t.label + '</button>'; }).join('') + '</div>' +
      '<label class="field mt"><span>نص الرسالة (يمكنك تعديله قبل الإرسال)</span><textarea id="mt_b" rows="7" style="min-height:150px"></textarea></label>' +
      '<div class="btnrow"><button class="btn wa" id="mt_wa">واتساب</button><button class="btn ghost" id="mt_em">إيميل</button><button class="btn ghost" id="mt_cp">نسخ</button></div>' +
      (x.id ? '<button class="btn ghost mt" id="mt_in" style="width:100%">إرسال كإشعار داخل التطبيق</button>' : '') +
      '<button class="btn ghost mt" id="mt_x" style="width:100%">إغلاق</button>');
    var ta = document.getElementById('mt_b'); ta.value = T[0].body;
    document.getElementById('mt_t').addEventListener('click', function (e) {
      var b = e.target.closest('[data-i]'); if (!b) return; cur = +b.getAttribute('data-i'); ta.value = T[cur].body;
      U.each('#mt_t .chip', function (c) { c.classList.toggle('on', c === b); });
    });
    on('mt_x', 'click', closeModal);
    on('mt_wa', 'click', function () { window.open('https://wa.me/' + SQ.util.digits(x.phone) + '?text=' + encodeURIComponent(ta.value), '_blank'); });
    on('mt_em', 'click', function () { if (!x.email) toast('لا يوجد بريد لهذا الصنايعي بعد، أضفه من تعديل الملف'); window.location.href = 'mailto:' + encodeURIComponent(x.email || '') + '?subject=' + encodeURIComponent(T[cur].subject) + '&body=' + encodeURIComponent(ta.value.replace(/\*/g, '')); });
    on('mt_in', 'click', async function () {
      var body = ta.value.replace(/\*/g, '').trim(); if (!body) return toast('الرسالة فارغة');
      try { await db.adminSendNotification(code, x.id, T[cur].label, body); toast('وصلت الرسالة لجرس الصنايعي'); } catch (e) { toast(U.errMsg ? U.errMsg(e) : 'تعذر الإرسال'); }
    });
    on('mt_cp', 'click', function () { ta.select(); try { navigator.clipboard.writeText(ta.value); } catch (e) { document.execCommand('copy'); } toast('تم نسخ الرسالة'); });
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
      var n = t[0] === 'providers' && ov && ov.pending ? ov.pending : t[0] === 'reports' && ov && ov.reports_open ? ov.reports_open : t[0] === 'badges' ? (cn.badges || 0) : t[0] === 'custom' ? (cn.custom || 0) : 0;
      return '<button class="' + (tab === t[0] ? 'on' : '') + '" data-tab="' + t[0] + '">' + t[1] + (n ? '<span class="cnt">' + n + '</span>' : '') + '</button>';
    }).join('');
    $app.innerHTML = '<header class="top"><a class="back" href="' + esc(appUrl()) + '" title="فتح التطبيق" aria-label="التطبيق">' + SQ.I('home', 22) + '</a><h1>إدارة صنايعي قريب</h1><button class="back" id="out" title="خروج" aria-label="خروج">' + SQ.I('out', 22) + '</button></header>' +
      '<nav class="anav">' + nav + '</nav><main class="main">' + inner + '</main>';
    on('out', 'click', logout);
    U.each('.anav button', function (b) { b.addEventListener('click', function () { tab = b.getAttribute('data-tab'); mp = null; render(); }); });
  }

  /* تحديث تلقائي لعدّادات التبويبات كل دقيقة دون إزعاج ما تعمل عليه */
  setInterval(async function () {
    if (!code) return;
    try {
      var o = await db.adminOverview(code), c = await db.adminCounts(code); ov = o; cn = c;
      U.each('.anav button', function (b) {
        var t = b.getAttribute('data-tab'), n = t === 'providers' ? o.pending : t === 'reports' ? o.reports_open : t === 'badges' ? c.badges : t === 'custom' ? c.custom : 0;
        var sp = b.querySelector('.cnt'); if (n) { if (!sp) { sp = document.createElement('span'); sp.className = 'cnt'; b.appendChild(sp); } sp.textContent = n; } else if (sp) sp.remove();
      });
    } catch (e) { /* تجاهل */ }
  }, 60000);

  async function render() {
    if (!code) return login();
    try { ov = await db.adminOverview(code); } catch (e) { if (guard(e)) return; ov = null; }
    try { if (ov) ov.totals = await db.adminTotals(code); } catch (e) {}
    try { cn = await db.adminCounts(code); } catch (e) { cn = { badges: 0, custom: 0 }; }
    ({ overview: viewOverview, custom: viewCustom, providers: viewProviders, requests: viewRequests, confirmed: viewConfirmed, payments: viewPayments, services: viewServices, reports: viewReports, settings: viewSettings, bans: viewBans, reviews: viewReviews, names: viewNames, stalled: viewStalled, inactive: viewInactive })[tab]();
  }

  /* ---------- نظرة عامة ---------- */
  function viewOverview() {
    if (!ov) { shell('<div class="empty"><div class="big">📶</div>تعذر الاتصال<div class="mt"><button class="btn primary" id="retry">إعادة المحاولة</button></div></div>'); return on('retry', 'click', render); }
    var tt = ov.totals || {}; var max = Math.max.apply(null, ov.by_day.map(function (d) { return d.n; }).concat([1]));
    var body = (ov.pending ? '<div class="banner">🔔 عندك <b>' + ov.pending + '</b> طلب انضمام بانتظار موافقتك.<br><button class="btn primary" id="goPending">راجع الطلبات الآن</button></div>' : '') +
      '<div class="card" style="background:linear-gradient(135deg,#0F4C8A,#2B8CF0);color:#fff"><b>💰 الأرباح الكلية</b><div style="font-size:30px;font-weight:800;margin:6px 0">' + Number(tt.earn_total || 0).toLocaleString('en') + ' <small style="font-size:14px">جنيه</small></div><div style="display:flex;gap:18px;flex-wrap:wrap;font-size:13px;opacity:.95"><span>✔ محصّل: <b>' + Number(tt.earn_paid || 0).toLocaleString('en') + '</b></span><span>⏳ مستحق: <b>' + Number(tt.earn_due || 0).toLocaleString('en') + '</b></span><span>🛠 إجمالي الخدمات المكتملة: <b>' + Number(tt.services_total || 0).toLocaleString('en') + '</b></span></div>' + (tt.first_ts ? '<div style="font-size:12px;opacity:.85;margin-top:6px">من ' + fmtDate(tt.first_ts) + ' إلى ' + fmtDate(tt.last_ts) + '</div>' : '') + '</div>' +
      '<div class="sgrid">' + [
        ['معتمدون', ov.approved, ''], ['بانتظار الموافقة', ov.pending, ov.pending ? 'warn' : ''], ['متاحون الآن', ov.available_now, ''], ['موقوفون', ov.suspended, ''],
        ['طلبات اليوم', ov.requests_today, ''], ['طلبات الأسبوع', ov.requests_week, ''], ['إجمالي الطلبات', ov.requests_total, ''], ['متوسط التقييم', ov.reviews_total ? '★ ' + ov.avg_rating : '-', '']
      ].map(function (x) { return '<div class="sbox ' + x[2] + '"><b>' + x[1] + '</b><small>' + x[0] + '</small></div>'; }).join('') + '</div>' +
      '<div class="agrid"><div class="card"><div class="rhead"><b>الطلبات</b><select id="rngSel" class="rsel">' + [['7d', 'آخر 7 أيام'], ['28d', 'آخر 28 يوما'], ['6m', 'آخر 6 أشهر'], ['1y', 'آخر سنة'], ['all', 'كل الوقت']].map(function (r) { return '<option value="' + r[0] + '"' + (rng === r[0] ? ' selected' : '') + '>' + r[1] + '</option>'; }).join('') + '</select></div><div id="rngBox"><div class="spin">...</div></div></div>' +
      '<div class="card"><b>أكثر الخدمات طلبا</b><table class="tbl"><tr><th>الخدمة</th><th>صنايعية</th><th>طلبات الأسبوع</th></tr>' + ov.top_services.map(function (s) {
        return '<tr><td>' + esc(s.icon) + ' ' + esc(s.name) + '</td><td>' + s.providers + '</td><td>' + s.requests_week + '</td></tr>';
      }).join('') + '</table></div>' +
      '<div class="card"><b>الصنايعية حسب المدينة</b>' + (ov.by_city.length ? '<table class="tbl">' + ov.by_city.map(function (c) { return '<tr><td>' + esc(SQ.cityName(c.city_id) || c.city_id) + '</td><td>' + c.n + '</td></tr>'; }).join('') + '</table>' : '<p class="muted">لا يوجد بعد</p>') + '</div>' +
      '<div class="card"><b>إجراءات سريعة</b><div class="btnrow"><button class="btn primary" id="qAdd">➕ إضافة صنايعي</button><button class="btn ghost" id="qSvc">🧰 إدارة الخدمات</button><button class="btn ghost" id="qCsv">⬇ تصدير الصنايعية (CSV)</button></div></div></div>';
    shell(body);
    on('rngSel', 'change', function () { rng = this.value; loadSeries(); });
    loadSeries();
    on('goPending', 'click', function () { pf.status = 'pending'; pf.offset = 0; tab = 'providers'; render(); });
    on('qAdd', 'click', function () { tab = 'providers'; render().then(function () { openProvForm(null); }); });
    on('qSvc', 'click', function () { tab = 'services'; render(); });
    on('qCsv', 'click', function () { exportCsv({}); });
  }

  async function loadSeries() {
    var box = document.getElementById('rngBox'); if (!box) return;
    var r;
    try { r = await db.adminRequestsSeries(code, rng); } catch (e) { box.innerHTML = '<p class="muted">تعذر تحميل الإحصاء</p>'; return; }
    box = document.getElementById('rngBox'); if (!box) return;
    var pts = r.points || [], max = Math.max.apply(null, pts.map(function (d) { return d.n; }).concat([1])), dense = pts.length > 14, step = pts.length > 14 ? Math.ceil(pts.length / 7) : 1;
    var cmp = '';
    if (r.prev != null) {
      if (r.prev === 0) cmp = r.total > 0 ? '<span class="up">جديد مقارنة بالفترة السابقة</span>' : '';
      else { var ch = Math.round((r.total - r.prev) / r.prev * 100); cmp = '<span class="' + (ch >= 0 ? 'up' : 'down') + '">' + (ch >= 0 ? '▲ ' : '▼ ') + Math.abs(ch) + '% عن الفترة السابقة (' + r.prev + ')</span>'; }
    }
    box.innerHTML = '<div class="rtotal"><b>' + Number(r.total).toLocaleString('en') + '</b> طلب ' + cmp + '</div><div class="bars' + (dense ? ' dense' : '') + '">' + pts.map(function (d, i) {
      return '<div class="bar"><b>' + (dense && !d.n ? '' : d.n) + '</b><i style="height:' + Math.round(d.n / max * 100) + '%"></i><small>' + (i % step === 0 || i === pts.length - 1 ? esc(d.d) : '') + '</small></div>';
    }).join('') + '</div>';
  }

  /* ---------- التقييمات: مراجعة وإخفاء وحذف ---------- */
  var rv = { filter: 'all', q: '' };
  async function viewReviews() {
    shell('<div class="toolbar"><input id="rq" type="search" placeholder="ابحث باسم الصنايعي أو بنص التعليق" value="' + esc(rv.q) + '"><select id="rf">' + [['all', 'كل التقييمات'], ['low', 'منخفضة أو غير ناجحة'], ['comments', 'فيها تعليق'], ['hidden', 'المخفية']].map(function (f) { return '<option value="' + f[0] + '"' + (rv.filter === f[0] ? ' selected' : '') + '>' + f[1] + '</option>'; }).join('') + '</select></div>' +
      '<p class="note">إخفاء التقييم يزيله من نسبة الصنايعي وعرضه للزبائن، ويمكنك إرجاعه. الحذف نهائي. عدد الخدمات المكتملة لا يتأثر.</p><div id="rvlist" class="plist"><div class="spin">جاري التحميل...</div></div>');
    var t; on('rq', 'input', function () { var v = this.value; clearTimeout(t); t = setTimeout(function () { rv.q = v.trim(); loadReviews(); }, 350); });
    on('rf', 'change', function () { rv.filter = this.value; loadReviews(); });
    document.getElementById('rvlist').addEventListener('click', onReviewAct);
    loadReviews();
  }


  /* ---------- طلبات معلّقة + حسابات غير نشطة ---------- */
  async function viewStalled() {
    shell('<div class="card"><b>طلبات مقبولة ومعلّقة أكثر من 3 أيام</b><p class="note">النظام يذكّر الطرفين تلقائيا بعد 48 ساعة وعند 3 أيام، ويغلق الطلب تلقائيا عند 7 أيام دون عمولة ولا أثر على التقييم. من هنا يمكنك تذكيرهما يدويا (مرة كل 6 ساعات).</p></div><div id="st_list" class="plist"><div class="spin">جاري التحميل...</div></div>');
    document.getElementById('st_list').addEventListener('click', async function (e) {
      var b = e.target.closest('[data-st]'); if (!b) return;
      try { await db.adminNudgeStalled(code, b.getAttribute('data-st')); toast('تم إرسال التذكير'); loadStalled(); } catch (x) { fail(/cooldown/.test(x.message) ? new Error('أُرسل تذكير قبل أقل من 6 ساعات') : x); }
    });
    loadStalled();
  }
  async function loadStalled() {
    var box = document.getElementById('st_list'); if (!box) return;
    var rows; try { rows = await db.adminStalled(code); } catch (e) { return fail(e); }
    box.innerHTML = rows.length ? rows.map(function (r) {
      return '<div class="card prow"><div class="pr-main"><div class="pr-name">' + esc(r.provider || '') + '</div><div class="pr-sub">' + esc(r.service || '') + ' · <span class="ltr">' + esc(r.phone || '') + '</span></div></div>' +
        pill('منذ ' + r.days + ' أيام', r.days >= 6 ? 'bad' : 'warn') + '<div class="btnrow"><button class="btn ghost" data-st="' + r.id + '">تذكير الطرفين</button></div></div>';
    }).join('') : '<div class="empty"><div class="big">✅</div>لا توجد طلبات معلّقة</div>';
  }
  async function viewInactive() {
    shell('<div class="card"><b>حسابات لم تدخل منذ 5 أشهر فأكثر</b><p class="note">تُحذف الحسابات بعد 6 أشهر (180 يوما) من آخر ظهور. أرسل تذكيرا بالبريد وبإشعار داخل التطبيق قبل الموعد بـ 10 أيام (عند بقاء 10 أيام أو أقل). الحذف يدوي منك.</p></div><div id="in_list" class="plist"><div class="spin">جاري التحميل...</div></div>');
    document.getElementById('in_list').addEventListener('click', async function (e) {
      var b = e.target.closest('[data-in]'); if (!b) return;
      var id = b.getAttribute('data-id'), a = b.getAttribute('data-in');
      try {
        if (a === 'mail') { var r = await db.adminInactiveRemind(code, id); toast(r.emailed ? 'أُرسل البريد والإشعار' : 'أُرسل الإشعار داخل التطبيق فقط' + (r.why === 'no_email' ? ' (لا بريد)' : '')); return loadInactive(); }
        if (!confirm('حذف هذا الحساب نهائيا؟')) return;
        await db.adminDeleteProvider(code, id); toast('تم الحذف'); loadInactive();
      } catch (x) { fail(/cooldown/.test(x.message) ? new Error('أُرسل تذكير قبل أقل من 3 أيام') : x); }
    });
    loadInactive();
  }
  async function loadInactive() {
    var box = document.getElementById('in_list'); if (!box) return;
    var rows; try { rows = await db.adminInactive(code, 150); } catch (e) { return fail(e); }
    box.innerHTML = rows.length ? rows.map(function (r) {
      var left = r.left, tone = left <= 0 ? 'bad' : (left <= 10 ? 'warn' : 'ok');
      return '<div class="card prow"><div class="pr-main"><div class="pr-name">' + esc(r.name || '') + '</div><div class="pr-sub">آخر ظهور قبل ' + r.days + ' يوما · <span class="ltr">' + esc(r.phone || '') + '</span>' + (r.email ? ' · ✉' : ' · بلا بريد') + (r.reminded_at ? ' · ذُكّر ' + fmtDate(r.reminded_at) : '') + '</div></div>' +
        pill(left <= 0 ? 'انتهت المهلة' : 'تبقى ' + left + ' يوما', tone) +
        '<div class="btnrow"><button class="btn ghost" data-in="mail" data-id="' + r.id + '">تذكير</button><button class="btn danger" data-in="del" data-id="' + r.id + '">حذف</button></div></div>';
    }).join('') : '<div class="empty"><div class="big">🌿</div>كل الحسابات نشطة</div>';
  }

  /* ---------- الأسماء المحجوزة ---------- */
  async function viewNames() {
    shell('<div class="card"><b>حجز أسماء مستخدمين</b><p class="note">أسماء لا يستطيع أي مستخدم اختيارها بنفسه، وتمنحها أنت وحدك لمن تشاء. الصق عدة أسماء مفصولة بسطر أو فاصلة أو مسافة (حروف إنجليزية صغيرة وأرقام و _ من 3 إلى 20).</p>' +
      '<label class="field"><span>الأسماء</span><textarea id="rs_n" rows="4" class="ltr" placeholder="electrician&#10;plumber&#10;carpenter"></textarea></label>' +
      '<label class="field"><span>ملاحظة (اختياري)</span><input id="rs_note" maxlength="120" placeholder="مثال: أسماء مهن"></label>' +
      '<button class="btn primary" id="rs_add" style="width:100%">حجز الأسماء</button></div>' +
      '<div class="toolbar"><input id="rs_q" type="search" placeholder="ابحث في الأسماء المحجوزة"></div><div id="rs_list" class="plist"></div>');
    on('rs_add', 'click', async function () {
      var n = document.getElementById('rs_n').value.trim(); if (!n) return toast('اكتب اسما واحدا على الأقل');
      try { var r = await db.adminReservedAdd(code, n, document.getElementById('rs_note').value.trim()); document.getElementById('rs_n').value = ''; toast('تم حجز ' + r.added + ' اسم' + (r.invalid ? ' (وتجاهلنا ' + r.invalid + ' غير صالح)' : '')); loadNames(); } catch (e) { fail(e); }
    });
    on('rs_q', 'input', function () { loadNames(); });
    document.getElementById('rs_list').addEventListener('click', onNameAct);
    loadNames();
  }
  var nmRows = [];
  async function loadNames() {
    var box = document.getElementById('rs_list'); if (!box) return;
    try { nmRows = await db.adminReservedList(code); } catch (e) { return fail(e); }
    var q = (document.getElementById('rs_q').value || '').trim().toLowerCase();
    var rows = nmRows.filter(function (r) { return !q || r.name.indexOf(q) >= 0 || (r.note || '').toLowerCase().indexOf(q) >= 0; });
    box.innerHTML = rows.length ? rows.map(function (r) {
      return '<div class="card prow"><div class="pr-main"><div class="pr-name ltr">@' + esc(r.name) + '</div><div class="pr-sub">' + (r.assigned_to ? 'ممنوح لـ ' + esc(r.assigned_name || '') : (r.note ? esc(r.note) : 'غير ممنوح')) + '</div></div>' +
        (r.assigned_to ? pill('ممنوح', 'ok') : pill('محجوز', 'warn')) +
        '<div class="btnrow"><button class="btn ghost" data-nm="give" data-n="' + esc(r.name) + '">منح</button><button class="btn danger" data-nm="del" data-n="' + esc(r.name) + '">فك الحجز</button></div></div>';
    }).join('') : '<div class="empty"><div class="big">🔒</div>لا توجد أسماء محجوزة</div>';
  }
  async function onNameAct(e) {
    var b = e.target.closest('[data-nm]'); if (!b) return;
    var n = b.getAttribute('data-n'), a = b.getAttribute('data-nm');
    try {
      if (a === 'del') { if (!confirm('فك حجز @' + n + '؟ سيستطيع أي مستخدم اختياره.')) return; await db.adminReservedRemove(code, n); toast('تم فك الحجز'); return loadNames(); }
      modal('<h3>منح @' + esc(n) + '</h3><p class="note">اكتب رقم هاتف الصنايعي (أو اسم مستخدمه الحالي) وسيتغير اسمه فورا إلى هذا الاسم.</p>' +
        '<label class="field"><span>رقم الهاتف أو اسم المستخدم</span><input id="gv_q" class="ltr" placeholder="9XXXXXXXX"></label><div id="gv_r" class="note"></div>' +
        '<div class="row2 mt"><button class="btn ghost" id="gv_x">إلغاء</button><button class="btn primary" id="gv_ok">منح</button></div>');
      on('gv_x', 'click', closeModal);
      on('gv_ok', 'click', async function () {
        var q = document.getElementById('gv_q').value.trim(); if (!q) return toast('اكتب رقم الهاتف');
        try {
          var rs = await db.adminProviders(code, { q: q, status: '', service: '', city: '', limit: 5, offset: 0 }), items = rs.items || [];
          if (items.length !== 1) return toast(items.length ? 'يوجد أكثر من نتيجة، اكتب الرقم كاملا' : 'لم نجد صنايعيا بهذه البيانات');
          if (!confirm('منح @' + n + ' إلى ' + items[0].name + '؟')) return;
          await db.adminReservedAssign(code, n, items[0].id); closeModal(); toast('تم المنح'); loadNames();
        } catch (x) { closeModal(); fail(x); }
      });
    } catch (x) { fail(x); }
  }
  var rvRows = {};
  async function loadReviews() {
    var box = document.getElementById('rvlist'); if (!box) return;
    var list;
    try { list = await db.adminReviews(code, rv.filter, rv.q); } catch (e) { return fail(e); }
    rvRows = {};
    box.innerHTML = list.length ? list.map(function (r) {
      rvRows[r.id] = r;
      var stars = r.stars ? '<span class="star">' + '★'.repeat(r.stars) + '<span style="color:#cbd5e1">' + '★'.repeat(5 - r.stars) + '</span></span>' : '<span class="muted">بلا نجوم</span>';
      return '<div class="card rvcard' + (r.hidden ? ' hid' : '') + '"><div class="rv-top"><b>' + esc(r.provider) + '</b>' + stars + (r.success ? pill('ناجحة') : pill('لم تنجح', 'bad')) + (r.hidden ? pill('مخفي', 'warn') : '') + '<span class="muted" style="margin-inline-start:auto">' + fmtDate(r.ts) + '</span></div>' +
        (r.comment ? '<p class="rv-c">' + esc(r.comment) + '</p>' : '<p class="muted">بلا تعليق</p>') + (r.hidden && r.reason ? '<p class="note">سبب الإخفاء: ' + esc(r.reason) + '</p>' : '') +
        '<div class="btnrow">' + (r.hidden ? '<button class="btn primary" data-rv="restore" data-id="' + r.id + '">إرجاع</button>' : '<button class="btn ghost" data-rv="hide" data-id="' + r.id + '">إخفاء</button>') + '<button class="btn danger" data-rv="del" data-id="' + r.id + '">حذف نهائي</button></div></div>';
    }).join('') : '<div class="empty"><div class="big">☆</div>لا توجد تقييمات</div>';
  }
  async function onReviewAct(e) {
    var b = e.target.closest('[data-rv]'); if (!b) return;
    var id = b.getAttribute('data-id'), a = b.getAttribute('data-rv');
    try {
      if (a === 'hide') { var why = prompt('سبب الإخفاء (للسجل فقط):', 'تقييم غير لائق'); if (why === null) return; await db.adminReviewHide(code, id, why.trim()); toast('تم الإخفاء'); }
      else if (a === 'restore') { await db.adminReviewRestore(code, id); toast('تم الإرجاع'); }
      else if (a === 'del') { if (!confirm('حذف هذا التقييم نهائيا؟ لا يمكن التراجع.')) return; await db.adminReviewDelete(code, id); toast('تم الحذف'); }
      loadReviews();
    } catch (x) { fail(x); }
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
      '<button class="btn primary" id="add">➕ إضافة صنايعي</button><button class="btn ghost" id="csv">⬇ CSV</button>' + (cn.badges ? '<button class="btn ghost" id="pbadges">🏅 شارات بانتظارك (' + cn.badges + ')</button>' : '') + '</div>' +
      '<div class="muted" id="pcount" style="margin-bottom:8px"></div><div id="plist" class="plist"></div><div class="center mt" id="more"></div>');
    var t;
    on('q', 'input', function () { var v = this.value; clearTimeout(t); t = setTimeout(function () { pf.q = v.trim(); pf.offset = 0; loadProviders(true); }, 350); });
    [['fs', 'status'], ['fv', 'service'], ['fc', 'city']].forEach(function (x) { on(x[0], 'change', function () { pf[x[1]] = this.value; pf.offset = 0; loadProviders(true); }); });
    on('add', 'click', function () { openProvForm(null); });
    on('csv', 'click', function () { exportCsv(pf); });
    on('pbadges', 'click', openPendingBadges);
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

  /* صف مضغوط: الاسم والحالة وسطر صغير؛ الضغط يفتح صفحة الصنايعي كاملة */
  function provCard(p) {
    var st = STATUS[p.status] || ['—', ''];
    var sub = [SQ.cityName(p.city_id) || p.city_id, 'كشف ' + Number(p.price || 0).toLocaleString('en'), (p.jobs || 0) + ' عمل مؤكد', p.rating != null ? '★ ' + p.rating : 'بلا تقييم', U.timeAgo(p.last_seen)].join(' · ');
    var q = p.status === 'pending' ? '<span class="prq"><button class="btn primary" data-act="approved" data-id="' + p.id + '">موافقة</button><button class="btn danger" data-act="rejected" data-id="' + p.id + '">رفض</button></span>' : '<span class="mng">إدارة</span>';
    return '<div class="prow" data-act="manage" data-id="' + p.id + '">' + U.avatar(p) + '<div class="pr-main"><div class="pr-name">' + esc(p.name) + ' ' + pill(st[0], st[1]) + (p.verified ? ' <span class="vtag">موثّق</span>' : '') + (p.ban_match && p.status !== 'banned' ? ' ' + pill('يتطابق مع محظور', 'bad') : '') + '</div><div class="pr-sub">' + esc(sub) + '</div></div>' + q + '</div>';
  }

  /* ---------- لوحة إدارة صنايعي واحد: الحالة، الشارة، التواصل، الحساب ---------- */
  function kvRow(k, v) { return '<div class="kv"><span class="muted">' + k + '</span><span>' + v + '</span></div>'; }
  function openManage(p) {
    mp = p.id; rows[p.id] = p;
    var st = STATUS[p.status] || ['—', ''];
    var wa = 'https://wa.me/' + SQ.util.digits(p.whatsapp || p.phone) + '?text=' + encodeURIComponent(waText(p));
    var statusBtns = [];
    if (p.status === 'approved') statusBtns.push('<button class="btn danger" data-ma="suspended">إيقاف مؤقت</button>');
    if (p.status === 'suspended' || p.status === 'rejected') statusBtns.push('<button class="btn primary" data-ma="approved">اعتماد</button>');
    if (p.status === 'pending') statusBtns.push('<button class="btn primary" data-ma="approved">موافقة</button><button class="btn danger" data-ma="rejected">رفض</button>');
    if (p.ban_match && p.status !== 'banned') statusBtns.push('<button class="btn ghost" data-ma="dismiss">تجاهل تطابق الحظر</button>');
    var data = '<div class="card"><div class="top2">' + U.avatar(p, 'big') + '<div class="pname">' + esc(p.name) + '<div style="margin-top:4px">' + pill(st[0], st[1]) + (p.verified ? ' <span class="vtag">موثّق</span>' : ' ' + pill('غير موثّق', 'warn')) + ' ' + pill('ملف ' + p.pct + '%', p.pct >= 70 ? '' : 'warn') + (p.ban_match && p.status !== 'banned' ? ' ' + pill('يتطابق مع محظور', 'bad') : '') + (!p.has_password ? ' ' + pill('بلا كلمة سر', 'warn') : '') + '</div></div></div>' +
      '<div class="kvs">' + kvRow('الهاتف', '<span class="ltr">' + esc(p.phone) + '</span>') + kvRow('واتساب', '<span class="ltr">' + esc(p.whatsapp || p.phone) + '</span>') + (p.email ? kvRow('البريد', '<span class="ltr">' + esc(p.email) + '</span>') : '') +
      kvRow('اسم المستخدم', '<span class="ltr">@' + esc(p.username || '') + '</span>') + kvRow('الخدمات', esc(U.svcNames(p.services))) + kvRow('المنطقة', esc((p.hood ? p.hood + '، ' : '') + (SQ.cityName(p.city_id) || p.city_id))) +
      kvRow('الخبرة', p.experience + ' سنة') + kvRow('العمر', p.age ? p.age + ' سنة' : '<span class="dangertxt">بلا تاريخ ميلاد</span>') + kvRow('سعر الكشف', Number(p.price).toLocaleString('en') + (p.price_max ? ' - ' + Number(p.price_max).toLocaleString('en') : '')) +
      kvRow('الأعمال المؤكدة', (p.jobs || 0)) + kvRow('الطلبات', p.requests_week + ' هذا الأسبوع / ' + p.requests_total + ' الكل') + kvRow('التقييم', (p.rating != null ? '★ ' + p.rating + ' (' + p.rating_n + ')' : 'بلا تقييم') + ' · ناجحة ' + p.ok + ' · فاشلة ' + p.fail) +
      kvRow('رقم الطلب', '<b class="ltr">' + refOf(p) + '</b>') + kvRow('التسجيل', fmtDate(p.created)) + kvRow('آخر ظهور', U.timeAgo(p.last_seen)) + '</div>' +
      (p.bio ? '<p class="note">' + esc(p.bio) + '</p>' : '') + (p.admin_note ? '<p class="note">ملاحظة: ' + esc(p.admin_note) + '</p>' : '') + (p.verified && p.verify_doc ? '<p class="note">التحقق: ' + esc(p.verify_doc) + '</p>' : '') + '</div>';
    shell('<div class="mhead"><button class="btn ghost" id="mp_back">‹ الصنايعية</button><b>إدارة الصنايعي</b></div>' + data +
      '<div class="mgrp"><b>الحالة</b>' + (statusBtns.length ? '<div class="btnrow">' + statusBtns.join('') + '</div>' : '<p class="note">لا إجراءات متاحة لهذه الحالة. استخدم «الحظر» أدناه عند الحاجة.</p>') + '</div>' +
      '<div class="mgrp"><b>الشارة</b><div id="mg_badge" class="muted">جارٍ التحميل…</div></div>' +
      '<div class="mgrp"><b>التواصل</b><div class="btnrow"><button class="btn primary" data-ma="msg">رسالة خاصة</button><a class="btn wa" href="' + wa + '" target="_blank" rel="noopener">واتساب</a><a class="btn ghost" href="tel:' + esc(p.phone) + '">اتصال</a></div></div>' +
      '<div class="mgrp"><b>الحساب</b><div class="btnrow"><button class="btn ghost" data-ma="edit">تعديل البيانات</button><button class="btn ghost" data-ma="verify">' + (p.verified ? 'إلغاء التوثيق' : 'توثيق') + '</button><button class="btn ghost" data-ma="uname">اسم المستخدم</button><button class="btn ghost" data-ma="pw">كلمة السر</button></div></div>' +
      '<div class="mgrp" style="border-color:#f3c0c0"><b style="color:#b42318">منطقة الخطر</b><div class="btnrow">' + (p.status !== 'banned' ? '<button class="btn danger" data-ma="banned">حظر</button>' : '<button class="btn primary" data-ma="unban">رفع الحظر</button>') + '<button class="btn danger" data-ma="del">حذف نهائي</button></div></div>');
    on('mp_back', 'click', function () { mp = null; viewProviders(); });
    document.querySelector('main.main').onclick = function (e) {
      var b = e.target.closest('[data-ma]'); if (!b) return;
      provAction(b.getAttribute('data-ma'), p, { disabled: false });
    };
    window.scrollTo(0, 0);
    loadManageBadge(p);
  }
  async function loadManageBadge(p) {
    var box = document.getElementById('mg_badge'); if (!box) return;
    var r = null;
    try { var rows = await db.adminBadges(code, 'all', p.phone); r = (rows || []).filter(function (x) { return x.id === p.id; })[0] || null; } catch (e) {}
    box = document.getElementById('mg_badge'); if (!box) return;
    if (!r) { box.textContent = 'تعذر تحميل بيانات الشارة'; return; }
    box.className = '';
    box.innerHTML = '<p class="note">الحالية: <b>' + TIER_NAMES[r.tier || ''] + '</b> · أعمال مؤكدة ' + r.jobs + ' · اكتمال الملف ' + r.pct + '% · الرمادية: ' + GRAY[r.gray_status] + (r.manual ? ' · منح يدوي: ' + TIER_NAMES[r.manual] + (r.reason ? ' (' + esc(r.reason) + ')' : '') : '') + '</p>' +
      (r.gray_status === 'pending' ? '<div class="btnrow"><button class="btn primary" data-bg="ok">✔ اعتماد الرمادية</button><button class="btn danger" data-bg="no">✖ رفض</button></div>' : '') +
      '<div class="row2"><label class="field"><span>منح شارة</span><select id="mg_t">' + ['gray', 'green', 'blue', 'gold'].map(function (k) { return '<option value="' + k + '">' + TIER_NAMES[k] + '</option>'; }).join('') + '</select></label><label class="field"><span>السبب (يصل للصنايعي)</span><input id="mg_r" maxlength="200" placeholder="مثال: أبلغ عن خطأ"></label></div>' +
      '<div class="btnrow"><button class="btn primary" data-bg="grant">🏅 منح</button>' + (r.manual ? '<button class="btn ghost" data-bg="revoke">إزالة المنح اليدوي</button>' : '') + '</div>';
    box.onclick = async function (e) {
      var b = e.target.closest('[data-bg]'); if (!b) return; var act = b.getAttribute('data-bg');
      try {
        if (act === 'ok') { b.disabled = true; await db.adminBadgeDecide(code, p.id, true, ''); toast('تم الاعتماد وأُرسلت تهنئة'); }
        else if (act === 'no') { var note = prompt('سبب الرفض (يصل للصنايعي):', ''); if (note === null) return; b.disabled = true; await db.adminBadgeDecide(code, p.id, false, note); toast('تم الرفض'); }
        else if (act === 'grant') { var t = document.getElementById('mg_t').value; if (!confirm('منح الشارة ' + TIER_NAMES[t] + ' لـ ' + p.name + '؟')) return; b.disabled = true; await db.adminSetBadge(code, p.id, t, document.getElementById('mg_r').value.trim()); toast('تم المنح وأُرسل إشعار'); }
        else if (act === 'revoke') { if (!confirm('إزالة الشارة الممنوحة يدويًا؟')) return; b.disabled = true; await db.adminSetBadge(code, p.id, '', ''); toast('تمت الإزالة'); }
        loadManageBadge(p);
        try { ov = await db.adminOverview(code); cn = await db.adminCounts(code); } catch (x) {}
      } catch (x) { b.disabled = false; fail(x); }
    };
  }

  async function provAction(a, p, btn) {
    if (!p) return;
    if (a === 'manage') return openManage(p);
    if (a === 'edit') return openProvForm(p);
    if (a === 'msg') return msgModal({ id: p.id, name: p.name, phone: p.whatsapp || p.phone, jobs: p.jobs || 0, verified: p.verified, username: p.username, email: p.email || '' });
    if (a === 'uname') {
      modal('<h3>اسم المستخدم لـ ' + esc(p.name) + '</h3><p class="note">للتعديل بعد تواصل الصنايعي مع الدعم. لا يستهلك مرته الواحدة. رابطه: <span class="ltr">' + esc(appUrl()) + esc(p.username || '') + '</span></p>' +
        '<label class="field"><span>الاسم (حروف إنجليزية صغيرة وأرقام و _)</span><input id="un_v" class="ltr" maxlength="20" autocapitalize="none" value="' + esc(p.username || '') + '"></label>' +
        '<div class="row2 mt"><button class="btn ghost" id="un_x">إلغاء</button><button class="btn primary" id="un_ok">حفظ</button></div>');
      on('un_x', 'click', closeModal);
      on('un_ok', 'click', async function () {
        var v = document.getElementById('un_v').value.trim().toLowerCase();
        if (!/^[a-z][a-z0-9_]{2,19}$/.test(v)) return toast(U.errMsg(new Error('invalid_username')));
        try { await db.adminSetUsername(code, p.id, v); closeModal(); toast('تم تعديل اسم المستخدم'); refreshAll(); } catch (e) { closeModal(); fail(e); }
      });
      return;
    }
    if (a === 'pw') return openResetPw(p);
    if (a === 'verify') {
      if (p.verified) { try { await db.adminSetVerified(code, p.id, false); toast('أُلغي التوثيق'); refreshAll(); } catch (e) { fail(e); } return; }
      modal('<h3>توثيق ' + esc(p.name) + '</h3><p class="note">سجّل ما تحققت منه فقط. لا تحفظ صور الهوية، واحذفها من واتساب بعد التحقق.</p>' +
        '<label class="field"><span>نوع الوثيقة التي رأيتها</span><select id="vd"><option>بطاقة قومية</option><option>رخصة قيادة</option><option>جواز سفر</option><option>شهادة مهنية</option><option>تزكية من صنايعي موثّق</option><option>معرفة شخصية</option></select></label>' +
        '<label class="field"><span>ملاحظة (اختياري)</span><input id="vn" maxlength="120" placeholder="مثال: صورة مع الهوية تطابقت"></label>' +
        '<div class="row2 mt"><button class="btn ghost" id="vx">إلغاء</button><button class="btn primary" id="vk">توثيق</button></div>');
      on('vx', 'click', closeModal);
      on('vk', 'click', async function () {
        var doc = document.getElementById('vd').value + ' · ' + new Date().toISOString().slice(0, 10) + (document.getElementById('vn').value.trim() ? ' · ' + document.getElementById('vn').value.trim() : '');
        try { await db.adminSetVerified(code, p.id, true, doc); closeModal(); toast('تم توثيق الصنايعي ✔'); refreshAll(); } catch (e) { closeModal(); fail(e); }
      });
      return;
    }
    if (a === 'del') {
      modal('<h3>حذف الصنايعي</h3><p>سيُحذف <b>' + esc(p.name) + '</b> وكل طلباته وتقييماته نهائيا. هذا لا يمكن التراجع عنه. يمكنك بدل ذلك <b>إيقافه</b>.</p><div class="row2 mt"><button class="btn ghost" id="dn">إلغاء</button><button class="btn danger" id="dy">نعم، احذف</button></div>');
      on('dn', 'click', closeModal);
      on('dy', 'click', async function () { try { await db.adminDeleteProvider(code, p.id); closeModal(); toast('تم الحذف'); refreshAll(); } catch (e) { fail(e); } });
      return;
    }
    if (a === 'banned') {
      var why = prompt('سبب الحظر (يظهر للصنايعي في صفحة الحظر):', 'مخالفة قوانين التطبيق'); if (why === null) return;
      btn.disabled = true;
      try { await db.adminBan(code, p.id, why.trim()); toast('تم الحظر'); refreshAll(); } catch (e) { btn.disabled = false; fail(e); }
      return;
    }
    if (a === 'unban') {
      var nt = prompt('رسالة تصل للصنايعي عند رفع الحظر (اختياري):', ''); if (nt === null) return;
      btn.disabled = true;
      try { await db.adminUnban(code, p.id, nt.trim()); toast('تم رفع الحظر'); refreshAll(); } catch (e) { btn.disabled = false; fail(e); }
      return;
    }
    if (a === 'dismiss') {
      btn.disabled = true;
      try { await db.adminDismissMatch(code, p.id); toast('تم التجاهل'); refreshAll(); } catch (e) { btn.disabled = false; fail(e); }
      return;
    }
    var names = { approved: 'اعتماد', rejected: 'رفض', suspended: 'إيقاف' };
    if ((a === 'rejected' || a === 'suspended') && !confirm(names[a] + ' ' + p.name + '؟')) return;
    btn.disabled = true;
    try { await db.adminSetStatus(code, p.id, a); toast('تم'); refreshAll(); } catch (e) { btn.disabled = false; fail(e); }
  }
  async function refreshAll() {
    try { ov = await db.adminOverview(code); } catch (e) {}
    if (mp && tab === 'providers') {
      var cur = rows[mp], np = null;
      try { var rs = await db.adminProviders(code, { q: cur ? cur.phone : '', status: '', service: '', city: '', limit: 10, offset: 0 }); np = (rs.items || []).filter(function (x) { return x.id === mp; })[0] || null; } catch (e) {}
      if (np) return openManage(np);
      mp = null; return viewProviders();
    }
    if (tab === 'providers') { shellKeep(); loadProviders(true); } else render(); }
  function shellKeep() { /* تحديث عدّاد الشريط فقط */
    var b = document.querySelector('.anav button[data-tab="providers"]'); if (!b || !ov) return;
    b.innerHTML = 'الصنايعية' + (ov.pending ? '<span class="cnt">' + ov.pending + '</span>' : '');
  }

  /* نموذج إضافة/تعديل صنايعي */
  function openProvForm(p) {
    var isNew = !p, d = p || { services: [], radius: '10', from: '08:00', to: '20:00', state_id: '', city_id: '' }, services = (d.services || []).slice();
    modal('<h3>' + (isNew ? 'إضافة صنايعي' : 'تعديل ' + esc(p.name)) + '</h3>' +
      '<label class="field"><span>الاسم الكامل</span><input id="f_nm" value="' + esc(d.name || '') + '"></label>' +
      U.photoHtml('f_ph_') + U.birthHtml('f_bd', d.birth_date, 'اختياري هنا. اكتب التاريخ الحقيقي كما في الوثيقة.') +
      '<label class="field"><span>رقم الهاتف</span><div class="phone-wrap"><b>' + SQ.COUNTRY.dial + '</b><input id="f_ph" class="ltr" inputmode="tel" value="' + esc(localPhone(d.phone)) + '" placeholder="' + SQ.COUNTRY.phoneHint + '"></div></label>' +
      '<label class="field"><span>البريد الإلكتروني (اختياري)</span><input id="f_em" class="ltr" type="email" value="' + esc(d.email || '') + '"></label>' +
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
      var be = U.birthErr(U.birthVal('f_bd'), false); if (be) return toast(be);
      if (!ph) return toast('رقم الهاتف غير صحيح');
      if (!wa) return toast('رقم الواتساب غير صحيح');
      if (!services.length) return toast('اختر خدمة واحدة على الأقل');
      if (!st || !ct) return toast('اختر الولاية والمدينة');
      if (g('f_ex') === '' || g('f_pr') === '') return toast('اكتب الخبرة وسعر الكشف');
      var o = { email: g('f_em').trim(), name: nm, birth_date: U.birthVal('f_bd'), phone: ph, whatsapp: wa, services: services, state_id: st, city_id: ct, hood: g('f_hd').trim(), radius: g('f_rd'), experience: +g('f_ex'), price: +g('f_pr'),
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
      return '<div class="card"><div class="pname">' + esc(r.provider_name) + '</div><div class="psvc">' + esc(U.svc(r.service).icon + ' ' + U.svc(r.service).name) + ' · ' + esc(SQ.cityName(r.city_id) || '') + '</div><div class="meta"><span>' + ({ pending: '⏳ بانتظار الرد', accepted: '✅ قُبل', declined: '✋ اعتذر', expired: '⌛ انتهت المهلة', taken: '🔁 أُخذ', cancelled: '🚫 ألغاه الزبون' }[r.accept] || (r.channel === 'call' ? '📞 اتصال' : '💬 واتساب')) + (r.reply_secs != null ? ' · ردّ خلال ' + (r.reply_secs < 60 ? r.reply_secs + ' ث' : Math.round(r.reply_secs / 60) + ' د') : '') + '</span><span>' + pill(REQ[r.status] || r.status, r.status === 'done' ? '' : r.status === 'failed' ? 'bad' : 'warn') + '</span>' + (r.confirm === 'done' ? '<span>' + pill('الصنايعي: نفّذ' + (r.amount ? ' · ' + Number(r.amount).toLocaleString('en') : ''), '') + '</span>' : r.confirm === 'not_done' ? '<span>' + pill('الصنايعي: لم تتم', 'warn') + '</span>' : '') + '<span class="muted">' + U.timeAgo(r.ts) + '</span></div></div>';
    }).join('') : '<div class="empty"><div class="big">📋</div>لا توجد طلبات</div>';
  }

  /* ---------- دفعيات العمولة ---------- */
  async function viewPayments() {
    shell('<div id="paybox"><div class="spin">جاري التحميل...</div></div>');
    var list, cfg = {};
    var dueList = [];
    try { list = await db.adminCommissionLedger(code); cfg = await db.adminGetSettings(code); dueList = await db.adminCommissions(code, 'due'); } catch (e) { return fail(e); }
    var fx = +cfg.commission_fixed || 0, box = document.getElementById('paybox'); if (!box) return;
    var dueBy = {}; dueList.forEach(function (c) { var g = dueBy[c.provider_id] || (dueBy[c.provider_id] = { pid: c.provider_id, id: c.id, name: c.provider_name, phone: c.phone, n: 0, total: 0, svc: [] }); g.n++; g.total += +c.amount; g.svc.push(c.service); });
    var dueRows = Object.keys(dueBy).map(function (k) { return dueBy[k]; });
    var dueHtml = '<div class="card"><b>عمولات مستحقة بانتظار الاستلام</b><p class="note">تظهر للصنايعي كرسالة منك حتى تضغط «تم استلام المبلغ» بعد وصول التحويل.</p>' +
      (dueRows.length ? dueRows.map(function (g) { return '<div class="kv"><span><b>' + esc(g.name) + '</b> <small class="ltr muted">' + esc(g.phone) + '</small><br><small class="muted">' + g.n + ' خدمة · ' + esc(g.svc.slice(0, 3).join('، ')) + '</small></span><span><b>' + g.total.toLocaleString('en') + '</b> جنيه <button class="btn primary" style="padding:6px 10px" data-cp="' + g.id + '">✔ تم الاستلام</button> <button class="btn ghost" style="padding:6px 10px" data-rm="' + g.pid + '" title="يصل للصنايعي إشعار ورسالة تذكير">🔔 تذكير</button></span></div>'; }).join('') : '<p class="note">لا توجد عمولات مستحقة الآن ✓</p>') + '</div>';
    function due(x) { return x.jobs * fx; }
    var T = list.reduce(function (a, x) { a.d += due(x); a.p += x.paid; a.n += x.pay_count; return a; }, { d: 0, p: 0, n: 0 });
    box.innerHTML = dueHtml + '<div class="stats"><div class="stat"><b>' + T.d.toLocaleString('en') + '</b><small>المستحق</small></div><div class="stat"><b>' + T.p.toLocaleString('en') + '</b><small>المحصّل (' + T.n + ' دفعة)</small></div><div class="stat"><b>' + (T.d - T.p).toLocaleString('en') + '</b><small>المتبقي</small></div></div>' +
      '<p class="note">العمولة الحالية ' + fx.toLocaleString('en') + ' جنيه لكل خدمة مؤكدة من الطرفين، وتُطبّق على كل الأعمال السابقة. غيّرها من الإعدادات.</p>' +
      (list.length ? '<div class="tbl-wrap"><table class="tbl"><thead><tr><th>الصنايعي</th><th>أعمال مؤكدة</th><th>المستحق</th><th>المدفوع</th><th>المتبقي</th><th>عدد الدفعات</th><th>آخر دفعة</th><th></th></tr></thead><tbody>' +
        list.map(function (x, i) {
          var rest = due(x) - x.paid;
          return '<tr><td><b>' + esc(x.name) + '</b><br><small class="ltr muted">' + esc(x.phone) + '</small></td><td>' + x.jobs + '</td><td>' + due(x).toLocaleString('en') + '</td><td>' + x.paid.toLocaleString('en') + '</td><td>' + (rest > 0 ? '<span class="dangertxt">' + rest.toLocaleString('en') + '</span>' : rest < 0 ? '<span class="muted">+' + (-rest).toLocaleString('en') + ' مقدم</span>' : '<span class="okc">مسدد</span>') + '</td><td>' + x.pay_count + '</td><td>' + (x.last_paid ? fmtDate(x.last_paid) : '—') + '</td><td class="nw">' + (x.pay_count > 0 ? '<button class="mini" data-pi="' + i + '" data-pa="log">✏ تعديل</button>' : '<button class="mini" data-pi="' + i + '" data-pa="add">+ دفعة</button>') + '</td></tr>';
        }).join('') + '</tbody></table></div>' : '<div class="empty"><div class="big">💰</div>لا توجد أعمال مؤكدة ولا دفعيات بعد</div>');
    box.onclick = async function (e) {
      var rm = e.target.closest('[data-rm]');
      if (rm) { if (!confirm('إرسال تذكير بالعمولة المستحقة لهذا الصنايعي؟')) return; try { await db.adminRemindCommission(code, rm.getAttribute('data-rm')); toast('تم إرسال التذكير'); } catch (err) { toast(/remind_cooldown/.test(String(err && err.message || err)) ? 'أُرسل تذكير قبل أقل من 6 ساعات' : /nothing_due/.test(String(err && err.message || err)) ? 'لا توجد عمولة مستحقة' : U.errMsg(err)); } return; }
      var cp = e.target.closest('[data-cp]');
      if (cp) { if (!confirm('تأكيد استلام العمولة؟ ستختفي رسالة العمولة من لدى الصنايعي.')) return; try { await db.adminCommissionPaid(code, cp.getAttribute('data-cp'), true); toast('تم تأكيد الاستلام'); viewPayments(); } catch (err) { fail(err); } return; }
      var b = e.target.closest('[data-pa]'); if (!b) return; var x = list[+b.getAttribute('data-pi')];
      if (b.getAttribute('data-pa') === 'add') {
        modal('<h3>تسجيل دفعة من ' + esc(x.name) + '</h3><label class="field"><span>المبلغ (جنيه)</span><input id="pm_a" class="ltr" inputmode="numeric" value="' + (fx || '') + '"></label><label class="field"><span>ملاحظة (اختياري: بنكك، كاش، رقم العملية)</span><input id="pm_n" maxlength="100"></label><div class="row2 mt"><button class="btn ghost" id="pm_x">إلغاء</button><button class="btn primary" id="pm_ok">تسجيل</button></div>');
        on('pm_x', 'click', closeModal);
        on('pm_ok', 'click', async function () {
          var v = String(document.getElementById('pm_a').value).replace(/[٠-٩]/g, function (c) { return '٠١٢٣٤٥٦٧٨٩'.indexOf(c); }).replace(/\D/g, '');
          if (!v || +v <= 0) return toast('اكتب المبلغ');
          try { await db.adminAddPayment(code, x.provider_id, +v, document.getElementById('pm_n').value.trim()); closeModal(); toast('تم تسجيل الدفعة'); viewPayments(); } catch (err) { closeModal(); fail(err); }
        });
      } else {
        modal('<h3>دفعات ' + esc(x.name) + '</h3><p class="note">عدّل المبلغ أو الملاحظة، أو احذف الدفعة المسجّلة بالخطأ، حتى تبقى الأرقام والإحصائيات دقيقة.</p>' + (x.payments.length ? '<div class="tbl-wrap"><table class="tbl"><thead><tr><th>التاريخ</th><th>المبلغ</th><th>ملاحظة</th><th></th></tr></thead><tbody>' + x.payments.map(function (p, k) { return '<tr><td>' + fmtDate(p.ts) + '</td><td>' + Number(p.amount).toLocaleString('en') + '</td><td>' + esc(p.note || '') + '</td><td class="nw"><button class="mini" data-ed="' + k + '" title="تعديل">✏</button> <button class="mini" data-del="' + p.id + '" title="حذف">🗑</button></td></tr>'; }).join('') + '</tbody></table></div>' : '<p class="note">لا توجد دفعات.</p>') + '<button class="btn ghost mt" id="pl_x" style="width:100%">إغلاق</button>');
        on('pl_x', 'click', closeModal);
        var mb = document.getElementById('modal'); mb.onclick = async function (ev) {
          var ed = ev.target.closest('[data-ed]');
          if (ed) {
            var pp = x.payments[+ed.getAttribute('data-ed')];
            modal('<h3>تعديل دفعة</h3><label class="field"><span>المبلغ (جنيه)</span><input id="pe_a" class="ltr" inputmode="numeric" value="' + Number(pp.amount) + '"></label><label class="field"><span>ملاحظة</span><input id="pe_n" maxlength="100" value="' + esc(pp.note || '') + '"></label><div class="row2 mt"><button class="btn ghost" id="pe_x">إلغاء</button><button class="btn primary" id="pe_ok">حفظ التعديل</button></div>');
            on('pe_x', 'click', closeModal);
            on('pe_ok', 'click', async function () {
              var v2 = String(document.getElementById('pe_a').value).replace(/[٠-٩]/g, function (c) { return '٠١٢٣٤٥٦٧٨٩'.indexOf(c); }).replace(/\D/g, '');
              if (!v2 || +v2 <= 0) return toast('اكتب المبلغ');
              try { await db.adminUpdatePayment(code, pp.id, +v2, document.getElementById('pe_n').value.trim()); closeModal(); toast('تم تعديل الدفعة'); viewPayments(); } catch (err) { closeModal(); fail(err); }
            });
            return;
          }
          var dl = ev.target.closest('[data-del]'); if (!dl) return;
          if (!confirm('حذف هذه الدفعة نهائيًا؟')) return;
          try { await db.adminDeletePayment(code, dl.getAttribute('data-del')); closeModal(); toast('تم حذف الدفعة'); viewPayments(); } catch (err) { closeModal(); fail(err); }
        };
      }
    };
  }

  /* ---------- الطلبات المؤكدة من الطرفين ---------- */
  var cdays = 30;
  async function viewConfirmed() {
    shell('<div class="toolbar"><select id="cd">' + [7, 30, 90, 365].map(function (n) { return '<option value="' + n + '"' + (cdays === n ? ' selected' : '') + '>آخر ' + n + ' يوم</option>'; }).join('') + '</select></div><div id="clist"><div class="spin">جاري التحميل...</div></div>');
    on('cd', 'change', function () { cdays = +this.value; viewConfirmed(); });
    var list;
    try { list = await db.adminConfirmReport(code, cdays); } catch (e) { return fail(e); }
    var el = document.getElementById('clist'); if (!el) return;
    var cfg2 = {}; try { cfg2 = await db.adminGetSettings(code); } catch (e) {}
    function due(x) { return Math.round(x.both * (+cfg2.commission_fixed || 0) + x.amount * (+cfg2.commission_pct || 0) / 100); }
    var tot = list.reduce(function (a, x) { a.t += x.total; a.b += x.both; a.m += x.mismatch; a.s += x.amount; a.d += due(x); return a; }, { t: 0, b: 0, m: 0, s: 0, d: 0 });
    el.onclick = function (e) { var b = e.target.closest('[data-msg]'); if (!b) return; var x = list.filter(function (y) { return y.provider_id === b.getAttribute('data-msg'); })[0]; if (x) msgModal({ id: x.provider_id, name: x.name, phone: x.phone, jobs: x.both, verified: x.verified }); };
    el.innerHTML = '<div class="stats"><div class="stat"><b>' + tot.t + '</b><small>كل الطلبات</small></div><div class="stat"><b>' + tot.b + '</b><small>مؤكدة من الطرفين</small></div><div class="stat"><b>' + tot.m + '</b><small>غير متطابقة</small></div></div>' + ((+cfg2.commission_fixed > 0 || +cfg2.commission_pct > 0) ? '<div class="card"><div class="kv"><span>العمولة المستحقة (تقديرية)</span><b>' + tot.d.toLocaleString('en') + ' جنيه</b></div></div>' : '') +
      '<p class="note">المؤكد من الطرفين = قال الزبون "تمت الخدمة" وأكد الصنايعي التنفيذ. المبلغ يصرّح به الصنايعي، فاعتبره تقديريا. "غير متطابق" يحتاج مراجعتك.</p>' +
      '<div class="agrid">' + (list.length ? list.map(function (x) {
        return '<div class="card"><div class="pname">' + esc(x.name) + (x.verified ? ' ✓' : '') + '</div><div class="meta"><span>طلبات: ' + x.total + '</span><span>الزبائن: ' + x.client_done + '</span><span>الصنايعي: ' + x.provider_done + '</span></div>' +
          '<div class="meta"><span>' + pill('مؤكدة: ' + x.both, x.both ? '' : 'warn') + '</span>' + (x.mismatch ? '<span>' + pill('غير متطابقة: ' + x.mismatch, 'bad') + '</span>' : '') + '<span class="muted">' + Number(x.amount).toLocaleString('en') + ' جنيه</span><button class="mini" data-msg="' + esc(x.provider_id) + '">✉️ رسالة</button>' + (due(x) ? '<span>' + pill('عمولة: ' + due(x).toLocaleString('en'), 'warn') + '</span>' : '') + '</div></div>';
      }).join('') : '<div class="empty"><div class="big">🤝</div>لا توجد بيانات في هذه الفترة</div>') + '</div>';
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


  async function openPendingBadges() {
    var rows;
    try { rows = await db.adminBadges(code, 'pending', ''); } catch (e) { return fail(e); }
    modal('<h3>شارات رمادية بانتظار موافقتك</h3>' + (rows.length ? rows.map(function (r) {
      return '<div class="kv"><span><b>' + esc(r.name) + '</b><br><small class="muted">' + esc(r.phone) + ' · اكتمال الملف ' + r.pct + '%</small></span><span><button class="btn primary" style="padding:6px 10px" data-bok="' + r.id + '">✔</button> <button class="btn danger" style="padding:6px 10px" data-bno="' + r.id + '">✖</button></span></div>';
    }).join('') : '<p class="note">لا توجد طلبات الآن ✓</p>') + '<button class="btn ghost mt" id="pb_x" style="width:100%">إغلاق</button>');
    on('pb_x', 'click', closeModal);
    document.getElementById('modal').onclick = async function (e) {
      var ok = e.target.closest('[data-bok]'), no = e.target.closest('[data-bno]');
      try {
        if (ok) await db.adminBadgeDecide(code, ok.getAttribute('data-bok'), true, '');
        else if (no) { var note = prompt('سبب الرفض (يصل للصنايعي):', ''); if (note === null) return; await db.adminBadgeDecide(code, no.getAttribute('data-bno'), false, note); }
        else return;
        closeModal(); toast('تم'); render();
      } catch (x) { fail(x); }
    };
  }

  /* ---------- الشارات ---------- */
  var TIER_NAMES = { '': 'بدون', gray: 'رمادية', green: 'خضراء', blue: 'زرقاء', gold: 'ذهبية' };
  var GRAY = { none: 'لم يكتمل الملف', pending: 'بانتظار الموافقة', approved: 'معتمدة', rejected: 'مرفوضة' };
  async function viewBadges() {
    shell('<div class="card"><b>الشارات</b><p class="note">الرمادية: ملف مكتمل 100% وتحتاج موافقتك. الخضراء 5 معاملات ناجحة، الزرقاء 25، الذهبية 100 (تلقائية). ويمكنك منح أي شارة يدويًا، مثلًا مكافأة لمن أبلغ عن خطأ أو اقترح ميزة.</p>' +
      '<div class="btnrow"><button class="btn ' + (bf.filter === 'pending' ? 'primary' : 'ghost') + '" data-f="pending">بانتظار الموافقة' + (cn.badges ? ' (' + cn.badges + ')' : '') + '</button><button class="btn ' + (bf.filter === 'manual' ? 'primary' : 'ghost') + '" data-f="manual">الممنوحة يدويًا</button></div>' +
      '<div class="row2" style="margin-top:8px"><label class="field"><span>بحث بالاسم أو الهاتف</span><input id="bq" value="' + esc(bf.q) + '"></label><button class="btn ghost" id="bqgo" style="align-self:end">بحث</button></div></div>' +
      '<div id="bl" class="agrid"><div class="spin">جاري التحميل...</div></div>');
    U.each('[data-f]', function (b) { b.addEventListener('click', function () { bf.filter = b.getAttribute('data-f'); bf.q = ''; viewBadges(); }); });
    on('bqgo', 'click', function () { bf.q = document.getElementById('bq').value.trim(); bf.filter = bf.q ? 'all' : bf.filter; viewBadges(); });
    var rows;
    try { rows = await db.adminBadges(code, bf.filter, bf.q); } catch (e) { return fail(e); }
    var el = document.getElementById('bl'); if (!el) return;
    el.innerHTML = rows.length ? rows.map(function (r) {
      return '<div class="card"><div class="pname">' + esc(r.name) + ' ' + pill('الشارة: ' + TIER_NAMES[r.tier || ''], r.tier ? '' : 'bad') + ' ' + (r.gray_status === 'pending' ? pill('الرمادية بانتظارك', 'warn') : '') + '</div>' +
        '<div class="psvc">' + esc(r.phone) + ' · ' + esc(SQ.cityName(r.city_id) || r.city_id || '') + ' · أعمال مؤكدة: ' + r.jobs + ' · اكتمال الملف ' + r.pct + '% · الرمادية: ' + GRAY[r.gray_status] + (r.manual ? ' · منح يدوي: ' + TIER_NAMES[r.manual] + (r.reason ? ' (' + esc(r.reason) + ')' : '') : '') + '</div>' +
        (r.gray_status === 'pending' ? '<div class="btnrow"><button class="btn primary" data-act="ok" data-id="' + r.id + '">✔ اعتماد الشارة الرمادية</button><button class="btn danger" data-act="no" data-id="' + r.id + '">✖ رفض</button></div>' : '') +
        '<div class="row2" style="margin-top:8px"><label class="field"><span>منح يدوي</span><select data-t="' + r.id + '">' + ['gray', 'green', 'blue', 'gold'].map(function (k) { return '<option value="' + k + '">' + TIER_NAMES[k] + '</option>'; }).join('') + '</select></label><label class="field"><span>السبب (يصل للصنايعي)</span><input data-r="' + r.id + '" maxlength="200" placeholder="مثال: أبلغ عن خطأ في التطبيق"></label></div>' +
        '<div class="btnrow"><button class="btn primary" data-act="grant" data-id="' + r.id + '">🏅 منح</button>' + (r.manual ? '<button class="btn ghost" data-act="revoke" data-id="' + r.id + '">إزالة المنح اليدوي</button>' : '') + '</div></div>';
    }).join('') : '<div class="empty"><div class="big">🏅</div>لا توجد نتائج</div>';
    el.onclick = async function (e) {
      var b = e.target.closest('[data-act]'); if (!b) return; var act = b.getAttribute('data-act'), id = b.getAttribute('data-id');
      try {
        if (act === 'ok') { b.disabled = true; await db.adminBadgeDecide(code, id, true, ''); toast('تم الاعتماد وأُرسل إشعار تهنئة'); }
        else if (act === 'no') { var note = prompt('سبب الرفض (يصل للصنايعي):', ''); if (note === null) return; b.disabled = true; await db.adminBadgeDecide(code, id, false, note); toast('تم الرفض'); }
        else if (act === 'grant') {
          var t = document.querySelector('[data-t="' + id + '"]').value, why = document.querySelector('[data-r="' + id + '"]').value.trim();
          if (!confirm('منح الشارة ' + TIER_NAMES[t] + ' لهذا الصنايعي؟')) return; b.disabled = true; await db.adminSetBadge(code, id, t, why); toast('تم المنح وأُرسل إشعار');
        } else if (act === 'revoke') { if (!confirm('إزالة الشارة الممنوحة يدويًا؟')) return; b.disabled = true; await db.adminSetBadge(code, id, '', ''); toast('تمت الإزالة'); }
        render();
      } catch (x) { b.disabled = false; fail(x); }
    };
  }

  /* ---------- الخدمات المقترحة من الصنايعية ---------- */
  var cf = { status: 'pending' };
  async function viewCustom() {
    shell('<div class="card"><b>خدمات يقترحها الصنايعية</b><p class="note">وافق لتصبح خدمة دائمة تظهر للجميع (يمكنك تعديل الاسم والأيقونة)، أو اربطها بخدمة موجودة، أو ارفض مع اقتراح بديل يصل للصنايعي.</p><div class="btnrow"><button class="btn ' + (cf.status === 'pending' ? 'primary' : 'ghost') + '" data-s="pending">بانتظار القرار' + (cn.custom ? ' (' + cn.custom + ')' : '') + '</button><button class="btn ' + (cf.status === 'all' ? 'primary' : 'ghost') + '" data-s="all">الكل</button></div></div><div id="cl" class="agrid"><div class="spin">جاري التحميل...</div></div>');
    U.each('[data-s]', function (b) { b.addEventListener('click', function () { cf.status = b.getAttribute('data-s'); viewCustom(); }); });
    var rows, svcs = [];
    try { rows = await db.adminCustomServices(code, cf.status); svcs = (await db.adminServices(code)) || []; } catch (e) { return fail(e); }
    var el = document.getElementById('cl'); if (!el) return;
    var opts = '<option value="">— خدمة جديدة —</option>' + svcs.map(function (s) { return '<option value="' + esc(s.id) + '">' + esc((s.icon || '') + ' ' + s.name) + '</option>'; }).join('');
    var ST = { pending: ['بانتظار القرار', 'warn'], approved: ['تمت الموافقة', ''], rejected: ['مرفوضة', 'bad'] };
    el.innerHTML = rows.length ? rows.map(function (r) {
      var st = ST[r.status] || ['', ''];
      return '<div class="card"><div class="pname">' + esc(r.name) + ' ' + pill(st[0], st[1]) + '</div><div class="psvc">من: ' + esc(r.provider) + ' · ' + esc(r.phone) + ' · ' + esc(SQ.cityName(r.city_id) || '') + (r.note ? '<br>وصفه: ' + esc(r.note) : '') + (r.admin_note ? '<br>ملاحظتك: ' + esc(r.admin_note) : '') + (r.suggest ? '<br>اقتراحك: ' + esc(r.suggest) : '') + '</div>' +
        (r.status === 'pending' ? '<div class="row2"><label class="field"><span>اسم الخدمة النهائي</span><input data-n="' + r.id + '" value="' + esc(r.name) + '" maxlength="40"></label><label class="field"><span>أيقونة (إيموجي)</span><input data-i="' + r.id + '" value="🔧" maxlength="4"></label></div>' +
          '<label class="field"><span>أو اربطها بخدمة موجودة</span><select data-e="' + r.id + '">' + opts + '</select></label>' +
          '<div class="row2"><label class="field"><span>ملاحظة للصنايعي (اختياري)</span><input data-m="' + r.id + '" maxlength="200"></label><label class="field"><span>خدمة بديلة نقترحها (عند الرفض)</span><input data-g="' + r.id + '" maxlength="100"></label></div>' +
          '<div class="btnrow"><button class="btn primary" data-act="ap" data-id="' + r.id + '">✔ موافقة</button><button class="btn danger" data-act="rj" data-id="' + r.id + '">✖ رفض</button></div>' : '') + '</div>';
    }).join('') : '<div class="empty"><div class="big">🛠</div>لا توجد اقتراحات</div>';
    el.onclick = async function (e) {
      var b = e.target.closest('[data-act]'); if (!b) return; var id = b.getAttribute('data-id'), q = function (k) { var x = document.querySelector('[data-' + k + '="' + id + '"]'); return x ? x.value.trim() : ''; };
      var act = b.getAttribute('data-act'); b.disabled = true;
      try {
        if (act === 'ap') await db.adminDecideCustom(code, id, { action: 'approve', name: q('n'), icon: q('i'), existing: q('e'), note: q('m') });
        else await db.adminDecideCustom(code, id, { action: 'reject', note: q('m'), suggest: q('g') });
        toast('تم، وأُرسل إشعار للصنايعي'); render();
      } catch (x) { b.disabled = false; fail(x); }
    };
  }

  /* ---------- الحظر والطعون ---------- */
  async function viewBans() {
    shell('<div id="banbox"><div class="spin">جاري التحميل...</div></div>');
    var d;
    try { d = await db.adminBans(code); } catch (e) { return fail(e); }
    var box = document.getElementById('banbox'); if (!box) return;
    var kinds = { mistake: 'حظر بالخطأ', regret: 'يقرّ ويلتزم', pay: 'سيسدّد العمولة', other: 'سبب آخر' };
    var pend = d.appeals.filter(function (a) { return a.status === 'pending'; });
    box.innerHTML =
      '<div class="card"><b>طعون بانتظار القرار (' + pend.length + ')</b>' + (d.appeals.length ? d.appeals.map(function (a, i) {
        return '<div class="kv" style="display:block;border-top:1px solid #eee;padding:10px 0"><b>' + esc(a.name) + '</b> <small class="ltr muted">' + esc(a.phone) + '</small> ' + pill(a.status === 'pending' ? 'بانتظار القرار' : (a.status === 'accepted' ? 'قُبل' : 'رُفض'), a.status === 'pending' ? 'warn' : (a.status === 'accepted' ? '' : 'bad')) +
          '<br><small class="muted">' + esc(kinds[a.kind] || a.kind || '') + ' · ' + U.timeAgo(a.ts) + (a.reason ? ' · سبب الحظر: ' + esc(a.reason) : '') + (+a.due > 0 ? ' · <span class="dangertxt">عمولة غير مسددة ' + Number(a.due).toLocaleString('en') + '</span>' : '') + '</small>' +
          '<p class="note">' + esc(a.body) + '</p>' + (a.note ? '<p class="note">ردّنا: ' + esc(a.note) + '</p>' : '') +
          (a.status === 'pending' ? '<div class="btnrow"><button class="btn primary" data-ap="1" data-i="' + i + '">♻ قبول واستعادة الحساب</button><button class="btn danger" data-ap="0" data-i="' + i + '">✖ رفض الطعن</button></div>' : '') + '</div>';
      }).join('') : '<p class="note">لا توجد طعون.</p>') + '</div>' +
      '<div class="card"><b>تطابقات مع محظورين (' + d.matches.length + ')</b><p class="note">متقدمون جدد يتطابق اسمهم وتاريخ ميلادهم مع شخص محظور. تحقق ثم احظر أو تجاهل.</p>' + (d.matches.length ? d.matches.map(function (m, i) {
        return '<div class="kv" style="display:block;border-top:1px solid #eee;padding:10px 0"><b>' + esc(m.name) + '</b> <small class="ltr muted">' + esc(m.phone) + '</small> ' + pill((STATUS[m.status] || ['—'])[0], m.status === 'approved' ? '' : 'warn') +
          '<br><small class="muted">يتطابق مع المحظور: <b>' + esc(m.ban_name) + '</b> (<span class="ltr">' + esc(m.ban_phone) + '</span>) · ميلاد ' + esc(String(m.birth_date || '')) + (m.ban_reason ? ' · ' + esc(m.ban_reason) : '') + '</small>' +
          '<div class="btnrow"><button class="btn danger" data-mt="ban" data-i="' + i + '">🚫 حظر</button><button class="btn ghost" data-mt="ok" data-i="' + i + '">تجاهل (ليس نفس الشخص)</button></div></div>';
      }).join('') : '<p class="note">لا توجد تطابقات ✓</p>') + '</div>' +
      '<div class="card"><b>المحظورون (' + d.banned.length + ')</b><p class="note">أرقامهم وبريدهم مرفوضة عند التسجيل أو التعديل، حتى لو حذفوا حسابهم.</p>' + (d.banned.length ? d.banned.map(function (b, i) {
        return '<div class="kv" style="display:block;border-top:1px solid #eee;padding:10px 0"><b>' + esc(b.name) + '</b> <small class="ltr muted">' + esc(b.phone) + (b.email ? ' · ' + esc(b.email) : '') + '</small><br><small class="muted">ميلاد ' + esc(String(b.birth_date || '—')) + ' · ' + U.timeAgo(b.ts) + (b.reason ? ' · ' + esc(b.reason) : '') + (+b.due > 0 ? ' · <span class="dangertxt">عمولة غير مسددة ' + Number(b.due).toLocaleString('en') + '</span>' : '') + (b.exists ? '' : ' · الحساب محذوف') + '</small>' +
          (b.exists ? '<div class="btnrow"><button class="btn primary" data-bn="' + i + '">♻ رفع الحظر</button></div>' : '') + '</div>';
      }).join('') : '<p class="note">لا يوجد محظورون.</p>') + '</div>';
    box.onclick = async function (e) {
      var t = e.target.closest('button'); if (!t) return;
      try {
        if (t.hasAttribute('data-ap')) {
          var a = pend[+t.getAttribute('data-i')] || d.appeals[+t.getAttribute('data-i')], acc = t.getAttribute('data-ap') === '1';
          var nt = prompt(acc ? 'رسالة للصنايعي عند الاستعادة (اختياري):' : 'سبب الرفض (يظهر للصنايعي):', ''); if (nt === null) return;
          await db.adminAppealDecide(code, a.id, acc, nt.trim()); toast(acc ? 'تمت استعادة الحساب' : 'تم رفض الطعن');
        } else if (t.hasAttribute('data-mt')) {
          var m = d.matches[+t.getAttribute('data-i')];
          if (t.getAttribute('data-mt') === 'ban') { var why = prompt('سبب الحظر:', 'تحايل بعد الحظر'); if (why === null) return; await db.adminBan(code, m.id, why.trim()); toast('تم الحظر'); }
          else { await db.adminDismissMatch(code, m.id); toast('تم التجاهل'); }
        } else if (t.hasAttribute('data-bn')) {
          var b = d.banned[+t.getAttribute('data-bn')]; var n2 = prompt('رسالة للصنايعي عند رفع الحظر (اختياري):', ''); if (n2 === null) return;
          await db.adminUnban(code, b.provider_id, n2.trim()); toast('تم رفع الحظر');
        } else return;
        viewBans();
      } catch (err) { fail(err); }
    };
  }

  /* ---------- الإعدادات ---------- */
  var PAY_DEF = [['bankak', 'بنكك'], ['fawry', 'فوري'], ['ocash', 'أوكاش'], ['mashreq', 'المشرق'], ['sahl', 'ساهل']];
  function payRows(cfg) {
    var cur = (cfg && cfg.pay_methods) || [], by = {};
    cur.forEach(function (m) { by[m.id] = m; });
    return PAY_DEF.map(function (d) {
      var m = by[d[0]] || {};
      return '<div class="paym" data-pid="' + d[0] + '"><label class="kv" style="cursor:pointer"><b>' + d[1] + '</b><input type="checkbox" class="pm_on"' + (m.on ? ' checked' : '') + ' style="width:auto"></label>' +
        '<div class="row2"><label class="field"><span>رقم الحساب</span><input class="ltr pm_no" maxlength="40" value="' + esc(m.account_no || '') + '"></label><label class="field"><span>اسم صاحب الحساب</span><input class="pm_nm" maxlength="60" value="' + esc(m.account_name || '') + '"></label></div></div>';
    }).join('');
  }
  async function viewSettings() {
    var cfg = {};
    try { cfg = await db.adminGetSettings(code); } catch (e) { return fail(e); }
    var closedSet = String(cfg.closed_states || '').split(',').map(function (x) { return x.trim(); }).filter(Boolean);
    shell('<div class="agrid"><div class="card"><b>بيانات الدعم</b><p class="note">تظهر للصنايعية والزبائن في زر "تواصل مع الدعم".</p>' +
      '<label class="field"><span>واتساب الدعم (بصيغة دولية بدون +)</span><input id="c_wa" class="ltr" inputmode="tel" placeholder="249912345678" value="' + esc(cfg.support_whatsapp || '') + '"></label>' +
      '<label class="field"><span>بريد الدعم</span><input id="c_em" class="ltr" type="email" value="' + esc(cfg.support_email || '') + '"></label><button class="btn primary" id="c_save" style="width:100%">حفظ</button></div>' +
      '<div class="card"><b>عمولة الخدمة</b><p class="note">على الصنايعي فقط؛ الزبون مجانًا. تُستحق عند اكتمال الخدمة بتأكيد الطرفين. عدّلها بما يناسب السوق (الافتراضي 5000 جنيه)، وتسري على الخدمات الجديدة فقط. اترك النسبة 0.</p>' +
      '<div class="row2"><label class="field"><span>مبلغ ثابت لكل خدمة (جنيه)</span><input id="c_fx" class="ltr" inputmode="numeric" value="' + esc(String(cfg.commission_fixed || 0)) + '"></label><label class="field"><span>نسبة من المبلغ (%)</span><input id="c_pc" class="ltr" inputmode="decimal" value="' + esc(String(cfg.commission_pct || 0)) + '"></label></div></div>' +
      '<div class="card"><b>رسالة العمولة للصنايعي</b><p class="note">تصله بعد اكتمال الخدمة كرسالة منك، وتبقى حتى تؤكد استلام المبلغ. اكتب {amount} مكان المبلغ.</p>' +
      '<label class="field"><span>نص الرسالة</span><textarea id="m_txt" rows="4" maxlength="600">' + esc(cfg.commission_text || '') + '</textarea></label>' +
      '<label class="field"><span>رقم الحساب</span><input id="m_no" class="ltr" maxlength="120" value="' + esc(cfg.commission_account_no || '') + '"></label>' +
      '<label class="field"><span>اسم الحساب</span><input id="m_nm" maxlength="120" value="' + esc(cfg.commission_account_name || '') + '"></label>' +
      '<label class="field"><span>واتساب استلام الإشعار (بصيغة دولية بدون +)</span><input id="m_wa" class="ltr" inputmode="tel" placeholder="249912345678" value="' + esc(cfg.commission_whatsapp || '') + '"></label>' +
      '<button class="btn primary" id="m_save" style="width:100%">حفظ رسالة العمولة</button></div>' +
      '<div class="card"><b>طرق دفع العمولة</b><p class="note">تظهر للصنايعي في شاشة العمولة كأيقونات، وبالضغط على واحدة يظهر رقم حسابها واسم صاحبه. فعّل ما تستقبل عليه فقط. إن لم تفعّل أي طريقة يظهر الحساب العام أعلاه.</p><div id="pm_box">' + payRows(cfg) + '</div>' +
      '<button class="btn primary" id="pm_save" style="width:100%">حفظ طرق الدفع</button></div>' +
      '<div class="card"><b>نصوص الشروط والخصوصية</b><p class="note">تظهر في التطبيق فورًا دون تحديثه. العنوان سطر يبدأ بـ ## والباقي فقرات؛ ويبدأ السطر بـ - لنقطة في قائمة. اترك الخانة فارغة لاستخدام النص الافتراضي المضمّن في التطبيق.</p>' +
      '<label class="field"><span>سياسة الخصوصية</span><textarea id="lg_p" rows="8" maxlength="30000" placeholder="## من نحن&#10;نص الفقرة...">' + esc(cfg.legal_privacy || '') + '</textarea></label>' +
      '<label class="field"><span>قوانين الاستخدام والشروط</span><textarea id="lg_t" rows="8" maxlength="30000" placeholder="## الاستخدام العام&#10;- نقطة...">' + esc(cfg.legal_terms || '') + '</textarea></label>' +
      '<button class="btn primary" id="lg_save" style="width:100%">حفظ النصوص</button></div>' +
      '<div class="card"><b>حدود أسعار الخدمات</b><p class="note">أقل وأعلى سعر يستطيع الصنايعي كتابته في ملفه. أي رقم خارج الحدين (مثل 10 جنيه أو مليار) يُرفض عند التسجيل والتعديل. غيّرها متى تغيّر السوق؛ لا تتأثر الأسعار المحفوظة حاليًا حتى يعدّلها صاحبها.</p>' +
      '<div class="row2"><label class="field"><span>أقل سعر (جنيه)</span><input id="p_floor" class="ltr" inputmode="numeric" value="' + esc(String(cfg.price_floor == null ? 10000 : cfg.price_floor)) + '"></label><label class="field"><span>أعلى سعر (جنيه)</span><input id="p_cap" class="ltr" inputmode="numeric" value="' + esc(String(cfg.price_cap == null ? 1000000 : cfg.price_cap)) + '"></label></div>' +
      '<button class="btn primary" id="p_save" style="width:100%">حفظ حدود الأسعار</button></div>' +
      '<div class="card"><b>الولايات المتاحة</b><p class="note">أزل العلامة عن الولاية غير الآمنة؛ تظهر في التطبيق «غير متاحة حاليًا» ولا يظهر صنايعيتها للزبائن ولا يُقبل الطلب منها.</p><div id="st_box">' +
      SQ.COUNTRY.states.map(function (s) { return '<label class="kv" style="cursor:pointer"><span>' + esc(s.name) + '</span><input type="checkbox" data-st="' + esc(s.id) + '"' + (closedSet.indexOf(s.id) < 0 ? ' checked' : '') + ' style="width:22px;height:22px"></label>'; }).join('') + '</div>' +
      '<button class="btn primary mt" id="st_save" style="width:100%">حفظ الولايات</button></div>' +
      '<div class="card"><b>تحديث التطبيق</b><p class="note">رقم النسخة يظهر في صفحة «عن التطبيق». «الحد الأدنى» أي نسخة أقل منه تُمنع من العمل حتى تتحدث (استخدمه للتحديثات الحرجة فقط). «الأحدث» يعرض تنبيهًا يمكن تجاوزه.</p><div class="row2"><label class="field"><span>الحد الأدنى الإجباري</span><input id="u_min" class="ltr" inputmode="numeric" value="' + esc(String(cfg.min_build || 0)) + '"></label><label class="field"><span>أحدث نسخة</span><input id="u_last" class="ltr" inputmode="numeric" value="' + esc(String(cfg.latest_build || 0)) + '"></label></div><label class="field"><span>رابط التحديث (https)</span><input id="u_url" class="ltr" value="' + esc(cfg.update_url || '') + '" placeholder="https://github.com/TheOuth/sanayei-qareeb-/releases/latest/download/sanayei-qareeb-native.apk"></label><label class="field"><span>رسالة للمستخدم (اختياري)</span><input id="u_msg" maxlength="300" value="' + esc(cfg.update_msg || '') + '"></label><button class="btn primary" id="u_save" style="width:100%">حفظ إعدادات التحديث</button></div>' +
      '<div class="card"><b>إشعار لجميع الصنايعية</b><p class="note">يصل إلى جرس الرسائل في تطبيق كل صنايعي (تحديث جديد، تنبيه، إعلان).</p><label class="field"><span>العنوان</span><input id="bc_t" maxlength="100"></label><label class="field"><span>النص</span><textarea id="bc_b" rows="3" maxlength="500"></textarea></label><label class="chk"><input type="checkbox" id="bc_up"> رسالة تحديث: يظهر فيها زر «تحديث الآن» يفتح رابط التحديث المحفوظ في الإعدادات</label><button class="btn primary" id="bc_send" style="width:100%">🔔 إرسال للجميع</button></div>' +
      '<div class="card"><div class="rhead"><b>سجل النشاط</b><button class="mini" id="au_hide" style="display:none;width:auto;padding:0 12px" title="تصغير">▲ تصغير</button></div><p class="note">آخر تغييرات الحالة والتوثيق وحذف الحسابات.</p><button class="btn ghost" id="au_show" style="width:100%">عرض السجل</button><div id="au_list"></div></div>' +
      '<div class="card"><b>تغيير رمز المدير</b>' + U.pwHtml('k_new', 'الرمز الجديد', '8 أحرف على الأقل، لا تشاركه') + U.pwHtml('k_new2', 'أعد كتابته') + '<button class="btn primary" id="k_save" style="width:100%">تغيير الرمز</button></div>' +
      '<div class="card"><b>نسخة احتياطية</b><p class="note">نزّل بيانات كل الصنايعية في ملف يفتح في Excel. أنصح بفعل ذلك أسبوعيا.</p><button class="btn ghost" id="c_csv" style="width:100%">⬇ تنزيل كل الصنايعية (CSV)</button></div>' +
      '<div class="card"><b>روابط</b><div class="kv"><span>التطبيق</span><a href="' + esc(appUrl()) + '" target="_blank" rel="noopener">فتح</a></div><div class="kv"><span>سياسة الخصوصية</span><a href="' + esc(appUrl()) + 'privacy-policy.html" target="_blank" rel="noopener">فتح</a></div></div></div>');
    function baseCfg() { return { support_whatsapp: cfg.support_whatsapp || '', support_email: cfg.support_email || '', commission_pct: cfg.commission_pct || 0, commission_fixed: cfg.commission_fixed || 0 }; }
    on('pm_save', 'click', async function () {
      var arr = [];
      document.querySelectorAll('#pm_box .paym').forEach(function (r) {
        var id = r.getAttribute('data-pid'), nm = (PAY_DEF.filter(function (d) { return d[0] === id; })[0] || [id, id])[1];
        arr.push({ id: id, name: nm, on: r.querySelector('.pm_on').checked, account_no: r.querySelector('.pm_no').value.trim(), account_name: r.querySelector('.pm_nm').value.trim() });
      });
      var bad = arr.filter(function (m) { return m.on && !m.account_no; });
      if (bad.length) return toast('اكتب رقم الحساب لـ ' + bad[0].name + ' أو ألغِ تفعيله');
      var o = baseCfg(); o.pay_methods = arr;
      try { await db.adminSaveSettings(code, o); toast('تم حفظ طرق الدفع'); viewSettings(); } catch (e) { fail(e); }
    });
    on('lg_save', 'click', async function () {
      var o = baseCfg(); o.legal_privacy = document.getElementById('lg_p').value.trim(); o.legal_terms = document.getElementById('lg_t').value.trim();
      try { await db.adminSaveSettings(code, o); toast('تم حفظ النصوص وستظهر في التطبيق فورًا'); viewSettings(); } catch (e) { fail(e); }
    });
    on('m_save', 'click', async function () {
      var o = baseCfg(); o.commission_text = document.getElementById('m_txt').value.trim(); o.commission_account_no = document.getElementById('m_no').value.trim(); o.commission_account_name = document.getElementById('m_nm').value.trim(); o.commission_whatsapp = document.getElementById('m_wa').value.replace(/\D/g, '');
      try { await db.adminSaveSettings(code, o); toast('تم حفظ رسالة العمولة'); viewSettings(); } catch (e) { fail(e); }
    });
    on('st_save', 'click', async function () {
      var closed = [].slice.call(document.querySelectorAll('#st_box [data-st]')).filter(function (x) { return !x.checked; }).map(function (x) { return x.getAttribute('data-st'); });
      if (closed.length && !confirm('ستُغلق ' + closed.length + ' ولاية. متأكد؟')) return;
      var o = baseCfg(); o.closed_states = closed.join(',');
      try { await db.adminSaveSettings(code, o); toast('تم حفظ الولايات'); viewSettings(); } catch (e) { fail(e); }
    });
    on('c_csv', 'click', function () { exportCsv({}); });
    on('au_show', 'click', async function () {
      var box = document.getElementById('au_list');
      try {
        var rows = await db.adminAudit(code, 100);
        var lbl = { status: 'تغيير حالة', verified: 'توثيق', delete_provider: 'حذف حساب', commission_paid: 'استلام عمولة', review_hide: 'إخفاء تقييم', review_restore: 'إرجاع تقييم', review_delete: 'حذف تقييم' };
        box.innerHTML = rows.length ? rows.map(function (r) { return '<div class="kv"><span>' + esc(lbl[r.action] || r.action) + ' — ' + esc(r.detail || '') + '</span><span class="note">' + esc(new Date(r.at).toLocaleString('ar-EG')) + '</span></div>'; }).join('') : '<p class="note">لا توجد أحداث بعد.</p>';
        document.getElementById('au_hide').style.display = ''; document.getElementById('au_show').style.display = 'none';
      } catch (e) { toast('تعذر تحميل السجل'); }
    });
    on('au_hide', 'click', function () { document.getElementById('au_list').innerHTML = ''; document.getElementById('au_hide').style.display = 'none'; var sh = document.getElementById('au_show'); sh.style.display = ''; sh.textContent = 'عرض السجل'; });
    lockCards([['c_save', 'c_fx'], 'p_save', 'm_save', 'pm_save', 'lg_save', 'st_save', 'u_save', 'k_save']);
    on('bc_send', 'click', async function () {
      var t = document.getElementById('bc_t').value.trim(), b = document.getElementById('bc_b').value.trim();
      if (!t) return toast('اكتب عنوانا للإشعار');
      if (!confirm('إرسال هذا الإشعار لجميع الصنايعية؟')) return;
      try { await db.adminSendNotification(code, null, t, b, document.getElementById('bc_up').checked ? 'update' : null); document.getElementById('bc_t').value = ''; document.getElementById('bc_up').checked = false; document.getElementById('bc_b').value = ''; toast('تم الإرسال للجميع'); } catch (e) { toast('تعذر الإرسال'); }
    });
    on('c_save', 'click', async function () {
      try { await db.adminSaveSettings(code, { support_whatsapp: document.getElementById('c_wa').value.replace(/\D/g, ''), support_email: document.getElementById('c_em').value.trim(), commission_pct: document.getElementById('c_pc').value, commission_fixed: document.getElementById('c_fx').value }); toast('تم الحفظ'); viewSettings(); } catch (e) { fail(e); }
    });
    on('p_save', 'click', async function () {
      var fl = Math.round(+String(document.getElementById('p_floor').value).replace(/[^\d.]/g, '')), cp = Math.round(+String(document.getElementById('p_cap').value).replace(/[^\d.]/g, ''));
      if (!(fl > 0) || !(cp > 0)) return toast('اكتب رقمين صحيحين');
      if (cp < fl) return toast('الحد الأعلى يجب ألا يقل عن الحد الأدنى');
      try { await db.adminSaveSettings(code, { support_whatsapp: cfg.support_whatsapp || '', support_email: cfg.support_email || '', commission_pct: cfg.commission_pct || 0, commission_fixed: cfg.commission_fixed || 0, price_floor: fl, price_cap: cp }); toast('تم حفظ حدود الأسعار'); viewSettings(); } catch (e) { fail(e); }
    });
    on('u_save', 'click', async function () {
      var mn = +document.getElementById('u_min').value || 0, lt = +document.getElementById('u_last').value || 0;
      if (mn > 0 && !confirm('سيُمنع كل من نسخته أقل من ' + mn + ' من استخدام التطبيق حتى يتحدث. متأكد؟')) return;
      try { await db.adminSaveSettings(code, { support_whatsapp: cfg.support_whatsapp || '', support_email: cfg.support_email || '', commission_pct: cfg.commission_pct || 0, commission_fixed: cfg.commission_fixed || 0, min_build: mn, latest_build: lt, update_url: document.getElementById('u_url').value.trim(), update_msg: document.getElementById('u_msg').value.trim() }); toast('تم حفظ إعدادات التحديث'); viewSettings(); } catch (e) { fail(e); }
    });
    on('k_save', 'click', async function () {
      var a = document.getElementById('k_new').value, b = document.getElementById('k_new2').value;
      if (a.length < 8) return toast('الرمز 8 أحرف على الأقل');
      if (a !== b) return toast('الرمزان غير متطابقين');
      try { await db.adminChangeCode(code, a); code = a; try { sessionStorage.setItem('sq_admin', a); } catch (e) {} toast('تم تغيير الرمز. احفظه جيدا'); viewSettings(); } catch (e) { fail(e); }
    });
  }

  /* تقفل بطاقات الإعدادات افتراضيا ويظهر زر «تعديل» لكل بطاقة */
  function lockCards(ids) {
    ids.forEach(function (it) {
      var id = Array.isArray(it) ? it[0] : it, extra = Array.isArray(it) ? it.slice(1) : [];
      var btn = document.getElementById(id); if (!btn) return;
      var card = btn.closest('.card'), cards = [card], title = card.querySelector('b');
      extra.forEach(function (x) { var el = document.getElementById(x); if (el) cards.push(el.closest('.card')); });
      var fields = []; cards.forEach(function (c) { fields = fields.concat([].slice.call(c.querySelectorAll('input,textarea,select'))); });
      fields.forEach(function (f) { f.disabled = true; });
      btn.style.display = 'none';
      var head = document.createElement('div'); head.className = 'rhead'; title.parentNode.insertBefore(head, title); head.appendChild(title);
      var ed = document.createElement('button'); ed.className = 'mini editbtn'; ed.textContent = 'تعديل'; head.appendChild(ed);
      cards.forEach(function (c) { c.classList.add('locked'); });
      ed.addEventListener('click', function () {
        if (card.classList.contains('locked')) {
          cards.forEach(function (c) { c.classList.remove('locked'); }); fields.forEach(function (f) { f.disabled = false; }); btn.style.display = ''; ed.textContent = 'إلغاء';
          var first = card.querySelector('input:not([type=checkbox]),textarea'); if (first) first.focus();
        } else viewSettings();
      });
    });
  }

  /* ---------- الإقلاع ---------- */
  (async function boot() {
    $app.innerHTML = '<div class="spin" style="margin-top:30vh">جاري التحميل...</div>';
    await SQ.refreshServices();
    render();
  })();
})();
