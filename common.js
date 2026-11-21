/* صنايعي قريب - أدوات واجهة مشتركة بين التطبيق ولوحة المدير */
(function () {
  'use strict';
  var SQ = window.SQ, U = (SQ.ui = {});

  U.esc = function (s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; });
  };
  U.on = function (id, ev, fn) { var el = document.getElementById(id); if (el) el.addEventListener(ev, fn); };
  U.each = function (sel, fn) { Array.prototype.forEach.call(document.querySelectorAll(sel), fn); };

  U.store = {
    get: function (k, d) { try { var v = localStorage.getItem('sq_' + k); return v == null ? d : JSON.parse(v); } catch (e) { return d; } },
    set: function (k, v) { try { localStorage.setItem('sq_' + k, JSON.stringify(v)); } catch (e) {} },
    del: function (k) { try { localStorage.removeItem('sq_' + k); } catch (e) {} }
  };

  var tt;
  U.toast = function (m) {
    var t = document.getElementById('toast'); if (!t) return;
    t.textContent = m; t.classList.add('show');
    clearTimeout(tt); tt = setTimeout(function () { t.classList.remove('show'); }, 3000);
  };

  /* الخدمات: كل الخدمات للعرض، والمفعّلة فقط للاختيار */
  U.svc = function (id) { return SQ.SERVICES.filter(function (s) { return s.id === id; })[0] || { id: id, name: id, icon: '➕', active: false }; };
  U.svcNames = function (a) { return (a || []).map(function (i) { return U.svc(i).name; }).join(' · '); };
  U.activeServices = function () { return SQ.SERVICES.filter(function (s) { return s.active !== false; }); };

  U.timeAgo = function (ts) {
    var m = Math.floor((Date.now() - ts) / 60e3);
    if (m < 1) return 'الآن'; if (m < 60) return 'قبل ' + m + ' دقيقة';
    var h = Math.floor(m / 60); if (h < 24) return 'قبل ' + h + ' ساعة';
    return 'قبل ' + Math.floor(h / 24) + ' يوم';
  };

  U.errMsg = function (e) {
    var m = (e && e.message) || '';
    var map = {
      duplicate: 'هذا الرقم مسجل من قبل', forbidden: 'غير مسموح', weak: 'كلمة السر قصيرة (6 أحرف أو أرقام على الأقل)',
      invalid: 'بيانات غير صحيحة', wrong_password: 'كلمة السر الحالية غير صحيحة', in_use: 'لا يمكن الحذف: الخدمة مستخدمة عند صنايعية، يمكنك إخفاؤها بدل ذلك',
      not_found: 'غير موجود', locked: 'تم إيقاف المحاولات مؤقتا، حاول بعد 15 دقيقة', already: 'تم هذا من قبل'
    };
    if (map[m]) return map[m];
    if (/duplicate key/i.test(m)) return map.duplicate;
    if (/Failed to fetch|NetworkError|Load failed/i.test(m)) return 'لا يوجد اتصال بالإنترنت، حاول مرة ثانية';
    return 'حصل خطأ، حاول مرة ثانية';
  };

  /* النافذة السفلية */
  function layer(id) {
    var m = document.getElementById(id);
    if (!m && id === 'modal2') { m = document.createElement('div'); m.id = 'modal2'; document.body.appendChild(m); }
    return m;
  }
  U.modal = function (html, nested) {
    var m = layer(nested ? 'modal2' : 'modal'); if (!m) return;
    m.innerHTML = '<div class="sheet">' + html + '</div>';
    m.onclick = function (e) { if (e.target === m) U.closeModal(nested); };
  };
  U.closeModal = function (nested) {
    var m = document.getElementById(nested === true ? 'modal2' : 'modal');
    if (m) { m.innerHTML = ''; m.onclick = null; }
  };

  /* الولاية والمدينة */
  U.stateOptions = function (sel) {
    return '<option value="">اختر الولاية</option>' + SQ.COUNTRY.states.map(function (s) {
      return '<option value="' + s.id + '"' + (s.id === sel ? ' selected' : '') + '>' + U.esc(s.name) + '</option>';
    }).join('');
  };
  U.cityOptions = function (sid, sel) {
    return '<option value="">اختر المدينة</option>' + SQ.cities(sid).map(function (c) {
      return '<option value="' + c.id + '"' + (c.id === sel ? ' selected' : '') + '>' + U.esc(c.name) + '</option>';
    }).join('');
  };
  U.bindStateCity = function (sId, cId) {
    var s = document.getElementById(sId), c = document.getElementById(cId);
    if (s && c) s.addEventListener('change', function () { c.innerHTML = U.cityOptions(s.value, ''); });
  };

  /* حقل الخدمات المنسدل (اختيار متعدد): arr تُعدَّل في مكانها */
  U.svcFieldHtml = function (id, label) {
    return '<div class="field"><span>' + U.esc(label || 'نوع الخدمة (يمكن اختيار أكثر من واحدة)') + '</span>' +
      '<button type="button" class="select" id="' + id + '"><span class="sv-text"></span><i>▾</i></button><div class="chips sv-chips" id="' + id + 'Chips"></div></div>';
  };
  U.bindSvcField = function (id, arr, onChange) {
    var btn = document.getElementById(id), chips = document.getElementById(id + 'Chips');
    if (!btn) return;
    function paint() {
      btn.querySelector('.sv-text').textContent = arr.length ? 'تم اختيار ' + arr.length + ' - اضغط للتعديل' : 'اضغط لاختيار الخدمات';
      chips.innerHTML = arr.map(function (i) { var s = U.svc(i); return '<span class="chip on">' + U.esc(s.icon) + ' ' + U.esc(s.name) + '</span>'; }).join('');
      if (onChange) onChange(arr);
    }
    paint();
    btn.addEventListener('click', function () {
      var list = U.activeServices().slice();
      arr.forEach(function (i) { if (!list.some(function (s) { return s.id === i; })) list.push(U.svc(i)); }); // خدمة معطّلة لكنه مسجل فيها
      var nest = !!(document.getElementById('modal') && document.getElementById('modal').innerHTML);
      U.modal('<h3>اختر الخدمات</h3><input class="search" id="svQ" placeholder="ابحث عن خدمة..." autocomplete="off">' +
        '<div class="slist" id="svList">' + list.map(function (s) {
          return '<label class="srow" data-n="' + U.esc(s.name) + '"><input type="checkbox" value="' + s.id + '"' + (arr.indexOf(s.id) > -1 ? ' checked' : '') + '><span class="si">' + U.esc(s.icon) + '</span><span>' + U.esc(s.name) + (s.active === false ? ' <small class="muted">(معطّلة)</small>' : '') + '</span></label>';
        }).join('') + '</div><button class="btn primary mt" id="svDone" style="width:100%">تم</button>', nest);
      U.on('svQ', 'input', function () {
        var q = this.value.trim();
        U.each('#svList .srow', function (r) { r.style.display = !q || r.getAttribute('data-n').indexOf(q) > -1 ? '' : 'none'; });
      });
      U.each('#svList input', function (c) {
        c.addEventListener('change', function () {
          var i = arr.indexOf(c.value);
          if (c.checked && i < 0) arr.push(c.value); else if (!c.checked && i > -1) arr.splice(i, 1);
          paint();
        });
      });
      U.on('svDone', 'click', function () { U.closeModal(nest); });
    });
  };

  /* حقل كلمة سر مع زر إظهار */
  U.pwHtml = function (id, label, hint) {
    return '<label class="field"><span>' + U.esc(label) + '</span><div class="pwbox"><input id="' + id + '" type="password" autocomplete="off" class="ltr"><button type="button" class="eye" data-for="' + id + '" aria-label="إظهار">👁</button></div>' + (hint ? '<small>' + U.esc(hint) + '</small>' : '') + '</label>';
  };
  document.addEventListener('click', function (e) {
    var b = e.target.closest && e.target.closest('.eye');
    if (!b) return;
    var i = document.getElementById(b.getAttribute('data-for'));
    if (i) i.type = i.type === 'password' ? 'text' : 'password';
  });

  U.randomPassword = function () {
    var a = 'abcdefghjkmnpqrstuvwxyz23456789', o = '';
    for (var i = 0; i < 8; i++) o += a.charAt(Math.floor(Math.random() * a.length));
    return o;
  };
})();
