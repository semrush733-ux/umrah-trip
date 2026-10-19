import 'package:flutter/material.dart';

/// Supported app languages. Roman Urdu is offered as a description option
/// inside destination details rather than a full UI locale.
enum AppLanguage { en, ur, ar }

extension AppLanguageX on AppLanguage {
  String get code => name;
  bool get isRtl => this == AppLanguage.ur || this == AppLanguage.ar;
  TextDirection get direction => isRtl ? TextDirection.rtl : TextDirection.ltr;
  String get label => switch (this) {
        AppLanguage.en => 'English',
        AppLanguage.ur => 'اردو',
        AppLanguage.ar => 'العربية',
      };
}

/// Lightweight tri-lingual string table (full .arb pipeline arrives with the
/// backend phase; this keeps the app dependency-light and offline-first).
class S {
  final AppLanguage lang;
  const S(this.lang);

  static S of(BuildContext context) =>
      _SProvider.of(context) ?? const S(AppLanguage.en);

  String _t(String en, String ur, String ar) => switch (lang) {
        AppLanguage.en => en,
        AppLanguage.ur => ur,
        AppLanguage.ar => ar,
      };

  String get appName => 'Umrah Trip';
  String get welcome => _t('Welcome to Umrah Journey', 'امرہ جرنی میں خوش آمدید', 'مرحباً بكم في رحلة العمرة');
  String get home => _t('Home', 'ہوم', 'الرئيسية');
  String get explore => _t('Explore', 'دریافت', 'استكشف');
  String get map => _t('Map', 'نقشہ', 'الخريطة');
  String get myTrip => _t('My Trip', 'میرا سفر', 'رحلتي');
  String get profile => _t('Profile', 'پروفائل', 'الملف');
  String get startNavigation => _t('START NAVIGATION', 'نیویگیشن شروع کریں', 'ابدأ الملاحة');
  String get navigate => _t('Navigate', 'نیویگیٹ', 'اذهب');
  String get addToTrip => _t('Add to Trip', 'سفر میں شامل کریں', 'أضف إلى الرحلة');
  String get markVisited => _t('Mark Visited', 'زیارت مکمل', 'تمت الزيارة');
  String get save => _t('Save', 'محفوظ کریں', 'حفظ');
  String get saved => _t('Saved', 'محفوظ', 'محفوظ');
  String get listenGuide => _t('Listen to Guide', 'گائیڈ سنیں', 'استمع للدليل');
  String get nearby => _t('Nearby Ziyarat', 'قریبی زیارات', 'مزارات قريبة');
  String get todayVisits => _t("Today's visits", 'آج کی زیارات', 'زيارات اليوم');
  String get nextDestination => _t('Next destination', 'اگلی منزل', 'الوجهة التالية');
  String get planned => _t('Planned', 'منصوبہ', 'مخطط');
  String get visited => _t('Visited', 'زیارت شدہ', 'تمت');
  String get remaining => _t('Remaining', 'باقی', 'متبقي');
  String get skipped => _t('Skipped', 'چھوڑ دی', 'تخطي');
  String get notPlanned => _t('Not planned', 'غیر منصوبہ', 'غير مخطط');
  String get planYourNext => _t('Plan your next Ziyarat', 'اگلی زیارت کا منصوبہ بنائیں', 'خطط لزيارتك القادمة');
  String get searchHint => _t('Search Ghar e Hira, Quba, Uhud…', 'تلاش کریں: غارِ حرا، قبا، احد…', 'ابحث: غار حراء، قباء، أحد…');
  String get saudiTime => _t('Saudi time', 'سعودی وقت', 'توقيت السعودية');
  String get currentCity => _t('Current city', 'موجودہ شہر', 'المدينة الحالية');
  String get selectCity => _t('Choose city', 'شہر منتخب کریں', 'اختر المدينة');
  String get straightLine => _t('straight-line', 'سیدھی لکیر', 'خط مستقيم');
  String get openInMaps => _t('Opens Google Maps for live turn-by-turn navigation.', 'لائیو نیویگیشن کے لیے گوگل میپس کھلے گا۔', 'سيفتح خرائط Google للملاحة المباشرة.');
  String get appleMaps => _t('Use Apple Maps instead', 'ایپل میپس استعمال کریں', 'استخدم خرائط Apple');
  String get darkMode => _t('Dark mode', 'ڈارک موڈ', 'الوضع الداكن');
  String get language => _t('Language', 'زبان', 'اللغة');
  String get romanUrdu => _t('Roman Urdu descriptions', 'رومن اردو تفصیل', 'وصف بالأردية اللاتينية');
  String get memories => _t('My Travel Memories', 'میری سفری یادیں', 'ذكريات رحلتي');
  String get budget => _t('Budget & Expenses', 'بجٹ اور اخراجات', 'الميزانية والمصروفات');
  String get arrival => _t('Arrival date', 'آمد کی تاریخ', 'تاريخ الوصول');
  String get departure => _t('Departure date', 'روانگی کی تاریخ', 'تاريخ المغادرة');
  String get addDay => _t('Add day', 'دن شامل کریں', 'أضف يوماً');
  String get addVisit => _t('Add visit', 'زیارت شامل کریں', 'أضف زيارة');
  String get checkInHere => _t('Check In Here', 'یہاں چیک اِن کریں', 'سجّل وصولك هنا');
  String get unverified => _t('Unverified — confirm before relying on this', 'غیر تصدیق شدہ — انحصار سے پہلے تصدیق کریں', 'غير مؤكد — تحقق قبل الاعتماد عليه');
  String get verifiedData => _t('Verified', 'تصدیق شدہ', 'مؤكد');
  String get distanceFromYou => _t('from you', 'آپ سے', 'منك');
  String get locationOff => _t('Location off — select your city manually', 'لوکیشن بند — شہر خود منتخب کریں', 'الموقع مغلق — اختر مدينتك يدوياً');
  String get enableLocation => _t('Enable location', 'لوکیشن آن کریں', 'تفعيل الموقع');
  String get all => _t('All', 'سب', 'الكل');
  String get details => _t('Details', 'تفصیلات', 'التفاصيل');
  String get history => _t('History & significance', 'تاریخ اور فضیلت', 'التاريخ والفضل');
  String get visitInfo => _t('Visit information', 'زیارت کی معلومات', 'معلومات الزيارة');
  String get tips => _t('Travel tips', 'سفری مشورے', 'نصائح السفر');
  String get bestTime => _t('Best time', 'بہترین وقت', 'أفضل وقت');
  String get duration => _t('Suggested duration', 'تجویز کردہ دورانیہ', 'المدة المقترحة');
  String get hours => _t('Hours', 'اوقات', 'الأوقات');
  String get entryFee => _t('Entry', 'داخلہ', 'الدخول');
  String get free => _t('Free', 'مفت', 'مجاني');
  String get notes => _t('Notes', 'نوٹس', 'ملاحظات');
  String get undo => _t('Undo', 'واپس', 'تراجع');
  String get delete => _t('Delete', 'حذف کریں', 'حذف');
  String get cancel => _t('Cancel', 'منسوخ', 'إلغاء');
  String get ok => _t('OK', 'ٹھیک ہے', 'حسناً');
  String get favorites => _t('Saved places', 'محفوظ مقامات', 'الأماكن المحفوظة');
  String get mosques => _t('Mosques', 'مساجد', 'مساجد');
  String get islamicSites => _t('Islamic historical', 'اسلامی تاریخی', 'تاريخية إسلامية');
  String get museums => _t('Museums', 'عجائب گھر', 'متاحف');
  String get natureMountains => _t('Nature & mountains', 'قدرتی مناظر', 'طبيعة وجبال');
  String get attractions => _t('Attractions', 'تفریحی مقامات', 'معالم');
  String get familyFriendly => _t('Family-friendly', 'فیملی کے لیے', 'عائلي');
  String get freeEntry => _t('Free entry', 'مفت داخلہ', 'دخول مجاني');
  String get day => _t('Day', 'دن', 'يوم');
  String get mapsKeyMissing => _t(
      'Add your Google Maps API key to see the live map. One-tap navigation works without it.',
      'لائیو نقشے کے لیے گوگل میپس API کلید شامل کریں۔ نیویگیشن اس کے بغیر بھی چلتی ہے۔',
      'أضف مفتاح Google Maps لعرض الخريطة. تعمل الملاحة بدونها.');

  String regionName(String region) => switch (region) {
        'makkah' => _t('Makkah', 'مکہ مکرمہ', 'مكة المكرمة'),
        'madinah' => _t('Madinah', 'مدینہ منورہ', 'المدينة المنورة'),
        'jeddah' => _t('Jeddah', 'جدہ', 'جدة'),
        'riyadh' => _t('Riyadh & Diriyah', 'ریاض و درعیہ', 'الرياض والدرعية'),
        'taif' => _t('Taif', 'طائف', 'الطائف'),
        'eastern' => _t('Eastern Province', 'مشرقی صوبہ', 'المنطقة الشرقية'),
        _ => region,
      };
}

/// Inherited widget so `S.of(context)` works without extra packages.
class _SProvider extends InheritedWidget {
  final S strings;
  const _SProvider({required this.strings, required super.child});
  static S? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SProvider>()?.strings;
  @override
  bool updateShouldNotify(_SProvider old) => old.strings.lang != strings.lang;
}

class StringsScope extends StatelessWidget {
  final AppLanguage lang;
  final Widget child;
  const StringsScope({super.key, required this.lang, required this.child});
  @override
  Widget build(BuildContext context) =>
      _SProvider(strings: S(lang), child: child);
}
