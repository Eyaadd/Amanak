// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'أمانك';

  @override
  String get appDescription => 'تطبيق الرعاية الصحية لكبار السن';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get dontHaveAccount => 'ليس لديك حساب؟';

  @override
  String get signUp => 'إنشاء حساب';

  @override
  String get createAccount => 'إنشاء حساب';

  @override
  String get confirmPassword => 'تأكيد كلمة المرور';

  @override
  String get alreadyHaveAccount => 'لديك حساب بالفعل؟';

  @override
  String get chooseRole => 'اختر الدور';

  @override
  String get chooseYourRole => 'اختر دورك';

  @override
  String get elder => 'كبير السن';

  @override
  String get guardian => 'الوصي';

  @override
  String get user => 'المستخدم';

  @override
  String get assignUser => 'تعيين المستخدم';

  @override
  String get assignUserTitle => 'كوصي، تحتاج إلى تعيين نفسك لمستخدم';

  @override
  String get assignUserSubtitle =>
      'يرجى إدخال بريد المستخدم الإلكتروني الذي تريد مراقبته';

  @override
  String get enterUserEmail => 'أدخل بريد المستخدم الإلكتروني';

  @override
  String get completeRegistration => 'إكمال التسجيل';

  @override
  String get noUserFound =>
      'لم يتم العثور على مستخدم بهذا البريد الإلكتروني أو المستخدم ليس مستخدم عادي';

  @override
  String get userAlreadyLinked => 'هذا المستخدم مرتبط بالفعل بوصي آخر';

  @override
  String get errorValidatingEmail => 'خطأ في التحقق من صحة البريد الإلكتروني';

  @override
  String get pleaseEnterUserEmail => 'يرجى إدخال بريد المستخدم الإلكتروني';

  @override
  String get errorAssigningUser => 'خطأ في تعيين المستخدم';

  @override
  String get mainAmbulance => 'الإسعاف الرئيسي';

  @override
  String get trafficPolice => 'شرطة المرور';

  @override
  String get emergencyPolice => 'الشرطة الطارئة';

  @override
  String get fireDepartment => 'إدارة الإطفاء';

  @override
  String get civilDefence => 'الدفاع المدني';

  @override
  String get naturalGasEmergency => 'الغاز الطبيعي الطارئ';

  @override
  String get waterEmergency => 'المياه الطارئة';

  @override
  String get electricityEmergency => 'الكهرباء الطارئة';

  @override
  String get goBack => 'رجوع';

  @override
  String get couldNotLaunchDialer => 'لا يمكن تشغيل الهاتف';

  @override
  String get errorOpeningDialer => 'خطأ في فتح الهاتف';

  @override
  String editField(Object field) {
    return 'تعديل $field';
  }

  @override
  String enterNewField(Object field) {
    return 'أدخل $field جديد';
  }

  @override
  String get home => 'الرئيسية';

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get settings => 'الإعدادات';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get search => 'البحث';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get messages => 'الرسائل';

  @override
  String get calendar => 'التقويم';

  @override
  String get medicine => 'الدواء';

  @override
  String get medicines => 'الأدوية';

  @override
  String get medicineName => 'اسم الدواء';

  @override
  String dosage(Object dosage) {
    return 'الجرعة: $dosage';
  }

  @override
  String get frequency => 'التكرار';

  @override
  String get time => 'الوقت';

  @override
  String get addMedicine => 'إضافة دواء';

  @override
  String get editMedicine => 'تعديل الدواء';

  @override
  String get deleteMedicine => 'حذف الدواء';

  @override
  String get liveTracking => 'التتبع\nالمباشر';

  @override
  String get location => 'الموقع';

  @override
  String get guardianLocation => 'موقع الوصي';

  @override
  String get nearestHospitals => 'أقرب\nالمستشفيات';

  @override
  String get chatbot => 'المساعد الذكي';

  @override
  String get askQuestion => 'اطرح سؤالاً...';

  @override
  String get send => 'إرسال';

  @override
  String get pillReminder => 'تذكير بالدواء';

  @override
  String get timeToTakeMedicine => 'حان وقت تناول الدواء';

  @override
  String get missedPill => 'دواء مفقود';

  @override
  String get youMissedYourMedicine => 'لقد فاتك تناول الدواء';

  @override
  String get language => 'اللغة';

  @override
  String get english => 'الإنجليزية';

  @override
  String get arabic => 'العربية';

  @override
  String get theme => 'المظهر';

  @override
  String get light => 'فاتح';

  @override
  String get dark => 'داكن';

  @override
  String get enableNotifications => 'تفعيل الإشعارات';

  @override
  String get about => 'حول';

  @override
  String get version => 'الإصدار';

  @override
  String get save => 'حفظ';

  @override
  String get cancel => 'إلغاء';

  @override
  String get delete => 'حذف';

  @override
  String get edit => 'تعديل';

  @override
  String get add => 'إضافة';

  @override
  String get yes => 'نعم';

  @override
  String get no => 'لا';

  @override
  String get ok => 'موافق';

  @override
  String get error => 'خطأ';

  @override
  String get success => 'نجح';

  @override
  String get loading => 'جاري التحميل...';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get back => 'رجوع';

  @override
  String get next => 'التالي';

  @override
  String get previous => 'السابق';

  @override
  String get done => 'تم';

  @override
  String get skip => 'تخطي';

  @override
  String get continueButton => 'يكمل';

  @override
  String get seeAll => 'عرض الكل';

  @override
  String get noMedicinesForToday => 'لا توجد أدوية لليوم';

  @override
  String get today => 'اليوم';

  @override
  String get emergencyContacts => 'جهات الاتصال الطارئة';

  @override
  String get editInformation => 'تعديل المعلومات';

  @override
  String get welcome => 'مرحباً';

  @override
  String get welcomeMessage => 'مرحباً بك في أمانك، رفيقك الصحي';

  @override
  String get getStarted => 'ابدأ';

  @override
  String get skipOnboarding => 'تخطي';

  @override
  String get onboarding_finish => 'إنهاء';

  @override
  String get onboarding_next => 'التالي';

  @override
  String get onboarding_back => 'رجوع';

  @override
  String get onboarding_welcome_title => 'مرحبًا بك في تطبيق أماناك';

  @override
  String get onboarding_welcome_body => 'نهتم بصحتك في كل خطوة على الطريق.';

  @override
  String get onboarding_safety_title => 'ابق آمنًا';

  @override
  String get onboarding_safety_body =>
      'تقنية كشف السقوط المتقدمة تنبه أحباءك عند الحاجة للمساعدة.';

  @override
  String get onboarding_connected_title => 'ابق على تواصل';

  @override
  String get onboarding_connected_body =>
      'تتبع مباشر في الوقت الفعلي لضمان أنك دائمًا في متناول اليد.';

  @override
  String get onboarding_organized_title => 'ابق منظمًا';

  @override
  String get onboarding_organized_body =>
      'تقويم ذكي لتذكيرك بالأدوية والمواعيد.';

  @override
  String get onboarding_hassle_free_title => 'ابق خاليًا من المتاعب';

  @override
  String get onboarding_hassle_free_body =>
      'امسح الوصفات الطبية ودع التطبيق يدير تذكيرات الدواء تلقائيًا.';

  @override
  String get chooseLanguagePrompt => 'اختر اللغة';

  @override
  String languageChangedMessage(Object language) {
    return 'تم تغيير اللغة إلى $language';
  }

  @override
  String get enterYourName => 'أدخل اسمك';

  @override
  String get enterYourEmail => 'أدخل بريدك الإلكتروني';

  @override
  String get enterYourPassword => 'أدخل كلمة المرور';

  @override
  String get agreeToAmanak => 'أوافق على أمانك';

  @override
  String get termsOfService => 'شروط الخدمة';

  @override
  String get and => 'و';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get pleaseEnterValidEmailPassword =>
      'يرجى إدخال بريد إلكتروني وكلمة مرور صالحين';

  @override
  String get chatbotGreeting => 'ازاي اقدر اساعدك انهاردة ؟';

  @override
  String get yourGuardian => 'وصيك:';

  @override
  String get yourCareReceiver => 'مستلم رعايتك:';

  @override
  String get medicineSearchTitle => 'البحث عن الأدوية';

  @override
  String get medicineSearchHint => 'ابحث عن الأدوية...';

  @override
  String get medicineSearchEmpty => 'أدخل اسم الدواء للبحث';

  @override
  String get medicineSearchNotFound => 'لم يتم العثور على أدوية';

  @override
  String get medicineDetailDescription => 'الوصف';

  @override
  String get medicineDetailUses => 'الاستخدامات';

  @override
  String get medicineDetailContraindications => 'موانع الاستعمال';

  @override
  String get medicineDetailPrecautions => 'الاحتياطات';

  @override
  String get medicineDetailInteractions => 'التفاعلات';

  @override
  String get medicineDetailDosage => 'الجرعة';

  @override
  String get medicineDetailDosageForms => 'أشكال الجرعة';

  @override
  String get medicineDetailStorage => 'التخزين';

  @override
  String get medicineDetailUsageInstructions => 'تعليمات الاستخدام';

  @override
  String get medicineDetailSideEffects => 'الآثار الجانبية';

  @override
  String get medicineDetailEnglishName => 'الاسم الإنجليزي';

  @override
  String get medicineDetailArabicName => 'الاسم العربي';

  @override
  String get medicineDetailNotFound => 'لم يتم العثور على الدواء';

  @override
  String get medicineDetailTitle => 'تفاصيل الدواء';

  @override
  String get liveTrackingTitle => 'التتبع المباشر';

  @override
  String get yourLocation => 'موقعك';

  @override
  String get trackingSharedUser => 'تتبع';

  @override
  String get nearestHospitalsTitle => 'أقرب المستشفيات';

  @override
  String get showAll => 'عرض الكل';

  @override
  String get searchHospitals => 'ابحث عن المستشفيات...';

  @override
  String get noHospitalsFound => 'لم يتم العثور على مستشفيات قريبة';

  @override
  String errorLoadingMedicineDetails(Object error) {
    return 'خطأ في تحميل تفاصيل الدواء: $error';
  }

  @override
  String get invalidMedicineId => 'معرف الدواء غير صحيح';

  @override
  String errorSearchingMedicines(Object error) {
    return 'خطأ في البحث عن الأدوية: $error';
  }

  @override
  String errorLoadingMedicineData(Object error) {
    return 'خطأ في تحميل بيانات الدواء: $error';
  }

  @override
  String get pillReminderTitle => 'تذكير بالدواء';

  @override
  String get guardianViewReadOnly =>
      'عرض الوصي للقراءة فقط. لا يمكنك إضافة أدوية.';

  @override
  String errorSavingPill(Object error) {
    return 'خطأ في حفظ الدواء: $error';
  }

  @override
  String errorPickingImage(Object error) {
    return 'خطأ في اختيار الصورة: $error';
  }

  @override
  String get noMedicinesFoundInPrescription =>
      'لم يتم العثور على أدوية في الوصفة الطبية';

  @override
  String errorProcessingPrescription(Object error) {
    return 'خطأ في معالجة الوصفة الطبية: $error';
  }

  @override
  String get scanPrescription => 'مسح الوصفة الطبية';

  @override
  String get takePhoto => 'التقاط صورة';

  @override
  String get chooseFromGallery => 'اختيار من المعرض';

  @override
  String get medicineAddedSuccessfully => 'تم إضافة الدواء بنجاح!';

  @override
  String get pillDeleted => 'تم حذف الدواء';

  @override
  String errorDeletingPill(Object error) {
    return 'خطأ في حذف الدواء: $error';
  }

  @override
  String get guardianViewReadOnlyMarkTaken =>
      'عرض الوصي للقراءة فقط. لا يمكن تحديد الأدوية كمؤخذة.';

  @override
  String get guardianViewReadOnlyEdit =>
      'عرض الوصي للقراءة فقط. لا يمكن تعديل الأدوية.';

  @override
  String errorUpdatingPill(Object error) {
    return 'خطأ في تحديث الدواء: $error';
  }

  @override
  String get prescriptionResults => 'نتائج الوصفة الطبية';

  @override
  String foundMedicinesInPrescription(Object count) {
    return 'تم العثور على $count دواء في وصفتك الطبية. انقر على الدواء لإضافته إلى تقويمك.';
  }

  @override
  String confidence(Object confidence) {
    return 'الثقة: $confidence%';
  }

  @override
  String get close => 'إغلاق';

  @override
  String get invalidPillIdReturned => 'معرف الدواء غير صحيح من Firebase';

  @override
  String get calendarTitle => 'التقويم';

  @override
  String displayNameMedications(Object name) {
    return 'أدوية $name';
  }

  @override
  String get dontForgetScheduleTomorrow => 'لا تنس الجدول الزمني للغد';

  @override
  String get noRemindersForTomorrow => 'لا توجد تذكيرات للغد';

  @override
  String get selectDayToSeePills => 'اختر يومًا لرؤية الأدوية';

  @override
  String get addPillsManually => 'إضافة الأدوية يدويًا';

  @override
  String get pleaseWaitScanningPrescription =>
      'يرجى الانتظار بينما نمسح وصفتك الطبية';

  @override
  String get noMedicationsForThisDay => 'لا توجد أدوية لهذا اليوم';

  @override
  String get confirm => 'تأكيد';

  @override
  String editFromStartDate(Object date) {
    return 'تعديل من تاريخ البدء ($date)';
  }

  @override
  String get markedAsTaken => 'محدد كمؤخذ';

  @override
  String get markAsTaken => 'تحديد كمؤخذ';

  @override
  String get errorUpdatingPillStatus => 'خطأ في تحديث حالة الدواء';

  @override
  String get medicineTaken => 'تم تناول الدواء';

  @override
  String get pillMissedAlert => 'تنبيه الدواء المفقود';

  @override
  String get invalidGuardianId => 'معرف الوصي غير صحيح';

  @override
  String get editMedication => 'تعديل الدواء';

  @override
  String get addNewMedication => 'إضافة دواء جديد';

  @override
  String get medicationName => 'اسم الدواء';

  @override
  String get pleaseEnterMedicationName => 'يرجى إدخال اسم الدواء';

  @override
  String get dosageExample => 'الجرعة (مثل 500 ملغ)';

  @override
  String get pleaseEnterDosage => 'يرجى إدخال الجرعة';

  @override
  String get timesPerDay => 'المرات في اليوم';

  @override
  String get treatmentPeriod => 'فترة العلاج الإجمالية';

  @override
  String get days => 'يوم(أيام)';

  @override
  String get notesOptional => 'ملاحظات (اختياري)';

  @override
  String get update => 'تحديث';

  @override
  String get addMedication => 'إضافة دواء';
}
