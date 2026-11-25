/* صنايعي قريب - لوحة المدير (صفحة منفصلة، غير مرتبطة بالتطبيق العام) */
(function () {
  'use strict';
  var SQ = window.SQ, C = SQ.CONFIG, db = SQ.db, U = SQ.ui, esc = U.esc, toast = U.toast, on = U.on, modal = U.modal, closeModal = U.closeModal;
  var $app = document.getElementById('app');
  var code = '', tab = 'overview', ov = null, cn = { badges: 0, custom: 0 }, bf = { filter: 'pending', q: '' };
  var pf = { q: '', status: '', service: '', city: '', limit: 30, offset: 0 }, rf = { status: '' };
  var rows = {}; // نسخة الصنايعية المعروضين حسب المعرّف
  try { code = sessionStorage.getItem('sq_admin') || ''; } catch (e) {}
  document.body.classList.add('admin');

  var TABS = [['overview', 'نظرة عامة'], ['providers', 'الصنايعية'], ['requests', 'الطلبات'], ['confirmed', 'المؤكدة'], ['payments', 'الدفعيات'], ['services', 'الخدمات'], ['custom', 'خدمات مقترحة'], ['badges', 'الشارات'], ['bans', 'الحظر'], ['reports', 'البلاغات'], ['settings', 'الإعدادات']];
  var STATUS = { pending: ['بانتظار الموافقة', 'warn'], approved: ['معتمد', ''], suspended: ['موقوف', 'bad'], rejected: ['مرفوض', 'bad'], banned: ['محظور', 'bad'] };
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
  /* قوالب الرسائل اليدوية (واتساب / إيميل / نسخ) */
  function msgTemplates(x) {
    var hi = 'السلام عليكم ورحمة الله وبركاته أخي/أختي ' + x.name + ' 🌿\n', t = SQ.tierOf(x.jobs), nx = SQ.nextTier(x.jobs), url = appUrl() + (x.username ? '#/u/' + x.username : '');
    var next = nx ? '\nباقي لك ' + (nx.min - x.jobs) + ' من الأعمال المؤكدة لتصل إلى شارة «' + nx.name + '».' : '\nوصلت إلى أعلى شارة إنجاز، شكرا لتميزك!';
    var how = '*كيف تحصل على علامة التوثيق؟*\n' +
      '✅ *توثيق الهوية:* أرسل لنا هنا صورة وثيقة سارية (بطاقة قومية أو رخصة قيادة أو جواز) مع صورة لك وأنت تحمل الوثيقة. بعد التحقق تُفعَّل علامتك، ونحذف الصور من محادثتنا.\n' +
      '🏅 *شارات الإنجاز:* تظهر تلقائيا مع كل عمل يؤكده عملاء مختلفون: ' + SQ.TIERS.slice().reverse().map(function (s) { return s.min + ' أعمال ← ' + s.name; }).join('، ') + '.\n\n' +
      '💡 اطلب من عملائك تأكيد «تمت الخدمة» من «طلباتي» في التطبيق، وأكّد أنت العمل من لوحتك.';
    return [
      { id: 'done', label: 'تهنئة بإتمام خدمة', subject: 'مبروك! تم تأكيد خدمة جديدة', body: hi + 'مبروك 🎉 تم *تأكيد إتمامك لخدمة جديدة* عبر تطبيق *' + C.appName + '* ✅\nمجموع أعمالك المؤكدة: *' + x.jobs + '*.' + (t ? '\nشارتك الحالية: *' + t.name + '*.' : '') + next + '\n\nشكرا لجودة عملك وأمانتك، ونتمنى لك المزيد من الطلبات.' + SIGN },
      { id: 'badge', label: 'تهنئة بالحصول على شارة', subject: 'مبروك شارتك الجديدة', body: hi + (t ? 'مبروك 🏅 حصلت على شارة *«' + t.name + '»* في تطبيق *' + C.appName + '* بعد ' + x.jobs + ' عمل مؤكد من عملائك.\nستظهر الشارة بجوار اسمك وتزيد ثقة الناس بك وترفع ظهورك.' + next : 'نشكرك على انضمامك إلى *' + C.appName + '* 🌿\nأول شارة إنجاز تحصل عليها بعد *' + SQ.TIERS[SQ.TIERS.length - 1].min + ' أعمال مؤكدة*، ونحن بجانبك لتصلها.') + '\n\nرابط ملفك للمشاركة:\n' + url + SIGN },
      { id: 'how', label: 'كيف تحصل على علامة التوثيق', subject: 'كيف تحصل على علامة التوثيق في ' + C.appName, body: hi + 'نود مساعدتك في رفع ثقة الناس بك داخل *' + C.appName + '*.\n\n' + how + SIGN }
    ];
  }
  function msgModal(x) {
    var T = msgTemplates(x), cur = 0;
    modal('<h3>رسالة إلى ' + esc(x.name) + '</h3><div class="seg" id="mt_t" style="flex-wrap:wrap;gap:6px">' + T.map(function (t, i) { return '<button class="chip' + (i === 0 ? ' on' : '') + '" data-i="' + i + '">' + t.label + '</button>'; }).join('') + '</div>' +
      '<label class="field mt"><span>نص الرسالة (يمكنك تعديله قبل الإرسال)</span><textarea id="mt_b" rows="10" style="min-height:220px"></textarea></label>' +
      '<div class="btnrow"><button class="btn wa" id="mt_wa">💬 واتساب</button><button class="btn ghost" id="mt_em">✉️ إيميل</button><button class="btn ghost" id="mt_cp">📋 نسخ</button></div>' +
      (x.id ? '<button class="btn ghost mt" id="mt_in" style="width:100%">🔔 إرسال كإشعار داخل التطبيق</button>' : '') +
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
    U.each('.anav button', function (b) { b.addEventListener('click', function () { tab = b.getAttribute('data-tab'); render(); }); });
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
    try { cn = await db.adminCounts(code); } catch (e) { cn = { badges: 0, custom: 0 }; }
    ({ overview: viewOverview, custom: viewCustom, badges: viewBadges, providers: viewProviders, requests: viewRequests, confirmed: viewConfirmed, payments: viewPayments, services: viewServices, reports: viewReports, settings: viewSettings, bans: viewBans })[tab]();
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
    if (p.status !== 'banned') act.push('<button class="btn danger" data-act="banned" data-id="' + p.id + '">🚫 حظر</button>');
    else act.push('<button class="btn primary" data-act="unban" data-id="' + p.id + '">♻ رفع الحظر</button>');
    if (p.ban_match && p.status !== 'banned') act.push('<button class="btn ghost" data-act="dismiss" data-id="' + p.id + '">تجاهل تطابق الحظر</button>');
    return '<div class="card acard"><div class="top2">' + U.avatar(p) + '<div class="pname">' + esc(p.name) + ' ' + pill(st[0], st[1]) + (p.status === 'approved' && p.available ? ' ' + pill('🟢 متاح الآن') : '') + (!p.has_password ? ' ' + pill('بلا كلمة سر', 'warn') : '') + (p.ban_match && p.status !== 'banned' ? ' ' + pill('⚠ يتطابق مع محظور', 'bad') : '') + ' ' + (p.verified ? '<span class="vtag">✔ موثّق</span>' : pill('غير موثّق', 'warn')) + ' ' + pill('ملف ' + p.pct + '%', p.pct >= 70 ? '' : 'warn') + '</div></div>' +
      '<div class="psvc">' + esc(U.svcNames(p.services)) + '</div>' +
      '<div class="meta"><span class="ltr">@' + esc(p.username || '') + '</span><span>📞 <span class="ltr">' + esc(p.phone) + '</span></span><span>📍 ' + esc((p.hood ? p.hood + '، ' : '') + (SQ.cityName(p.city_id) || p.city_id)) + '</span><span>' + (p.age ? '🎂 ' + p.age + ' سنة' : '<span class="dangertxt">بلا تاريخ ميلاد</span>') + '</span><span>' + p.experience + ' سنة خبرة</span><span>💰 ' + Number(p.price).toLocaleString('en') + '</span></div>' +
      '<div class="meta"><span>📨 ' + p.requests_week + ' هذا الأسبوع / ' + p.requests_total + '</span><span>' + (p.rating != null ? '<span class="star">★ ' + p.rating + '</span> (' + p.rating_n + ')' : 'بلا تقييم') + '</span><span>✔ ' + p.ok + ' ✖ ' + p.fail + '</span><span>🔖 رقم الطلب <b class="ltr">' + refOf(p) + '</b></span><span class="muted">سُجّل ' + fmtDate(p.created) + ' · ظهر ' + U.timeAgo(p.last_seen) + '</span></div>' +
      (p.bio ? '<p class="note">' + esc(p.bio) + '</p>' : '') + (p.admin_note ? '<p class="note">📝 ' + esc(p.admin_note) + '</p>' : '') + (p.verified && p.verify_doc ? '<p class="note">✔ التحقق: ' + esc(p.verify_doc) + '</p>' : '') +
      '<div class="btnrow">' + act.join('') + '<a class="btn wa" href="' + wa + '" target="_blank" rel="noopener">' + (p.status === 'pending' ? '💬 رسالة التأكيد' : 'واتساب') + '</a><button class="btn ghost" data-act="verify" data-id="' + p.id + '">' + (p.verified ? 'إلغاء التوثيق' : '✔ توثيق') + '</button><a class="btn ghost" href="tel:' + esc(p.phone) + '">📞</a>' +
      '<button class="btn ghost" data-act="msg" data-id="' + p.id + '">✉️ رسائل</button><button class="btn ghost" data-act="uname" data-id="' + p.id + '">@ المستخدم</button><button class="btn ghost" data-act="edit" data-id="' + p.id + '">✏️ تعديل</button><button class="btn ghost" data-act="pw" data-id="' + p.id + '">🔑 كلمة سر</button><button class="btn danger" data-act="del" data-id="' + p.id + '">🗑</button></div></div>';
  }

  async function provAction(a, p, btn) {
    if (!p) return;
    if (a === 'edit') return openProvForm(p);
    if (a === 'msg') return msgModal({ id: p.id, name: p.name, phone: p.whatsapp || p.phone, jobs: p.jobs || 0, verified: p.verified, username: p.username, email: p.email || '' });
    if (a === 'uname') {
      modal('<h3>اسم المستخدم لـ ' + esc(p.name) + '</h3><p class="note">للتعديل بعد تواصل الصنايعي مع الدعم. لا يستهلك مرته الواحدة. رابطه: <span class="ltr">' + esc(appUrl()) + '#/u/' + esc(p.username || '') + '</span></p>' +
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
    var dueBy = {}; dueList.forEach(function (c) { var g = dueBy[c.provider_id] || (dueBy[c.provider_id] = { id: c.id, name: c.provider_name, phone: c.phone, n: 0, total: 0, svc: [] }); g.n++; g.total += +c.amount; g.svc.push(c.service); });
    var dueRows = Object.keys(dueBy).map(function (k) { return dueBy[k]; });
    var dueHtml = '<div class="card"><b>عمولات مستحقة بانتظار الاستلام</b><p class="note">تظهر للصنايعي كرسالة منك حتى تضغط «تم استلام المبلغ» بعد وصول التحويل.</p>' +
      (dueRows.length ? dueRows.map(function (g) { return '<div class="kv"><span><b>' + esc(g.name) + '</b> <small class="ltr muted">' + esc(g.phone) + '</small><br><small class="muted">' + g.n + ' خدمة · ' + esc(g.svc.slice(0, 3).join('، ')) + '</small></span><span><b>' + g.total.toLocaleString('en') + '</b> جنيه <button class="btn primary" style="padding:6px 10px" data-cp="' + g.id + '">✔ تم الاستلام</button></span></div>'; }).join('') : '<p class="note">لا توجد عمولات مستحقة الآن ✓</p>') + '</div>';
    function due(x) { return x.jobs * fx; }
    var T = list.reduce(function (a, x) { a.d += due(x); a.p += x.paid; a.n += x.pay_count; return a; }, { d: 0, p: 0, n: 0 });
    box.innerHTML = dueHtml + '<div class="stats"><div class="stat"><b>' + T.d.toLocaleString('en') + '</b><small>المستحق</small></div><div class="stat"><b>' + T.p.toLocaleString('en') + '</b><small>المحصّل (' + T.n + ' دفعة)</small></div><div class="stat"><b>' + (T.d - T.p).toLocaleString('en') + '</b><small>المتبقي</small></div></div>' +
      '<p class="note">العمولة الحالية ' + fx.toLocaleString('en') + ' جنيه لكل خدمة مؤكدة من الطرفين، وتُطبّق على كل الأعمال السابقة. غيّرها من الإعدادات.</p>' +
      (list.length ? '<div class="tbl-wrap"><table class="tbl"><thead><tr><th>الصنايعي</th><th>أعمال مؤكدة</th><th>المستحق</th><th>المدفوع</th><th>المتبقي</th><th>عدد الدفعات</th><th>آخر دفعة</th><th></th></tr></thead><tbody>' +
        list.map(function (x, i) {
          var rest = due(x) - x.paid;
          return '<tr><td><b>' + esc(x.name) + '</b><br><small class="ltr muted">' + esc(x.phone) + '</small></td><td>' + x.jobs + '</td><td>' + due(x).toLocaleString('en') + '</td><td>' + x.paid.toLocaleString('en') + '</td><td>' + (rest > 0 ? '<span class="dangertxt">' + rest.toLocaleString('en') + '</span>' : rest < 0 ? '<span class="muted">+' + (-rest).toLocaleString('en') + ' مقدم</span>' : '<span class="okc">مسدد</span>') + '</td><td>' + x.pay_count + '</td><td>' + (x.last_paid ? fmtDate(x.last_paid) : '—') + '</td><td class="nw"><button class="mini" data-pi="' + i + '" data-pa="add">+ دفعة</button> <button class="mini" data-pi="' + i + '" data-pa="log">السجل</button></td></tr>';
        }).join('') + '</tbody></table></div>' : '<div class="empty"><div class="big">💰</div>لا توجد أعمال مؤكدة ولا دفعيات بعد</div>');
    box.onclick = async function (e) {
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
        modal('<h3>دفعات ' + esc(x.name) + '</h3>' + (x.payments.length ? '<div class="tbl-wrap"><table class="tbl"><thead><tr><th>التاريخ</th><th>المبلغ</th><th>ملاحظة</th><th></th></tr></thead><tbody>' + x.payments.map(function (p) { return '<tr><td>' + fmtDate(p.ts) + '</td><td>' + Number(p.amount).toLocaleString('en') + '</td><td>' + esc(p.note || '') + '</td><td><button class="mini" data-del="' + p.id + '" title="حذف">🗑</button></td></tr>'; }).join('') + '</tbody></table></div>' : '<p class="note">لا توجد دفعات.</p>') + '<button class="btn ghost mt" id="pl_x" style="width:100%">إغلاق</button>');
        on('pl_x', 'click', closeModal);
        var mb = document.getElementById('modal'); mb.onclick = async function (ev) {
          var dl = ev.target.closest('[data-del]'); if (!dl) return;
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
      '<div class="card"><b>الولايات المتاحة</b><p class="note">أزل العلامة عن الولاية غير الآمنة؛ تظهر في التطبيق «غير متاحة حاليًا» ولا يظهر صنايعيتها للزبائن ولا يُقبل الطلب منها.</p><div id="st_box">' +
      SQ.COUNTRY.states.map(function (s) { return '<label class="kv" style="cursor:pointer"><span>' + esc(s.name) + '</span><input type="checkbox" data-st="' + esc(s.id) + '"' + (closedSet.indexOf(s.id) < 0 ? ' checked' : '') + ' style="width:22px;height:22px"></label>'; }).join('') + '</div>' +
      '<button class="btn primary mt" id="st_save" style="width:100%">حفظ الولايات</button></div>' +
      '<div class="card"><b>تحديث التطبيق</b><p class="note">رقم النسخة يظهر في صفحة «عن التطبيق». «الحد الأدنى» أي نسخة أقل منه تُمنع من العمل حتى تتحدث (استخدمه للتحديثات الحرجة فقط). «الأحدث» يعرض تنبيهًا يمكن تجاوزه.</p><div class="row2"><label class="field"><span>الحد الأدنى الإجباري</span><input id="u_min" class="ltr" inputmode="numeric" value="' + esc(String(cfg.min_build || 0)) + '"></label><label class="field"><span>أحدث نسخة</span><input id="u_last" class="ltr" inputmode="numeric" value="' + esc(String(cfg.latest_build || 0)) + '"></label></div><label class="field"><span>رابط التحديث (https)</span><input id="u_url" class="ltr" value="' + esc(cfg.update_url || '') + '" placeholder="https://github.com/TheOuth/sanayei-qareeb-/releases/latest/download/sanayei-qareeb-native.apk"></label><label class="field"><span>رسالة للمستخدم (اختياري)</span><input id="u_msg" maxlength="300" value="' + esc(cfg.update_msg || '') + '"></label><button class="btn primary" id="u_save" style="width:100%">حفظ إعدادات التحديث</button></div>' +
      '<div class="card"><b>إشعار لجميع الصنايعية</b><p class="note">يصل إلى جرس الرسائل في تطبيق كل صنايعي (تحديث جديد، تنبيه، إعلان).</p><label class="field"><span>العنوان</span><input id="bc_t" maxlength="100"></label><label class="field"><span>النص</span><textarea id="bc_b" rows="3" maxlength="500"></textarea></label><button class="btn primary" id="bc_send" style="width:100%">🔔 إرسال للجميع</button></div>' +
      '<div class="card"><b>سجل النشاط</b><p class="note">آخر تغييرات الحالة والتوثيق وحذف الحسابات.</p><button class="btn ghost" id="au_show" style="width:100%">عرض السجل</button><div id="au_list"></div></div>' +
      '<div class="card"><b>تغيير رمز المدير</b>' + U.pwHtml('k_new', 'الرمز الجديد', '8 أحرف على الأقل، لا تشاركه') + U.pwHtml('k_new2', 'أعد كتابته') + '<button class="btn primary" id="k_save" style="width:100%">تغيير الرمز</button></div>' +
      '<div class="card"><b>نسخة احتياطية</b><p class="note">نزّل بيانات كل الصنايعية في ملف يفتح في Excel. أنصح بفعل ذلك أسبوعيا.</p><button class="btn ghost" id="c_csv" style="width:100%">⬇ تنزيل كل الصنايعية (CSV)</button></div>' +
      '<div class="card"><b>روابط</b><div class="kv"><span>التطبيق</span><a href="' + esc(appUrl()) + '" target="_blank" rel="noopener">فتح</a></div><div class="kv"><span>سياسة الخصوصية</span><a href="' + esc(appUrl()) + 'privacy-policy.html" target="_blank" rel="noopener">فتح</a></div></div></div>');
    function baseCfg() { return { support_whatsapp: cfg.support_whatsapp || '', support_email: cfg.support_email || '', commission_pct: cfg.commission_pct || 0, commission_fixed: cfg.commission_fixed || 0 }; }
    on('m_save', 'click', async function () {
      var o = baseCfg(); o.commission_text = document.getElementById('m_txt').value.trim(); o.commission_account_no = document.getElementById('m_no').value.trim(); o.commission_account_name = document.getElementById('m_nm').value.trim(); o.commission_whatsapp = document.getElementById('m_wa').value.replace(/\D/g, '');
      try { await db.adminSaveSettings(code, o); toast('تم حفظ رسالة العمولة'); } catch (e) { fail(e); }
    });
    on('st_save', 'click', async function () {
      var closed = [].slice.call(document.querySelectorAll('#st_box [data-st]')).filter(function (x) { return !x.checked; }).map(function (x) { return x.getAttribute('data-st'); });
      if (closed.length && !confirm('ستُغلق ' + closed.length + ' ولاية. متأكد؟')) return;
      var o = baseCfg(); o.closed_states = closed.join(',');
      try { await db.adminSaveSettings(code, o); toast('تم حفظ الولايات'); } catch (e) { fail(e); }
    });
    on('c_csv', 'click', function () { exportCsv({}); });
    on('au_show', 'click', async function () {
      var box = document.getElementById('au_list');
      try {
        var rows = await db.adminAudit(code, 100);
        var lbl = { status: 'تغيير حالة', verified: 'توثيق', delete_provider: 'حذف حساب' };
        box.innerHTML = rows.length ? rows.map(function (r) { return '<div class="kv"><span>' + esc(lbl[r.action] || r.action) + ' — ' + esc(r.detail || '') + '</span><span class="note">' + esc(new Date(r.at).toLocaleString('ar-EG')) + '</span></div>'; }).join('') : '<p class="note">لا توجد أحداث بعد.</p>';
      } catch (e) { toast('تعذر تحميل السجل'); }
    });
    on('bc_send', 'click', async function () {
      var t = document.getElementById('bc_t').value.trim(), b = document.getElementById('bc_b').value.trim();
      if (!t) return toast('اكتب عنوانا للإشعار');
      if (!confirm('إرسال هذا الإشعار لجميع الصنايعية؟')) return;
      try { await db.adminSendNotification(code, null, t, b); document.getElementById('bc_t').value = ''; document.getElementById('bc_b').value = ''; toast('تم الإرسال للجميع'); } catch (e) { toast('تعذر الإرسال'); }
    });
    on('c_save', 'click', async function () {
      try { await db.adminSaveSettings(code, { support_whatsapp: document.getElementById('c_wa').value.replace(/\D/g, ''), support_email: document.getElementById('c_em').value.trim(), commission_pct: document.getElementById('c_pc').value, commission_fixed: document.getElementById('c_fx').value }); toast('تم الحفظ'); } catch (e) { fail(e); }
    });
    on('u_save', 'click', async function () {
      var mn = +document.getElementById('u_min').value || 0, lt = +document.getElementById('u_last').value || 0;
      if (mn > 0 && !confirm('سيُمنع كل من نسخته أقل من ' + mn + ' من استخدام التطبيق حتى يتحدث. متأكد؟')) return;
      try { await db.adminSaveSettings(code, { support_whatsapp: cfg.support_whatsapp || '', support_email: cfg.support_email || '', commission_pct: cfg.commission_pct || 0, commission_fixed: cfg.commission_fixed || 0, min_build: mn, latest_build: lt, update_url: document.getElementById('u_url').value.trim(), update_msg: document.getElementById('u_msg').value.trim() }); toast('تم حفظ إعدادات التحديث'); } catch (e) { fail(e); }
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
