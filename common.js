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
      invalid: 'بيانات غير صحيحة', invalid_phone: 'رقم الهاتف غير صحيح (مثال: 0912345678)', wrong_password: 'كلمة السر الحالية غير صحيحة', birth_required: 'اكتب تاريخ ميلادك', invalid_birth: 'تاريخ الميلاد غير صحيح', underage: 'التطبيق لمن عمره 18 سنة فأكثر', invalid_username: 'اسم المستخدم: 3 إلى 20 حرفا إنجليزيا صغيرا أو أرقاما أو _ ويبدأ بحرف', taken: 'اسم المستخدم محجوز، جرّب غيره', already: 'تم هذا من قبل', in_use: 'لا يمكن الحذف: الخدمة مستخدمة عند صنايعية، يمكنك إخفاؤها بدل ذلك',
      not_found: 'غير موجود', rate_limited: 'محاولات كثيرة في وقت قصير، حاول بعد قليل', locked: 'تم إيقاف المحاولات مؤقتا، حاول بعد 15 دقيقة', already: 'تم هذا من قبل'
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
  /* تصحيح رقم الهاتف تلقائيا عند مغادرة الحقل: يقبل 09x / 9x / 01x / +249 / 249 / 00249 ويعرضه بالشكل المحلي */
  document.addEventListener('focusout', function (e) {
    var i = e.target;
    if (!i || i.tagName !== 'INPUT' || !i.closest || !i.closest('.phone-wrap') || !i.value.trim()) return;
    var n = SQ.util.normalizePhone(i.value);
    i.classList.toggle('bad', !n);
    if (n) i.value = SQ.util.localPhone(n);
  });

  /* الصورة الشخصية: تُصغَّر في المتصفح إلى 128px تقريبا (حوالي 5 كيلوبايت) */
  U.avatar = function (p, cls) {
    var ini = U.esc(String(p.name || '').replace(/^م\.\s*/, '').charAt(0));
    return '<div class="ava ' + (cls || '') + '">' + (p.photo ? '<img alt="" src="' + U.esc(p.photo) + '">' : ini) + '</div>';
  };
  U.shrinkImage = function (file) {
    return new Promise(function (resolve, reject) {
      var url = URL.createObjectURL(file), img = new Image();
      img.onload = function () {
        try {
          var S = 128, side = Math.min(img.width, img.height), cv = document.createElement('canvas');
          cv.width = cv.height = S;
          var g = cv.getContext('2d'); g.fillStyle = '#fff'; g.fillRect(0, 0, S, S);
          g.drawImage(img, (img.width - side) / 2, (img.height - side) / 2, side, side, 0, 0, S, S);
          var q = 0.62, out = cv.toDataURL('image/jpeg', q);
          while (out.length > 14000 && q > 0.3) { q -= 0.08; out = cv.toDataURL('image/jpeg', q); }
          URL.revokeObjectURL(url); resolve(out);
        } catch (e) { reject(e); }
      };
      img.onerror = function () { URL.revokeObjectURL(url); reject(new Error('img')); };
      img.src = url;
    });
  };
  /* تاريخ الميلاد: 18 سنة فأكثر */
  U.maxBirth = function () { var d = new Date(); d.setFullYear(d.getFullYear() - 18); return d.toISOString().slice(0, 10); };
  U.ageOf = function (s) { if (!s) return null; var b = new Date(s), n = new Date(); if (isNaN(b)) return null; var a = n.getFullYear() - b.getFullYear(); if (n.getMonth() < b.getMonth() || (n.getMonth() === b.getMonth() && n.getDate() < b.getDate())) a--; return a; };
  U.MONTHS = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
  U.birthHtml = function (id, value, hint) {
    var p = String(value || '').split('-'), y = +p[0] || 0, m = +p[1] || 0, d = +p[2] || 0, top = new Date().getFullYear() - 18, o;
    o = '<option value="">اليوم</option>'; for (var i = 1; i <= 31; i++) o += '<option value="' + i + '"' + (i === d ? ' selected' : '') + '>' + i + '</option>';
    var dd = '<select id="' + id + '_d" aria-label="اليوم">' + o + '</select>';
    o = '<option value="">الشهر</option>'; U.MONTHS.forEach(function (n, k) { o += '<option value="' + (k + 1) + '"' + (k + 1 === m ? ' selected' : '') + '>' + n + '</option>'; });
    var mm = '<select id="' + id + '_m" aria-label="الشهر">' + o + '</select>';
    o = '<option value="">السنة</option>'; for (var yy = top; yy >= 1950; yy--) o += '<option value="' + yy + '"' + (yy === y ? ' selected' : '') + '>' + yy + '</option>';
    var yr = '<select id="' + id + '_y" aria-label="السنة">' + o + '</select>';
    return '<div class="field birth"><span>تاريخ الميلاد (18 سنة فأكثر)</span><div class="bsel">' + dd + mm + yr + '</div>' +
      '<small>' + (hint || 'اكتب تاريخ ميلادك الحقيقي، فسيُطابَق مع وثيقتك عند التوثيق. يظهر عمرك فقط للزبائن، ولا يظهر التاريخ.') + '</small></div>';
  };
  U.birthVal = function (id) {
    var g = function (k) { var e = document.getElementById(id + '_' + k); return e ? e.value : ''; }, y = g('y'), m = g('m'), d = g('d');
    if (!y || !m || !d) return '';
    var dt = new Date(+y, +m - 1, +d); if (dt.getMonth() !== +m - 1) return 'bad';
    return y + '-' + ('0' + m).slice(-2) + '-' + ('0' + d).slice(-2);
  };
  U.birthErr = function (v, required) {
    if (v === 'bad') return 'هذا اليوم غير موجود في الشهر المختار';
    if (!v) return required ? 'اختر اليوم والشهر والسنة' : '';
    var a = U.ageOf(v); if (a == null || a > 90 || new Date(v) > new Date()) return 'تاريخ الميلاد غير صحيح';
    if (a < 18) return 'التطبيق لمن عمره 18 سنة فأكثر';
    return '';
  };
  U.photoHtml = function (id, name) {
    return '<div class="field photofield"><span>الصورة الشخصية (اختياري، تزيد ثقة الزبائن وترفع ترتيبك)</span><div class="photorow">' +
      '<div id="' + id + 'Prev"></div><div><label class="btn ghost small" for="' + id + 'In">📷 اختيار صورة</label>' +
      '<input id="' + id + 'In" type="file" accept="image/*" hidden><button type="button" class="btn ghost small" id="' + id + 'Del" style="margin-top:6px">إزالة</button></div></div></div>';
  };
  // state = { photo: '', name: '' } يُعدَّل في مكانه
  U.bindPhoto = function (id, state, onChange) {
    function paint() {
      document.getElementById(id + 'Prev').innerHTML = U.avatar({ name: state.name || '؟', photo: state.photo }, 'big');
      var d = document.getElementById(id + 'Del'); if (d) d.style.display = state.photo ? '' : 'none';
    }
    paint();
    U.on(id + 'In', 'change', async function () {
      var f = this.files && this.files[0]; if (!f) return;
      try { state.photo = await U.shrinkImage(f); paint(); if (onChange) onChange(state.photo); }
      catch (e) { U.toast('تعذر قراءة الصورة، جرّب صورة أخرى'); }
      this.value = '';
    });
    U.on(id + 'Del', 'click', function () { state.photo = ''; paint(); if (onChange) onChange(''); });
  };
})();