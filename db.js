/* صنايعي قريب - طبقة البيانات
   وضعان بنفس الواجهة: LocalDB (تجريبي على الجهاز) و SupabaseDB (حقيقي).
   الواجهة (app.js) لا تعرف أي وضع تعمل فيه. */
(function () {
  'use strict';
  var SQ = window.SQ, C = SQ.CONFIG;

  /* ---------- أدوات الجغرافيا والوقت ---------- */
  var G = (SQ.geo = {
    haversine: function (a, b, c, d) {
      var R = 6371, r = function (x) { return (x * Math.PI) / 180; };
      var dl = r(c - a), dn = r(d - b);
      var h = Math.pow(Math.sin(dl / 2), 2) + Math.cos(r(a)) * Math.cos(r(c)) * Math.pow(Math.sin(dn / 2), 2);
      return 2 * R * Math.asin(Math.sqrt(h));
    },
    eta: function (km) {
      if (km == null) return null;
      return Math.max(5, Math.round(((km / C.speedKmh) * 60) / 5) * 5);
    },
    nearestCity: function (lat, lng) {
      var best = null;
      SQ.COUNTRY.states.forEach(function (s) {
        s.cities.forEach(function (ct) {
          var d = G.haversine(lat, lng, ct.lat, ct.lng);
          if (!best || d < best.km) best = { state_id: s.id, city_id: ct.id, km: d };
        });
      });
      return best;
    }
  });

  function mins(t) {
    var m = /^(\d{1,2}):(\d{2})/.exec(t || '');
    return m ? +m[1] * 60 + +m[2] : null;
  }
  function isOpen(f, t) {
    var a = mins(f), b = mins(t);
    if (a == null || b == null) return true;
    var d = new Date(), n = d.getHours() * 60 + d.getMinutes();
    return a <= b ? n >= a && n <= b : n >= a || n <= b;
  }
  SQ.isOpen = isOpen;

  function uid() {
    try { if (window.crypto && crypto.randomUUID) return crypto.randomUUID(); } catch (e) {}
    return 'id' + Date.now().toString(36) + Math.random().toString(36).slice(2, 10);
  }
  SQ.uid = uid;

  var KEY = 'sq_db_v1';
  function load() { try { return JSON.parse(localStorage.getItem(KEY)); } catch (e) { return null; } }
  function save(d) { try { localStorage.setItem(KEY, JSON.stringify(d)); } catch (e) {} }

  /* ---------- بيانات تجريبية ---------- */
  function seed() {
    var base = {
      khartoum: [15.5007, 32.5599], omdurman: [15.6445, 32.4777], bahri: [15.6333, 32.5333],
      wad_madani: [14.4012, 33.5199], port_sudan: [19.6158, 37.2164]
    };
    // [الاسم، الخدمات، المدينة، الحي، إزاحة خط العرض، إزاحة خط الطول، الخبرة، سعر الكشف، الوصف، النطاق، ناجحة، فاشلة، عدد التقييمات، المتوسط]
    var rows = [
      ['م. عثمان إبراهيم', ['solar'], 'omdurman', 'الثورة', 0.012, -0.01, 9, 10000, 'تركيب ألواح وبطاريات وانفرتر وصيانة', '20', 84, 1, 37, 4.8],
      ['خالد الطيب', ['electric'], 'omdurman', 'ود نوباوي', -0.018, 0.006, 12, 5000, 'توصيلات وصيانة كهرباء منازل', '10', 120, 3, 52, 4.6],
      ['محمد آدم', ['plumbing'], 'omdurman', 'الملازمين', 0.03, 0.02, 7, 4000, 'سباكة وتسليك وتركيب أدوات صحية', '10', 60, 2, 25, 4.5],
      ['مصطفى عمر', ['water', 'generator'], 'omdurman', 'أمبدة', 0.04, -0.03, 10, 6000, 'مضخات مياه وصيانة مولدات', '20', 41, 2, 18, 4.3],
      ['آمنة يوسف', ['cleaning'], 'omdurman', 'بيت المال', -0.005, 0.004, 4, 3000, 'نظافة منازل بعد التشطيب وعادية', '10', 22, 0, 4, 4.9],
      ['الصادق حسن', ['carpentry'], 'bahri', 'الحلفايا', 0.025, 0.01, 15, 5000, 'أبواب ومطابخ وغرف نوم', '10', 70, 2, 31, 4.4],
      ['بشير عبدالله', ['blacksmith'], 'bahri', 'شمبات', -0.01, 0.015, 11, 4000, 'أبواب حديد وشبابيك وسقالات', '10', 55, 1, 20, 4.2],
      ['حامد الأمين', ['appliance'], 'bahri', 'كافوري', 0.02, 0.03, 6, 3000, 'ثلاجات وغسالات ومراوح', '10', 33, 1, 14, 4.1],
      ['سعد النور', ['transport'], 'bahri', 'المزاد', -0.02, -0.01, 8, 8000, 'نقل أثاث وعفش بالدفار', '20', 47, 3, 16, 4.0],
      ['أحمد سعيد', ['building', 'paint'], 'khartoum', 'الرياض', 0.01, 0.02, 14, 6000, 'بناء وسيراميك وبلاط ودهانات', '20', 90, 4, 40, 4.5],
      ['علي موسى', ['ac'], 'khartoum', 'العمارات', -0.012, -0.008, 9, 5000, 'تركيب وصيانة وشحن غاز مكيفات', '10', 66, 2, 29, 4.7],
      ['يوسف جمعة', ['solar', 'electric'], 'khartoum', 'بري', 0.015, 0.025, 7, 8000, 'منظومات شمسية وتمديدات كهرباء', '10', 38, 1, 12, 4.6],
      ['إبراهيم ناصر', ['mobile'], 'khartoum', 'الصحافة', -0.03, 0.005, 5, 2000, 'شاشات وبطاريات وسوفتوير', '5', 150, 6, 60, 4.4],
      ['عادل فضل', ['plumbing'], 'khartoum', 'الطائف', 0.005, -0.015, 6, 4000, 'سباكة وخزانات وتمديدات', '10', 12, 0, 2, 0],
      ['ياسر بشارة', ['electric', 'solar'], 'wad_madani', 'حي الدرجة', 0.01, 0.01, 8, 5000, 'كهرباء وطاقة شمسية', '10', 28, 1, 10, 4.5],
      ['نادر طه', ['plumbing'], 'port_sudan', 'ديم عرب', 0.005, -0.01, 10, 5000, 'سباكة وصيانة مياه', '10', 35, 2, 15, 4.3]
    ];
    var now = Date.now();
    var providers = rows.map(function (r, i) {
      var b = base[r[2]];
      return {
        id: 'demo' + (i + 1), token: 'x', name: r[0], phone: '+249900000000', whatsapp: '+249900000000',
        state_id: SQ.findCity(r[2]).state.id, city_id: r[2], hood: r[3],
        lat: b[0] + r[4], lng: b[1] + r[5], radius: r[9], services: r[1], experience: r[6], price: r[7], bio: r[8],
        from: '08:00', to: '20:00', status: 'approved', available: i % 7 !== 6, last_seen: now, created: now, demo: true,
        stats: { ok: r[10], fail: r[11], n: r[12], avg: r[13] }
      };
    });
    var reviews = [
      { id: 'r1', provider_id: 'demo1', stars: 5, comment: 'شغل نضيف وجاء في الميعاد', success: true, ts: now - 86400000 * 6 },
      { id: 'r2', provider_id: 'demo1', stars: 5, comment: 'ركّب المنظومة وشرح لي كل حاجة', success: true, ts: now - 86400000 * 12 },
      { id: 'r3', provider_id: 'demo2', stars: 4, comment: 'ماهر لكن تأخر شوية', success: true, ts: now - 86400000 * 3 },
      { id: 'r4', provider_id: 'demo3', stars: 5, comment: 'حل المشكلة في ساعة', success: true, ts: now - 86400000 * 9 },
      { id: 'r5', provider_id: 'demo11', stars: 5, comment: 'تكييف زي الجديد', success: true, ts: now - 86400000 * 2 }
    ];
    return { v: 1, providers: providers, requests: [], reviews: reviews, reports: [] };
  }

  /* ---------- الوضع التجريبي المحلي ---------- */
  function isAvail(p) {
    if (!p.available) return false;
    if (p.demo) return true;
    if (Date.now() - p.last_seen > C.availableTimeoutHours * 3600e3) return false;
    return isOpen(p.from, p.to);
  }

  function pct(p) {
    return (p.photo ? 30 : 0) + (String(p.bio || '').trim().length >= 20 ? 25 : 0) + (String(p.hood || '').trim() ? 15 : 0) +
      (p.price > 0 ? 10 : 0) + (p.experience > 0 ? 10 : 0) + (p.password ? 10 : 0);
  }
  function nph(x) { var n = SQ.util.normalizePhone(x); if (!n) throw new Error('invalid_phone'); return n; }

  // أولوية الظهور: اكتمال الملف + نشاط آخر 30 يوما (حتى 10 طلبات)
  function score(p) {
    var since = Date.now() - 30 * 86400000, n = L.d.requests.filter(function (q) { return q.provider_id === p.id && q.ts > since; }).length;
    return pct(p) + (p.verified ? 20 : 0) + Math.min(n, 10) * 5;
  }

  var L = {
    d: null,
    init: function () {
      this.d = load();
      if (!this.d || !this.d.v) { this.d = seed(); save(this.d); }
      var d = this.d, ch = false;
      if (!d.services) { d.services = SQ.SERVICES.map(function (s, i) { return { id: s.id, name: s.name, icon: s.icon, sort: (i + 1) * 10, active: true, cat: SQ.catOf(s).id }; }); ch = true; }
      if (!d.settings) { d.settings = { support_whatsapp: '', support_email: '' }; ch = true; }
      if (!d.adminCode) { d.adminCode = C.adminCode; ch = true; }
      if (ch) save(d);
    },
    pub: function (p, d) {
      return {
        id: p.id, name: p.name, services: p.services, state_id: p.state_id, city_id: p.city_id, hood: p.hood,
        experience: p.experience, price: p.price, bio: p.bio, from: p.from, to: p.to, available: isAvail(p),
        distance_km: d == null ? null : Math.round(d * 10) / 10,
        rating: p.stats.n >= C.minReviewsForStars ? p.stats.avg : null, rating_n: p.stats.n,
        ok: p.stats.ok, fail: p.stats.fail, phone: p.phone, whatsapp: p.whatsapp, demo: !!p.demo, photo: p.photo || '', verified: !!p.verified
      };
    },
    find: function (id) { return this.d.providers.filter(function (p) { return p.id === id; })[0]; },
    auth: function (id, token) {
      var p = this.find(id);
      if (!p || p.token !== token) throw new Error('forbidden');
      return p;
    },
    admin: function (code) { if (code !== this.d.adminCode) throw new Error('forbidden'); },

    featured: async function (q) {
      var self = this, off = q.offset || 0, lim = Math.min(q.limit || 12, 24), hasLoc = q.lat != null;
      var arr = this.d.providers.filter(function (p) { return p.status === 'approved'; })
        .map(function (p) { return { p: p, d: hasLoc ? G.haversine(q.lat, q.lng, p.lat, p.lng) : null, av: isAvail(p) }; });
      arr.sort(function (a, b) {
        if (a.av !== b.av) return a.av ? -1 : 1;
        var da = a.d == null ? 0 : Math.floor(a.d / 3), db = b.d == null ? 0 : Math.floor(b.d / 3);
        if (da !== db) return da - db;
        var sa = score(a.p), sb = score(b.p); if (sa !== sb) return sb - sa;
        return (a.d || 0) - (b.d || 0);
      });
      return { items: arr.slice(off, off + lim).map(function (x) { return self.pub(x.p, x.d); }), more: arr.length > off + lim };
    },
    nearby: async function (q) {
      var self = this, hasLoc = q.lat != null;
      var all = this.d.providers
        .filter(function (p) { return p.status === 'approved' && p.services.indexOf(q.service) > -1; })
        .map(function (p) { return { p: p, d: hasLoc ? G.haversine(q.lat, q.lng, p.lat, p.lng) : null, av: isAvail(p) }; });
      // الأقرب أولا (بتقريب لأقرب كيلو)، وعند التساوي الأعلى تقييما ثم الأكثر شغلانات ناجحة
      var cmp = function (a, b) {
        var da = a.d == null ? 1e9 : Math.floor(a.d / 3), db = b.d == null ? 1e9 : Math.floor(b.d / 3);
        if (da !== db) return da - db;
        var sa = score(a.p), sb = score(b.p);
        if (sa !== sb) return sb - sa;
        var ra = a.p.stats.n >= C.minReviewsForStars ? a.p.stats.avg : 0;
        var rb = b.p.stats.n >= C.minReviewsForStars ? b.p.stats.avg : 0;
        if (rb !== ra) return rb - ra;
        return b.p.stats.ok - a.p.stats.ok;
      };
      var out = function (a) { return a.sort(cmp).map(function (x) { return self.pub(x.p, x.d); }); };
      var inr = all.filter(function (x) {
        return x.p.city_id === q.cityId && x.av && (x.p.radius === 'all' || x.d == null || x.d <= Number(x.p.radius));
      });
      if (inr.length) return { tier: 'inrange', items: out(inr) };
      var cav = all.filter(function (x) { return x.p.city_id === q.cityId && x.av; });
      if (cav.length) return { tier: 'nearest_city', items: out(cav) };
      var oav = all.filter(function (x) { return x.p.city_id !== q.cityId && x.av; });
      if (oav.length) return { tier: 'other_city', items: out(oav).slice(0, 10) };
      return { tier: 'none', items: [] };
    },

    getProvider: async function (id, loc) {
      var p = this.find(id);
      if (!p || p.status !== 'approved') return null;
      var d = loc && loc.lat != null ? G.haversine(loc.lat, loc.lng, p.lat, p.lng) : null;
      var r = this.pub(p, d);
      r.reviews = this.d.reviews.filter(function (x) { return x.provider_id === id; })
        .sort(function (a, b) { return b.ts - a.ts; }).slice(0, 5)
        .map(function (x) { return { stars: x.stars, comment: x.comment, success: x.success, ts: x.ts }; });
      return r;
    },

    registerProvider: async function (x) {
      x.phone = nph(x.phone); x.whatsapp = x.whatsapp ? nph(x.whatsapp) : x.phone;
      if (this.d.providers.some(function (p) { return p.phone === x.phone; })) throw new Error('duplicate');
      if (String(x.password || '').length < 6) throw new Error('weak');
      if (!x.services || !x.services.length) throw new Error('invalid');
      if (x.photo && (x.photo.indexOf('data:image/jpeg;base64,') !== 0 || x.photo.length > 60000)) throw new Error('invalid');
      var p = {
        photo: x.photo || '',
        password: x.password, fails: 0, locked_until: 0, admin_note: '',
        id: uid(), token: uid(), name: x.name, phone: x.phone, whatsapp: x.whatsapp, state_id: x.state_id, city_id: x.city_id,
        hood: x.hood, lat: x.lat, lng: x.lng, radius: String(x.radius), services: x.services, experience: Number(x.experience) || 0,
        price: Number(x.price) || 0, bio: x.bio, from: x.from, to: x.to, status: 'pending', available: false,
        last_seen: Date.now(), created: Date.now(), stats: { ok: 0, fail: 0, n: 0, avg: 0 }
      };
      this.d.providers.push(p); save(this.d);
      return { id: p.id, token: p.token };
    },

    providerSelf: async function (id, token) {
      var p = this.auth(id, token);
      p.last_seen = Date.now(); save(this.d);
      var week = Date.now() - 7 * 86400000;
      var r = this.pub(p, null);
      r.status = p.status; r.flag = !!p.available; r.in_hours = isOpen(p.from, p.to); r.radius = p.radius; r.has_password = !!p.password; r.pct = pct(p);
      r.requests_week = this.d.requests.filter(function (q) { return q.provider_id === id && q.ts > week; }).length;
      return r;
    },
    setAvailable: async function (id, token, v) {
      var p = this.auth(id, token); p.available = !!v; p.last_seen = Date.now(); save(this.d); return true;
    },
    setHours: async function (id, token, from, to) {
      var p = this.auth(id, token); p.from = from; p.to = to; save(this.d); return true;
    },
    deleteProvider: async function (id, token) {
      this.auth(id, token);
      this.d.providers = this.d.providers.filter(function (p) { return p.id !== id; });
      this.d.requests = this.d.requests.filter(function (q) { return q.provider_id !== id; });
      this.d.reviews = this.d.reviews.filter(function (q) { return q.provider_id !== id; });
      save(this.d); return true;
    },

    createRequest: async function (x) {
      var p = this.find(x.provider_id);
      if (!p || p.status !== 'approved') throw new Error('not_found');
      var day = new Date().toDateString();
      var ex = this.d.requests.filter(function (q) {
        return q.anon_id === x.anon_id && q.provider_id === x.provider_id && new Date(q.ts).toDateString() === day;
      })[0];
      if (ex) return { id: ex.id, existing: true };
      var r = { id: uid(), provider_id: x.provider_id, anon_id: x.anon_id, service: x.service, city_id: x.city_id, channel: x.channel, status: 'new', ts: Date.now() };
      this.d.requests.push(r); save(this.d);
      return { id: r.id };
    },
    myRequests: async function (anon) {
      var self = this;
      return this.d.requests.filter(function (q) { return q.anon_id === anon; })
        .sort(function (a, b) { return b.ts - a.ts; })
        .map(function (q) {
          var p = self.find(q.provider_id);
          return { id: q.id, provider_id: q.provider_id, provider_name: p ? p.name : '—', service: q.service, channel: q.channel, status: q.status, ts: q.ts };
        });
    },
    // outcome: done | failed | not_agreed
    addReview: async function (reqId, anon, x) {
      var q = this.d.requests.filter(function (r) { return r.id === reqId && r.anon_id === anon; })[0];
      if (!q) throw new Error('forbidden');
      if (q.status !== 'new') throw new Error('already');
      if (x.outcome === 'not_agreed') { q.status = 'not_agreed'; save(this.d); return true; }
      var p = this.find(q.provider_id);
      var stars = Math.max(1, Math.min(5, Number(x.stars) || 5));
      q.status = x.outcome;
      if (p) {
        var s = p.stats, total = s.avg * s.n + stars;
        s.n += 1; s.avg = Math.round((total / s.n) * 10) / 10;
        if (x.outcome === 'done') s.ok += 1; else s.fail += 1;
      }
      this.d.reviews.push({ id: uid(), request_id: reqId, provider_id: q.provider_id, stars: stars, comment: String(x.comment || '').slice(0, 300), success: x.outcome === 'done', ts: Date.now() });
      save(this.d); return true;
    },
    reportProvider: async function (id, anon, reason) {
      this.d.reports.push({ id: uid(), provider_id: id, anon_id: anon, reason: reason, status: 'open', ts: Date.now() });
      var seen = {}, n = 0;
      this.d.reports.forEach(function (r) { if (r.provider_id === id && r.status === 'open' && !seen[r.anon_id]) { seen[r.anon_id] = 1; n++; } });
      var p = this.find(id);
      if (p && n >= 3 && p.status === 'approved' && !p.demo) p.status = 'suspended';
      save(this.d); return true;
    },

    adminCheck: async function (code) { this.admin(code); return true; },
    adminList: async function (code, status) {
      this.admin(code);
      return this.d.providers.filter(function (p) { return p.status === status && !p.demo; })
        .sort(function (a, b) { return b.created - a.created; })
        .map(function (p) {
          return { id: p.id, name: p.name, phone: p.phone, whatsapp: p.whatsapp, services: p.services, state_id: p.state_id, city_id: p.city_id, hood: p.hood, experience: p.experience, price: p.price, bio: p.bio, status: p.status, created: p.created };
        });
    },
    adminSetStatus: async function (code, id, status) {
      this.admin(code);
      var p = this.find(id); if (!p) throw new Error('not_found');
      p.status = status; if (status === 'approved') p.last_seen = Date.now();
      save(this.d); return true;
    },
    adminReports: async function (code) {
      this.admin(code); var self = this;
      return this.d.reports.filter(function (r) { return r.status === 'open'; }).sort(function (a, b) { return b.ts - a.ts; })
        .map(function (r) { var p = self.find(r.provider_id); return { id: r.id, provider_id: r.provider_id, provider_name: p ? p.name : '—', provider_status: p ? p.status : '', reason: r.reason, ts: r.ts }; });
    },
    adminResolveReport: async function (code, id) {
      this.admin(code);
      this.d.reports.forEach(function (r) { if (r.id === id) r.status = 'resolved'; });
      save(this.d); return true;
    },
    adminStats: async function (code) {
      this.admin(code);
      var week = Date.now() - 7 * 86400000, real = this.d.providers.filter(function (p) { return !p.demo; });
      return {
        providers: real.filter(function (p) { return p.status === 'approved'; }).length,
        pending: real.filter(function (p) { return p.status === 'pending'; }).length,
        requests_week: this.d.requests.filter(function (q) { return q.ts > week; }).length,
        reports: this.d.reports.filter(function (r) { return r.status === 'open'; }).length
      };
    },
    /* ===== الخدمات والإعدادات ===== */
    listServices: async function () {
      return this.d.services.slice().sort(function (a, b) { return a.sort - b.sort; })
        .map(function (s) { return { id: s.id, name: s.name, icon: s.icon, active: s.active, cat: s.cat || SQ.catOf(s).id }; });
    },
    appConfig: async function () { return { support_whatsapp: this.d.settings.support_whatsapp || '', support_email: this.d.settings.support_email || '' }; },

    /* ===== حسابات الصنايعية ===== */
    providerLogin: async function (phone, pw) {
      var np = SQ.util.normalizePhone(phone);
      var p = this.d.providers.filter(function (x) { return x.phone === np && !x.demo; })[0];
      if (!p) throw new Error('invalid');
      if (p.locked_until && p.locked_until > Date.now()) throw new Error('locked');
      if (!p.password) throw new Error('no_password');
      if (p.password !== pw) {
        p.fails = (p.fails || 0) + 1;
        if (p.fails >= 5) { p.fails = 0; p.locked_until = Date.now() + 15 * 60e3; }
        save(this.d); throw new Error('invalid');
      }
      p.fails = 0; p.last_seen = Date.now(); save(this.d);
      return { id: p.id, token: p.token };
    },
    setPassword: async function (id, token, nw, old) {
      var p = this.auth(id, token);
      if (String(nw || '').length < 6) throw new Error('weak');
      if (p.password) {
        if (old !== p.password) throw new Error('wrong_password');
        p.token = uid();
      }
      p.password = nw; save(this.d);
      return { token: p.token };
    },
    applyProfile: function (p, o, admin) {
      if (o.services && !o.services.length) throw new Error('invalid');
      if (o.name && String(o.name).trim()) p.name = String(o.name).trim().slice(0, 80);
      if (o.whatsapp) p.whatsapp = nph(o.whatsapp);
      if (admin && o.phone) p.phone = nph(o.phone);
      if (o.photo != null) {
        if (o.photo && (o.photo.indexOf('data:image/jpeg;base64,') !== 0 || o.photo.length > 60000)) throw new Error('invalid');
        p.photo = o.photo;
      }
      if (o.state_id) p.state_id = o.state_id;
      if (o.city_id) p.city_id = o.city_id;
      if (o.hood != null) p.hood = String(o.hood).slice(0, 60);
      if (o.lat != null) p.lat = o.lat;
      if (o.lng != null) p.lng = o.lng;
      if (o.radius) p.radius = String(o.radius);
      if (o.services) p.services = o.services.slice();
      if (o.experience != null) p.experience = Number(o.experience);
      if (o.price != null) p.price = Number(o.price);
      if (o.bio != null) p.bio = String(o.bio).slice(0, 200);
      if (o.from) p.from = o.from;
      if (o.to) p.to = o.to;
      if (admin && o.admin_note != null) p.admin_note = String(o.admin_note).slice(0, 500);
    },
    updateProfile: async function (id, token, o) {
      var p = this.auth(id, token); this.applyProfile(p, o, false); save(this.d); return true;
    },

    /* ===== إدارة المدير ===== */
    realProviders: function () { return this.d.providers.filter(function (p) { return !p.demo; }); },
    adminRow: function (p) {
      var rid = p.id, week = Date.now() - 7 * 86400000, rq = this.d.requests.filter(function (q) { return q.provider_id === rid; });
      return {
        id: p.id, name: p.name, phone: p.phone, whatsapp: p.whatsapp, services: p.services, state_id: p.state_id, city_id: p.city_id, hood: p.hood,
        radius: p.radius, experience: p.experience, price: p.price, bio: p.bio, from: p.from, to: p.to, status: p.status,
        available: p.status === 'approved' && isAvail(p), flag: !!p.available, has_password: !!p.password, admin_note: p.admin_note || '',
        last_seen: p.last_seen, created: p.created, requests_total: rq.length, requests_week: rq.filter(function (q) { return q.ts > week; }).length,
        rating_n: p.stats.n, rating: p.stats.n > 0 ? p.stats.avg : null, ok: p.stats.ok, fail: p.stats.fail,
        photo: p.photo || '', pct: pct(p), verified: !!p.verified
      };
    },
    adminOverview: async function (code) {
      this.admin(code);
      var self = this, real = this.realProviders(), now = Date.now(), DAY = 86400000;
      var cnt = function (st) { return real.filter(function (p) { return p.status === st; }).length; };
      var dayKey = function (t) { var x = new Date(t); return x.getFullYear() + '-' + (x.getMonth() + 1) + '-' + x.getDate(); };
      var days = [];
      for (var i = 6; i >= 0; i--) {
        var t = now - i * DAY, k = dayKey(t), dd = new Date(t);
        days.push({ d: ('0' + (dd.getMonth() + 1)).slice(-2) + '-' + ('0' + dd.getDate()).slice(-2), n: this.d.requests.filter(function (q) { return dayKey(q.ts) === k; }).length });
      }
      var tops = this.d.services.map(function (s) {
        return { id: s.id, name: s.name, icon: s.icon,
          providers: real.filter(function (p) { return p.status === 'approved' && p.services.indexOf(s.id) > -1; }).length,
          requests_week: self.d.requests.filter(function (q) { return q.service === s.id && q.ts > now - 7 * DAY; }).length };
      }).sort(function (a, b) { return b.requests_week - a.requests_week || b.providers - a.providers; }).slice(0, 8);
      var cities = {};
      real.forEach(function (p) { if (p.status === 'approved') cities[p.city_id] = (cities[p.city_id] || 0) + 1; });
      var allRev = this.d.reviews;
      return {
        approved: cnt('approved'), pending: cnt('pending'), suspended: cnt('suspended'), rejected: cnt('rejected'),
        available_now: real.filter(function (p) { return p.status === 'approved' && isAvail(p); }).length,
        requests_today: this.d.requests.filter(function (q) { return dayKey(q.ts) === dayKey(now); }).length,
        requests_week: this.d.requests.filter(function (q) { return q.ts > now - 7 * DAY; }).length,
        requests_total: this.d.requests.length, reviews_total: allRev.length,
        avg_rating: allRev.length ? Math.round(allRev.reduce(function (a, r) { return a + r.stars; }, 0) / allRev.length * 10) / 10 : 0,
        reports_open: this.d.reports.filter(function (r) { return r.status === 'open'; }).length,
        by_day: days, top_services: tops,
        by_city: Object.keys(cities).map(function (k) { return { city_id: k, n: cities[k] }; }).sort(function (a, b) { return b.n - a.n; }).slice(0, 8)
      };
    },
    adminProviders: async function (code, f) {
      this.admin(code); f = f || {};
      var q = String(f.q || '').trim().toLowerCase(), qd = q.replace(/\D/g, '').replace(/^0+/, ''), self = this;
      var list = this.realProviders().filter(function (p) {
        if (f.status && p.status !== f.status) return false;
        if (f.service && p.services.indexOf(f.service) < 0) return false;
        if (f.city && p.city_id !== f.city) return false;
        if (q && !(p.name.toLowerCase().indexOf(q) > -1 || (qd && p.phone.indexOf(qd) > -1))) return false;
        return true;
      }).sort(function (a, b) { return (a.status !== 'pending') - (b.status !== 'pending') || b.created - a.created; });
      var off = f.offset || 0, lim = f.limit || 30;
      return { total: list.length, items: list.slice(off, off + lim).map(function (p) { return self.adminRow(p); }) };
    },
    adminUpdateProvider: async function (code, id, o) {
      this.admin(code); var p = this.find(id); if (!p) throw new Error('not_found');
      if (o.phone && this.d.providers.some(function (x) { return x.id !== id && x.phone === o.phone; })) throw new Error('duplicate');
      this.applyProfile(p, o, true); save(this.d); return true;
    },
    adminCreateProvider: async function (code, o) {
      this.admin(code);
      o.phone = nph(o.phone); o.whatsapp = o.whatsapp ? nph(o.whatsapp) : o.phone;
      if (this.d.providers.some(function (p) { return p.phone === o.phone; })) throw new Error('duplicate');
      if (String(o.password || '').length < 6) throw new Error('weak');
      if (!o.services || !o.services.length) throw new Error('invalid');
      var city = SQ.findCity(o.city_id), p = {
        photo: o.photo || '', id: uid(), token: uid(), password: o.password, fails: 0, locked_until: 0, admin_note: o.admin_note || '',
        name: o.name, phone: o.phone, whatsapp: o.whatsapp || o.phone, state_id: o.state_id, city_id: o.city_id, hood: o.hood || '',
        lat: o.lat != null ? o.lat : (city ? city.city.lat : 0), lng: o.lng != null ? o.lng : (city ? city.city.lng : 0),
        radius: String(o.radius || '10'), services: o.services, experience: Number(o.experience) || 0, price: Number(o.price) || 0, bio: o.bio || '',
        from: o.from || '08:00', to: o.to || '20:00', status: 'approved', available: false, last_seen: Date.now(), created: Date.now(),
        stats: { ok: 0, fail: 0, n: 0, avg: 0 }
      };
      this.d.providers.push(p); save(this.d); return { id: p.id };
    },
    adminSetVerified: async function (code, id, v) { this.admin(code); var p = this.find(id); if (p) p.verified = !!v; save(this.d); return true; },
    adminResetPassword: async function (code, id, pw) {
      this.admin(code); var p = this.find(id); if (!p) throw new Error('not_found');
      if (String(pw || '').length < 6) throw new Error('weak');
      p.password = pw; p.token = uid(); p.fails = 0; p.locked_until = 0; save(this.d); return true;
    },
    adminDeleteProvider: async function (code, id) {
      this.admin(code);
      this.d.providers = this.d.providers.filter(function (p) { return p.id !== id; });
      this.d.requests = this.d.requests.filter(function (q) { return q.provider_id !== id; });
      this.d.reviews = this.d.reviews.filter(function (q) { return q.provider_id !== id; });
      save(this.d); return true;
    },
    adminRequests: async function (code, limit, status) {
      this.admin(code); var self = this;
      return this.d.requests.filter(function (q) { return !status || q.status === status; })
        .sort(function (a, b) { return b.ts - a.ts; }).slice(0, limit || 100)
        .map(function (q) { var p = self.find(q.provider_id); return { id: q.id, provider_id: q.provider_id, provider_name: p ? p.name : '—', service: q.service, city_id: q.city_id, channel: q.channel, status: q.status, ts: q.ts }; });
    },
    adminServices: async function (code) {
      this.admin(code); var d = this.d;
      return d.services.slice().sort(function (a, b) { return a.sort - b.sort; }).map(function (s) {
        return { id: s.id, name: s.name, icon: s.icon, active: s.active, sort: s.sort, cat: s.cat || SQ.catOf(s).id, providers: d.providers.filter(function (p) { return !p.demo && p.services.indexOf(s.id) > -1; }).length };
      });
    },
    adminSaveService: async function (code, id, name, icon, active, cat) {
      this.admin(code);
      if (String(name || '').trim().length < 2) throw new Error('invalid');
      var s = id ? this.d.services.filter(function (x) { return x.id === id; })[0] : null;
      if (id && !s) throw new Error('not_found');
      if (!s) {
        id = 's' + uid().slice(0, 8);
        s = { id: id, sort: this.d.services.reduce(function (m, x) { return Math.max(m, x.sort); }, 0) + 10, active: true };
        this.d.services.push(s);
      }
      s.name = String(name).trim().slice(0, 40); if (icon) s.icon = icon; if (active != null) s.active = !!active; if (cat != null) s.cat = String(cat).slice(0, 20);
      save(this.d); return id;
    },
    adminReorderServices: async function (code, ids) {
      this.admin(code); var d = this.d;
      ids.forEach(function (id, i) { var s = d.services.filter(function (x) { return x.id === id; })[0]; if (s) s.sort = (i + 1) * 10; });
      save(d); return true;
    },
    adminDeleteService: async function (code, id) {
      this.admin(code);
      if (this.d.providers.some(function (p) { return p.services.indexOf(id) > -1; })) throw new Error('in_use');
      this.d.services = this.d.services.filter(function (s) { return s.id !== id; }); save(this.d); return true;
    },
    adminGetSettings: async function (code) { this.admin(code); return this.appConfig(); },
    adminSaveSettings: async function (code, o) {
      this.admin(code); this.d.settings.support_whatsapp = o.support_whatsapp || ''; this.d.settings.support_email = o.support_email || ''; save(this.d); return true;
    },
    adminChangeCode: async function (code, nw) {
      this.admin(code); if (String(nw || '').length < 8) throw new Error('weak'); this.d.adminCode = nw; save(this.d); return true;
    },
    resetDemo: function () { try { localStorage.removeItem(KEY); } catch (e) {} this.init(); }
  };

  /* ---------- Supabase عبر REST و RPC (بدون مكتبات) ---------- */
  var SB = {
    rpc: async function (fn, args) {
      var h = { 'Content-Type': 'application/json', apikey: C.supabaseKey };
      if (/^eyJ/.test(C.supabaseKey)) h.Authorization = 'Bearer ' + C.supabaseKey;
      var r = await fetch(C.supabaseUrl.replace(/\/$/, '') + '/rest/v1/rpc/' + fn, { method: 'POST', headers: h, body: JSON.stringify(args || {}) });
      var txt = await r.text(), data = null;
      try { data = txt ? JSON.parse(txt) : null; } catch (e) {}
      if (!r.ok) {
        var m = (data && (data.message || data.hint)) || ('HTTP ' + r.status);
        if (/duplicate key/i.test(m)) m = 'duplicate';
        throw new Error(m);
      }
      return data;
    },
    featured: function (q) { return SB.rpc('featured_providers', { p_lat: q.lat == null ? null : q.lat, p_lng: q.lng == null ? null : q.lng, p_limit: q.limit || 12, p_offset: q.offset || 0 }); },
    nearby: function (q) { return SB.rpc('nearby_providers', { p_lat: q.lat, p_lng: q.lng, p_service: q.service, p_city: q.cityId }); },
    getProvider: function (id, loc) { return SB.rpc('get_provider', { p_id: id, p_lat: loc ? loc.lat : null, p_lng: loc ? loc.lng : null }); },
    registerProvider: function (x) { return SB.rpc('register_provider', { p: x }); },
    providerSelf: function (id, t) { return SB.rpc('provider_self', { p_id: id, p_token: t }); },
    setAvailable: function (id, t, v) { return SB.rpc('set_available', { p_id: id, p_token: t, p_value: !!v }); },
    setHours: function (id, t, f, to) { return SB.rpc('set_hours', { p_id: id, p_token: t, p_from: f, p_to: to }); },
    deleteProvider: function (id, t) { return SB.rpc('delete_provider', { p_id: id, p_token: t }); },
    createRequest: function (x) { return SB.rpc('create_request', { p: x }); },
    myRequests: function (anon) { return SB.rpc('my_requests', { p_anon: anon }); },
    addReview: function (reqId, anon, x) { return SB.rpc('add_review', { p_request: reqId, p_anon: anon, p_outcome: x.outcome, p_stars: x.stars || null, p_comment: x.comment || '' }); },
    reportProvider: function (id, anon, reason) { return SB.rpc('report_provider', { p_id: id, p_anon: anon, p_reason: reason }); },
    adminCheck: function (code) { return SB.rpc('admin_check', { p_code: code }); },
    adminList: function (code, status) { return SB.rpc('admin_list', { p_code: code, p_status: status }); },
    adminSetStatus: function (code, id, status) { return SB.rpc('admin_set_status', { p_code: code, p_id: id, p_status: status }); },
    adminReports: function (code) { return SB.rpc('admin_reports', { p_code: code }); },
    adminResolveReport: function (code, id) { return SB.rpc('admin_resolve_report', { p_code: code, p_id: id }); },
    adminStats: function (code) { return SB.rpc('admin_stats', { p_code: code }); },

    listServices: function () { return SB.rpc('list_services'); },
    appConfig: function () { return SB.rpc('app_config'); },
    providerLogin: async function (phone, pw) {
      var r = await SB.rpc('provider_login', { p_phone: phone, p_password: pw });
      if (!r || !r.ok) throw new Error((r && r.error) || 'invalid');
      return { id: r.id, token: r.token };
    },
    setPassword: function (id, t, nw, old) { return SB.rpc('set_password', { p_id: id, p_token: t, p_new: nw, p_old: old || null }); },
    updateProfile: function (id, t, o) { return SB.rpc('update_profile', { p_id: id, p_token: t, p: o }); },

    adminOverview: function (code) { return SB.rpc('admin_overview', { p_code: code }); },
    adminProviders: function (code, f) {
      f = f || {};
      return SB.rpc('admin_providers', { p_code: code, p_q: f.q || '', p_status: f.status || '', p_service: f.service || '', p_city: f.city || '', p_limit: f.limit || 30, p_offset: f.offset || 0 });
    },
    adminUpdateProvider: function (code, id, o) { return SB.rpc('admin_update_provider', { p_code: code, p_id: id, p: o }); },
    adminCreateProvider: function (code, o) { return SB.rpc('admin_create_provider', { p_code: code, p: o }); },
    adminResetPassword: function (code, id, pw) { return SB.rpc('admin_reset_password', { p_code: code, p_id: id, p_password: pw }); },
    adminDeleteProvider: function (code, id) { return SB.rpc('admin_delete_provider', { p_code: code, p_id: id }); },
    adminRequests: function (code, limit, status) { return SB.rpc('admin_requests', { p_code: code, p_limit: limit || 100, p_status: status || '' }); },
    adminServices: function (code) { return SB.rpc('admin_services', { p_code: code }); },
    adminSaveService: function (code, id, name, icon, active, cat) { return SB.rpc('admin_save_service', { p_code: code, p_id: id || '', p_name: name, p_icon: icon || '', p_active: active == null ? true : !!active, p_cat: cat == null ? null : cat }); },
    adminSetVerified: function (code, id, v) { return SB.rpc('admin_set_verified', { p_code: code, p_id: id, p_value: !!v }); },
    adminReorderServices: function (code, ids) { return SB.rpc('admin_reorder_services', { p_code: code, p_ids: ids }); },
    adminDeleteService: function (code, id) { return SB.rpc('admin_delete_service', { p_code: code, p_id: id }); },
    adminGetSettings: function (code) { return SB.rpc('admin_get_settings', { p_code: code }); },
    adminSaveSettings: function (code, o) { return SB.rpc('admin_save_settings', { p_code: code, p: o }); },
    adminChangeCode: function (code, nw) { return SB.rpc('admin_change_code', { p_code: code, p_new: nw }); }
  };

  if (C.mode === 'supabase' && C.supabaseUrl && C.supabaseKey) {
    SQ.db = SB; SQ.demo = false;
  } else {
    L.init(); SQ.db = L; SQ.demo = true;
  }

  /* قائمة الخدمات يديرها المدير: تُحمَّل من القاعدة وتُخزَّن نسخة للعمل بلا إنترنت */
  var SKEY = 'sq_services_cache';
  SQ.hasServicesCache = false;
  try {
    var cached = JSON.parse(localStorage.getItem(SKEY));
    if (cached && cached.length) { SQ.SERVICES = cached; SQ.hasServicesCache = true; }
  } catch (e) {}
  SQ.refreshServices = async function () {
    try {
      var list = await SQ.db.listServices();
      if (list && list.length) { SQ.SERVICES = list; try { localStorage.setItem(SKEY, JSON.stringify(list)); } catch (e) {} }
    } catch (e) {}
  };
})();
