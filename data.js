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

  // تصنيفات الخدمات (المدير يحدد تصنيف كل خدمة من لوحته)
  /* شارات الإنجاز حسب عدد الأعمال المؤكدة (عملاء مختلفون قالوا "تمت الخدمة") */
  SQ.TIERS = [{ id: 'gold', min: 25, name: 'ذهبي' }, { id: 'blue', min: 10, name: 'متميز' }, { id: 'gray', min: 3, name: 'منجز' }];
  SQ.tierOf = function (jobs) { jobs = +jobs || 0; for (var i = 0; i < SQ.TIERS.length; i++) if (jobs >= SQ.TIERS[i].min) return SQ.TIERS[i]; return null; };
  SQ.nextTier = function (jobs) { jobs = +jobs || 0; var n = null; for (var i = SQ.TIERS.length - 1; i >= 0; i--) if (jobs < SQ.TIERS[i].min) { n = SQ.TIERS[i]; break; } return n; };

  SQ.CATEGORIES = [
    { id: 'home', name: 'البيت والصيانة', icon: '🏠', color: '#2B8CF0' },
    { id: 'energy', name: 'الطاقة والمياه', icon: '⚡', color: '#F08C2B' },
    { id: 'devices', name: 'الأجهزة والإلكترونيات', icon: '📱', color: '#6D5BEF' },
    { id: 'personal', name: 'خدمات منزلية وشخصية', icon: '🧹', color: '#E0508F' },
    { id: 'other', name: 'أخرى', icon: '➕', color: '#5B6F86' }
  ];
  var CAT_DEFAULT = { plumbing: 'home', electric: 'home', ac: 'home', carpentry: 'home', blacksmith: 'home', paint: 'home', building: 'home', locks: 'home',
    solar: 'energy', generator: 'energy', water: 'energy', mobile: 'devices', appliance: 'devices', cleaning: 'personal', tailor: 'personal', barber: 'personal', transport: 'personal' };
  SQ.KEYWORDS = { plumbing: 'سباك مواسير حنفية تسريب مياه صرف', electric: 'كهربائي كهرباء اسلاك فيوز', solar: 'طاقة شمسية الواح بطاريات انفرتر',
    ac: 'تكييف مكيف تبريد ثلاجة فريون', carpentry: 'نجار اثاث ابواب خشب', blacksmith: 'حداد ابواب شبابيك لحام', paint: 'نقاش دهان صبغ',
    building: 'بناء معلم سيراميك بلاط طوب', generator: 'مولد مولدات', water: 'مضخة بئر ماء طلمبة', mobile: 'موبايل هاتف جوال شاشة', appliance: 'غسالة ثلاجة اجهزة',
    transport: 'نقل توصيل عفش شحن', cleaning: 'نظافة تنظيف', tailor: 'خياط ترزي خياطة', barber: 'حلاق تجميل', locks: 'قفل مفتاح' };
  SQ.catOf = function (s) {
    var id = s.cat || CAT_DEFAULT[s.id] || 'other';
    for (var i = 0; i < SQ.CATEGORIES.length; i++) if (SQ.CATEGORIES[i].id === id) return SQ.CATEGORIES[i];
    return SQ.CATEGORIES[SQ.CATEGORIES.length - 1];
  };

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

  // مدن ومناطق إضافية لكل ولاية (الإحداثيات تقريبية لمركز المنطقة، ودقة GPS أفضل عند السماح بالموقع)
  var MORE = {
    khartoum: [['kh_riyadh', 'الرياض', 15.5735, 32.576], ['kh_sahafa', 'الصحافة', 15.539, 32.556], ['kh_jabra', 'جبرة', 15.5, 32.53], ['kh_jereif', 'الجريف', 15.55, 32.58],
      ['kh_kalakla', 'الكلاكلة', 15.43, 32.5], ['kh_azhari', 'الأزهري', 15.46, 32.5], ['kh_mayo', 'مايو', 15.43, 32.55], ['kh_souba', 'سوبا', 15.5, 32.65],
      ['kh_jebel_awlia', 'جبل أولياء', 15.25, 32.5], ['kh_east_nile', 'شرق النيل', 15.62, 32.62], ['kh_haj_yousif', 'الحاج يوسف', 15.62, 32.67], ['kh_bari', 'بري', 15.6, 32.6],
      ['kh_umbada', 'أم بدة', 15.65, 32.42], ['kh_karari', 'كرري', 15.72, 32.45], ['kh_thawra', 'الثورة', 15.62, 32.47], ['kh_shambat', 'شمبات', 15.65, 32.53],
      ['kh_droshab', 'الدروشاب', 15.72, 32.55], ['kh_halfaya', 'الحلفايا', 15.7, 32.5], ['kh_kadro', 'الكدرو', 15.78, 32.55]],
    red_sea: [['rs_tokar', 'طوكر', 18.43, 37.73], ['rs_haya', 'هيا', 18.33, 36.33], ['rs_arkawit', 'أركويت', 18.78, 37.07]],
    gezira: [['gz_kamlin', 'الكاملين', 15.1, 32.98], ['gz_umalqura', 'أم القرى', 14.75, 33.1], ['gz_abunaama', 'أبو نعامة', 13.5, 33.9]],
    river_nile: [['rn_berber', 'بربر', 18.02, 33.98], ['rn_abuhamad', 'أبو حمد', 19.53, 33.33], ['rn_metema', 'المتمة', 16.72, 33.43]],
    northern: [['nr_karima', 'كريمة', 18.55, 31.85], ['nr_delgo', 'دلقو', 20.13, 30.58]],
    white_nile: [['wn_jabalain', 'الجبلين', 12.47, 32.78], ['wn_qutaina', 'القطينة', 13.17, 32.43]],
    blue_nile: [['bn_kurmuk', 'الكرمك', 10.55, 34.28], ['bn_geissan', 'قيسان', 10.27, 34.28]],
    gedaref: [['gd_doka', 'دوكة', 13.52, 35.77], ['gd_galabat', 'القلابات', 12.97, 36.15]],
    kassala: [['ks_newhalfa', 'حلفا الجديدة', 15.32, 35.6]],
    n_kordofan: [['nk_bara', 'بارا', 13.7, 30.4], ['nk_umrawaba', 'أم روابة', 12.9, 31.2], ['nk_rahad', 'الرهد', 12.7, 30.65]],
    w_kordofan: [['wk_babanusa', 'بابنوسة', 11.33, 27.8], ['wk_muglad', 'المجلد', 11.03, 27.73]],
    n_darfur: [['nd_mellit', 'مليط', 14.1, 25.58], ['nd_tina', 'الطينة', 15.4, 23.8]],
    s_darfur: [['sd_kass', 'كاس', 12.5, 24.3]],
    e_darfur: [['ed_adila', 'عديلة', 11.1, 26.1]]
  };
  COUNTRY.states.forEach(function (st) {
    (MORE[st.id] || []).forEach(function (r) { st.cities.push(c(r[0], r[1], r[2], r[3])); });
    var f = st.cities[0];
    st.cities.push(c(st.id + '_other', 'منطقة أخرى في الولاية', f.lat, f.lng)); // اكتب اسم الحي في خانة الحي
  });

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
      if (d.indexOf('00') === 0) d = d.slice(2);
      if (d.indexOf(dial) === 0) d = d.slice(dial.length);
      if (d.charAt(0) === '0') d = d.slice(1);
      return COUNTRY.phoneRegex.test(d) ? COUNTRY.dial + d : null;
    },
    // الشكل المحلي للعرض: 09xxxxxxxx أو 01xxxxxxxx
    localPhone: function (phone) { var n = SQ.util.normalizePhone(phone); return n ? '0' + n.slice(COUNTRY.dial.length) : String(phone || ''); },
    digits: function (phone) { return String(phone || '').replace(/\D/g, ''); }
  };
})();
