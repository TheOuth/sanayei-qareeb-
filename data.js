/* صنايعي قريب - البيانات الثابتة والإعدادات
   لإضافة دولة جديدة: أضف عنصرا في SQ.COUNTRIES ثم غيّر CONFIG.countryCode. */
(function () {
  'use strict';
  var SQ = (window.SQ = window.SQ || {});

  SQ.CONFIG = {
    appName: 'صنايعي قريب',
    tagline: 'خدمتك لحدي بيتك',
    countryCode: 'SD',
    // 'demo' = يعمل محليا على الجهاز ببيانات تجريبية | 'supabase' = قاعدة بيانات حقيقية
    mode: 'supabase',
    supabaseUrl: 'https://pwqtvixjkpvyajqmfqpa.supabase.co',
    supabaseKey: 'sb_publishable_sFHW2864oPilfQvjs3txaA__QjKY0sG', // مفتاح عام آمن للنشر
    adminCode: '1234', // للوضع التجريبي فقط (mode: 'demo'). في Supabase يُحفظ رمز المدير في جدول app_settings
    availableTimeoutHours: 6, // يتحول الصنايعي إلى غير متاح لو لم يفتح التطبيق هذه المدة
    speedKmh: 25, // لحساب زمن الوصول التقريبي داخل المدينة
    minReviewsForStars: 3, // تظهر النجوم بعد هذا العدد من التقييمات
    reviewDelayHours: 24, // يسأل التطبيق عن الشغلانة بعد هذه المدة
    supportWhatsapp: '' // رقم دعم واتساب بصيغة 249XXXXXXXXX (اختياري)
  };

  SQ.SERVICES = [
    { id: 'plumbing', name: 'سباكة', icon: '🔧' },
    { id: 'electric', name: 'كهرباء', icon: '⚡' },
    { id: 'solar', name: 'طاقة شمسية وبطاريات', icon: '☀️' },
    { id: 'ac', name: 'تكييف وتبريد', icon: '❄️' },
    { id: 'carpentry', name: 'نجارة', icon: '📐' },
    { id: 'blacksmith', name: 'حدادة', icon: '🔨' },
    { id: 'paint', name: 'نقاشة ودهان', icon: '🎨' },
    { id: 'building', name: 'بناء وسيراميك', icon: '🧱' },
    { id: 'generator', name: 'مولدات', icon: '⚙️' },
    { id: 'water', name: 'مضخات ومياه وآبار', icon: '💧' },
    { id: 'mobile', name: 'صيانة موبايلات', icon: '📱' },
    { id: 'appliance', name: 'صيانة أجهزة كهربائية', icon: '🔌' },
    { id: 'transport', name: 'توصيل ونقل', icon: '🚚' },
    { id: 'cleaning', name: 'نظافة منزلية', icon: '🧹' },
    { id: 'tailor', name: 'خياطة', icon: '🧵' },
    { id: 'barber', name: 'حلاقة وتجميل منزلي', icon: '💈' },
    { id: 'locks', name: 'أقفال ومفاتيح', icon: '🔑' },
    { id: 'other', name: 'أخرى', icon: '➕' }
  ];

  function c(id, name, lat, lng) { return { id: id, name: name, lat: lat, lng: lng }; }

  SQ.COUNTRIES = {
    SD: {
      name: 'السودان',
      dial: '+249',
      currency: 'جنيه',
      // رقم الموبايل السوداني: 9 أرقام تبدأ بـ 9 أو 1
      phoneRegex: /^[19]\d{8}$/,
      phoneHint: '09xxxxxxxx',
      states: [
        { id: 'khartoum', name: 'الخرطوم', cities: [c('khartoum', 'الخرطوم', 15.5007, 32.5599), c('omdurman', 'أم درمان', 15.6445, 32.4777), c('bahri', 'بحري', 15.6333, 32.5333)] },
        { id: 'red_sea', name: 'البحر الأحمر', cities: [c('port_sudan', 'بورتسودان', 19.6158, 37.2164), c('suakin', 'سواكن', 19.1059, 37.3321)] },
        { id: 'gezira', name: 'الجزيرة', cities: [c('wad_madani', 'ود مدني', 14.4012, 33.5199), c('hasahisa', 'الحصاحيصا', 14.7833, 33.3833), c('managil', 'المناقل', 14.25, 32.9833)] },
        { id: 'river_nile', name: 'نهر النيل', cities: [c('atbara', 'عطبرة', 17.702, 33.9861), c('shendi', 'شندي', 16.6833, 33.4333), c('damer', 'الدامر', 17.5917, 33.9722)] },
        { id: 'northern', name: 'الشمالية', cities: [c('dongola', 'دنقلا', 19.1651, 30.4764), c('merowe', 'مروي', 18.4833, 31.8167), c('halfa', 'وادي حلفا', 21.8, 31.35)] },
        { id: 'white_nile', name: 'النيل الأبيض', cities: [c('rabak', 'ربك', 13.1833, 32.7333), c('kosti', 'كوستي', 13.1667, 32.6667), c('duwaym', 'الدويم', 13.995, 32.3139)] },
        { id: 'blue_nile', name: 'النيل الأزرق', cities: [c('damazin', 'الدمازين', 11.7891, 34.3592), c('roseires', 'الروصيرص', 11.85, 34.3833)] },
        { id: 'sennar', name: 'سنار', cities: [c('sennar', 'سنار', 13.55, 33.6167), c('singa', 'سنجة', 13.15, 33.9333)] },
        { id: 'gedaref', name: 'القضارف', cities: [c('gedaref', 'القضارف', 14.0348, 35.3836)] },
        { id: 'kassala', name: 'كسلا', cities: [c('kassala', 'كسلا', 15.45, 36.4), c('girba', 'خشم القربة', 14.95, 35.9)] },
        { id: 'n_kordofan', name: 'شمال كردفان', cities: [c('obeid', 'الأبيض', 13.1833, 30.2167)] },
        { id: 's_kordofan', name: 'جنوب كردفان', cities: [c('kadugli', 'كادقلي', 11.0167, 29.7167), c('dilling', 'الدلنج', 11.8667, 29.65)] },
        { id: 'w_kordofan', name: 'غرب كردفان', cities: [c('fula', 'الفولة', 11.9983, 28.355), c('nuhud', 'النهود', 12.7, 28.4333)] },
        { id: 'n_darfur', name: 'شمال دارفور', cities: [c('fasher', 'الفاشر', 13.6289, 25.3493), c('kutum', 'كتم', 14.2, 24.6667)] },
        { id: 's_darfur', name: 'جنوب دارفور', cities: [c('nyala', 'نيالا', 12.0489, 24.8807)] },
        { id: 'e_darfur', name: 'شرق دارفور', cities: [c('daein', 'الضعين', 11.46, 26.13)] },
        { id: 'c_darfur', name: 'وسط دارفور', cities: [c('zalingei', 'زالنجي', 12.91, 23.47)] },
        { id: 'w_darfur', name: 'غرب دارفور', cities: [c('geneina', 'الجنينة', 13.45, 22.45)] }
      ]
    }
  };

  var COUNTRY = (SQ.COUNTRY = SQ.COUNTRIES[SQ.CONFIG.countryCode]);

  var cityIdx = {};
  COUNTRY.states.forEach(function (s) {
    s.cities.forEach(function (ct) { cityIdx[ct.id] = { state: s, city: ct }; });
  });

  SQ.findCity = function (id) { return cityIdx[id] || null; };
  SQ.cityName = function (id) { return cityIdx[id] ? cityIdx[id].city.name : ''; };
  SQ.stateName = function (id) {
    for (var i = 0; i < COUNTRY.states.length; i++) if (COUNTRY.states[i].id === id) return COUNTRY.states[i].name;
    return '';
  };
  SQ.cities = function (stateId) {
    for (var i = 0; i < COUNTRY.states.length; i++) if (COUNTRY.states[i].id === stateId) return COUNTRY.states[i].cities;
    return [];
  };

  SQ.util = {
    // يرجع +249XXXXXXXXX أو null لو الرقم غير صحيح
    normalizePhone: function (raw) {
      var d = String(raw || '').replace(/[٠-٩]/g, function (x) { return String(x.charCodeAt(0) - 1632); }).replace(/\D/g, '');
      var dial = COUNTRY.dial.replace('+', '');
      if (d.indexOf(dial) === 0) d = d.slice(dial.length);
      if (d.charAt(0) === '0') d = d.slice(1);
      return COUNTRY.phoneRegex.test(d) ? COUNTRY.dial + d : null;
    },
    digits: function (phone) { return String(phone || '').replace(/\D/g, ''); }
  };
})();
