import 'strings.dart';

/// Access-crew strings (onboarding, business setup, app lock).
///
/// FRESH copy written for Hisab Business — none of this text is copied from
/// any competitor's resources. [accessTr] reads [AppLocale.current] directly;
/// screens wrap their content in a `ValueListenableBuilder` on
/// [AppLocale.current] so a language change rebuilds them.
const Map<String, Map<String, String>> accessStrings = {
  'en': {
    // onboarding
    'access.onboarding.title': 'Onboarding',
    'access.onb1.title': 'Your parties, one ledger',
    'access.onb1.body':
        'Add customers and suppliers once. Every rupee you give or receive stays written down, safely.',
    'access.onb2.title': 'Cash, stock & bills in hand',
    'access.onb2.body':
        'Record cash in and out, watch your stock move, and make bills in seconds.',
    'access.onb3.title': 'Collect what is yours',
    'access.onb3.body':
        'See who owes you at a glance, and nudge them with a payment reminder in one tap.',
    'access.skip': 'Skip',    'access.next': 'Next',
    'access.getStarted': 'Get Started',
    // business setup
    'access.biz.setupTitle': 'Set up your business',
    'access.biz.editTitle': 'Business details',
    'access.biz.subtitle':
        'This shows up on your bills and business card.',
    'access.biz.nameHint': 'e.g. Ahmed Kiryana Store',
    'access.biz.typeLabel': 'Business type',
    'access.biz.choose': 'Choose…',
    'access.biz.phoneHint': '0300 1234567',
    'access.biz.ownerHint': 'e.g. Ahmed Khan',
    'access.biz.addressLabel': 'Shop address (optional)',
    'access.biz.addressHint': 'Shop 4, Main Bazaar Road',
    'access.biz.saved': 'Business saved',
    'access.cat.kiryana': 'Kiryana Store',
    'access.cat.pharmacy': 'Pharmacy',
    'access.cat.restaurant': 'Restaurant',
    'access.cat.bakery': 'Bakery',
    'access.cat.clothing': 'Clothing',
    'access.cat.mobile': 'Mobile Shop',
    'access.cat.services': 'Services',
    'access.cat.other': 'Other',
    // lock
    'access.lock.createTitle': 'Set a 4-digit PIN',
    'access.lock.createBody': 'Pick a PIN you will remember.',
    'access.lock.confirmBody': 'Type it once more to confirm.',
    'access.lock.enterTitle': 'Welcome back',
    'access.lock.enterBody': 'Enter your PIN to open the app.',
    'access.lock.changeOld': 'Type your current PIN',
    'access.lock.changeNew': 'Now set your new PIN',
    'access.lock.verifyTitle': 'Turn off app lock',
    'access.lock.verifyBody': 'Enter your PIN to switch off the lock.',
    'access.lock.wrong': "That's not the right PIN",
    'access.lock.mismatch':
        "The two PINs don't match — let's start over",
    'access.lock.pinSaved': 'PIN saved. Your app is now locked.',
    'access.lock.pinChanged': 'PIN changed',
    'access.lock.pinCleared': 'App lock turned off',
    'access.lock.tooMany':
        'Too many wrong tries. The app is locked for {m} minutes.',
    'access.lock.retryIn': 'Try again in {s}s',
    'access.lock.forgot': 'Forgot PIN?',
    'access.lock.forgotTitle': 'Reset the app?',
    'access.lock.forgotBody':
        'A forgotten PIN cannot be recovered. Resetting erases ALL your data — parties, khata, cash, stock, bills and staff — and starts the app fresh. This cannot be undone.',
    'access.lock.forgotConfirm': 'Erase everything & start fresh',
    'access.lock.bioReason': 'Unlock Hisab Business with your fingerprint',
    'access.lock.bioHint': 'Or use your fingerprint',
    'access.lock.bioFailed':
        "Fingerprint didn't work — type your PIN instead",
  },
  'ur': {
    // onboarding (fresh Urdu)
    'access.onboarding.title': 'آن بورڈنگ',
    'access.onb1.title': 'آپ کی پارٹیاں، ایک کھاتہ',
    'access.onb1.body':
        'گاہک اور سپلائر ایک بار شامل کریں۔ دی یا لی گئی ہر رقم محفوظ طریقے سے درج رہے گی۔',
    'access.onb2.title': 'کیش، اسٹاک اور بل آپ کے ہاتھ میں',
    'access.onb2.body':
        'کیش ان اور آؤٹ ریکارڈ کریں، اسٹاک کی نقل و حرکت دیکھیں اور سیکنڈوں میں بل بنائیں۔',
    'access.onb3.title': 'اپنا حق وصول کریں',
    'access.onb3.body':
        'ایک نظر میں دیکھیں کہ کون آپ کا مقروض ہے اور ایک ٹیپ سے ادائیگی کی یاد دہانی بھیجیں۔',
    'access.skip': 'چھوڑیں',
    'access.next': 'آگے',
    'access.getStarted': 'شروع کریں',
    // business setup
    'access.biz.setupTitle': 'اپنا کاروبار سیٹ کریں',
    'access.biz.editTitle': 'کاروباری تفصیلات',
    'access.biz.subtitle': 'یہ آپ کے بلوں اور بزنس کارڈ پر نظر آئے گا۔',
    'access.biz.nameHint': 'مثلاً احمد کریانہ اسٹور',
    'access.biz.typeLabel': 'کاروبار کی قسم',
    'access.biz.choose': 'منتخب کریں…',
    'access.biz.phoneHint': '0300 1234567',
    'access.biz.ownerHint': 'مثلاً احمد خان',
    'access.biz.addressLabel': 'دکان کا پتہ (اختیاری)',
    'access.biz.addressHint': 'دکان 4، مین بازار روڈ',
    'access.biz.saved': 'کاروبار محفوظ ہو گیا',
    'access.cat.kiryana': 'کریانہ اسٹور',
    'access.cat.pharmacy': 'فارمیسی',
    'access.cat.restaurant': 'ریسٹورنٹ',
    'access.cat.bakery': 'بیکری',
    'access.cat.clothing': 'کپڑے',
    'access.cat.mobile': 'موبائل شاپ',
    'access.cat.services': 'خدمات',
    'access.cat.other': 'دیگر',
    // lock
    'access.lock.createTitle': '4 ہندسوں کا پن سیٹ کریں',
    'access.lock.createBody': 'ایسا پن چنیں جو آپ کو یاد رہے۔',
    'access.lock.confirmBody': 'تصدیق کے لیے دوبارہ لکھیں۔',
    'access.lock.enterTitle': 'خوش آمدید',
    'access.lock.enterBody': 'ایپ کھولنے کے لیے اپنا پن درج کریں۔',
    'access.lock.changeOld': 'اپنا موجودہ پن لکھیں',
    'access.lock.changeNew': 'اب اپنا نیا پن سیٹ کریں',
    'access.lock.verifyTitle': 'ایپ لاک بند کریں',
    'access.lock.verifyBody': 'لاک بند کرنے کے لیے اپنا پن درج کریں۔',
    'access.lock.wrong': 'یہ پن درست نہیں ہے',
    'access.lock.mismatch': 'دونوں پن ایک جیسے نہیں ہیں — دوبارہ شروع کریں',
    'access.lock.pinSaved': 'پن محفوظ ہو گیا۔ آپ کی ایپ اب مقفل ہے۔',
    'access.lock.pinChanged': 'پن تبدیل ہو گیا',
    'access.lock.pinCleared': 'ایپ لاک بند کر دیا گیا',
    'access.lock.tooMany':
        'غلط کوششیں زیادہ ہو گئیں۔ ایپ {m} منٹ کے لیے مقفل ہے۔',
    'access.lock.retryIn': '{s} سیکنڈ میں دوبارہ کوشش کریں',
    'access.lock.forgot': 'پن بھول گئے؟',
    'access.lock.forgotTitle': 'ایپ ری سیٹ کریں؟',
    'access.lock.forgotBody':
        'بھولا ہوا پن واپس نہیں مل سکتا۔ ری سیٹ کرنے سے آپ کا تمام ڈیٹا — پارٹیاں، کھاتہ، کیش، اسٹاک، بلز اور عملہ — مکمل طور پر مٹ جائے گا اور ایپ نئے سرے سے شروع ہوگی۔ یہ عمل واپس نہیں ہو سکتا۔',
    'access.lock.forgotConfirm': 'سب کچھ مٹا کر نئے سرے سے شروع کریں',
    'access.lock.bioReason': 'فنگر پرنٹ سے حساب بزنس ان لاک کریں',
    'access.lock.bioHint': 'یا اپنا فنگر پرنٹ استعمال کریں',
    'access.lock.bioFailed':
        'فنگر پرنٹ کام نہیں کرا — اپنا پن لکھیں',
  },
};

/// Translate an access-crew [key] for the current locale.
/// Falls back to English, then the key itself.
String accessTr(String key) {
  final lang = AppLocale.current.value;
  final table = accessStrings[lang] ?? accessStrings['en']!;
  return table[key] ?? accessStrings['en']![key] ?? key;
}
