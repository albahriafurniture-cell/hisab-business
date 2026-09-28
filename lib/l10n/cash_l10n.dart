import 'package:flutter/material.dart';

import '../data/models.dart';
import 'strings.dart';

/// Cash + Expense feature copy (crew-owned sidecar).
///
/// The foundation table in `strings.dart` is NOT touched: cash/expense
/// screens read their own strings from [cashStrings] below via [cashTr],
/// which follows the same [AppLocale]-driven lookup with an English fallback.
/// All Urdu strings here are written fresh for this feature.
/// Screens wrap their build in a ValueListenableBuilder on
/// [AppLocale.current] so a language switch rebuilds them.
Map<String, Map<String, String>> cashStrings = {
  'en': {
    'cash.title': 'Cash Book',
    'cash.inHand': 'Cash in Hand',
    'cash.todayBalance': 'Today Balance',
    'cash.history': 'History',
    'cash.entries': 'Entries',
    'cash.entryIn': 'Cash In',
    'cash.entryOut': 'Cash Out',
    'cash.amount': 'Amount',
    'cash.date': 'Date',
    'cash.category': 'Category',
    'cash.categoryHint': 'e.g. Shop sales, Salary…',
    'cash.party': 'Party',
    'cash.noParty': 'No party',
    'cash.detail': 'Details',
    'cash.detailHint': 'Add a note…',
    'cash.attachBill': 'Attach bill photo',
    'cash.changePhoto': 'Change photo',
    'cash.takePhoto': 'Take photo',
    'cash.chooseGallery': 'Choose from gallery',
    'cash.save': 'Save',
    'cash.amountRequired': 'Please enter an amount',
    'cash.invalidAmount': 'Enter a valid amount',
    'cash.saved': 'Entry saved',
    'cash.in': 'In',
    'cash.out': 'Out',
    'cash.noTransactions': 'No transactions found',
    'cash.noTransactionsHint':
        'Cash entries for this day will show up here.',
    'cash.backToToday': 'Back to today',
    'cash.expenseTitle': 'Expense Book',
    'cash.totalExpenses': 'Total Expenses',
    'cash.categories': 'Categories',
    'cash.addExpense': 'Add Expense',
    'cash.addCategory': 'New Category',
    'cash.categoryName': 'Category name',
    'cash.icon': 'Icon',
    'cash.color': 'Color',
    'cash.selectCategory': 'Select a category',
    'cash.nameRequired': 'Please enter a name',
    'cash.categorySaved': 'Category added',
    'cash.noExpenses': 'No expenses yet',
    'cash.noExpensesHint':
        'Tap + below to record your first expense.',
    // Seeded (foundation) category names, keyed by iconKey.
    'cash.cat.rent': 'Shop Rent',
    'cash.cat.salaries': 'Salaries',
    'cash.cat.utilities': 'Utilities',
    'cash.cat.fuel': 'Fuel',
    'cash.cat.repairs': 'Repairs',
    'cash.cat.marketing': 'Marketing',
    'cash.cat.supplies': 'Supplies',
    'cash.cat.transport': 'Transport',
    'cash.cat.taxes': 'Taxes',
  },
  'ur': {
    'cash.title': 'کیش بک',
    'cash.inHand': 'ہاتھ میں کیش',
    'cash.todayBalance': 'آج کا بیلنس',
    'cash.history': 'ریکارڈ',
    'cash.entries': 'اندراجات',
    'cash.entryIn': 'کیش ان',
    'cash.entryOut': 'کیش آؤٹ',
    'cash.amount': 'رقم',
    'cash.date': 'تاریخ',
    'cash.category': 'قسم',
    'cash.categoryHint': 'مثلاً دکان کی فروخت، تنخواہ…',
    'cash.party': 'پارٹی',
    'cash.noParty': 'کوئی پارٹی نہیں',
    'cash.detail': 'تفصیل',
    'cash.detailHint': 'نوٹ لکھیں…',
    'cash.attachBill': 'بل کی تصویر لگائیں',
    'cash.changePhoto': 'تصویر بدلیں',
    'cash.takePhoto': 'تصویر لیں',
    'cash.chooseGallery': 'گیلری سے منتخب کریں',
    'cash.save': 'محفوظ کریں',
    'cash.amountRequired': 'براہ کرم رقم لکھیں',
    'cash.invalidAmount': 'درست رقم لکھیں',
    'cash.saved': 'اندراج محفوظ ہو گیا',
    'cash.in': 'ان',
    'cash.out': 'آؤٹ',
    'cash.noTransactions': 'کوئی لین دین نہیں ملا',
    'cash.noTransactionsHint':
        'اس دن کے کیش اندراجات یہاں نظر آئیں گے۔',
    'cash.backToToday': 'آج پر واپس جائیں',
    'cash.expenseTitle': 'اخراجات کی کتاب',
    'cash.totalExpenses': 'کل اخراجات',
    'cash.categories': 'اقسام',
    'cash.addExpense': 'خرچ شامل کریں',
    'cash.addCategory': 'نئی قسم',
    'cash.categoryName': 'قسم کا نام',
    'cash.icon': 'آئیکن',
    'cash.color': 'رنگ',
    'cash.selectCategory': 'قسم منتخب کریں',
    'cash.nameRequired': 'براہ کرم نام لکھیں',
    'cash.categorySaved': 'قسم شامل ہو گئی',
    'cash.noExpenses': 'ابھی کوئی خرچ نہیں',
    'cash.noExpensesHint':
        'پہلا خرچ لکھنے کے لیے نیچے + دبائیں۔',
    // Seeded (foundation) category names, keyed by iconKey.
    'cash.cat.rent': 'دکان کا کرایہ',
    'cash.cat.salaries': 'تنخواہیں',
    'cash.cat.utilities': 'بجلی، گیس، پانی',
    'cash.cat.fuel': 'ایندھن',
    'cash.cat.repairs': 'مرمت',
    'cash.cat.marketing': 'مارکیٹنگ',
    'cash.cat.supplies': 'سامان',
    'cash.cat.transport': 'نقل و حمل',
    'cash.cat.taxes': 'ٹیکس',
  },
};

/// Translate [key] for the cash/expense feature. Falls back to English,
/// then the key itself.
String cashTr(BuildContext context, String key) {
  final lang = AppLocale.current.value;
  final table = cashStrings[lang] ?? cashStrings['en']!;
  return table[key] ?? cashStrings['en']![key] ?? key;
}

/// Icon keys of the foundation-seeded categories. Only these get a
/// translated display name; user-created categories keep their own name.
const Set<String> _seededCategoryKeys = {
  'rent',
  'salaries',
  'utilities',
  'fuel',
  'repairs',
  'marketing',
  'supplies',
  'transport',
  'taxes',
};

/// Display name for an [ExpenseCategory]: translated when it is one of the
/// seeded categories, otherwise the stored name as-is.
String expenseCategoryLabel(BuildContext context, ExpenseCategory category) {
  if (!_seededCategoryKeys.contains(category.iconKey)) {
    return category.name;
  }
  final lang = AppLocale.current.value;
  final table = cashStrings[lang] ?? cashStrings['en']!;
  return table['cash.cat.${category.iconKey}'] ?? category.name;
}
