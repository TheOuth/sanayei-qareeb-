/* صنايعي قريب - الواجهة والتنقل
   مسارات: #/ (البداية) | #/c/... (طالب الخدمة) | #/p/... (مقدم الخدمة) */
(function () {
  'use strict';
  var SQ = window.SQ, C = SQ.CONFIG, db = SQ.db, $app = document.getElementById('app');

  /* ---------- أدوات ---------- */
  var U = SQ.ui, esc = U.esc, store = U.store, toast = U.toast, svc = U.svc, svcNames = U.svcNames, errMsg = U.errMsg, timeAgo = U.timeAgo,
      on = U.on, modal = U.modal, closeModal = U.closeModal, stateOptions = U.stateOptions, cityOptions = U.cityOptions, bindStateCity = U.bindStateCity;
  var anon = store.get('anon', null);
  if (!anon) { anon = SQ.uid(); store.set('anon', anon); }
  function go(h) { if (location.hash === h) route(); else location.hash = h; }
  var SVG_LOGO = '<svg viewBox="0 0 96 96" aria-hidden="true"><circle cx="48" cy="48" r="46" fill="#0f766e"/><path d="M48 18c-11 0-19 8-19 18 0 14 19 34 19 34s19-20 19-34c0-10-8-18-19-18z" fill="#f5efe6"/><path d="M41 33l14 14m0-14L41 47" stroke="#0f766e" stroke-width="5" stroke-linecap="round" opacity="0"/><path d="M52 29a7 7 0 0 0-8 9L33 49a3 3 0 0 0 4 4l11-11a7 7 0 0 0 9-8l-4 4-4-1-1-4z" fill="#0f766e"/></svg>';

  /* ---------- هيكل الصفحة ---------- */
  function page(o) {
    var back = o.back ? '<a class="back" href="' + o.back + '" aria-label="رجوع">›</a>' : '<span class="back ghost"></span>';
    var menu = o.menu ? '<button class="back" id="menuBtn" aria-label="القائمة">⋮</button>' : '<span class="back ghost"></span>';
    var tabbar = o.tab ? '<nav class="tabbar"><a class="' + (o.tab === 'home' ? 'on' : '') + '" href="#/p/home"><i>🏠</i><small>الرئيسية</small></a><a class="' + (o.tab === 'profile' ? 'on' : '') + '" href="#/p/profile"><i>👤</i><small>ملفي</small></a></nav>' : '';
    var bottom = (o.foot || tabbar) ? '<div class="bottom">' + (o.foot ? '<div class="foot">' + o.foot + '</div>' : '') + tabbar + '</div>' : '';
    $app.innerHTML = '<header class="top">' + back + '<h1>' + esc(o.title || C.appName) + '</h1>' + menu + '</header><main class="main">' + o.body + '</main>' + bottom;
    window.scrollTo(0, 0);
  }
  function loading(t) { page({ title: t || C.appName, body: '<div class="spin">جاري التحميل...</div>' }); }
  function demoNote() { return SQ.demo ? '<div class="banner">نسخة تجريبية: البيانات تُحفظ على جهازك فقط والصنايعية المعروضون أسماء وهمية للتجربة.</div>' : ''; }

  /* ---------- الموقع ---------- */
  var loc = store.get('loc', null); // { lat, lng, state_id, city_id, hood, manual }
  function getGps() {
    return new Promise(function (res, rej) {
      if (!navigator.geolocation) return rej(new Error('nogps'));
      navigator.geolocation.getCurrentPosition(
        function (p) { res({ lat: p.coords.latitude, lng: p.coords.longitude, acc: p.coords.accuracy }); },
        function (e) { rej(e); }, { enableHighAccuracy: true, timeout: 12000, maximumAge: 60000 });
    });
  }
  function locLabel() {
    if (!loc) return '';
    return (loc.hood ? loc.hood + '، ' : '') + SQ.cityName(loc.city_id) + (loc.manual ? '' : ' (موقعك الحالي)');
  }

  /* ---------- 1) الشاشة الأولى ---------- */
  function viewWelcome() {
    var role = store.get('role', null);
    if (role === 'client') return go('#/c/loc');
    if (role === 'provider') return go(store.get('pid', null) ? '#/p/home' : '#/p/start');
    $app.innerHTML =
      '<div class="welcome"><div class="logo">' + SVG_LOGO + '</div>' +
      '<div class="brand">' + esc(C.appName) + '</div>' +
      '<div class="tag">' + esc(C.tagline) + ' - ' + esc(SQ.COUNTRY.name) + '</div>' +
      '<div class="choices">' +
      '<button class="choice" id="bProv"><span class="ci">🛠️</span><b>مقدم خدمة</b><small>سجل واعرض خدماتك للناس القريبة منك</small></button>' +
      '<button class="choice alt" id="bClient"><span class="ci">📍</span><b>محتاج خدمة</b><small>اطلب أقرب مقدم خدمة ليك</small></button>' +
      '</div>' + (SQ.demo ? '<div class="note">نسخة تجريبية</div>' : '') +
      '</div>';
    on('bProv', 'click', function () { store.set('role', 'provider'); go(store.get('pid', null) ? '#/p/home' : '#/p/start'); });
    on('bClient', 'click', function () { store.set('role', 'client'); go('#/c/loc'); });
  }
  function switchRole() { store.del('role'); go('#/'); }

  /* ---------- 2) مسار طالب الخدمة ---------- */
  function viewClientLoc() {
    var gpsMsg = '';
    function render(manual) {
      page({
        title: 'موقعك', back: '', menu: true,
        body: demoNote() + '<div class="h2">وين أنت الآن؟</div>' +
          (manual ? '' : '<p class="muted" style="margin-bottom:16px">نحتاج موقعك لنعرض لك أقرب صنايعي ليك. نستخدمه وقت الطلب فقط.</p>') +
          (gpsMsg ? '<div class="banner">' + esc(gpsMsg) + '</div>' : '') +
          (manual
            ? '<label class="field"><span>الولاية</span><select id="st">' + stateOptions(loc && loc.state_id) + '</select></label>' +
              '<label class="field"><span>المدينة</span><select id="ct">' + cityOptions(loc && loc.state_id, loc && loc.city_id) + '</select></label>' +
              '<label class="field"><span>الحي (اختياري)</span><input id="hd" value="' + esc(loc && loc.hood || '') + '" placeholder="مثال: الثورة"></label>'
            : '<button class="btn primary" id="useGps" style="width:100%">📍 استخدم موقعي</button>' +
              '<div class="center mt"><button class="linkbtn" id="manual">أو اختار يدويا</button></div>'),
        foot: manual ? '<button class="btn primary" id="okLoc">التالي</button>' : ''
      });
      bindMenu();
      if (manual) {
        bindStateCity('st', 'ct');
        on('okLoc', 'click', function () {
          var s = document.getElementById('st').value, c = document.getElementById('ct').value;
          if (!s || !c) return toast('اختر الولاية والمدينة');
          var cc = SQ.findCity(c).city;
          loc = { lat: cc.lat, lng: cc.lng, state_id: s, city_id: c, hood: document.getElementById('hd').value.trim(), manual: true };
          store.set('loc', loc); go('#/c/service');
        });
      } else {
        on('manual', 'click', function () { render(true); });
        on('useGps', 'click', async function () {
          var b = document.getElementById('useGps'); b.disabled = true; b.textContent = 'جاري تحديد موقعك...';
          try {
            var g = await getGps(), n = SQ.geo.nearestCity(g.lat, g.lng);
            if (!n || n.km > 150) { gpsMsg = 'موقعك بعيد عن المدن المسجلة، اختر مدينتك يدويا'; return render(true); }
            loc = { lat: g.lat, lng: g.lng, state_id: n.state_id, city_id: n.city_id, hood: '', manual: false };
            store.set('loc', loc); go('#/c/service');
          } catch (e) { gpsMsg = 'ما قدرنا نحدد موقعك. اختر يدويا وسنكمل.'; render(true); }
        });
      }
    }
    render(false);
  }

  function viewClientService() {
    if (!loc) return go('#/c/loc');
    page({
      title: 'اختر الخدمة', back: '#/c/loc', menu: true,
      body: '<button class="locchip" id="chLoc">📍 ' + esc(locLabel()) + ' · تغيير</button>' +
        '<div class="grid">' + U.activeServices().map(function (s) {
          return '<button class="tile" data-s="' + s.id + '"><span class="ti">' + s.icon + '</span>' + esc(s.name) + '</button>';
        }).join('') + '</div>'
    });
    bindMenu(); on('chLoc', 'click', function () { go('#/c/loc'); });
    db.myRequests(anon).then(function (l) {
      var due = l.filter(function (r) { return r.status === 'new' && Date.now() - r.ts > C.reviewDelayHours * 3600e3; })[0];
      var main = document.querySelector('.main');
      if (!due || !main || !document.querySelector('.tile')) return;
      var d = document.createElement('div'); d.className = 'banner';
      d.innerHTML = 'تمت الشغلانة مع ' + esc(due.provider_name) + '؟<br><button class="btn primary" id="dueBtn">قيّم الآن</button>';
      main.insertBefore(d, main.firstChild);
      document.getElementById('dueBtn').addEventListener('click', function () { go('#/c/rate/' + due.id); });
    }).catch(function () {});
    Array.prototype.forEach.call(document.querySelectorAll('.tile'), function (t) {
      t.addEventListener('click', function () { go('#/c/list/' + t.getAttribute('data-s')); });
    });
  }

  async function viewClientList(sid) {
    if (!loc) return go('#/c/loc');
    loading(svc(sid).name);
    var res;
    try { res = await db.nearby({ lat: loc.lat, lng: loc.lng, cityId: loc.city_id, service: sid }); }
    catch (e) { return page({ title: svc(sid).name, back: '#/c/service', body: '<div class="empty"><div class="big">📶</div>' + errMsg(e) + '<div class="mt"><button class="btn primary" id="retry">إعادة المحاولة</button></div></div>' }), on('retry', 'click', route); }
    var items = res.items, head = '';
    if (res.tier === 'nearest_city') head = '<div class="banner">ما في أحد داخل نطاقك الآن. هذا أقرب زول ليك في المدينة على بعد ' + (items[0].distance_km != null ? items[0].distance_km + ' كم' : 'قريب') + '، تحب تشوفه؟</div>';
    if (res.tier === 'other_city') head = '<div class="banner">لا يوجد مقدم خدمة في مدينتك الآن. هؤلاء أقرب الموجودين في مدن أخرى، تحب تطلب منهم؟</div>';
    var body = demoNote() + head;
    if (!items.length) {
      body += '<div class="empty"><div class="big">🔎</div><p>لا يوجد ' + esc(svc(sid).name) + ' متاح في مدينتك الآن.</p><p class="note">جرب خدمة أخرى أو ارجع لاحقا.</p></div>';
    } else {
      body += items.map(function (p) { return pCard(p); }).join('');
    }
    page({ title: svc(sid).name, back: '#/c/service', menu: true, body: body });
    bindMenu();
    Array.prototype.forEach.call(document.querySelectorAll('.pcard-wrap'), function (c) {
      c.addEventListener('click', function () { go('#/c/p/' + c.getAttribute('data-id') + '/' + sid); });
    });
  }
  function pCard(p) {
    var dist = p.distance_km != null ? 'حوالي ' + (p.distance_km < 1 ? 'أقل من 1' : p.distance_km) + ' كم' : '';
    var em = p.distance_km != null ? SQ.geo.eta(p.distance_km) : null;
    var eta = em != null ? 'يصل في حوالي ' + em + (em <= 10 ? ' دقائق' : ' دقيقة') : '';
    return '<div class="card click pcard-wrap" data-id="' + p.id + '"><div class="pcard">' + U.avatar(p) + '' +
      '<div class="pinfo"><div class="pname">' + esc(p.name) + (p.demo ? ' <span class="demo">تجريبي</span>' : '') + '</div>' +
      '<div class="psvc">' + esc(svcNames(p.services)) + '</div>' +
      '<div class="meta">' +
      (dist ? '<span>📍 ' + dist + '</span>' : '') + (eta ? '<span>🕒 ' + eta + '</span>' : '') +
      '<span>' + (p.rating != null ? '<span class="star">★ ' + p.rating + '</span> (' + p.rating_n + ')' : '<span class="new">جديد</span>') + '</span>' +
      '<span>💰 كشف ' + Number(p.price).toLocaleString('en') + ' ' + esc(SQ.COUNTRY.currency) + '</span>' +
      '<span><i class="dot' + (p.available ? '' : ' off') + '"></i>' + (p.available ? 'متاح الآن' : 'مشغول') + '</span>' +
      '</div></div></div></div>';
  }

  async function viewClientProvider(id, sid) {
    loading('ملف الصنايعي');
    var p;
    try { p = await db.getProvider(id, loc); } catch (e) { toast(errMsg(e)); return go('#/c/list/' + sid); }
    if (!p) { toast('هذا الملف غير متاح'); return go('#/c/list/' + sid); }
    var dist = p.distance_km != null ? 'حوالي ' + p.distance_km + ' كم' : '—';
    page({
      title: p.name, back: '#/c/list/' + sid,
      body: demoNote() +
        '<div class="phead">' + U.avatar(p) + '<div class="h2" style="margin:0">' + esc(p.name) + '</div><div class="muted">' + esc(svcNames(p.services)) + '</div></div>' +
        '<div class="stats"><div class="stat"><b>' + (p.rating != null ? '★ ' + p.rating : 'جديد') + '</b><small>' + p.rating_n + ' تقييم</small></div>' +
        '<div class="stat"><b>' + p.ok + ' - ' + p.fail + '</b><small>ناجحة - فاشلة</small></div>' +
        '<div class="stat"><b>' + p.experience + '</b><small>سنة خبرة</small></div></div>' +
        '<div class="card">' +
        '<div class="kv"><span>الحالة</span><span><i class="dot' + (p.available ? '' : ' off') + '"></i>' + (p.available ? 'متاح الآن' : 'مشغول') + '</span></div>' +
        '<div class="kv"><span>المسافة</span><span>' + dist + '</span></div>' +
        '<div class="kv"><span>سعر الكشف</span><span>' + Number(p.price).toLocaleString('en') + ' ' + esc(SQ.COUNTRY.currency) + '</span></div>' +
        '<div class="kv"><span>المنطقة</span><span>' + esc((p.hood ? p.hood + '، ' : '') + SQ.cityName(p.city_id)) + '</span></div>' +
        '<div class="kv"><span>أوقات العمل</span><span>من ' + esc(p.from || '--') + ' إلى ' + esc(p.to || '--') + '</span></div></div>' +
        (p.bio ? '<div class="card"><b>عن الصنايعي</b><p style="margin-top:6px">' + esc(p.bio) + '</p></div>' : '') +
        '<div class="card"><b>آخر التقييمات</b>' + (p.reviews && p.reviews.length ? p.reviews.map(function (r) {
          return '<div class="rev"><span class="star">' + '★'.repeat(r.stars) + '</span> <small class="muted">' + (r.success ? 'شغلانة ناجحة' : 'شغلانة فاشلة') + ' · ' + timeAgo(r.ts) + '</small>' + (r.comment ? '<div>' + esc(r.comment) + '</div>' : '') + '</div>';
        }).join('') : '<p class="muted">لا توجد تقييمات بعد</p>') + '</div>' +
        '<div class="center"><button class="linkbtn" id="rep">🚩 إبلاغ عن هذا الصنايعي</button></div>',
      foot: '<button class="btn primary" id="call">📞 اتصال</button><button class="btn wa" id="wa">واتساب</button>'
    });
    async function contact(channel) {
      try { await db.createRequest({ provider_id: p.id, anon_id: anon, service: sid, city_id: loc ? loc.city_id : p.city_id, channel: channel }); }
      catch (e) { return toast(errMsg(e)); }
      if (channel === 'call') { location.href = 'tel:' + p.phone; return; }
      var msg = 'السلام عليكم، شفتك في ' + C.appName + ' وأحتاج ' + svc(sid).name + (loc && (loc.hood || loc.city_id) ? ' في ' + (loc.hood ? loc.hood + '، ' : '') + SQ.cityName(loc.city_id) : '');
      window.open('https://wa.me/' + SQ.util.digits(p.whatsapp || p.phone) + '?text=' + encodeURIComponent(msg), '_blank');
    }
    on('call', 'click', function () { contact('call'); });
    on('wa', 'click', function () { contact('whatsapp'); });
    on('rep', 'click', function () {
      modal('<h3>إبلاغ عن ' + esc(p.name) + '</h3><div class="chips" id="rs">' +
        ['رقم غلط', 'سلوك سيئ', 'احتيال', 'أخرى'].map(function (r, i) { return '<button class="chip' + (i === 0 ? ' on' : '') + '" data-r="' + r + '">' + r + '</button>'; }).join('') +
        '</div><div class="row2"><button class="btn ghost" id="mc">إلغاء</button><button class="btn danger" id="ms">إرسال البلاغ</button></div>');
      var reason = 'رقم غلط';
      Array.prototype.forEach.call(document.querySelectorAll('#rs .chip'), function (c) {
        c.addEventListener('click', function () {
          Array.prototype.forEach.call(document.querySelectorAll('#rs .chip'), function (x) { x.classList.remove('on'); });
          c.classList.add('on'); reason = c.getAttribute('data-r');
        });
      });
      on('mc', 'click', closeModal);
      on('ms', 'click', async function () {
        try { await db.reportProvider(p.id, anon, reason); closeModal(); toast('وصل بلاغك، شكرا'); } catch (e) { toast(errMsg(e)); }
      });
    });
  }

  /* طلباتي والتقييم */
  async function viewMyRequests() {
    loading('طلباتي');
    var list;
    try { list = await db.myRequests(anon); } catch (e) { toast(errMsg(e)); return go('#/c/service'); }
    var st = { 'new': 'بانتظار رأيك', done: 'ناجحة', failed: 'فاشلة', not_agreed: 'ما اتفقنا' };
    page({
      title: 'طلباتي', back: '#/c/service',
      body: list.length ? list.map(function (r) {
        var can = r.status === 'new' && Date.now() - r.ts > 5 * 60e3; // يسمح بالتقييم بعد 5 دقائق (والتطبيق يذكّره بعد يوم)
        return '<div class="card"><div class="pname">' + esc(r.provider_name) + '</div><div class="psvc">' + esc(svc(r.service).name) + ' · ' + (r.channel === 'call' ? 'اتصال' : 'واتساب') + ' · ' + timeAgo(r.ts) + '</div>' +
          '<div class="meta"><span>' + st[r.status] + '</span></div>' +
          (can ? '<button class="btn primary small mt rate" data-id="' + r.id + '" style="width:100%">تمت الشغلانة؟ قيّم الآن</button>' : '') + '</div>';
      }).join('') : '<div class="empty"><div class="big">📋</div>لا توجد طلبات بعد</div>'
    });
    Array.prototype.forEach.call(document.querySelectorAll('.rate'), function (b) {
      b.addEventListener('click', function () { go('#/c/rate/' + b.getAttribute('data-id')); });
    });
  }
  function viewRate(id) {
    var out = null, stars = 0;
    function render() {
      var body = '<div class="h2">تمت الشغلانة؟</div><div class="seg" id="oc">' +
        [['done', 'نعم، تمت'], ['failed', 'نعم، لكن فشلت'], ['not_agreed', 'ما اتفقنا']].map(function (x) {
          return '<button class="chip' + (out === x[0] ? ' on' : '') + '" data-o="' + x[0] + '">' + x[1] + '</button>';
        }).join('') + '</div>';
      if (out === 'done' || out === 'failed') {
        body += '<div class="center"><b>كم نجمة؟</b></div><div class="stars" id="st">' + [1, 2, 3, 4, 5].map(function (n) { return '<button data-n="' + n + '" class="' + (n <= stars ? 'on' : '') + '">★</button>'; }).join('') + '</div>' +
          '<label class="field"><span>تعليق (اختياري)</span><textarea id="cm" maxlength="300" placeholder="اكتب رأيك بإيجاز"></textarea></label>';
      }
      page({ title: 'التقييم', back: '#/c/requests', body: body, foot: '<button class="btn primary" id="send"' + (!out || ((out === 'done' || out === 'failed') && !stars) ? ' disabled' : '') + '>إرسال</button>' });
      Array.prototype.forEach.call(document.querySelectorAll('#oc .chip'), function (c) { c.addEventListener('click', function () { out = c.getAttribute('data-o'); render(); }); });
      Array.prototype.forEach.call(document.querySelectorAll('#st button'), function (b) { b.addEventListener('click', function () { stars = +b.getAttribute('data-n'); var t = (document.getElementById('cm') || {}).value; render(); if (t) document.getElementById('cm').value = t; }); });
      on('send', 'click', async function () {
        try { await db.addReview(id, anon, { outcome: out, stars: stars, comment: (document.getElementById('cm') || {}).value || '' }); toast('شكرا على تقييمك'); go('#/c/requests'); }
        catch (e) { toast(e.message === 'already' ? 'تم تقييم هذا الطلب من قبل' : errMsg(e)); }
      });
    }
    render();
  }

  function bindMenu() {
    on('menuBtn', 'click', function () {
      var role = store.get('role'), isC = role === 'client', isP = role === 'provider' && getPid();
      var sup = (SQ.cfg && SQ.cfg.support_whatsapp) || C.supportWhatsapp;
      modal('<h3>القائمة</h3><div style="display:flex;flex-direction:column;gap:10px">' +
        (isC ? '<button class="btn ghost" id="mReq">📋 طلباتي</button>' : '') +
        (isP ? '<button class="btn ghost" id="mProf">👤 ملفي الشخصي</button>' : '') +
        (sup ? '<a class="btn ghost" id="mSup" target="_blank" rel="noopener" href="https://wa.me/' + String(sup).replace(/\D/g, '') + '">💬 تواصل مع الدعم</a>' : '') +
        '<button class="btn ghost" id="mRole">🔄 تغيير (مقدم/محتاج خدمة)</button>' +
        (isP ? '<button class="btn danger" id="mOut">🚪 تسجيل الخروج</button>' : '') +
        (SQ.demo ? '<button class="btn ghost" id="mReset">♻️ إعادة ضبط البيانات التجريبية</button>' : '') +
        '<button class="btn ghost" id="mClose">إغلاق</button></div>');
      on('mReq', 'click', function () { closeModal(); go('#/c/requests'); });
      on('mProf', 'click', function () { closeModal(); go('#/p/profile'); });
      on('mRole', 'click', function () { closeModal(); switchRole(); });
      on('mOut', 'click', function () { closeModal(); confirmLogout(); });
      on('mReset', 'click', function () { closeModal(); db.resetDemo(); ['pid', 'ptoken', 'loc'].forEach(store.del); loc = null; toast('تمت إعادة الضبط'); go('#/'); });
      on('mClose', 'click', closeModal);
    });
  }

  /* ---------- 3) مسار مقدم الخدمة ---------- */
  var reg = store.get('reg', { services: [], radius: '10', from: '08:00', to: '20:00', waSame: true });
  if (!reg.services) reg.services = [];
  var regPw = ''; // كلمة السر تبقى في الذاكرة فقط ولا تُحفظ في الجهاز
  function regSave() { store.set('reg', reg); }
  function getPid() { return store.get('pid', null); }
  function getTok() { return store.get('ptoken', null); }
  function signIn(id, token) { store.set('pid', id); store.set('ptoken', token); store.set('role', 'provider'); }
  function signOut() { store.del('pid'); store.del('ptoken'); }
  function sessionExpired() { signOut(); toast('انتهت جلستك، ادخل من جديد'); go('#/p/login'); }
  function stepsBar(n) { return '<div class="steps">' + [1, 2, 3, 4].map(function (i) { return '<i class="' + (i <= n ? 'on' : '') + '"></i>'; }).join('') + '</div><div class="stepno">الخطوة ' + n + ' من 4</div>'; }
  function regBack(n) { return n === 1 ? '#/p/start' : '#/p/' + (n - 1); }
  function localPhone(p) { return SQ.util.localPhone(p); }
  var STATUS = { pending: ['قيد المراجعة', 'st-pending'], approved: ['معتمد', 'st-approved'], rejected: ['مرفوض', 'st-rejected'], suspended: ['موقوف', 'st-rejected'] };

  /* بوابة مقدم الخدمة: تسجيل جديد أو دخول */
  function viewProvStart() {
    if (getPid()) return go('#/p/home');
    page({
      title: 'مقدم خدمة', back: '#/',
      body: '<div class="welcome" style="padding:30px 0"><div class="logo">' + SVG_LOGO + '</div><div class="h2" style="margin:10px 0 18px">أهلا بك يا صنايعي</div>' +
        '<div class="choices"><button class="choice" id="bNew"><span class="ci">📝</span><b>تسجيل جديد</b><small>أنشئ ملفك واعرض خدماتك</small></button>' +
        '<button class="choice alt" id="bIn"><span class="ci">🔑</span><b>دخول</b><small>عندي حساب مسجل</small></button></div></div>'
    });
    on('bNew', 'click', function () { go('#/p/1'); });
    on('bIn', 'click', function () { go('#/p/login'); });
  }

  function viewProvLogin() {
    if (getPid()) return go('#/p/home');
    var sup = (SQ.cfg && SQ.cfg.support_whatsapp) || C.supportWhatsapp;
    page({
      title: 'دخول مقدم الخدمة', back: '#/p/start',
      body: '<div class="h2">سجّل دخولك</div>' +
        '<label class="field"><span>رقم الهاتف</span><div class="phone-wrap"><b>' + SQ.COUNTRY.dial + '</b><input id="ph" class="ltr" inputmode="tel" placeholder="' + SQ.COUNTRY.phoneHint + '" autocomplete="username"></div></label>' +
        U.pwHtml('pw', 'كلمة السر') +
        '<p class="note center">نسيت كلمة السر؟ ' + (sup ? '<a href="https://wa.me/' + String(sup).replace(/\D/g, '') + '" target="_blank" rel="noopener">تواصل مع الدعم</a> لإعادة تعيينها.' : 'تواصل مع مدير التطبيق لإعادة تعيينها.') + '</p>' +
        '<p class="center"><a href="#/p/1" class="linkbtn">ليس عندي حساب؟ سجّل الآن</a></p>',
      foot: '<button class="btn primary" id="go">دخول</button>'
    });
    var submit = async function () {
      var ph = SQ.util.normalizePhone(document.getElementById('ph').value), pw = document.getElementById('pw').value;
      if (!ph) return toast('رقم الهاتف غير صحيح');
      if (!pw) return toast('اكتب كلمة السر');
      var b = document.getElementById('go'); b.disabled = true; b.textContent = 'جاري الدخول...';
      try { var r = await db.providerLogin(ph, pw); signIn(r.id, r.token); toast('أهلا بك'); go('#/p/home'); }
      catch (e) {
        b.disabled = false; b.textContent = 'دخول';
        var m = e && e.message;
        toast(m === 'invalid' ? 'رقم الهاتف أو كلمة السر غير صحيحة' : m === 'no_password' ? 'حسابك بلا كلمة سر. ادخل من الجهاز الذي سجلت منه وأضف كلمة سر، أو تواصل مع الدعم' : errMsg(e));
      }
    };
    on('go', 'click', submit);
    on('pw', 'keydown', function (e) { if (e.key === 'Enter') submit(); });
  }

  function viewReg1() {
    if (getPid()) return go('#/p/home');
    page({
      title: 'تسجيل مقدم خدمة', back: regBack(1), menu: true,
      body: stepsBar(1) + '<div class="h2">بياناتك الشخصية</div>' +
        '<label class="field"><span>الاسم الكامل</span><input id="nm" value="' + esc(reg.name || '') + '" autocomplete="name"></label>' +
        '<label class="field"><span>رقم الهاتف</span><div class="phone-wrap"><b>' + SQ.COUNTRY.dial + '</b><input id="ph" class="ltr" inputmode="tel" value="' + esc(localPhone(reg.phone)) + '" placeholder="' + SQ.COUNTRY.phoneHint + '" autocomplete="username"></div><small>رقم حقيقي، سنتواصل معك عليه في واتساب للتأكيد</small></label>' +
        '<label class="check"><input type="checkbox" id="same"' + (reg.waSame !== false ? ' checked' : '') + '> رقم الواتساب هو نفس رقم الهاتف</label>' +
        '<label class="field" id="waBox" style="display:' + (reg.waSame !== false ? 'none' : 'block') + '"><span>رقم الواتساب</span><div class="phone-wrap"><b>' + SQ.COUNTRY.dial + '</b><input id="wa" class="ltr" inputmode="tel" value="' + esc(reg.wa || '') + '"></div></label>' +
        U.pwHtml('pw', 'كلمة السر', '6 أحرف أو أرقام على الأقل. بها تدخل حسابك من أي جهاز') +
        '<p class="center"><a href="#/p/login" class="linkbtn">عندي حساب؟ دخول</a></p>',
      foot: '<button class="btn primary" id="next">التالي</button>'
    });
    bindMenu();
    on('same', 'change', function () { document.getElementById('waBox').style.display = this.checked ? 'none' : 'block'; });
    document.getElementById('pw').value = regPw;
    on('next', 'click', function () {
      var nm = document.getElementById('nm').value.trim(), ph = SQ.util.normalizePhone(document.getElementById('ph').value);
      var same = document.getElementById('same').checked, wa = same ? ph : SQ.util.normalizePhone(document.getElementById('wa').value);
      var pw = document.getElementById('pw').value;
      if (nm.length < 3) return toast('اكتب اسمك الكامل');
      if (!ph) return toast('رقم الهاتف غير صحيح');
      if (!wa) return toast('رقم الواتساب غير صحيح');
      if (pw.length < 6) return toast('كلمة السر قصيرة (6 أحرف أو أرقام على الأقل)');
      reg.name = nm; reg.phone = ph; reg.whatsapp = wa; reg.wa = document.getElementById('wa').value; reg.waSame = same; regPw = pw; regSave(); go('#/p/2');
    });
  }

  function viewReg2() {
    if (!reg.phone) return go('#/p/1');
    if (!regPw) { toast('اكتب كلمة السر من جديد'); return go('#/p/1'); }
    page({
      title: 'تسجيل مقدم خدمة', back: regBack(2), menu: true,
      body: stepsBar(2) + '<div class="h2">الخدمة والمنطقة</div>' + U.svcFieldHtml('sv') +
        '<label class="field"><span>الولاية</span><select id="st">' + stateOptions(reg.state_id) + '</select></label>' +
        '<label class="field"><span>المدينة</span><select id="ct">' + cityOptions(reg.state_id, reg.city_id) + '</select></label>' +
        '<label class="field"><span>الحي</span><input id="hd" value="' + esc(reg.hood || '') + '" placeholder="مثال: الثورة"></label>' +
        '<div class="field"><span>موقعك الدقيق (مرة واحدة)</span><button class="btn ghost" id="gps" style="width:100%">📍 حدد موقعي</button><small id="gpsNote">' + (reg.lat ? '✔ تم تحديد موقعك (لن يظهر للزبائن، تظهر المسافة فقط)' : 'بدونه نستخدم مركز مدينتك، والمسافة تكون أقل دقة') + '</small></div>' +
        '<div class="field"><span>نطاق التغطية</span><div class="seg" id="rd">' + [['5', '5 كم'], ['10', '10 كم'], ['20', '20 كم'], ['all', 'كل المدينة']].map(function (r) {
          return '<button class="chip' + (reg.radius === r[0] ? ' on' : '') + '" data-r="' + r[0] + '">' + r[1] + '</button>';
        }).join('') + '</div></div>',
      foot: '<button class="btn primary" id="next">التالي</button>'
    });
    bindMenu(); bindStateCity('st', 'ct'); U.bindSvcField('sv', reg.services, regSave);
    U.each('#rd .chip', function (c) {
      c.addEventListener('click', function () {
        reg.radius = c.getAttribute('data-r'); regSave();
        U.each('#rd .chip', function (x) { x.classList.toggle('on', x === c); });
      });
    });
    on('gps', 'click', async function () {
      var n = document.getElementById('gpsNote'); n.textContent = 'جاري التحديد...';
      try { var g = await getGps(); reg.lat = g.lat; reg.lng = g.lng; regSave(); n.textContent = '✔ تم تحديد موقعك (لن يظهر للزبائن، تظهر المسافة فقط)'; }
      catch (e) { n.textContent = 'ما قدرنا نحدد موقعك، سنستخدم مركز مدينتك'; }
    });
    on('next', 'click', function () {
      var s = document.getElementById('st').value, c = document.getElementById('ct').value;
      if (!reg.services.length) return toast('اختر خدمة واحدة على الأقل');
      if (!s || !c) return toast('اختر الولاية والمدينة');
      if (/_other$/.test(c) && !document.getElementById('hd').value.trim()) return toast('اكتب اسم منطقتك أو قريتك في خانة الحي');
      reg.state_id = s; reg.city_id = c; reg.hood = document.getElementById('hd').value.trim(); regSave(); go('#/p/3');
    });
  }

  function viewReg3() {
    if (!reg.city_id) return go('#/p/2');
    page({
      title: 'تسجيل مقدم خدمة', back: regBack(3), menu: true,
      body: stepsBar(3) + '<div class="h2">الخبرة والسعر</div>' +
        '<label class="field"><span>سنوات الخبرة</span><input id="ex" type="number" inputmode="numeric" min="0" max="60" value="' + esc(reg.experience == null ? '' : reg.experience) + '"></label>' +
        '<label class="field"><span>سعر الكشف (' + esc(SQ.COUNTRY.currency) + ')</span><input id="pr" type="number" inputmode="numeric" min="0" value="' + esc(reg.price == null ? '' : reg.price) + '"><small>اكتب 0 لو الكشف مجاني</small></label>' +
        '<label class="field"><span>وصف قصير لمهارتك</span><textarea id="bio" maxlength="200" placeholder="مثال: تركيب ألواح شمسية وبطاريات وصيانة (20 حرفا فأكثر ترفع ترتيبك)">' + esc(reg.bio || '') + '</textarea></label>' + U.photoHtml('pp') +
        '<div class="row2"><label class="field"><span>من الساعة</span><input id="fr" type="time" class="ltr" value="' + esc(reg.from) + '"></label><label class="field"><span>إلى الساعة</span><input id="to" type="time" class="ltr" value="' + esc(reg.to) + '"></label></div>',
      foot: '<button class="btn primary" id="next">التالي</button>'
    });
    bindMenu();
    var ps = { name: reg.name, photo: reg.photo || '' };
    U.bindPhoto('pp', ps, function (v) { reg.photo = v; regSave(); });
    on('next', 'click', function () {
      var ex = document.getElementById('ex').value, pr = document.getElementById('pr').value, bio = document.getElementById('bio').value.trim();
      if (ex === '' || +ex < 0) return toast('اكتب سنوات الخبرة');
      if (pr === '' || +pr < 0) return toast('اكتب سعر الكشف');
      if (bio.length < 5) return toast('اكتب وصفا قصيرا لمهارتك');
      reg.experience = +ex; reg.price = +pr; reg.bio = bio; reg.from = document.getElementById('fr').value || '08:00'; reg.to = document.getElementById('to').value || '20:00';
      regSave(); go('#/p/4');
    });
  }

  function viewReg4() {
    if (reg.price == null) return go('#/p/3');
    if (!regPw) { toast('اكتب كلمة السر من جديد'); return go('#/p/1'); }
    page({
      title: 'تسجيل مقدم خدمة', back: regBack(4), menu: true,
      body: stepsBar(4) + '<div class="h2">راجع بياناتك</div><div class="card">' +
        [['الاسم', reg.name], ['الهاتف', reg.phone], ['الواتساب', reg.whatsapp], ['الخدمات', svcNames(reg.services)], ['المنطقة', (reg.hood ? reg.hood + '، ' : '') + SQ.cityName(reg.city_id) + ' - ' + SQ.stateName(reg.state_id)],
          ['النطاق', reg.radius === 'all' ? 'كل المدينة' : reg.radius + ' كم'], ['الخبرة', reg.experience + ' سنة'], ['سعر الكشف', Number(reg.price).toLocaleString('en') + ' ' + SQ.COUNTRY.currency], ['أوقات العمل', 'من ' + reg.from + ' إلى ' + reg.to], ['الوصف', reg.bio]]
          .map(function (r) { return '<div class="kv"><span>' + r[0] + '</span><span style="text-align:left">' + esc(r[1]) + '</span></div>'; }).join('') + '</div>' +
        '<p class="note">بعد الإرسال يراجع المدير طلبك ويتواصل معك على واتساب خلال 24 ساعة. تدخل بعدها بالهاتف وكلمة السر.</p>',
      foot: '<button class="btn primary" id="send">أرسل للمراجعة</button>'
    });
    bindMenu();
    on('send', 'click', async function () {
      var b = document.getElementById('send'); b.disabled = true; b.textContent = 'جاري الإرسال...';
      var city = SQ.findCity(reg.city_id).city;
      try {
        var r = await db.registerProvider({
          name: reg.name, phone: reg.phone, whatsapp: reg.whatsapp, password: regPw, state_id: reg.state_id, city_id: reg.city_id, hood: reg.hood,
          lat: reg.lat || city.lat, lng: reg.lng || city.lng, radius: reg.radius, services: reg.services, experience: reg.experience, price: reg.price,
          bio: reg.bio, from: reg.from, to: reg.to, photo: reg.photo || ''
        });
        signIn(r.id, r.token); store.del('reg'); reg = { services: [], radius: '10', from: '08:00', to: '20:00', waSame: true }; regPw = '';
        go('#/p/home');
      } catch (e) { b.disabled = false; b.textContent = 'أرسل للمراجعة'; toast(e && e.message === 'duplicate' ? 'هذا الرقم مسجل من قبل، ادخل بدل التسجيل' : errMsg(e)); }
    });
  }

  /* الرئيسية: مفتاح "متاح الآن" */
  async function viewProviderHome() {
    var pid = getPid(), tk = getTok();
    if (!pid) return go('#/p/start');
    loading('ملفي');
    var me;
    try { me = await db.providerSelf(pid, tk); } catch (e) { return sessionExpired(); }
    var pwBanner = !me.has_password ? '<div class="banner">🔐 أضف كلمة سر لتتمكن من الدخول لحسابك من أي جهاز.<br><button class="btn primary" id="addPw">إضافة كلمة سر</button></div>' : '';
    if (me.status !== 'approved') {
      var msg = { pending: ['⏳', 'طلبك قيد المراجعة', 'سنتواصل معك على واتساب خلال 24 ساعة للتأكد من رقمك.'], rejected: ['✖', 'لم يتم قبول طلبك', 'تواصل مع الدعم لمعرفة السبب.'], suspended: ['⛔', 'حسابك موقوف مؤقتا', 'تواصل مع الدعم لمراجعة حسابك.'] }[me.status] || ['⏳', 'قيد المراجعة', ''];
      var sup = (SQ.cfg && SQ.cfg.support_whatsapp) || C.supportWhatsapp;
      page({
        title: 'ملفي', menu: true, tab: 'home',
        body: pwBanner + '<div class="empty"><div class="big">' + msg[0] + '</div><div class="h2">' + msg[1] + '</div><p>' + msg[2] + '</p></div>' +
          (sup ? '<a class="btn wa" href="https://wa.me/' + String(sup).replace(/\D/g, '') + '" target="_blank" rel="noopener">تواصل مع الدعم</a>' : '') +
          '<div class="center mt"><button class="linkbtn" id="refresh">🔄 تحديث الحالة</button></div>'
      });
      bindMenu(); on('refresh', 'click', route); on('addPw', 'click', function () { openPwModal(me); });
      return;
    }
    var flag = !!me.flag, shown = flag && me.available;
    var hoursNote = flag && !me.in_hours
      ? '<div class="banner">⏰ أنت "متاح" لكن الوقت الآن خارج أوقات عملك (من ' + esc(me.from) + ' إلى ' + esc(me.to) + ')، فلن تظهر للزبائن حتى يحين وقتك.<br><button class="btn primary" id="hrs">تعديل أوقات العمل</button></div>'
      : '';
    page({
      title: 'الرئيسية', menu: true, tab: 'home',
      body: demoNote() + pwBanner + hoursNote + '<button class="switch' + (shown ? ' on' : '') + '" id="sw">' + (shown ? '🟢 متاح الآن' : (flag ? '🟡 متاح (خارج أوقات عملك)' : '⚪ مشغول')) + '<small>' + (flag ? 'اضغط لو انشغلت لتختفي عن الزبائن' : 'مخفي عن الزبائن. اضغط لتظهر') + '</small></button>' +
        '<div class="stats mt"><div class="stat"><b>' + me.requests_week + '</b><small>اتصالات هذا الأسبوع</small></div>' +
        '<div class="stat"><b>' + (me.rating != null ? '★ ' + me.rating : 'جديد') + '</b><small>' + me.rating_n + ' تقييم</small></div>' +
        '<div class="stat"><b>' + me.ok + ' - ' + me.fail + '</b><small>ناجحة - فاشلة</small></div></div>' +
        '<div class="card"><div class="kv"><span>الخدمات</span><span>' + esc(svcNames(me.services)) + '</span></div><div class="kv"><span>المنطقة</span><span>' + esc((me.hood ? me.hood + '، ' : '') + SQ.cityName(me.city_id)) + '</span></div><div class="kv"><span>أوقات العمل</span><span>' + esc(me.from + ' - ' + me.to) + ' <button class="linkbtn" id="hrs2">تعديل</button></span></div></div>' +
        '<p class="note">يتحول وضعك تلقائيا إلى "مشغول" لو ما فتحت التطبيق ' + C.availableTimeoutHours + ' ساعات، أو خارج أوقات عملك.</p>',
      foot: '<button class="btn wa" id="share">📤 شارك رابط ملفي</button>'
    });
    bindMenu();
    function editHours() {
      modal('<h3>أوقات العمل</h3><div class="row2"><label class="field"><span>من الساعة</span><input id="hf" type="time" class="ltr" value="' + esc(me.from) + '"></label><label class="field"><span>إلى الساعة</span><input id="ht" type="time" class="ltr" value="' + esc(me.to) + '"></label></div>' +
        '<button class="linkbtn" id="h24">طوال اليوم (00:00 - 23:59)</button><div class="row2 mt"><button class="btn ghost" id="hc">إلغاء</button><button class="btn primary" id="hs">حفظ</button></div>');
      on('h24', 'click', function () { document.getElementById('hf').value = '00:00'; document.getElementById('ht').value = '23:59'; });
      on('hc', 'click', closeModal);
      on('hs', 'click', async function () {
        var f = document.getElementById('hf').value, t = document.getElementById('ht').value;
        if (!f || !t) return toast('اكتب الوقتين');
        try { await db.setHours(pid, tk, f, t); closeModal(); toast('تم حفظ أوقات العمل'); route(); } catch (e) { toast(errMsg(e)); }
      });
    }
    on('hrs', 'click', editHours); on('hrs2', 'click', editHours); on('addPw', 'click', function () { openPwModal(me); });
    on('sw', 'click', async function () { try { await db.setAvailable(pid, tk, !flag); route(); } catch (e) { toast(errMsg(e)); } });
    on('share', 'click', function () {
      var url = location.href.split('#')[0] + '#/c/p/' + pid + '/' + me.services[0];
      var txt = 'أنا ' + me.name + '، ' + svcNames(me.services) + '. تقدر تتواصل معي من تطبيق ' + C.appName + ': ' + url;
      if (navigator.share) navigator.share({ text: txt }).catch(function () {});
      else window.open('https://wa.me/?text=' + encodeURIComponent(txt), '_blank');
    });
  }

  /* الملف الشخصي */
  /* اكتمال الملف: الملفات المكتملة والنشطة تظهر أولا للزبائن */
  function completeCard(me) {
    var todo = [];
    if (!me.photo) todo.push('📷 أضف صورة شخصية (+30%)');
    if (!me.bio || me.bio.trim().length < 20) todo.push('✍️ اكتب وصفا لمهارتك بـ 20 حرفا فأكثر (+25%)');
    if (!me.hood) todo.push('📍 اكتب اسم حيك (+15%)');
    if (!me.price) todo.push('💰 حدد سعر الكشف (+10%)');
    if (!me.experience) todo.push('🛠️ اكتب سنوات خبرتك (+10%)');
    if (!me.has_password) todo.push('🔐 أضف كلمة سر (+10%)');
    var pct = me.pct != null ? me.pct : 100 - 0;
    return '<div class="card"><b>اكتمال ملفك: ' + pct + '%</b><div class="pbar"><i style="width:' + pct + '%"></i></div>' +
      (todo.length ? '<ul class="todo">' + todo.map(function (t) { return '<li>' + t + '</li>'; }).join('') + '</ul><p class="note">الملفات المكتملة والأكثر نشاطا تظهر أولا للزبائن. <a href="#/p/edit" class="linkbtn">أكمل الآن</a></p>'
        : '<p class="note">ملفك مكتمل ✔. حافظ على نشاطك (فعّل "متاح" وردّ على الزبائن) ليبقى ترتيبك متقدما.</p>') + '</div>';
  }

  async function viewProfile() {
    var pid = getPid(), tk = getTok();
    if (!pid) return go('#/p/start');
    loading('ملفي الشخصي');
    var me, revs = [];
    try { me = await db.providerSelf(pid, tk); } catch (e) { return sessionExpired(); }
    if (me.status === 'approved') { try { var pub = await db.getProvider(pid, null); revs = (pub && pub.reviews) || []; } catch (e) {} }
    var st = STATUS[me.status] || STATUS.pending;
    page({
      title: 'ملفي الشخصي', menu: true, tab: 'profile',
      body: demoNote() + '<div class="phead">' + U.avatar(me) + '<div class="h2" style="margin:0">' + esc(me.name) + '</div>' +
        '<div class="muted">' + esc(svcNames(me.services)) + '</div><span class="badge ' + st[1] + '">' + st[0] + '</span></div>' +
        completeCard(me) +
        '<div class="stats"><div class="stat"><b>' + (me.rating != null ? '★ ' + me.rating : 'جديد') + '</b><small>' + me.rating_n + ' تقييم</small></div>' +
        '<div class="stat"><b>' + me.ok + ' - ' + me.fail + '</b><small>ناجحة - فاشلة</small></div><div class="stat"><b>' + me.experience + '</b><small>سنة خبرة</small></div></div>' +
        '<div class="card"><div class="cardhead"><b>بياناتي</b><button class="linkbtn" id="edit">✏️ تعديل</button></div>' +
        '<div class="kv"><span>الهاتف</span><span class="ltr">' + esc(me.phone) + '</span></div>' +
        '<div class="kv"><span>الواتساب</span><span class="ltr">' + esc(me.whatsapp) + '</span></div>' +
        '<div class="kv"><span>المنطقة</span><span>' + esc((me.hood ? me.hood + '، ' : '') + SQ.cityName(me.city_id) + ' - ' + SQ.stateName(me.state_id)) + '</span></div>' +
        '<div class="kv"><span>نطاق التغطية</span><span>' + (me.radius === 'all' ? 'كل المدينة' : esc(me.radius) + ' كم') + '</span></div>' +
        '<div class="kv"><span>سعر الكشف</span><span>' + Number(me.price).toLocaleString('en') + ' ' + esc(SQ.COUNTRY.currency) + '</span></div>' +
        '<div class="kv"><span>أوقات العمل</span><span>من ' + esc(me.from) + ' إلى ' + esc(me.to) + '</span></div>' +
        (me.bio ? '<div class="kv"><span>الوصف</span><span style="text-align:left">' + esc(me.bio) + '</span></div>' : '') +
        '<p class="note">لتغيير رقم الهاتف تواصل مع الدعم.</p></div>' +
        (me.status === 'approved' ? '<div class="card"><b>آخر التقييمات</b>' + (revs.length ? revs.map(function (r) {
          return '<div class="rev"><span class="star">' + '★'.repeat(r.stars) + '</span> <small class="muted">' + (r.success ? 'شغلانة ناجحة' : 'شغلانة فاشلة') + ' · ' + timeAgo(r.ts) + '</small>' + (r.comment ? '<div>' + esc(r.comment) + '</div>' : '') + '</div>';
        }).join('') : '<p class="muted">لا توجد تقييمات بعد</p>') + '</div>' : '') +
        '<div class="card"><b>الحساب</b><div class="acts">' +
        '<button class="btn ghost small" id="pw">🔐 ' + (me.has_password ? 'تغيير كلمة السر' : 'إضافة كلمة سر') + '</button>' +
        '<button class="btn ghost small" id="out">🚪 تسجيل الخروج</button></div>' +
        '<div class="center"><button class="linkbtn dangertxt" id="del">🗑 حذف حسابي نهائيا</button></div></div>'
    });
    bindMenu();
    on('edit', 'click', function () { go('#/p/edit'); });
    on('pw', 'click', function () { openPwModal(me); });
    on('out', 'click', confirmLogout);
    on('del', 'click', function () {
      modal('<h3>حذف الحساب</h3><p>سيتم حذف حسابك وتقييماتك وطلباتك نهائيا ولا يمكن التراجع. هل أنت متأكد؟</p><div class="row2 mt"><button class="btn ghost" id="dn">إلغاء</button><button class="btn danger" id="dy">نعم، احذف</button></div>');
      on('dn', 'click', closeModal);
      on('dy', 'click', async function () {
        try { await db.deleteProvider(pid, tk); closeModal(); signOut(); toast('تم حذف حسابك'); go('#/p/start'); } catch (e) { toast(errMsg(e)); }
      });
    });
  }

  function confirmLogout() {
    modal('<h3>تسجيل الخروج</h3><p>هل تريد تسجيل الخروج؟ تدخل مرة ثانية برقم هاتفك وكلمة السر.</p><div class="row2 mt"><button class="btn ghost" id="lc">إلغاء</button><button class="btn primary" id="ly">خروج</button></div>');
    on('lc', 'click', closeModal);
    on('ly', 'click', function () { closeModal(); signOut(); toast('تم تسجيل الخروج'); go('#/p/login'); });
  }

  function openPwModal(me) {
    var has = !!me.has_password;
    modal('<h3>' + (has ? 'تغيير كلمة السر' : 'إضافة كلمة سر') + '</h3>' +
      (has ? U.pwHtml('pwOld', 'كلمة السر الحالية') : '') + U.pwHtml('pwNew', 'كلمة السر الجديدة', '6 أحرف أو أرقام على الأقل') + U.pwHtml('pwNew2', 'أعد كتابتها') +
      '<div class="row2"><button class="btn ghost" id="pc">إلغاء</button><button class="btn primary" id="ps">حفظ</button></div>');
    on('pc', 'click', closeModal);
    on('ps', 'click', async function () {
      var o = has ? document.getElementById('pwOld').value : null, n = document.getElementById('pwNew').value, n2 = document.getElementById('pwNew2').value;
      if (n.length < 6) return toast('كلمة السر قصيرة (6 أحرف أو أرقام على الأقل)');
      if (n !== n2) return toast('كلمتا السر غير متطابقتين');
      try { var r = await db.setPassword(getPid(), getTok(), n, o); if (r && r.token) store.set('ptoken', r.token); closeModal(); toast('تم حفظ كلمة السر'); route(); }
      catch (e) { toast(errMsg(e)); }
    });
  }

  /* تعديل الملف الشخصي */
  async function viewEdit() {
    var pid = getPid(), tk = getTok();
    if (!pid) return go('#/p/start');
    loading('تعديل ملفي');
    var me;
    try { me = await db.providerSelf(pid, tk); } catch (e) { return sessionExpired(); }
    var ed = { services: me.services.slice(), radius: String(me.radius || '10'), lat: null, lng: null, name: me.name, photo: me.photo || '' };
    page({
      title: 'تعديل ملفي', back: '#/p/profile',
      body: U.photoHtml('pe') + '<label class="field"><span>الاسم الكامل</span><input id="nm" value="' + esc(me.name) + '"></label>' +
        '<label class="field"><span>رقم الهاتف</span><input class="ltr" value="' + esc(me.phone) + '" disabled><small>لتغيير الرقم تواصل مع الدعم</small></label>' +
        '<label class="field"><span>رقم الواتساب</span><div class="phone-wrap"><b>' + SQ.COUNTRY.dial + '</b><input id="wa" class="ltr" inputmode="tel" value="' + esc(localPhone(me.whatsapp)) + '"></div></label>' +
        U.svcFieldHtml('sv') +
        '<label class="field"><span>الولاية</span><select id="st">' + stateOptions(me.state_id) + '</select></label>' +
        '<label class="field"><span>المدينة</span><select id="ct">' + cityOptions(me.state_id, me.city_id) + '</select></label>' +
        '<label class="field"><span>الحي</span><input id="hd" value="' + esc(me.hood || '') + '"></label>' +
        '<div class="field"><span>تحديث موقعي الدقيق</span><button class="btn ghost" id="gps" style="width:100%">📍 حدد موقعي الآن</button><small id="gpsNote">اتركه إن لم يتغير مكانك</small></div>' +
        '<div class="field"><span>نطاق التغطية</span><div class="seg" id="rd">' + [['5', '5 كم'], ['10', '10 كم'], ['20', '20 كم'], ['all', 'كل المدينة']].map(function (r) {
          return '<button class="chip' + (ed.radius === r[0] ? ' on' : '') + '" data-r="' + r[0] + '">' + r[1] + '</button>';
        }).join('') + '</div></div>' +
        '<div class="row2"><label class="field"><span>سنوات الخبرة</span><input id="ex" type="number" inputmode="numeric" min="0" value="' + esc(me.experience) + '"></label>' +
        '<label class="field"><span>سعر الكشف</span><input id="pr" type="number" inputmode="numeric" min="0" value="' + esc(me.price) + '"></label></div>' +
        '<label class="field"><span>وصف قصير لمهارتك</span><textarea id="bio" maxlength="200">' + esc(me.bio || '') + '</textarea></label>' +
        '<div class="row2"><label class="field"><span>من الساعة</span><input id="fr" type="time" class="ltr" value="' + esc(me.from) + '"></label><label class="field"><span>إلى الساعة</span><input id="to" type="time" class="ltr" value="' + esc(me.to) + '"></label></div>',
      foot: '<button class="btn primary" id="save">حفظ التعديلات</button>'
    });
    bindStateCity('st', 'ct'); U.bindSvcField('sv', ed.services); U.bindPhoto('pe', ed);
    U.each('#rd .chip', function (c) {
      c.addEventListener('click', function () { ed.radius = c.getAttribute('data-r'); U.each('#rd .chip', function (x) { x.classList.toggle('on', x === c); }); });
    });
    on('gps', 'click', async function () {
      var n = document.getElementById('gpsNote'); n.textContent = 'جاري التحديد...';
      try { var g = await getGps(); ed.lat = g.lat; ed.lng = g.lng; n.textContent = '✔ تم تحديد موقعك'; } catch (e) { n.textContent = 'ما قدرنا نحدد موقعك'; }
    });
    on('save', 'click', async function () {
      var nm = document.getElementById('nm').value.trim(), wa = SQ.util.normalizePhone(document.getElementById('wa').value);
      var st = document.getElementById('st').value, ct = document.getElementById('ct').value, bio = document.getElementById('bio').value.trim();
      var ex = document.getElementById('ex').value, pr = document.getElementById('pr').value;
      if (nm.length < 3) return toast('اكتب اسمك الكامل');
      if (!wa) return toast('رقم الواتساب غير صحيح');
      if (!ed.services.length) return toast('اختر خدمة واحدة على الأقل');
      if (!st || !ct) return toast('اختر الولاية والمدينة');
      if (ex === '' || pr === '') return toast('اكتب الخبرة وسعر الكشف');
      if (bio.length < 5) return toast('اكتب وصفا قصيرا لمهارتك');
      var o = { name: nm, whatsapp: wa, services: ed.services, state_id: st, city_id: ct, hood: document.getElementById('hd').value.trim(), radius: ed.radius,
        experience: +ex, price: +pr, bio: bio, photo: ed.photo, from: document.getElementById('fr').value || '08:00', to: document.getElementById('to').value || '20:00' };
      if (ed.lat != null) { o.lat = ed.lat; o.lng = ed.lng; }
      else if (ct !== me.city_id) { var cc = SQ.findCity(ct).city; o.lat = cc.lat; o.lng = cc.lng; }
      var b = document.getElementById('save'); b.disabled = true;
      try { await db.updateProfile(pid, tk, o); toast('تم حفظ التعديلات'); go('#/p/profile'); } catch (e) { b.disabled = false; toast(errMsg(e)); }
    });
  }

  /* ---------- التوجيه ---------- */
  function route() {
    closeModal();
    var h = (location.hash || '#/').replace(/^#/, ''), p = h.split('/').filter(Boolean);
    try {
      if (!p.length) return viewWelcome();
      if (p[0] === 'c') {
        if (p[1] === 'p') { if (!store.get('role')) store.set('role', 'client'); return viewClientProvider(p[2], p[3] || 'other'); } // رابط مشاركة الصنايعي
        if (p[1] === 'loc') return viewClientLoc();
        if (p[1] === 'service') return viewClientService();
        if (p[1] === 'list') return viewClientList(p[2]);
        if (p[1] === 'requests') return viewMyRequests();
        if (p[1] === 'rate') return viewRate(p[2]);
        return viewClientLoc();
      }
      if (p[0] === 'p') {
        if (p[1] === 'home') return viewProviderHome();
        if (p[1] === 'profile') return viewProfile();
        if (p[1] === 'edit') return viewEdit();
        if (p[1] === 'login') return viewProvLogin();
        if (p[1] === 'start') return viewProvStart();
        if (p[1] === '1') return viewReg1();
        if (p[1] === '2') return viewReg2();
        if (p[1] === '3') return viewReg3();
        if (p[1] === '4') return viewReg4();
        return getPid() ? viewProviderHome() : viewProvStart();
      }
      viewWelcome();
    } catch (e) { $app.innerHTML = '<div class="empty"><div class="big">⚠️</div>حصل خطأ. <a href="#/">الرئيسية</a></div>'; }
  }
  window.addEventListener('hashchange', route);

  /* الإقلاع: نحمّل قائمة الخدمات (التي يديرها المدير) ثم نعرض الشاشة */
  SQ.cfg = {};
  (async function boot() {
    $app.innerHTML = '<div class="spin" style="margin-top:40vh">جاري التحميل...</div>';
    var pending = SQ.refreshServices();
    if (!SQ.hasServicesCache) { await Promise.race([pending, new Promise(function (r) { setTimeout(r, 7000); })]); }
    db.appConfig().then(function (c) { SQ.cfg = c || {}; }).catch(function () {});
    route();
  })();
})();
