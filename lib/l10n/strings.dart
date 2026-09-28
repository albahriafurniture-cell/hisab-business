import 'package:flutter/material.dart';

/// App-wide locale state. Set [AppLocale.current.value] to 'en' or 'ur';
/// widgets that read [tr] rebuild via ValueListenableBuilder on this.
class AppLocale {
  static final ValueNotifier<String> current = ValueNotifier<String>('en');
}

/// Translate [key] for the current locale. Falls back to English, then the
/// key itself if nothing is found.
String tr(BuildContext context, String key) {
  final lang = AppLocale.current.value;
  final table = AppStrings.values[lang] ?? AppStrings.values['en']!;
  return table[key] ?? AppStrings.values['en']![key] ?? key;
}

/// True when the current locale is right-to-left.
bool get isRtl => AppLocale.current.value == 'ur';

/// Key-naming convention (crews: follow this when adding keys):
///   - `nav.<screen>`   bottom-nav / drawer labels, e.g. `nav.home`
///   - `module.<name>`  module tiles, e.g. `module.stock`
///   - `action.<verb>`  buttons, e.g. `action.save`
///   - `label.<thing>`  small labels, e.g. `label.search`
///   - `money.<dir>`    give/got/in/out words
///   - `msg.<thing>`    toasts / empty-state copy
///   - `form.<field>`   input labels / hints
///
/// To add keys: add the entry to BOTH 'en' and 'ur' maps, same key string.
class AppStrings {
  static const values = <String, Map<String, String>>{
    'en': {
      // nav
      'nav.home': 'Home',
      'nav.parties': 'Parties',
      'nav.cash': 'Cash',
      'nav.bills': 'Bills',
      'nav.more': 'More',
      // modules
      'module.party': 'Party',
      'module.cash': 'Cash',
      'module.stock': 'Stock',
      'module.bills': 'Bills',
      'module.staff': 'Staff',
      'module.expense': 'Expense',
      'module.bank': 'Bank',
      'module.reminders': 'Reminders',
      'module.reports': 'Reports',
      'module.backup': 'Backup',
      'module.businessCard': 'Business Card',
      'module.settings': 'Settings',
      // actions
      'action.save': 'Save',
      'action.cancel': 'Cancel',
      'action.delete': 'Delete',
      'action.edit': 'Edit',
      'action.share': 'Share',
      'action.add': 'Add',
      'action.done': 'Done',
      'action.search': 'Search',
      'action.filter': 'Filter',
      'action.report': 'Report',
      'action.remind': 'Remind',
      'action.call': 'Call',
      'action.print': 'Print',
      'action.download': 'Download',
      'action.continue': 'Continue',
      'action.back': 'Back',
      'action.yes': 'Yes',
      'action.no': 'No',
      'action.ok': 'OK',
      // labels
      'label.search': 'Search',
      'label.total': 'Total',
      'label.today': 'Today',
      'label.date': 'Date',
      'label.amount': 'Amount',
      'label.details': 'Details',
      'label.name': 'Name',
      'label.phone': 'Phone',
      'label.address': 'Address',
      'label.notes': 'Notes',
      'label.balance': 'Balance',
      'label.customers': 'Customers',
      'label.suppliers': 'Suppliers',
      'label.all': 'All',
      'label.entries': 'Entries',
      'label.hideBalance': 'Hide Balance',
      'label.showBalance': 'Show Balance',
      // money direction
      'money.gave': 'You Gave',
      'money.got': 'You Got',
      'money.in': 'Cash In',
      'money.out': 'Cash Out',
      'money.youWillGive': 'You will give',
      'money.youWillGet': 'You will get',
      'money.cashInHand': 'Cash in Hand',
      'money.deposit': 'Deposit',
      'money.withdraw': 'Withdraw',
      'money.paid': 'Paid',
      'money.due': 'Due',
      'money.partial': 'Partial',
      // forms
      'form.name': 'Name',
      'form.phone': 'Mobile number',
      'form.address': 'Address',
      'form.notes': 'Notes',
      'form.amount': 'Amount',
      'form.detail': 'Add details',
      'form.required': 'This field is required',
      'form.invalidAmount': 'Enter a valid amount',
      'form.businessName': 'Business name',
      'form.ownerName': 'Owner name',
      'form.category': 'Category',
      'form.selectDate': 'Select date',
      'form.selectParty': 'Select party',
      // messages
      'msg.saved': 'Saved successfully',
      'msg.deleted': 'Deleted successfully',
      'msg.noData': 'Nothing here yet',
      'msg.noDataHint': 'Tap the button below to add your first entry.',
      'msg.confirmDelete': 'Are you sure you want to delete this?',
      'msg.reminderSent': 'Reminder sent',
      'msg.backupDone': 'Backup completed',
      'msg.restored': 'Data restored',
      // home / misc
      'home.khata': 'KHATA',
      'home.payments': 'PAYMENTS',
      'home.viewParties': 'View Parties',
      'home.welcome': 'Your daily business khata, made simple.',
      'home.tagline': 'Track every rupee — customers, cash, stock and staff.',
      'app.name': 'Hisab Business',
      'app.madeIn': 'Made in Pakistan',
      // onboarding
      'onboard.1.title': 'Add your parties',
      'onboard.1.body': 'Save customers and suppliers with their phone numbers.',
      'onboard.2.title': 'Record every entry',
      'onboard.2.body': 'Log money you give or get in a simple daily khata.',
      'onboard.3.title': 'Send payment reminders',
      'onboard.3.body': 'Nudge anyone who owes you with one tap.',
      'onboard.skip': 'Skip',
      'onboard.next': 'Next',
      'onboard.getStarted': 'Get Started',
      // lock
      'lock.enterPin': 'Enter your PIN',
      'lock.createPin': 'Create a new PIN',
      'lock.confirmPin': 'Confirm your PIN',
      'lock.wrongPin': 'Wrong PIN, try again',
      'lock.pinMismatch': 'PINs do not match',
      'lock.useBiometric': 'Use fingerprint',
      'lock.forgotPin': 'Forgot PIN?',
    },
    'ur': {
      // nav
      'nav.home': 'ہوم',
      'nav.parties': 'پارٹیز',
      'nav.cash': 'کیش',
      'nav.bills': 'بلز',
      'nav.more': 'مزید',
      // modules
      'module.party': 'پارٹی',
      'module.cash': 'کیش',
      'module.stock': 'اسٹاک',
      'module.bills': 'بلز',
      'module.staff': 'عملہ',
      'module.expense': 'اخراجات',
      'module.bank': 'بینک',
      'module.reminders': 'یاد دہانیاں',
      'module.reports': 'رپورٹس',
      'module.backup': 'بیک اپ',
      'module.businessCard': 'بزنس کارڈ',
      'module.settings': 'ترتیبات',
      // actions
      'action.save': 'محفوظ کریں',
      'action.cancel': 'منسوخ کریں',
      'action.delete': 'حذف کریں',
      'action.edit': 'ترمیم',
      'action.share': 'شیئر',
      'action.add': 'شامل کریں',
      'action.done': 'ہو گیا',
      'action.search': 'تلاش',
      'action.filter': 'فلٹر',
      'action.report': 'رپورٹ',
      'action.remind': 'یاد دلائیں',
      'action.call': 'کال کریں',
      'action.print': 'پرنٹ',
      'action.download': 'ڈاؤن لوڈ',
      'action.continue': 'آگے بڑھیں',
      'action.back': 'واپس',
      'action.yes': 'جی ہاں',
      'action.no': 'نہیں',
      'action.ok': 'ٹھیک ہے',
      // labels
      'label.search': 'تلاش کریں',
      'label.total': 'کل',
      'label.today': 'آج',
      'label.date': 'تاریخ',
      'label.amount': 'رقم',
      'label.details': 'تفصیل',
      'label.name': 'نام',
      'label.phone': 'فون',
      'label.address': 'پتہ',
      'label.notes': 'نوٹس',
      'label.balance': 'بیلنس',
      'label.customers': 'گاہک',
      'label.suppliers': 'سپلائرز',
      'label.all': 'تمام',
      'label.entries': 'اندراجات',
      'label.hideBalance': 'بیلنس چھپائیں',
      'label.showBalance': 'بیلنس دکھائیں',
      // money direction
      'money.gave': 'آپ نے دیا',
      'money.got': 'آپ کو ملا',
      'money.in': 'کیش ان',
      'money.out': 'کیش آؤٹ',
      'money.youWillGive': 'آپ دیں گے',
      'money.youWillGet': 'آپ لیں گے',
      'money.cashInHand': 'ہاتھ میں کیش',
      'money.deposit': 'جمع',
      'money.withdraw': 'نکالنا',
      'money.paid': 'ادا شدہ',
      'money.due': 'واجب الادا',
      'money.partial': 'جزوی',
      // forms
      'form.name': 'نام',
      'form.phone': 'موبائل نمبر',
      'form.address': 'پتہ',
      'form.notes': 'نوٹس',
      'form.amount': 'رقم',
      'form.detail': 'تفصیل لکھیں',
      'form.required': 'یہ خانہ ضروری ہے',
      'form.invalidAmount': 'درست رقم لکھیں',
      'form.businessName': 'کاروبار کا نام',
      'form.ownerName': 'مالک کا نام',
      'form.category': 'قسم',
      'form.selectDate': 'تاریخ منتخب کریں',
      'form.selectParty': 'پارٹی منتخب کریں',
      // messages
      'msg.saved': 'کامیابی سے محفوظ ہو گیا',
      'msg.deleted': 'کامیابی سے حذف ہو گیا',
      'msg.noData': 'ابھی کچھ نہیں ہے',
      'msg.noDataHint': 'پہلا اندراج شامل کرنے کے لیے نیچے بٹن دبائیں۔',
      'msg.confirmDelete': 'کیا آپ واقعی حذف کرنا چاہتے ہیں؟',
      'msg.reminderSent': 'یاد دہانی بھیج دی گئی',
      'msg.backupDone': 'بیک اپ مکمل ہو گیا',
      'msg.restored': 'ڈیٹا بحال ہو گیا',
      // home / misc
      'home.khata': 'کھاتہ',
      'home.payments': 'ادائیگیاں',
      'home.viewParties': 'پارٹیز دیکھیں',
      'home.welcome': 'آپ کا روزانہ کاروباری کھاتہ، آسان طریقے سے۔',
      'home.tagline': 'ہر روپے کا حساب — گاہک، کیش، اسٹاک اور عملہ۔',
      'app.name': 'حساب بزنس',
      'app.madeIn': 'پاکستان میں بنایا گیا',
      // onboarding
      'onboard.1.title': 'اپنی پارٹیز شامل کریں',
      'onboard.1.body': 'گاہکوں اور سپلائرز کو ان کے فون نمبروں کے ساتھ محفوظ کریں۔',
      'onboard.2.title': 'ہر اندراج ریکارڈ کریں',
      'onboard.2.body': 'دی گئی یا لی گئی رقم کو آسان روزانہ کھاتے میں لکھیں۔',
      'onboard.3.title': 'ادائیگی کی یاد دہانی بھیجیں',
      'onboard.3.body': 'جو آپ کا مقروض ہے اسے ایک ٹیپ سے یاد دلائیں۔',
      'onboard.skip': 'چھوڑیں',
      'onboard.next': 'آگے',
      'onboard.getStarted': 'شروع کریں',
      // lock
      'lock.enterPin': 'اپنا پن درج کریں',
      'lock.createPin': 'نیا پن بنائیں',
      'lock.confirmPin': 'پن کی تصدیق کریں',
      'lock.wrongPin': 'غلط پن، دوبارہ کوشش کریں',
      'lock.pinMismatch': 'پن آپس میں نہیں ملے',
      'lock.useBiometric': 'فنگر پرنٹ استعمال کریں',
      'lock.forgotPin': 'پن بھول گئے؟',
    },
  };
}
