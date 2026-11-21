/* صنايعي قريب - لوحة المدير (صفحة منفصلة، غير مرتبطة بالتطبيق العام) */
(function () {
  'use strict';
  var SQ = window.SQ, C = SQ.CONFIG, db = SQ.db, $app = document.getElementById('app');
  var code = '', tab = 'pending';
  try { code = sessionStorage.getItem('sq_admin') || ''; } catch (e) {}

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; });
  }
  var tt;
  function toast(m) {
    var t = document.getElementById('toast'); t.textContent = m; t.classList.add('show');
    clearTimeout(tt); tt = setTimeout(function () { t.classList.remove('show'); }, 2800);
  }
  function on(id, ev, fn) { var el = document.getElementById(id); if (el) el.addEventListener(ev, fn); }
  function svcNames(a) {
    return (a || []).map(function (i) { var s = SQ.SERVICES.filter(function (x) { return x.id === i; })[0]; return s ? s.name : i; }).join(' · ');
  }
  function ago(ts) {
    var h = Math.floor((Date.now() - ts) / 3600e3);
    return h < 1 ? 'قبل قليل' : h < 24 ? 'قبل ' + h + ' ساعة' : 'قبل ' + Math.floor(h / 24) + ' يوم';
  }
  function page(title, body, foot, logout) {
    $app.innerHTML = '<header class="top"><span class="back ghost"></span><h1>' + esc(title) + '</h1>' +
      (logout ? '<button class="back" id="out" aria-label="خروج" title="خروج">⏻</button>' : '<span class="back ghost"></span>') + '</header>' +
      '<main class="main">' + body + '</main>' + (foot ? '<div class="foot">' + foot + '</div>' : '');
    on('out', 'click', function () { code = ''; try { sessionStorage.removeItem('sq_admin'); } catch (e) {} render(); });
  }

  function login() {
    page('إدارة صنايعي قريب',
      '<label class="field"><span>رمز المدير</span><input id="code" type="password" class="ltr" autocomplete="current-password" autofocus></label>' +
      (SQ.demo ? '<p class="note">وضع تجريبي: الرمز ' + esc(C.adminCode) + '</p>' : ''),
      '<button class="btn primary" id="ok">دخول</button>');
    var go = async function () {
      var v = document.getElementById('code').value.trim();
      if (!v) return;
      var b = document.getElementById('ok'); b.disabled = true;
      try { await db.adminCheck(v); code = v; try { sessionStorage.setItem('sq_admin', v); } catch (e) {} render(); }
      catch (e) { b.disabled = false; toast('الرمز غير صحيح'); }
    };
    on('ok', 'click', go);
    on('code', 'keydown', function (e) { if (e.key === 'Enter') go(); });
  }

  async function panel() {
    page('لوحة المدير', '<div class="spin">جاري التحميل...</div>', '', true);
    var stats, list = [], reps = [];
    try {
      stats = await db.adminStats(code);
      if (tab === 'reports') reps = await db.adminReports(code); else list = await db.adminList(code, tab);
    } catch (e) {
      if (/forbidden/i.test(e.message || '')) { code = ''; try { sessionStorage.removeItem('sq_admin'); } catch (x) {} toast('انتهت الجلسة'); return login(); }
      page('لوحة المدير', '<div class="empty"><div class="big">📶</div>تعذر الاتصال<div class="mt"><button class="btn primary" id="retry">إعادة المحاولة</button></div></div>', '', true);
      return on('retry', 'click', render);
    }
    var tabs = [['pending', 'طلبات الانضمام (' + stats.pending + ')'], ['approved', 'المعتمدون'], ['suspended', 'الموقوفون'], ['rejected', 'المرفوضون'], ['reports', 'البلاغات (' + stats.reports + ')']];
    var body = '<div class="stats"><div class="stat"><b>' + stats.providers + '</b><small>صنايعي معتمد</small></div><div class="stat"><b>' + stats.requests_week + '</b><small>طلبات الأسبوع</small></div><div class="stat"><b>' + stats.pending + '</b><small>بانتظار الموافقة</small></div></div>' +
      '<div class="tabs">' + tabs.map(function (t) { return '<button class="chip' + (tab === t[0] ? ' on' : '') + '" data-t="' + t[0] + '">' + t[1] + '</button>'; }).join('') + '</div>';
    if (tab === 'reports') {
      body += reps.length ? reps.map(function (r) {
        return '<div class="card"><div class="pname">' + esc(r.provider_name) + '</div><div class="psvc">السبب: ' + esc(r.reason) + ' · ' + ago(r.ts) + '</div><div class="btnrow">' +
          (r.provider_status === 'approved' ? '<button class="btn danger" data-act="suspended" data-id="' + r.provider_id + '">إيقاف الصنايعي</button>' : '') +
          '<button class="btn ghost" data-act="resolve" data-id="' + r.id + '">تم الحل</button></div></div>';
      }).join('') : '<div class="empty"><div class="big">✔</div>لا توجد بلاغات</div>';
    } else {
      body += list.length ? list.map(function (p) {
        var wa = 'https://wa.me/' + SQ.util.digits(p.whatsapp) + '?text=' + encodeURIComponent('السلام عليكم ' + p.name + '، معك مدير ' + C.appName + '. وصلنا طلب تسجيلك، نرجو تأكيد أنك صاحب هذا الرقم وأن بياناتك صحيحة.');
        return '<div class="card"><div class="pname">' + esc(p.name) + '</div><div class="psvc">' + esc(svcNames(p.services)) + '</div>' +
          '<div class="meta"><span>📞 <span class="ltr">' + esc(p.phone) + '</span></span><span>📍 ' + esc((p.hood ? p.hood + '، ' : '') + SQ.cityName(p.city_id)) + '</span><span>' + p.experience + ' سنة</span><span>💰 ' + Number(p.price).toLocaleString('en') + '</span></div>' +
          (p.bio ? '<p class="note">' + esc(p.bio) + '</p>' : '') +
          '<div class="btnrow"><a class="btn wa" href="' + wa + '" target="_blank" rel="noopener">تواصل واتساب</a>' +
          (p.status === 'pending' ? '<button class="btn primary" data-act="approved" data-id="' + p.id + '">موافقة</button><button class="btn danger" data-act="rejected" data-id="' + p.id + '">رفض</button>' : '') +
          (p.status === 'approved' ? '<button class="btn danger" data-act="suspended" data-id="' + p.id + '">إيقاف</button>' : '') +
          ((p.status === 'suspended' || p.status === 'rejected') ? '<button class="btn primary" data-act="approved" data-id="' + p.id + '">اعتماد</button>' : '') + '</div></div>';
      }).join('') : '<div class="empty"><div class="big">✔</div>لا يوجد شيء هنا</div>';
    }
    page('لوحة المدير', body, '', true);
    Array.prototype.forEach.call(document.querySelectorAll('.tabs .chip'), function (c) { c.addEventListener('click', function () { tab = c.getAttribute('data-t'); render(); }); });
    Array.prototype.forEach.call(document.querySelectorAll('[data-act]'), function (b) {
      b.addEventListener('click', async function () {
        var a = b.getAttribute('data-act'), id = b.getAttribute('data-id');
        if (a === 'rejected' && !confirm('رفض هذا الطلب؟')) return;
        if (a === 'suspended' && !confirm('إيقاف هذا الصنايعي؟')) return;
        b.disabled = true;
        try {
          if (a === 'resolve') await db.adminResolveReport(code, id); else await db.adminSetStatus(code, id, a);
          toast('تم'); render();
        } catch (e) { b.disabled = false; toast('حصل خطأ، حاول مرة ثانية'); }
      });
    });
  }

  function render() { return code ? panel() : login(); }
  render();
})();
