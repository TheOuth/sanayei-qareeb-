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
  var SVG_LOGO = '<svg viewBox="0 0 96 96" aria-hidden="true"><defs><linearGradient id="lg1" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#D6EBFF"/></linearGradient></defs><circle cx="48" cy="48" r="45" fill="rgba(255,255,255,.14)" stroke="#fff" stroke-opacity=".75" stroke-width="1.5"/><path d="M48 17c-11.5 0-20 8.3-20 19 0 15 20 35 20 35s20-20 20-35c0-10.7-8.500-19-20-19z" fill="url(#lg1)"/><path d="M52.500 28.500a7.500 7.500 0 0 0-8.600 9.700L32.500 49.500a3.200 3.200 0 0 0 4.500 4.500l11.300-11.300a7.500 7.500 0 0 0 9.700-8.600l-4.400 4.400-4.300-1.100-1.100-4.300z" fill="#1E6FD0"/></svg>';

  /* ---------- هيكل الصفحة ---------- */
  function page(o) {
    var back = o.back ? '<a class="back" href="' + o.back + '" aria-label="رجوع">' + SQ.I('back', 22) + '</a>' : '<span class="back ghost"></span>';
    var menu = o.menu ? '<button class="back" id="menuBtn" aria-label="القائمة">' + SQ.I('menu', 22) + '</button>' : '<span class="back ghost"></span>';
    var tabbar = o.tab ? '<nav class="tabbar"><a class="' + (o.tab === 'home' ? 'on' : '') + '" href="#/p/home"><i>' + SQ.I('home', 24) + '</i><small>الرئيسية</small></a><a class="' + (o.tab === 'profile' ? 'on' : '') + '" href="#/p/profile"><i>' + SQ.I('user', 24) + '</i><small>ملفي</small></a></nav>' : '';
    var bottom = (o.foot || tabbar) ? '<div class="bottom">' + (o.foot ? '<div class="foot">' + o.foot + '</div>' : '') + tabbar + '</div>' : '';
    $app.innerHTML = '<header class="top">' + back + '<h1>' + esc(o.title || C.appName) + '</h1>' + menu + '</header><main class="main">' + o.body + '</main>' + bottom;
    window.scrollTo(0, 0); enter();
  }
  function enter() { $app.classList.remove('enter'); void $app.offsetWidth; $app.classList.add('enter'); }
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

  /* ---------- 1) الرئيسية: قسمان (أحتاج خدمة | أنا صنايعي) + بحث + تصنيفات ---------- */
  function normAr(t) {
    return String(t || '').toLowerCase().replace(/[ً-ْـ]/g, '').replace(/[أإآ]/g, 'ا').replace(/ة/g, 'ه').replace(/ى/g, 'ي').replace(/ـ/g, '').trim();
  }
  function afterLoc() {
    var n = store.get('next', null);
    if (n) { store.del('next'); return go('#/c/list/' + n); }
    go('#/');
  }
  function viewHome() {
    document.body.classList.add('is-home');
    var side = store.get('side', getPid() ? 'prov' : 'client');
    var list = U.activeServices(), cats = SQ.CATEGORIES.filter(function (c) { return list.some(function (s) { return SQ.catOf(s).id === c.id; }); });
    var tiles = cats.map(function (c) {
      var items = list.filter(function (s) { return SQ.catOf(s).id === c.id; });
      return '<div class="cat" data-c="' + c.id + '"><div class="cathead" style="--c:' + c.color + '"><i>' + SQ.catIcon(c, 20) + '</i><b>' + esc(c.name) + '</b><small>' + items.length + ' خدمة</small></div><div class="grid">' +
        items.map(function (s) {
          return '<button class="tile" data-s="' + s.id + '" data-n="' + esc(normAr(s.name + ' ' + (SQ.KEYWORDS[s.id] || '') + ' ' + c.name)) + '" style="--c:' + c.color + '"><span class="ti">' + SQ.svcIcon(s, 27) + '</span><span class="tn">' + esc(s.name) + '</span></button>';
        }).join('') + '</div></div>';
    }).join('');
    var chips = '<div class="catchips"><button class="chip on" data-c="">الكل</button>' + cats.map(function (c) { return '<button class="chip" data-c="' + c.id + '">' + SQ.catIcon(c, 16) + ' ' + esc(c.name) + '</button>'; }).join('') + '</div>';
    $app.innerHTML =
      '<div class="home"><header class="hero"><div class="herotop"><div class="hlogo"><div class="logo sm">' + SVG_LOGO + '</div>' +
      '<button class="back" id="menuBtn" aria-label="القائمة">' + SQ.I('menu', 24) + '</button></div><div class="hname"><b>' + esc(C.appName) + '</b><small>' + esc(C.tagline) + '</small></div></div>' +
      '<div class="searchbar"><span class="sico">' + SQ.I('search', 22) + '</span><input id="hq" type="search" placeholder="ابحث: سباك، كهربائي، تكييف..." autocomplete="off" enterkeyhint="search"><button id="hqx" hidden aria-label="مسح">✕</button></div>' +
      '<button class="locchip2" id="chLoc">' + SQ.I('pin', 17) + ' ' + (loc ? esc(locLabel()) + ' · تغيير' : 'حدد موقعك ليظهر لك الأقرب') + '</button></header>' +
      '<div class="sides"><div class="seg" id="seg" data-side="' + side + '"><i class="thumb"></i><button class="side' + (side === 'client' ? ' on' : '') + '" data-side="client">' + SQ.I('client', 21) + '<b>أحتاج خدمة</b></button>' +
      '<button class="side' + (side === 'prov' ? ' on' : '') + '" data-side="prov">' + SQ.I('wrench', 21) + '<b>أنا صنايعي</b></button></div></div>' +
      '<div class="panels s-' + side + '"><section class="panel pclient" id="pClient">' + demoNote() + '<div id="dueBox"></div>' + chips + '<div id="tiles">' + tiles +
      '</div><div class="empty" id="noRes" hidden><div class="big">🔎</div><p>ما لقينا خدمة بهذا الاسم.</p><p class="note">جرّب كلمة أخرى، أو أخبرنا بالخدمة التي تحتاجها عبر الدعم.</p></div>' +
      '<div class="sechead" id="pgHead"><b>' + SQ.I('star', 20, 'sf') + ' الصنايعية</b><small>الأقرب والأعلى تقييما أولا</small></div><div class="pgrid" id="pgrid"></div><div id="pgMore" class="center mt"></div><div id="pgSentinel" style="height:1px"></div></section>' +
      '<section class="panel pprov" id="pProv"></section></div></div>';
    bindMenu();
    on('chLoc', 'click', function () { go('#/c/loc'); });
    // التبديل بين القسمين
    U.each('.side', function (b) {
      b.addEventListener('click', function () {
        var v = b.getAttribute('data-side'); store.set('side', v);
        U.each('.side', function (x) { x.classList.toggle('on', x === b); });
        document.querySelector('.panels').className = 'panels s-' + v; document.getElementById('seg').setAttribute('data-side', v);
        window.scrollTo(0, 0);
      });
    });
    // فتح خدمة
    var openSvc = function (sid) { if (!loc) { store.set('next', sid); return go('#/c/loc'); } go('#/c/list/' + sid); };
    U.each('.tile', function (t) { t.addEventListener('click', function () { openSvc(t.getAttribute('data-s')); }); });
    // التصنيفات
    var catSel = '';
    function applyFilter() {
      var q = normAr(document.getElementById('hq').value), any = 0;
      document.getElementById('hqx').hidden = !q;
      U.each('.cat', function (c) {
        var shown = 0;
        U.each('#' + 'tiles' + ' .cat[data-c="' + c.getAttribute('data-c') + '"] .tile', function (t) {
          var ok = (!catSel || c.getAttribute('data-c') === catSel) && (!q || t.getAttribute('data-n').indexOf(q) > -1);
          t.style.display = ok ? '' : 'none'; if (ok) shown++;
        });
        c.style.display = shown ? '' : 'none'; any += shown;
      });
      var gshown = 0;
      U.each('#pgrid .gcard', function (g) {
        var ok = (!catSel || (' ' + g.getAttribute('data-cats') + ' ').indexOf(' ' + catSel + ' ') > -1) && (!q || g.getAttribute('data-n').indexOf(q) > -1);
        g.style.display = ok ? '' : 'none'; if (ok) gshown++;
      });
      var ph = document.getElementById('pgHead'); if (ph) ph.style.display = (document.getElementById('pgrid').children.length && !gshown && (q || catSel)) ? 'none' : '';
      document.getElementById('noRes').hidden = !!(any || gshown);
    }
    window.__applyFilter = applyFilter;
    U.each('.catchips .chip', function (b) {
      b.addEventListener('click', function () { catSel = b.getAttribute('data-c'); U.each('.catchips .chip', function (x) { x.classList.toggle('on', x === b); }); applyFilter(); });
    });
    on('hq', 'input', function () {
      applyFilter();
      if (this.value && store.get('side', 'client') !== 'client') document.querySelector('.side[data-side="client"]').click();
    });
    on('hq', 'keydown', function (e) {
      if (e.key !== 'Enter') return;
      var vis = Array.prototype.filter.call(document.querySelectorAll('.tile'), function (t) { return t.style.display !== 'none'; });
      if (vis.length === 1) openSvc(vis[0].getAttribute('data-s')); else this.blur();
    });
    on('hqx', 'click', function () { document.getElementById('hq').value = ''; applyFilter(); });
    // طلب بانتظار التقييم
    db.myRequests(anon).then(function (l) {
      var due = l.filter(function (r) { return r.status === 'new' && (r.accept || 'accepted') === 'accepted' && Date.now() - r.ts > C.reviewDelayHours * 3600e3; })[0], box = document.getElementById('dueBox');
      if (!due || !box) return;
      box.innerHTML = '<div class="banner">تمت الشغلانة مع ' + esc(due.provider_name) + '؟ تأكيدك يرفع ترتيب الصنايعي ويمنحه شارة إنجاز.<br><button class="btn primary" id="dueBtn">قيّم الآن</button></div>';
      on('dueBtn', 'click', function () { go('#/c/rate/' + due.id); });
    }).catch(function () {});
    renderProvPanel();
    loadGrid();
  }

  /* شبكة الصنايعية أسفل الرئيسية: تُحمَّل عند الاقتراب منها لتوفير الاستهلاك */
  var tbReg = {};
  function trustBadge(p) {
    var t = SQ.tierId(p); if (!t && !p.verified) return '';
    tbReg[p.id] = p;
    return '<span class="tb t-' + (t || 'gray') + '" role="button" tabindex="0" data-tb="' + p.id + '" aria-label="موثوق">' + SQ.badge(t || 'gray', 21) + '</span>';
  }
  function trustModal(p) {
    var j = p.jobs || 0, tid = SQ.tierId(p), t = tid ? { id: tid, name: ({ gray: 'رمادية', green: 'خضراء', blue: 'زرقاء', gold: 'ذهبية' })[tid] } : null, nx = SQ.nextTier(j);
    var yes = '<b class="okc">✓ نعم</b>', no = '<span class="muted">لا</span>';
    modal('<h3>لماذا ' + esc(p.name) + ' موثوق؟</h3><div class="tbl-wrap"><table class="tbl"><tbody>' +
      '<tr><th>الهوية</th><td>' + (p.verified ? yes + ' · تحقق منها فريق التطبيق' : no + ' · لم يتم التحقق بعد') + '</td></tr>' +
      '<tr><th>الأعمال المؤكدة</th><td>' + j + (nx ? ' <small class="muted">(' + (nx.min - j) + ' للوصول إلى «' + nx.name + '»)</small>' : '') + '</td></tr>' +
      '<tr><th>الشارة الحالية</th><td>' + (t ? '<span class="tier t-' + t.id + '">' + SQ.badge(t.id, 15) + ' ' + t.name + '</span>' : '<span class="muted">لا يوجد بعد</span>') + '</td></tr>' +
      '<tr><th>التقييم</th><td>' + (p.rating != null ? '★ ' + p.rating + ' (' + p.rating_n + ')' : 'جديد') + '</td></tr></tbody></table></div>' +
      '<h3 style="margin-top:14px">كيف تحصل على التوثيق؟</h3><div class="tbl-wrap"><table class="tbl"><thead><tr><th>العلامة</th><th>الشرط</th></tr></thead><tbody>' +
      '<tr><td><span class="tier t-gray">' + SQ.badge('gray', 15) + ' موثّق</span></td><td>أرسل لفريق التطبيق على واتساب وثيقة سارية وصورة لك معها، وبعد التحقق تُفعَّل علامتك.</td></tr>' +
      '<tr><td><span class="tier t-gray">' + SQ.badge('gray', 15) + ' رمادية</span></td><td>أكمل بيانات ملفك بالكامل، وتراجعها الإدارة وتمنحك الشارة إن كانت صحيحة.</td></tr>' +
      SQ.TIERS.slice().reverse().map(function (x) { return '<tr><td><span class="tier t-' + x.id + '">' + SQ.badge(x.id, 15) + ' ' + x.name + '</span></td><td>' + x.min + ' معاملة ناجحة من عملاء مختلفين.</td></tr>'; }).join('') +
      '</tbody></table></div><p class="note">العمل يُحسب مؤكدا حين يقول العميل «تمت الخدمة» من «طلباتي» ولا يعترض الصنايعي.</p><button class="btn primary" id="tbClose" style="width:100%">حسنا</button>');
    on('tbClose', 'click', closeModal);
  }
  var tbTimer = null;
  function hideBubble() { var b = document.getElementById('tbBubble'); if (b) b.remove(); clearTimeout(tbTimer); }
  document.addEventListener('click', function (e) {
    var bub = e.target.closest('#tbBubble');
    if (bub) { e.preventDefault(); e.stopPropagation(); var p = tbReg[bub.getAttribute('data-id')]; hideBubble(); if (p) trustModal(p); return; }
    var tb = e.target.closest('.tb');
    if (!tb) { hideBubble(); return; }
    e.preventDefault(); e.stopPropagation(); hideBubble();
    var id = tb.getAttribute('data-tb'), r = tb.getBoundingClientRect(), c = (tb.className.match(/t-(gray|green|blue|gold)/) || [0, 'gray'])[1];
    var el = document.createElement('button'); el.id = 'tbBubble'; el.className = 'tbbub t-' + c; el.setAttribute('data-id', id); el.textContent = 'موثوق · اعرف لماذا';
    document.body.appendChild(el);
    var w = el.offsetWidth, x = Math.max(8, Math.min(window.innerWidth - w - 8, r.left + r.width / 2 - w / 2));
    el.style.left = x + 'px'; el.style.top = (r.bottom + 8) + 'px';
    requestAnimationFrame(function () { el.classList.add('show'); });
    tbTimer = setTimeout(hideBubble, 5000);
  }, true);
  window.addEventListener('hashchange', hideBubble);

  function tierTag(p, long) {
    var tid = SQ.tierId(p), t = tid ? { id: tid, name: ({ gray: 'رمادية', green: 'خضراء', blue: 'زرقاء', gold: 'ذهبية' })[tid] } : null; if (!t) return '';
    return '<span class="tier t-' + t.id + '" title="' + p.jobs + ' عمل مؤكد">' + SQ.badge(t.id, 15) + (long ? ' صنايعي ' + t.name + ' · ' + p.jobs + ' عمل مؤكد' : ' ' + t.name) + '</span>';
  }
  function gridCard(p) {
    var ids = p.services || [], first = ids[0] || '';
    var chips = ids.slice(0, 2).map(function (i) { return '<span class="mchip">' + esc(svc(i).name) + '</span>'; }).join('') + (ids.length > 2 ? '<span class="mchip more">+' + (ids.length - 2) + '</span>' : '');
    var cats = ids.map(function (i) { return SQ.catOf(svc(i)).id; }).join(' ');
    return '<button class="gcard" data-id="' + p.id + '" data-s="' + esc(first) + '" data-cats="' + cats + '" data-n="' + esc(normAr(p.name + ' ' + ids.map(function (i) { return svc(i).name; }).join(' '))) + '">' +
      '<span class="gph">' + U.avatar(p, p.verified ? 'sq ver' : 'sq') + (p.available ? '<i class="dot on" title="متاح الآن"></i>' : '<i class="dot"></i>') + '</span>' +
      '<b class="gname">' + esc(p.name) + ' ' + trustBadge(p) + '</b>' +
      '<span class="gstar">' + (p.rating != null ? '<span class="star">' + SQ.I('star', 13, 'sf') + ' ' + p.rating + '</span> <small>(' + p.rating_n + ')</small>' : '<small class="muted">جديد</small>') + (p.age ? ' <small class="muted">· ' + p.age + ' سنة</small>' : '') + (p.distance_km != null ? ' <small class="muted">· ' + (p.distance_km < 1 ? '<1' : p.distance_km) + ' كم</small>' : '') + '</span>' +
      '<span class="gchips">' + chips + '</span></button>';
  }
  var gridState = { offset: 0, loading: false, done: false, io: null };
  function loadGrid(reset) {
    var el = document.getElementById('pgrid'); if (!el) return;
    if (reset !== false) { gridState.offset = 0; gridState.done = false; el.innerHTML = ''; }
    var sentinel = document.getElementById('pgSentinel');
    var run = function () {
      if (gridState.loading || gridState.done) return;
      gridState.loading = true;
      var more = document.getElementById('pgMore'); if (more) more.innerHTML = '<div class="spin">...</div>';
      db.featured({ lat: loc ? loc.lat : null, lng: loc ? loc.lng : null, limit: 12, offset: gridState.offset }).then(function (r) {
        gridState.loading = false;
        var g = document.getElementById('pgrid'); if (!g) return;
        g.insertAdjacentHTML('beforeend', r.items.map(gridCard).join(''));
        gridState.offset += r.items.length; gridState.done = !r.more || !r.items.length;
        var m = document.getElementById('pgMore'); if (m) m.innerHTML = '';
        if (!g.children.length) { var h = document.getElementById('pgHead'); if (h) h.style.display = 'none'; }
        U.each('#pgrid .gcard:not([data-b])', function (c) { c.setAttribute('data-b', 1); c.addEventListener('click', function () { go('#/c/p/' + c.getAttribute('data-id') + '/' + c.getAttribute('data-s')); }); });
        if (window.__applyFilter) window.__applyFilter();
        if (!gridState.done && 'IntersectionObserver' in window && sentinel) { gridState.io && gridState.io.disconnect(); gridState.io = new IntersectionObserver(function (e) { if (e[0].isIntersecting) { gridState.io.disconnect(); run(); } }, { rootMargin: '300px' }); gridState.io.observe(sentinel); }
        else if (!gridState.done && m) { m.innerHTML = '<button class="btn ghost" id="pgBtn">عرض المزيد</button>'; on('pgBtn', 'click', run); }
      }).catch(function () { gridState.loading = false; var m = document.getElementById('pgMore'); if (m) m.innerHTML = ''; });
    };
    if ('IntersectionObserver' in window && sentinel) {
      gridState.io && gridState.io.disconnect();
      gridState.io = new IntersectionObserver(function (e) { if (e[0].isIntersecting) { gridState.io.disconnect(); run(); } }, { rootMargin: '400px' });
      gridState.io.observe(sentinel);
    } else run();
  }

  function renderProvPanel() {
    var el = document.getElementById('pProv'); if (!el) return;
    var pid = getPid();
    if (!pid) {
      el.innerHTML = '<div class="provhero"><div class="pe">' + SQ.I('wrench', 30) + '</div><h2>اعرض مهارتك للناس القريبين منك</h2><p>سجّل مجانا في دقائق، وفريق صنايعي قريب يراجع طلبك ويؤكد بياناتك.</p>' +
        '<ul class="perks"><li><i>' + SQ.I('gift', 20) + '</i>اعرض خدمتك حسب المهارات العندك</li><li><i>' + SQ.I('pin', 20) + '</i>يصلك الزبون الأقرب إليك</li><li><i>' + SQ.I('phone', 20) + '</i>الزبون يتصل بك مباشرة</li><li><i>' + SQ.I('star', 20) + '</i>تقييماتك تبني سمعتك</li></ul>' +
        '<button class="btn primary" id="bNew">سجّل الآن مجانا</button><button class="btn ghost" id="bIn">عندي حساب؟ دخول</button></div>' +
        '<div class="card how"><b>كيف يعمل؟</b><ol><li>تسجّل بياناتك وخدماتك ومنطقتك</li><li>نؤكد حسابك معك على واتساب ويُوثَّق ملفك</li><li>تفعّل "متاح" فيصلك الزبائن</li></ol></div>';
      on('bNew', 'click', function () { go('#/p/1'); }); on('bIn', 'click', function () { go('#/p/login'); });
      return;
    }
    el.innerHTML = '<div class="card"><div class="spin">...</div></div>';
    db.providerSelf(pid, getTok()).then(function (me) {
      var st = STATUS[me.status] || STATUS.pending;
      el.innerHTML = '<div class="card mecard"><div class="mehead">' + U.avatar(me) + '<div><b>' + esc(me.name) + '</b>' + ' ' + trustBadge(me) + '<div class="muted">' + esc(svcNames(me.services)) + '</div><span class="badge ' + st[1] + '">' + st[0] + '</span></div></div>' +
        '<div class="pbar"><i style="width:' + (me.pct || 0) + '%"></i></div><small class="muted">اكتمال ملفك ' + (me.pct || 0) + '%</small>' +
        '<div class="btnrow mt"><a class="btn primary" href="#/p/home">لوحتي</a><a class="btn ghost" href="#/p/profile">ملفي الشخصي</a></div></div>';
    }).catch(function () { el.innerHTML = '<div class="card"><a class="btn primary" href="#/p/login">ادخل إلى حسابك</a></div>'; });
  }
  function switchRole() { store.del('role'); go('#/'); }

  /* ---------- 2) مسار طالب الخدمة ---------- */
  function viewClientLoc() {
    var gpsMsg = '';
    function render(manual) {
      page({
        title: 'موقعك', back: '#/', menu: true,
        body: demoNote() + '<div class="h2">وين أنت الآن؟</div>' +
          (manual ? '' : '<p class="muted" style="margin-bottom:16px">نحتاج موقعك لنعرض لك أقرب صنايعي ليك. نستخدمه وقت الطلب فقط.</p>') +
          (gpsMsg ? '<div class="banner">' + esc(gpsMsg) + '</div>' : '') +
          (manual
            ? '<label class="field"><span>الولاية</span><select id="st">' + stateOptions(loc && loc.state_id) + '</select></label>' +
              '<label class="field"><span>المدينة</span><select id="ct">' + cityOptions(loc && loc.state_id, loc && loc.city_id) + '</select></label>' +
              '<label class="field"><span>الحي (اختياري)</span><input id="hd" value="' + esc(loc && loc.hood || '') + '" placeholder="مثال: الثورة"></label>'
            : '<button class="btn primary" id="useGps" style="width:100%">' + SQ.I('pin', 20) + ' استخدم موقعي</button>' +
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
          store.set('loc', loc); afterLoc();
        });
      } else {
        on('manual', 'click', function () { render(true); });
        on('useGps', 'click', async function () {
          var b = document.getElementById('useGps'); b.disabled = true; b.textContent = 'جاري تحديد موقعك...';
          try {
            var g = await getGps(), n = SQ.geo.nearestCity(g.lat, g.lng);
            if (!n || n.km > 150) { gpsMsg = 'موقعك بعيد عن المدن المسجلة، اختر مدينتك يدويا'; return render(true); }
            loc = { lat: g.lat, lng: g.lng, state_id: n.state_id, city_id: n.city_id, hood: '', manual: false };
            store.set('loc', loc); afterLoc();
          } catch (e) { gpsMsg = 'ما قدرنا نحدد موقعك. اختر يدويا وسنكمل.'; render(true); }
        });
      }
    }
    render(false);
  }

  async function viewClientList(sid) {
    if (!loc) return go('#/c/loc');
    loading(svc(sid).name);
    var res;
    try { res = await db.nearby({ lat: loc.lat, lng: loc.lng, cityId: loc.city_id, service: sid }); }
    catch (e) { return page({ title: svc(sid).name, back: '#/', body: '<div class="empty"><div class="big">📶</div>' + errMsg(e) + '<div class="mt"><button class="btn primary" id="retry">إعادة المحاولة</button></div></div>' }), on('retry', 'click', route); }
    var items = res.items, head = '';
    if (res.tier === 'nearest_city') head = '<div class="banner">ما في أحد داخل نطاقك الآن. هذا أقرب زول ليك في المدينة على بعد ' + (items[0].distance_km != null ? items[0].distance_km + ' كم' : 'قريب') + '، تحب تشوفه؟</div>';
    if (res.tier === 'other_city') head = '<div class="banner">لا يوجد مقدم خدمة في مدينتك الآن. هؤلاء أقرب الموجودين في مدن أخرى، تحب تطلب منهم؟</div>';
    var body = demoNote() + head;
    if (!items.length) {
      body += '<div class="empty"><div class="big">🔎</div><p>لا يوجد ' + esc(svc(sid).name) + ' متاح في مدينتك الآن.</p><p class="note">جرب خدمة أخرى أو ارجع لاحقا.</p></div>';
    } else {
      body += items.map(function (p) { return pCard(p); }).join('');
    }
    page({ title: svc(sid).name, back: '#/', menu: true, body: body });
    bindMenu();
    Array.prototype.forEach.call(document.querySelectorAll('.pcard-wrap'), function (c) {
      c.addEventListener('click', function () { go('#/c/p/' + c.getAttribute('data-id') + '/' + sid); });
    });
  }
  function priceTxt(p) {
    var lo = Number(p.price) || 0, hi = Number(p.price_max) || 0, cu = ' ' + SQ.COUNTRY.currency;
    if (lo <= 0 && hi <= 0) return '';
    if (hi <= lo) return lo.toLocaleString('en') + cu;
    return 'من ' + lo.toLocaleString('en') + ' إلى ' + hi.toLocaleString('en') + cu;
  }
  function ring(p, big) {
    if (p.reply_pct == null) return '';
    var v = p.reply_pct, col = v >= 80 ? '#1a7f4b' : v >= 50 ? '#b45309' : '#b42318';
    return '<span class="ring' + (big ? ' big' : '') + '" title="سرعة الرد" style="--v:' + v + ';--c:' + col + '"><b>' + v + '%</b></span>';
  }
  function pCard(p) {
    var dist = p.distance_km != null ? 'حوالي ' + (p.distance_km < 1 ? 'أقل من 1' : p.distance_km) + ' كم' : '';
    var em = p.distance_km != null ? SQ.geo.eta(p.distance_km) : null;
    var eta = em != null ? 'يصل في حوالي ' + em + (em <= 10 ? ' دقائق' : ' دقيقة') : '';
    return '<div class="card click pcard-wrap" data-id="' + p.id + '"><div class="pcard">' + U.avatar(p) + '' +
      '<div class="pinfo"><div class="pname">' + esc(p.name) + ' ' + trustBadge(p) + (p.demo ? ' <span class="demo">تجريبي</span>' : '') + '</div>' +
      '<div class="psvc">' + esc(svcNames(p.services)) + '</div>' +
      '<div class="meta">' +
      (dist ? '<span class="mi">' + SQ.I('pin', 15) + ' ' + dist + '</span>' : '') + (eta ? '<span class="mi">' + SQ.I('clock', 15) + ' ' + eta + '</span>' : '') + (p.age ? '<span class="mi">' + SQ.I('user', 15) + ' ' + p.age + ' سنة</span>' : '') +
      '<span>' + (p.rating != null ? '<span class="star">★ ' + p.rating + '</span> (' + p.rating_n + ')' : '<span class="new">جديد</span>') + '</span>' +
      (priceTxt(p) ? '<span>' + esc(priceTxt(p)) + '</span>' : '') +
      '<span><i class="dot' + (p.available ? '' : ' off') + '"></i>' + (p.available ? 'متاح الآن' : 'مشغول') + '</span>' + ring(p) +
      '</div></div></div></div>';
  }

  async function viewByUsername(u) {
    loading('ملف الصنايعي');
    var id = null;
    try { id = await db.providerByUsername(u); } catch (e) {}
    if (!id) { toast('لم نجد صنايعيا بهذا الاسم'); return go('#/'); }
    return viewClientProvider(id, 'other');
  }
  function shareUrl(p) { return p.username ? location.origin + '/' + p.username : location.href.split('#')[0] + '#/c/p/' + p.id; }

  async function viewClientProvider(id, sid) {
    loading('ملف الصنايعي');
    var p;
    try { p = await db.getProvider(id, loc); } catch (e) { toast(errMsg(e)); return go('#/c/list/' + sid); }
    if (!p) { toast('هذا الملف غير متاح'); return go('#/c/list/' + sid); }
    var dist = p.distance_km != null ? 'حوالي ' + p.distance_km + ' كم' : '—';
    page({
      title: p.name, back: '#/c/list/' + sid,
      body: demoNote() +
        '<div class="phead">' + U.avatar(p) + '<div class="h2" style="margin:0">' + esc(p.name) + ' ' + trustBadge(p) + '</div><div class="muted">' + esc(svcNames(p.services)) + '</div></div>' +
        '<div class="stats"><div class="stat"><b>' + (p.rating != null ? '★ ' + p.rating : 'جديد') + '</b><small>' + p.rating_n + ' تقييم</small></div>' +
        '<div class="stat"><b>' + p.ok + ' - ' + p.fail + '</b><small>ناجحة - فاشلة</small></div>' +
        '<div class="stat"><b>' + p.experience + '</b><small>سنة خبرة</small></div></div>' + (p.age ? '<div class="card"><div class="kv"><span>العمر</span><span>' + p.age + ' سنة</span></div></div>' : '') +
        '<div class="card">' +
        '<div class="kv"><span>الحالة</span><span><i class="dot' + (p.available ? '' : ' off') + '"></i>' + (p.available ? 'متاح الآن' : 'مشغول') + '</span></div>' +
        '<div class="kv"><span>المسافة</span><span>' + dist + '</span></div>' +
        (priceTxt(p) ? '<div class="kv"><span>السعر</span><span>' + esc(priceTxt(p)) + '</span></div><div class="note" style="margin:2px 0 6px">السعر النهائي يُتفق عليه مع الصنايعي بعد معرفة حجم الخدمة، ويكون ضمن هذا النطاق.</div>' : '') +
        '<div class="kv"><span>المنطقة</span><span>' + esc((p.hood ? p.hood + '، ' : '') + SQ.cityName(p.city_id)) + '</span></div>' +
        '<div class="kv"><span>أوقات العمل</span><span>من ' + esc(p.from || '--') + ' إلى ' + esc(p.to || '--') + '</span></div></div>' +
        '<div class="card">' + (p.reply_pct != null ? ring(p, true) + ' <b>سرعة الرد</b><div class="note" style="margin:4px 0 0">ردّ خلال 15 دقيقة على ' + p.reply_pct + '% من الطلبات</div>' : '<span class="muted">سرعة الرد تظهر بعد 3 طلبات على الأقل</span>') + '</div>' +
        (p.bio ? '<div class="card"><b>عن الصنايعي</b><p style="margin-top:6px">' + esc(p.bio) + '</p></div>' : '') +
        '<div class="card"><b>آخر التقييمات</b>' + (p.reviews && p.reviews.length ? p.reviews.map(function (r) {
          return '<div class="rev"><span class="star">' + '★'.repeat(r.stars || 0) + '</span> <small class="muted">' + (r.success ? 'شغلانة ناجحة' : 'شغلانة فاشلة') + ' · ' + timeAgo(r.ts) + '</small>' + (r.comment ? '<div>' + esc(r.comment) + '</div>' : '') + '</div>';
        }).join('') : '<p class="muted">لا توجد تقييمات بعد</p>') + '</div>' +
        '<div class="center"><button class="linkbtn" id="rep">🚩 إبلاغ عن هذا الصنايعي</button></div>',
      foot: '<button class="btn primary" id="reqsvc"' + (p.available ? '' : ' disabled') + '>' + (p.available ? 'طلب الخدمة' : 'غير متاح الآن') + '</button>'
    });
    async function sendReq(service) {
      try { await db.createRequest({ provider_id: p.id, anon_id: anon, service: service, city_id: loc ? loc.city_id : p.city_id }); }
      catch (e) { return toast(errMsg(e)); }
      modal('<h3>تم إرسال طلبك</h3><p class="note">سيظهر لك رقم الصنايعي وواتساب في «طلباتي» بمجرد أن يضغط «قبول». يمكنك طلب الخدمة من أكثر من صنايعي، ومن يرد أولا تبدأ معه.</p><div class="row2 mt"><button class="btn ghost" id="mx">البقاء هنا</button><button class="btn primary" id="mgo">طلباتي</button></div>');
      on('mx', 'click', closeModal);
      on('mgo', 'click', function () { closeModal(); go('#/c/requests'); });
    }
    on('reqsvc', 'click', function () {
      var list = (p.services || []).map(String);
      if (sid && list.indexOf(String(sid)) >= 0) return sendReq(sid);
      if (list.length === 1) return sendReq(list[0]);
      modal('<h3>ما الخدمة التي تحتاجها؟</h3><div class="chips" id="sv">' + list.map(function (s) { return '<button class="chip" data-s="' + esc(s) + '">' + esc(svc(s).name) + '</button>'; }).join('') + '</div>');
      Array.prototype.forEach.call(document.querySelectorAll('#sv .chip'), function (b) { b.addEventListener('click', function () { closeModal(); sendReq(b.getAttribute('data-s')); }); });
    });
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
    try { list = await db.myRequests(anon); } catch (e) { toast(errMsg(e)); return go('#/'); }
    var st = { 'new': 'بانتظار رأيك', done: 'ناجحة', failed: 'فاشلة', not_agreed: 'ما اتفقنا' };
    var ac = { pending: '⏳ بانتظار رد الصنايعي', declined: 'اعتذر الصنايعي', expired: 'انتهت المهلة دون رد', taken: 'بدأت مع صنايعي آخر', cancelled: 'ألغيت الطلب' };
    page({
      title: 'طلباتي', back: '#/',
      body: list.length ? list.map(function (r) {
        var a = r.accept || 'accepted', acc = a === 'accepted';
        var line = acc ? (r.status === 'new' ? '<span class="vtag">✓ قبل طلبك</span>' : '<span>' + st[r.status] + '</span>') : '<span>' + ac[a] + '</span>';
        var d = acc && r.status === 'new' && r.phone ? SQ.util.digits(r.whatsapp || r.phone) : '';
        return '<div class="card"><div class="pname">' + esc(r.provider_name) + '</div><div class="psvc">' + esc(svc(r.service).name) + ' · ' + timeAgo(r.ts) + '</div>' +
          '<div class="meta">' + line + '</div>' +
          (d ? '<div class="row2 mt"><a class="btn primary" href="tel:' + esc(r.phone) + '">اتصال</a><a class="btn wa" target="_blank" rel="noopener" href="https://wa.me/' + d + '?text=' + encodeURIComponent('السلام عليكم، قبلت طلبي في ' + C.appName + ' لخدمة ' + svc(r.service).name) + '">واتساب</a></div>' : '') +
          (acc && r.status === 'new' ? '<button class="btn ghost small mt rate" data-id="' + r.id + '" style="width:100%">أنهيت الخدمة؟ قيّم (اختياري)</button>' : '') +
          (a === 'pending' ? '<button class="btn ghost small mt cancelq" data-id="' + r.id + '" style="width:100%">إلغاء الطلب</button>' : '') + '</div>';
      }).join('') : '<div class="empty"><div class="big">📋</div>لا توجد طلبات بعد. افتح صنايعي واضغط «طلب الخدمة»</div>'
    });
    Array.prototype.forEach.call(document.querySelectorAll('.cancelq'), function (b) {
      b.addEventListener('click', function () { db.cancelRequest(b.getAttribute('data-id'), anon).then(viewMyRequests).catch(function (e) { toast(errMsg(e)); }); });
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
        body += '<div class="center"><b>كم نجمة؟</b> <small class="muted">(اختياري)</small></div><div class="stars" id="st">' + [1, 2, 3, 4, 5].map(function (n) { return '<button data-n="' + n + '" class="' + (n <= stars ? 'on' : '') + '">★</button>'; }).join('') + '</div>' +
          '<label class="field"><span>تعليق (اختياري)</span><textarea id="cm" maxlength="300" placeholder="اكتب رأيك بإيجاز"></textarea></label>';
      }
      page({ title: 'التقييم', back: '#/c/requests', body: body, foot: '<button class="btn primary" id="send"' + (!out ? ' disabled' : '') + '>إرسال</button>' });
      Array.prototype.forEach.call(document.querySelectorAll('#oc .chip'), function (c) { c.addEventListener('click', function () { out = c.getAttribute('data-o'); render(); }); });
      Array.prototype.forEach.call(document.querySelectorAll('#st button'), function (b) { b.addEventListener('click', function () { var n = +b.getAttribute('data-n'); stars = stars === n ? 0 : n; var t = (document.getElementById('cm') || {}).value; render(); if (t) document.getElementById('cm').value = t; }); });
      on('send', 'click', async function () {
        try { await db.addReview(id, anon, { outcome: out, stars: stars, comment: (document.getElementById('cm') || {}).value || '' }); toast('شكرا على تقييمك'); go('#/c/requests'); }
        catch (e) { toast(e.message === 'already' ? 'تم تقييم هذا الطلب من قبل' : errMsg(e)); }
      });
    }
    render();
  }

  function bindMenu() {
    on('menuBtn', 'click', openDrawer);
  }
  function openDrawer() {
    var old = document.getElementById('drawer'); if (old) old.remove();
    var isP = !!getPid();
    var sup = (SQ.cfg && SQ.cfg.support_whatsapp) || C.supportWhatsapp;
    var supUrl = sup ? 'https://wa.me/' + String(sup).replace(/\D/g, '') : '';
    function item(id, ic, label, extra) { return '<button class="ditem" id="' + id + '"' + (extra || '') + '><i>' + SQ.I(ic, 20) + '</i><span>' + label + '</span></button>'; }
    function acc(key, ic, title, body, open) { return '<div class="acc' + (open ? ' open' : '') + '" data-k="' + key + '"><button class="acch" aria-expanded="' + (!!open) + '"><i>' + SQ.I(ic, 20) + '</i><span>' + title + '</span><b class="chev"></b></button><div class="accb"><div>' + body + '</div></div></div>'; }
    var steps = '<ol class="dsteps"><li>حدد موقعك أو اختر مدينتك.</li><li>اختر الخدمة التي تحتاجها.</li><li>سنعرض لك الأقرب والأعلى تقييما أولا.</li><li>اتصل أو راسل عبر واتساب، ثم قيّم الصنايعي بعد انتهاء العمل.</li></ol>';
    var html = '<div class="scrim" id="dScrim"></div><aside class="dpanel" role="dialog" aria-label="القائمة">' +
      '<div class="dhead"><span class="dlogo">' + SVG_LOGO + '</span><div><b>صنايعي قريب</b><small>خدمتك لحدي بيتك</small></div><button class="dclose" id="dClose" aria-label="إغلاق">' + SQ.I('plus', 20) + '</button></div>' +
      '<div class="dbody">' +
        (isP ? '' : '<div class="dauth"><button class="btn primary" id="dLogin">تسجيل الدخول</button><button class="btn ghost" id="dJoin">إنشاء حساب صنايعي</button><small>الدخول والتسجيل لمقدمي الخدمة. طلب الخدمة متاح للجميع بلا حساب.</small></div>') +
        item('dHome', 'home', 'الرئيسية') + item('dReq', 'clock', 'طلباتي') +
        (isP ? acc('acct', 'user', 'حسابي كصنايعي', item('dProf', 'user', 'ملفي الشخصي') + item('dPHome', 'wrench', 'لوحة الصنايعي') + item('dOut', 'out', 'تسجيل الخروج', ' data-danger="1"'), false) : ''
          ) +
        acc('help', 'chat', 'المساعدة', (supUrl ? '<a class="ditem" id="dSup" target="_blank" rel="noopener" href="' + supUrl + '"><i>' + SQ.I('chat', 20) + '</i><span>تواصل مع الدعم</span></a>' : '') + '<div class="dh">كيف يعمل التطبيق؟</div>' + steps, false) +
        acc('about', 'shield', 'عن التطبيق', item('dShare', 'share', 'مشاركة التطبيق') + '<a class="ditem" href="privacy-policy.html" target="_blank" rel="noopener"><i>' + SQ.I('lock', 20) + '</i><span>سياسة الخصوصية</span></a><p class="dnote">الإصدار 1.0</p>', false) +
        (SQ.demo ? acc('dev', 'edit', 'أدوات التجربة', item('dReset', 'check', 'إعادة ضبط البيانات التجريبية'), false) : '') +
      '</div></aside>';
    var d = document.createElement('div'); d.id = 'drawer'; d.innerHTML = html; document.body.appendChild(d);
    requestAnimationFrame(function () { requestAnimationFrame(function () { d.classList.add('show'); }); });
    function close(cb) { d.classList.remove('show'); document.removeEventListener('keydown', esc); setTimeout(function () { d.remove(); if (cb) cb(); }, 260); }
    function esc(e) { if (e.key === 'Escape') close(); }
    document.addEventListener('keydown', esc);
    function q(id, fn) { var el = d.querySelector('#' + id); if (el) el.addEventListener('click', fn); }
    q('dScrim', function () { close(); }); q('dClose', function () { close(); });
    Array.prototype.forEach.call(d.querySelectorAll('.acch'), function (b) { b.addEventListener('click', function () { var p = b.parentNode, o = !p.classList.contains('open'); Array.prototype.forEach.call(d.querySelectorAll('.acc.open'), function (x) { x.classList.remove('open'); x.firstChild.setAttribute('aria-expanded', 'false'); }); if (o) { p.classList.add('open'); b.setAttribute('aria-expanded', 'true'); } }); });
    q('dHome', function () { close(function () { go('#/'); }); });
    q('dReq', function () { close(function () { go('#/c/requests'); }); });
    q('dProf', function () { close(function () { go('#/p/profile'); }); });
    q('dJoin', function () { close(function () { go('#/p/1'); }); });
    q('dLogin', function () { close(function () { go('#/p/login'); }); });
    q('dPHome', function () { close(function () { go('#/p/home'); }); });
    q('dOut', function () { close(confirmLogout); });
    q('dSup', function () { setTimeout(function () { close(); }, 100); });
    q('dShare', function () { var u = location.origin + location.pathname, t = 'صنايعي قريب: اعثر على أقرب صنايعي لك'; if (navigator.share) navigator.share({ title: 'صنايعي قريب', text: t, url: u }).catch(function () {}); else { try { navigator.clipboard.writeText(u); } catch (e) {} toast('تم نسخ رابط التطبيق'); } });
    q('dReset', function () { close(function () { db.resetDemo(); ['pid', 'ptoken', 'loc'].forEach(store.del); loc = null; toast('تمت إعادة الضبط'); go('#/'); }); });
  }

  /* ---------- 3) مسار مقدم الخدمة ---------- */
  var reg = store.get('reg', { services: [], radius: '10', from: '08:00', to: '20:00', waSame: true });
  if (!reg.services) reg.services = [];
  var regPw = ''; // كلمة السر تبقى في الذاكرة فقط ولا تُحفظ في الجهاز
  function regSave() { store.set('reg', reg); }
  function getPid() { return store.get('pid', null); }
  function getTok() { return store.get('ptoken', null); }
  function signIn(id, token) { store.set('pid', id); store.set('ptoken', token); store.set('role', 'provider'); store.set('side', 'prov'); }
  function signOut() { store.del('pid'); store.del('ptoken'); }
  function sessionExpired() { signOut(); store.set('side', 'client'); toast('انتهت جلستك، ادخل من جديد'); go('#/p/login'); }
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
        U.birthHtml('bd', reg.birth_date) +
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
      var be = U.birthErr(U.birthVal('bd'), true); if (be) return toast(be);
      if (!ph) return toast('رقم الهاتف غير صحيح');
      if (!wa) return toast('رقم الواتساب غير صحيح');
      if (pw.length < 6) return toast('كلمة السر قصيرة (6 أحرف أو أرقام على الأقل)');
      reg.name = nm; reg.birth_date = U.birthVal('bd'); reg.phone = ph; reg.whatsapp = wa; reg.wa = document.getElementById('wa').value; reg.waSame = same; regPw = pw; regSave(); go('#/p/2');
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
        '<div class="row2"><label class="field"><span>أدنى سعر (' + esc(SQ.COUNTRY.currency) + ')</span><input id="pr" type="number" inputmode="numeric" min="0" value="' + esc(reg.price == null ? '' : reg.price) + '"></label><label class="field"><span>أعلى سعر</span><input id="pm" type="number" inputmode="numeric" min="0" value="' + esc(reg.price_max == null ? '' : reg.price_max) + '"></label></div><div class="note">السعر النهائي يُحدَّد بالاتفاق مع الزبون بعد معرفة حجم الخدمة، ويقع بين الأدنى والأعلى.</div>' +
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
      var pm = document.getElementById('pm').value;
      if (pr === '' || +pr <= 0) return toast('اكتب أدنى سعر');
      if (pm === '' || +pm < +pr) return toast('أعلى سعر يجب ألا يقل عن أدنى سعر');
      if (bio.length < 5) return toast('اكتب وصفا قصيرا لمهارتك');
      reg.experience = +ex; reg.price = +pr; reg.price_max = +pm; reg.bio = bio; reg.from = document.getElementById('fr').value || '08:00'; reg.to = document.getElementById('to').value || '20:00';
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
          ['النطاق', reg.radius === 'all' ? 'كل المدينة' : reg.radius + ' كم'], ['الخبرة', reg.experience + ' سنة'], ['السعر', priceTxt(reg)], ['أوقات العمل', 'من ' + reg.from + ' إلى ' + reg.to], ['الوصف', reg.bio]]
          .map(function (r) { return '<div class="kv"><span>' + r[0] + '</span><span style="text-align:left">' + esc(r[1]) + '</span></div>'; }).join('') + '</div>' +
        '<p class="note">بعد الإرسال يراجع فريق صنايعي قريب طلبك ويتواصل معك على واتساب لتأكيد بياناتك خلال 24 ساعة. تدخل بعدها بالهاتف وكلمة السر.</p>',
      foot: '<button class="btn primary" id="send">أرسل للمراجعة</button>'
    });
    bindMenu();
    on('send', 'click', async function () {
      var b = document.getElementById('send'); b.disabled = true; b.textContent = 'جاري الإرسال...';
      var city = SQ.findCity(reg.city_id).city;
      try {
        var r = await db.registerProvider({
          name: reg.name, phone: reg.phone, whatsapp: reg.whatsapp, password: regPw, state_id: reg.state_id, city_id: reg.city_id, hood: reg.hood,
          lat: reg.lat || city.lat, lng: reg.lng || city.lng, radius: reg.radius, services: reg.services, experience: reg.experience, price: reg.price, price_max: reg.price_max,
          bio: reg.bio, from: reg.from, to: reg.to, photo: reg.photo || '', birth_date: reg.birth_date
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
      var msg = { pending: ['⏳', 'طلبك قيد المراجعة', 'سيصلك على واتساب رسالة من فريق صنايعي قريب لتأكيد بياناتك. رد عليها برقم طلبك: <b class="ltr" style="font-size:22px">' + String(me.id).replace(/-/g, '').slice(0, 4).toUpperCase() + '</b>'], rejected: ['✖', 'لم يتم قبول طلبك', 'تواصل مع الدعم لمعرفة السبب.'], suspended: ['⛔', 'حسابك موقوف مؤقتا', 'تواصل مع الدعم لمراجعة حسابك.'] }[me.status] || ['⏳', 'قيد المراجعة', ''];
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
    var bdBanner = !me.birth_date ? '<div class="banner">🎂 أضف تاريخ ميلادك الحقيقي. التطبيق لمن هم 18 سنة فأكثر، وسيُطابَق مع وثيقتك عند التوثيق.<br><a class="btn primary" href="#/p/edit">إضافة تاريخ الميلاد</a></div>' : '';
    var flag = !!me.flag, shown = flag && me.available;
    var hoursNote = flag && !me.in_hours
      ? '<div class="banner">⏰ أنت "متاح" لكن الوقت الآن خارج أوقات عملك (من ' + esc(me.from) + ' إلى ' + esc(me.to) + ')، فلن تظهر للزبائن حتى يحين وقتك.<br><button class="btn primary" id="hrs">تعديل أوقات العمل</button></div>'
      : '';
    page({
      title: 'الرئيسية', menu: true, tab: 'home',
      body: demoNote() + pwBanner + bdBanner + hoursNote + '<button class="switch' + (shown ? ' on' : '') + '" id="sw">' + (shown ? '🟢 متاح الآن' : (flag ? '🟡 متاح (خارج أوقات عملك)' : '⚪ مشغول')) + '<small>' + (flag ? 'اضغط لو انشغلت لتختفي عن الزبائن' : 'مخفي عن الزبائن. اضغط لتظهر') + '</small></button>' +
        '<div class="stats mt"><div class="stat"><b>' + me.requests_week + '</b><small>اتصالات هذا الأسبوع</small></div>' +
        '<div class="stat"><b>' + (me.rating != null ? '★ ' + me.rating : 'جديد') + '</b><small>' + me.rating_n + ' تقييم</small></div>' +
        '<div class="stat"><b>' + me.ok + ' - ' + me.fail + '</b><small>ناجحة - فاشلة</small></div></div>' +
        '<div class="card"><div class="kv"><span>الخدمات</span><span>' + esc(svcNames(me.services)) + '</span></div><div class="kv"><span>المنطقة</span><span>' + esc((me.hood ? me.hood + '، ' : '') + SQ.cityName(me.city_id)) + '</span></div><div class="kv"><span>أوقات العمل</span><span>' + esc(me.from + ' - ' + me.to) + ' <button class="linkbtn" id="hrs2">تعديل</button></span></div></div>' +
        tierProgress(me) +
        '<div class="h2 mt">طلبات العملاء</div><div id="preqs"><div class="spin">جاري التحميل...</div></div>' +
        '<p class="note">يتحول وضعك تلقائيا إلى "مشغول" لو ما فتحت التطبيق ' + C.availableTimeoutHours + ' ساعات، أو خارج أوقات عملك.</p>',
      foot: '<button class="btn wa" id="share">📤 شارك رابط ملفي</button>'
    });
    bindMenu(); loadProvReqs(pid, tk);
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
      var url = shareUrl(me);
      var txt = 'أنا ' + me.name + '، ' + svcNames(me.services) + '. تقدر تتواصل معي من تطبيق ' + C.appName + ': ' + url;
      if (navigator.share) navigator.share({ text: txt }).catch(function () {});
      else window.open('https://wa.me/?text=' + encodeURIComponent(txt), '_blank');
    });
  }

  function tierProgress(me) {
    var j = me.jobs || 0, t = SQ.tierId(me), n = SQ.nextTier(j), cfg = SQ.cfg || {};
    var com = (+cfg.commission_pct > 0 || +cfg.commission_fixed > 0)
      ? '<p class="note" style="margin:8px 0 0">عمولة التطبيق على كل خدمة مؤكدة: ' + [(+cfg.commission_fixed > 0 ? Number(cfg.commission_fixed).toLocaleString('en') + ' ' + SQ.COUNTRY.currency : ''), (+cfg.commission_pct > 0 ? cfg.commission_pct + '% من المبلغ' : '')].filter(Boolean).join(' + ') + '.</p>' : '';
    return '<div class="card tierbox"><div class="kv"><span>شارة الإنجاز</span><span>' + (t ? tierTag(me, true) : '<span class="muted">لم تبدأ بعد</span>') + '</span></div>' +
      (n ? '<div class="pbar"><i style="width:' + Math.min(100, Math.round(j / n.min * 100)) + '%"></i></div><p class="note" style="margin:6px 0 0">' + j + ' من ' + n.min + ' أعمال مؤكدة للوصول إلى شارة «' + n.name + '». كل عمل يؤكده عميل مختلف يُحسب.</p>' : '<p class="note" style="margin:6px 0 0">وصلت لأعلى شارة. شكرا لك.</p>') + com + '</div>';
  }

  /* طلبات العملاء: تأكيد الصنايعي لإتمام الخدمة */
  async function loadProvReqs(pid, tk) {
    var el = document.getElementById('preqs'); if (!el) return;
    var list;
    try { list = await db.providerRequests(pid, tk); } catch (e) { el.innerHTML = '<p class="note">تعذر تحميل الطلبات.</p>'; return; }
    el = document.getElementById('preqs'); if (!el) return;
    if (!list.length) { el.innerHTML = '<div class="card"><p class="note" style="margin:0">لا توجد طلبات بعد. تظهر هنا كل مرة يطلب عميل خدمتك.</p></div>'; return; }
    var cl = { new: 'العميل لم يرد بعد', done: 'العميل قال: تمت الخدمة', failed: 'العميل قال: لم تنجح', not_agreed: 'العميل قال: لم نتفق' };
    el.innerHTML = list.map(function (r) {
      var s = svc(r.service), ac = r.accept || 'accepted';
      if (ac === 'pending') {
        return '<div class="card preq" style="background:#fff8e1"><div class="pname">' + esc(s.icon + ' ' + s.name) + '</div><div class="meta"><span class="muted">' + timeAgo(r.ts) + '</span></div>' +
          '<div class="note" style="margin:6px 0">عميل يطلب هذه الخدمة. اقبل ليظهر له رقمك (تنتهي المهلة بعد ساعتين).</div>' +
          '<div class="row2 mt"><button class="btn primary" data-rs="1" data-id="' + r.id + '">قبول</button><button class="btn ghost" data-rs="0" data-id="' + r.id + '">اعتذار</button></div></div>';
      }
      if (ac !== 'accepted') {
        var t = { declined: 'اعتذرت', expired: 'انتهت المهلة دون رد', taken: 'بدأ العميل مع صنايعي آخر' }[ac] || ac;
        return '<div class="card preq"><div class="pname">' + esc(s.icon + ' ' + s.name) + '</div><div class="meta"><span class="muted">' + t + ' · ' + timeAgo(r.ts) + '</span></div></div>';
      }
      var mine = r.confirm === 'done' ? '<span class="vtag">✓ أكدت التنفيذ' + (r.amount ? ' · ' + Number(r.amount).toLocaleString('en') + ' جنيه' : '') + '</span>' : r.confirm === 'not_done' ? '<span class="muted">أكدت: لم تتم</span>' : '';
      var both = r.confirm === 'done' && r.client === 'done' ? '<span class="vtag">✓ مؤكدة من الطرفين</span>' : '';
      return '<div class="card preq"><div class="pname">' + esc(s.icon + ' ' + s.name) + '</div><div class="meta"><span class="muted">' + timeAgo(r.ts) + '</span></div>' +
        '<div class="note" style="margin:6px 0">' + cl[r.client] + '</div>' + both + mine +
        '<div class="row2 mt"><button class="btn primary" data-pc="done" data-id="' + r.id + '">تمت الخدمة</button><button class="btn ghost" data-pc="not_done" data-id="' + r.id + '">لم تتم</button></div></div>';
    }).join('');
    el.onclick = function (e) {
      var rb = e.target.closest('[data-rs]');
      if (rb) {
        var ok = rb.getAttribute('data-rs') === '1';
        db.respondRequest(pid, tk, rb.getAttribute('data-id'), ok).then(function (res) { toast(res && res.ok === false ? 'لم يعد الطلب متاحا' : (ok ? 'تم القبول. ظهر رقمك للزبون' : 'تم الاعتذار')); loadProvReqs(pid, tk); }).catch(function (x) { toast(errMsg(x)); });
        return;
      }
      var b = e.target.closest('[data-pc]'); if (!b) return;
      var id = b.getAttribute('data-id'), done = b.getAttribute('data-pc') === 'done';
      if (!done) { db.providerConfirm(pid, tk, id, false, null).then(function () { toast('تم التسجيل'); loadProvReqs(pid, tk); }).catch(function (x) { toast(errMsg(x)); }); return; }
      modal('<h3>تأكيد تنفيذ الخدمة</h3><label class="field"><span>المبلغ المتفق عليه بالجنيه (اختياري)</span><input id="pcAmt" class="ltr" inputmode="numeric" placeholder="0"></label>' +
        '<p class="note">يُستخدم المبلغ لتقارير فريق التطبيق فقط ولا يظهر للعملاء.</p><div class="row2 mt"><button class="btn ghost" id="pcX">إلغاء</button><button class="btn primary" id="pcOk">تأكيد</button></div>');
      on('pcX', 'click', closeModal);
      on('pcOk', 'click', async function () {
        var v = String(document.getElementById('pcAmt').value || '').replace(/[٠-٩]/g, function (c) { return '٠١٢٣٤٥٦٧٨٩'.indexOf(c); }).replace(/[^\d]/g, '');
        try { await db.providerConfirm(pid, tk, id, true, v ? +v : null); closeModal(); toast('تم تأكيد الطلب'); loadProvReqs(pid, tk); } catch (x) { toast(errMsg(x)); }
      });
    };
  }

  /* الملف الشخصي */
  /* اكتمال الملف: الملفات المكتملة والنشطة تظهر أولا للزبائن */
  function completeCard(me) {
    var todo = [];
    if (!me.photo) todo.push('أضف صورة شخصية (+30%)');
    if (!me.bio || me.bio.trim().length < 20) todo.push('اكتب وصفا لمهارتك بـ 20 حرفا فأكثر (+25%)');
    if (!me.hood) todo.push('اكتب اسم حيك (+15%)');
    if (!me.price || (me.price_max || 0) < me.price) todo.push('حدد أدنى وأعلى سعر (+10%)');
    if (!me.experience) todo.push('اكتب سنوات خبرتك (+10%)');
    if (!me.has_password) todo.push('أضف كلمة سر (+10%)');
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
        '<div class="kv"><span>اسم المستخدم</span><span class="ltr">@' + esc(me.username || '') + (me.username_changed ? '' : ' <button class="linkbtn" id="unm">تغيير</button>') + '</span></div>' +
        '<div class="kv"><span>الهاتف</span><span class="ltr">' + esc(me.phone) + '</span></div>' +
        '<div class="kv"><span>الواتساب</span><span class="ltr">' + esc(me.whatsapp) + '</span></div>' +
        '<div class="kv"><span>المنطقة</span><span>' + esc((me.hood ? me.hood + '، ' : '') + SQ.cityName(me.city_id) + ' - ' + SQ.stateName(me.state_id)) + '</span></div>' +
        '<div class="kv"><span>نطاق التغطية</span><span>' + (me.radius === 'all' ? 'كل المدينة' : esc(me.radius) + ' كم') + '</span></div>' +
        '<div class="kv"><span>السعر</span><span>' + esc(priceTxt(me)) + '</span></div>' +
        '<div class="kv"><span>أوقات العمل</span><span>من ' + esc(me.from) + ' إلى ' + esc(me.to) + '</span></div>' +
        (me.bio ? '<div class="kv"><span>الوصف</span><span style="text-align:left">' + esc(me.bio) + '</span></div>' : '') +
        '<p class="note">لتغيير رقم الهاتف تواصل مع الدعم. رابط ملفك: <span class="ltr">' + esc(shareUrl(me)) + '</span>' + (me.username_changed ? '<br>اسم المستخدم لا يُغيَّر إلا مرة واحدة، وللتعديل تواصل مع الدعم.' : '<br>يمكنك تغيير اسم المستخدم مرة واحدة فقط.') + '</p></div>' +
        (me.status === 'approved' ? '<div class="card"><b>آخر التقييمات</b>' + (revs.length ? revs.map(function (r) {
          return '<div class="rev"><span class="star">' + '★'.repeat(r.stars || 0) + '</span> <small class="muted">' + (r.success ? 'شغلانة ناجحة' : 'شغلانة فاشلة') + ' · ' + timeAgo(r.ts) + '</small>' + (r.comment ? '<div>' + esc(r.comment) + '</div>' : '') + '</div>';
        }).join('') : '<p class="muted">لا توجد تقييمات بعد</p>') + '</div>' : '') +
        '<div class="card"><b>الحساب</b><div class="acts">' +
        '<button class="btn ghost small" id="pw">🔐 ' + (me.has_password ? 'تغيير كلمة السر' : 'إضافة كلمة سر') + '</button>' +
        '<button class="btn ghost small" id="out">🚪 تسجيل الخروج</button></div>' +
        '<div class="center"><button class="linkbtn dangertxt" id="del">🗑 حذف حسابي نهائيا</button></div></div>'
    });
    bindMenu();
    on('edit', 'click', function () { go('#/p/edit'); });
    on('unm', 'click', function () {
      modal('<h3>اسم المستخدم</h3><p class="note">يُستخدم في رابط ملفك للمشاركة. <b>يمكنك تغييره مرة واحدة فقط</b>، وبعدها لا يغيّره إلا فريق الدعم.</p>' +
        '<label class="field"><span>الاسم الجديد (حروف إنجليزية صغيرة وأرقام و _)</span><input id="unv" class="ltr" maxlength="20" autocapitalize="none" autocomplete="off" value="' + esc(me.username || '') + '"></label>' +
        '<div class="row2 mt"><button class="btn ghost" id="unx">إلغاء</button><button class="btn primary" id="unk">حفظ</button></div>');
      on('unx', 'click', closeModal);
      on('unk', 'click', async function () {
        var v = document.getElementById('unv').value.trim().toLowerCase();
        if (!/^[a-z][a-z0-9_]{2,19}$/.test(v)) return toast(errMsg(new Error('invalid_username')));
        try { await db.setUsername(pid, tk, v); closeModal(); toast('تم حفظ اسم المستخدم'); route(); } catch (e) { toast(errMsg(e)); }
      });
    });
    on('pw', 'click', function () { openPwModal(me); });
    on('out', 'click', confirmLogout);
    on('del', 'click', function () {
      modal('<h3>حذف الحساب</h3><p>سيتم حذف حسابك نهائيا ولا يمكن التراجع. اكتب كلمة السر للتأكيد. (إن كان بريدك موثّقا فالحذف يتم من تطبيق الجوال برمز يصل لبريدك).</p><input class="inp" id="dpw" type="password" placeholder="كلمة السر"><div class="row2 mt"><button class="btn ghost" id="dn">إلغاء</button><button class="btn danger" id="dy">نعم، احذف</button></div>');
      on('dn', 'click', closeModal);
      on('dy', 'click', async function () {
        try {
          var r = await db.deleteProvider(pid, tk, document.getElementById('dpw').value);
          if (r && r.ok) { closeModal(); signOut(); toast('تم حذف حسابك'); go('#/p/start'); }
          else toast(r && r.error === 'wrong_password' ? 'كلمة السر غير صحيحة' : r && r.error === 'locked' ? 'محاولات كثيرة، حاول بعد 15 دقيقة' : 'لحذف الحساب استخدم تطبيق الجوال (يتطلب رمز البريد)');
        } catch (e) { toast(errMsg(e)); }
      });
    });
  }

  function confirmLogout() {
    modal('<h3>تسجيل الخروج</h3><p>هل تريد تسجيل الخروج؟ تدخل مرة ثانية برقم هاتفك وكلمة السر.</p><div class="row2 mt"><button class="btn ghost" id="lc">إلغاء</button><button class="btn primary" id="ly">خروج</button></div>');
    on('lc', 'click', closeModal);
    on('ly', 'click', function () { closeModal(); signOut(); store.set('side', 'client'); toast('تم تسجيل الخروج'); go('#/'); });
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
      body: U.photoHtml('pe') + '<label class="field"><span>الاسم الكامل</span><input id="nm" value="' + esc(me.name) + '"></label>' + U.birthHtml('bd', me.birth_date) +
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
        '<label class="field"><span>أدنى سعر</span><input id="pr" type="number" inputmode="numeric" min="0" value="' + esc(me.price) + '"></label></div>' +
        '<label class="field"><span>أعلى سعر</span><input id="pm" type="number" inputmode="numeric" min="0" value="' + esc(me.price_max || me.price) + '"><small>السعر النهائي يُتفق عليه مع الزبون بعد معرفة حجم الخدمة، ويقع بين الأدنى والأعلى.</small></label>' +
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
      var be = U.birthErr(U.birthVal('bd'), true); if (be) return toast(be);
      if (!wa) return toast('رقم الواتساب غير صحيح');
      if (!ed.services.length) return toast('اختر خدمة واحدة على الأقل');
      if (!st || !ct) return toast('اختر الولاية والمدينة');
      var pm = document.getElementById('pm').value;
      if (ex === '' || pr === '' || +pr <= 0) return toast('اكتب الخبرة وأدنى سعر');
      if (pm === '' || +pm < +pr) return toast('أعلى سعر يجب ألا يقل عن أدنى سعر');
      if (bio.length < 5) return toast('اكتب وصفا قصيرا لمهارتك');
      var o = { name: nm, birth_date: U.birthVal('bd'), whatsapp: wa, services: ed.services, state_id: st, city_id: ct, hood: document.getElementById('hd').value.trim(), radius: ed.radius,
        experience: +ex, price: +pr, price_max: +pm, bio: bio, photo: ed.photo, from: document.getElementById('fr').value || '08:00', to: document.getElementById('to').value || '20:00' };
      if (ed.lat != null) { o.lat = ed.lat; o.lng = ed.lng; }
      else if (ct !== me.city_id) { var cc = SQ.findCity(ct).city; o.lat = cc.lat; o.lng = cc.lng; }
      var b = document.getElementById('save'); b.disabled = true;
      try { await db.updateProfile(pid, tk, o); toast('تم حفظ التعديلات'); go('#/p/profile'); } catch (e) { b.disabled = false; toast(errMsg(e)); }
    });
  }

  /* ---------- التوجيه ---------- */
  function route() {
    closeModal(); document.body.classList.remove('is-home');
    var h = (location.hash || '#/').replace(/^#/, ''), p = h.split('/').filter(Boolean);
    try {
      // رابط نظيف: saqapp.net/username (يُعاد توجيهه إلى index.html من .htaccess)
      var pm = !location.hash && location.pathname.match(/^\/([A-Za-z][A-Za-z0-9_]{2,19})\/?$/);
      if (pm && !/^(index|admin)$/i.test(pm[1])) return viewByUsername(pm[1].toLowerCase());
      if (!p.length) return viewHome();
      if (p[0] === 'u' && p[1]) return viewByUsername(decodeURIComponent(p[1]));
      if (p[0] === 'c') {
        if (p[1] === 'p') { if (!store.get('role')) store.set('role', 'client'); return viewClientProvider(p[2], p[3] || 'other'); } // رابط مشاركة الصنايعي
        if (p[1] === 'loc') return viewClientLoc();
        if (p[1] === 'service') return go('#/');
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
      viewHome();
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
