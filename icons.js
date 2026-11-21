/* مكتبة أيقونات موحّدة (خطوط ناعمة بسُمك واحد) بدل الإيموجي */
(function () {
  'use strict';
  var SQ = window.SQ;
  var P = {
    search: '<circle cx="11" cy="11" r="6.5"/><path d="M16 16l4.5 4.5"/>',
    pin: '<path d="M12 21s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0c0 5.4-6.5 11-6.5 11z"/><circle cx="12" cy="10" r="2.3"/>',
    dots: '<circle cx="12" cy="5.5" r="1.4"/><circle cx="12" cy="12" r="1.4"/><circle cx="12" cy="18.5" r="1.4"/>',
    back: '<path d="M9 5l7 7-7 7"/>',
    chev: '<path d="M15 5l-7 7 7 7"/>',
    x: '<path d="M6 6l12 12M18 6L6 18"/>',
    home: '<path d="M4 11l8-6.5 8 6.5v8.5a1 1 0 0 1-1 1h-4.5v-6h-5v6H5a1 1 0 0 1-1-1z"/>',
    user: '<circle cx="12" cy="8.5" r="3.8"/><path d="M4.5 20c.8-3.6 3.8-5.5 7.5-5.5s6.7 1.9 7.5 5.5"/>',
    wrench: '<path d="M14.7 6.3a4 4 0 0 0-5.4 5.1L3.8 17a1.9 1.9 0 0 0 2.7 2.7l5.6-5.5a4 4 0 0 0 5.1-5.4l-2.6 2.6-2.5-.6-.6-2.5z"/>',
    client: '<circle cx="10.5" cy="10.5" r="6"/><path d="M15 15l5 5M8 10.5h5M10.5 8v5"/>',
    star: '<path d="M12 3.6l2.5 5.3 5.8.7-4.3 4 1.2 5.8L12 16.5l-5.2 2.9L8 13.6l-4.3-4 5.8-.7z"/>',
    phone: '<path d="M5.2 4h3.2l1.6 4.1-2 1.4a11 11 0 0 0 5.5 5.5l1.4-2 4.1 1.6v3.2a2 2 0 0 1-2.1 2A15.5 15.5 0 0 1 3.2 6.1 2 2 0 0 1 5.2 4z"/>',
    chat: '<path d="M4 20l1.3-4.2A8 8 0 1 1 8.2 18.8z"/><path d="M9 9.5c.3 2 2.2 4 4.5 4.5l1.2-1.2-1.8-1-.8.7a3 3 0 0 1-1.6-1.6l.7-.8-1-1.8z"/>',
    shield: '<path d="M12 3l7 3v5.2c0 4.3-2.9 7.7-7 9.8-4.1-2.1-7-5.5-7-9.8V6z"/><path d="M8.8 12.2l2.2 2.2 4.2-4.4"/>',
    clock: '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
    gift: '<rect x="4" y="9" width="16" height="11" rx="1.5"/><path d="M12 9v11M4 13h16M12 9c-2.5 0-4-1-4-2.5S9.5 4 12 9zM12 9c2.5 0 4-1 4-2.5S14.5 4 12 9z"/>',
    camera: '<path d="M4 8h3l1.5-2h7L17 8h3v11H4z"/><circle cx="12" cy="13" r="3.4"/>',
    check: '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    out: '<path d="M10 4H5v16h5M15 8l4 4-4 4M19 12H9"/>',
    edit: '<path d="M4 20h4L19 9l-4-4L4 16z"/>',
    lock: '<rect x="5" y="10.5" width="14" height="9.5" rx="2"/><path d="M8.5 10.5V8a3.5 3.5 0 0 1 7 0v2.5"/>',
    share: '<circle cx="6.5" cy="12" r="2.3"/><circle cx="17" cy="6.5" r="2.3"/><circle cx="17" cy="17.5" r="2.3"/><path d="M8.6 11l6.3-3.4M8.6 13l6.3 3.4"/>',
    /* خدمات */
    plumbing: '<path d="M3.5 7.5h9a4 4 0 0 1 4 4V15"/><path d="M3.5 5v5"/><path d="M16.5 21c-1.3 0-2.1-.9-2.1-2.1 0-1.2 2.1-3.4 2.1-3.4s2.1 2.2 2.1 3.4c0 1.2-.8 2.1-2.1 2.1z"/>',
    electric: '<path d="M13.2 2.5L5.5 13.5h6L10.5 21.5l8-11.5h-6z"/>',
    solar: '<circle cx="12" cy="8.5" r="3"/><path d="M12 2.5V4M5.8 5.3l1 1M18.2 5.3l-1 1M3 8.5h1.5M19.5 8.5H21"/><path d="M4 20.5l2-5.5h12l2 5.5z"/><path d="M8.3 15l-.9 5.5M12 15v5.5M15.7 15l.9 5.5"/>',
    ac: '<path d="M12 3v18M4.2 7.5l15.6 9M4.2 16.5l15.6-9"/><path d="M9.8 4.7L12 6.4l2.2-1.7M9.8 19.3L12 17.6l2.2 1.7"/>',
    carpentry: '<path d="M4.5 19.5V4.5l15 15z"/><path d="M8 19.5v-2.2M11.5 19.5v-3.8M7.5 12.2H9.8M7.5 8.7h2.3"/>',
    blacksmith: '<path d="M13.5 4.5l6 6-2.6 2.6-6-6z"/><path d="M11.6 8.4L4.5 15.5a1.9 1.9 0 0 0 2.7 2.7l7.1-7.1"/>',
    paint: '<rect x="4.5" y="3.5" width="13" height="5" rx="1.3"/><path d="M17.5 6h2v5.5h-7.5v3"/><path d="M12 14.5v6"/>',
    building: '<rect x="3.5" y="6" width="17" height="12.5" rx="1"/><path d="M3.5 10.2h17M3.5 14.3h17M9 6v4.2M15 10.2v4.1M9 14.3v4.2"/>',
    generator: '<circle cx="12" cy="12" r="3.4"/><path d="M12 3v3M12 18v3M3 12h3M18 12h3M5.6 5.6l2.1 2.1M16.3 16.3l2.1 2.1M18.4 5.6l-2.1 2.1M7.7 16.3l-2.1 2.1"/>',
    water: '<path d="M12 3.2s6 6.1 6 10.4a6 6 0 0 1-12 0c0-4.3 6-10.4 6-10.4z"/><path d="M9 14.2c1 1 2 1 3 0s2-1 3 0"/>',
    mobile: '<rect x="7" y="3" width="10" height="18" rx="2.2"/><path d="M10.5 18h3"/>',
    appliance: '<rect x="5" y="3" width="14" height="18" rx="2"/><circle cx="12" cy="13.5" r="4"/><path d="M8.2 6.5h.01M11 6.5h.01"/>',
    transport: '<path d="M2.8 6.8h10.7v9.4H2.8z"/><path d="M13.5 9.8h4l3.2 3.2v3.2h-7.2z"/><circle cx="7" cy="17.8" r="1.8"/><circle cx="17" cy="17.8" r="1.8"/>',
    cleaning: '<path d="M11 3.5l1.9 5.2 5.2 1.9-5.2 1.9L11 17.7l-1.9-5.2L3.9 10.6l5.2-1.9z"/><path d="M18.5 15.5l.8 2 2 .8-2 .8-.8 2-.8-2-2-.8 2-.8z"/>',
    tailor: '<circle cx="6.2" cy="6.8" r="2.5"/><circle cx="6.2" cy="17.2" r="2.5"/><path d="M8.2 8.3L20 18M8.2 15.7L20 6"/>',
    barber: '<path d="M8 3h8v3H8zM8 18h8v3H8z"/><path d="M9 6h6v12H9z"/><path d="M9 9.2l6-2M9 13l6-2M9 16.8l6-2"/>',
    locks: '<circle cx="8" cy="12" r="4"/><path d="M12 12h9M18 12v3M21 12v2.2"/>',
    other: '<rect x="4" y="4" width="7" height="7" rx="1.6"/><rect x="13" y="4" width="7" height="7" rx="1.6"/><rect x="4" y="13" width="7" height="7" rx="1.6"/><path d="M16.5 13.5v6M13.5 16.5h6"/>',
    /* تصنيفات */
    c_home: '<path d="M4 11l8-6.5 8 6.5v8.5a1 1 0 0 1-1 1h-4.5v-6h-5v6H5a1 1 0 0 1-1-1z"/>',
    c_energy: '<path d="M13.2 2.5L5.5 13.5h6L10.5 21.5l8-11.5h-6z"/>',
    c_devices: '<rect x="7" y="3" width="10" height="18" rx="2.2"/><path d="M10.5 18h3"/>',
    c_personal: '<path d="M11 3.5l1.9 5.2 5.2 1.9-5.2 1.9L11 17.7l-1.9-5.2L3.9 10.6l5.2-1.9z"/>',
    c_other: '<path d="M12 5v14M5 12h14"/>'
  };
  // الأيقونة: stroke للخطوط وتعبئة خفيفة للأشكال المغلقة
  SQ.I = function (name, size, cls) {
    var p = P[name]; if (!p) return '';
    var s = size || 22;
    return '<svg class="ico ' + (cls || '') + '" width="' + s + '" height="' + s + '" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + p + '</svg>';
  };
  SQ.hasIcon = function (name) { return !!P[name]; };
  // أيقونة خدمة: SVG إن وُجد، وإلا الإيموجي الذي اختاره المدير
  SQ.svcIcon = function (s, size) { return P[s.id] ? SQ.I(s.id, size || 26) : '<span class="emo">' + (s.icon || '🔧').replace(/</g, '&lt;') + '</span>'; };
  SQ.catIcon = function (c, size) { return SQ.I('c_' + c.id, size || 20); };
})();
