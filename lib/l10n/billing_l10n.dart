import 'strings.dart';

/// Billing feature strings (English + Urdu).
///
/// Owned by the billing crew. Same lookup rules as [AppStrings]: key naming
/// `billing.<thing>`, English fallback, then the key itself. Screens rebuild
/// on locale change via `ValueListenableBuilder` on [AppLocale.current].
///
/// NOTE (crew-ownership): PROJECT_STATUS.md says crews must not edit
/// `lib/l10n/*` foundation files — this is a NEW billing-owned file created
/// per the coordinator's task (it does not modify `strings.dart`).
const Map<String, Map<String, String>> billingStrings = {
  'en': {
    'billing.book': 'Bill Book',
    'billing.salesThisMonth': 'Sales this month',
    'billing.report': 'Report',
    'billing.searchHint': 'Search bills…',
    'billing.filterStatus': 'Filter by status',
    'billing.filterAll': 'All',
    'billing.filterPaid': 'Paid',
    'billing.filterDue': 'Due',
    'billing.filterNew': 'New',
    'billing.createNew': 'CREATE NEW BILL',
    'billing.billPrefix': 'Bill #',
    'billing.item': 'item',
    'billing.items': 'items',
    'billing.emptyTitle': 'No bills yet',
    'billing.emptySub': 'Create your first bill and it will show up here.',
    'billing.billNo': 'Bill no',
    'billing.date': 'Date',
    'billing.partyOptional': 'Party (optional)',
    'billing.noParty': 'No party selected',
    'billing.pickParty': 'Choose party',
    'billing.searchParty': 'Search parties…',
    'billing.clear': 'Clear',
    'billing.addItem': 'Add item',
    'billing.fromStock': 'From stock',
    'billing.manual': 'Manual entry',
    'billing.itemName': 'Item name',
    'billing.itemNameHint': 'e.g. Sugar 1kg',
    'billing.qty': 'Qty',
    'billing.rate': 'Rate',
    'billing.total': 'Total',
    'billing.subtotal': 'Subtotal',
    'billing.taxPct': 'Tax %',
    'billing.discount': 'Discount',
    'billing.grandTotal': 'Grand total',
    'billing.note': 'Note',
    'billing.noteHint': 'Add a note…',
    'billing.saveBill': 'SAVE BILL',
    'billing.needItem': 'Add at least one item first',
    'billing.saved': 'Bill saved',
    'billing.invoice': 'INVOICE',
    'billing.receiptNo': 'Receipt no',
    'billing.invoiceDate': 'Invoice date',
    'billing.billTo': 'Bill to',
    'billing.walkIn': 'Walk-in customer',
    'billing.paymentInfo': 'Payment info',
    'billing.paymentInfoBody':
        'Pay by cash or bank transfer. Share this invoice on WhatsApp to confirm your payment.',
    'billing.terms': 'Terms',
    'billing.termsBody':
        'Sold goods cannot be returned. Payment is due within 7 days unless agreed otherwise.',
    'billing.signature': 'Authorised signature',
    'billing.theme': 'Invoice colour',
    'billing.whatsapp': 'WhatsApp',
    'billing.pdf': 'PDF',
    'billing.print': 'Print',
    'billing.markPaid': 'Mark paid',
    'billing.markDue': 'Mark due',
    'billing.statusPaid': 'Paid',
    'billing.statusDue': 'Due',
    'billing.statusNew': 'New',
    'billing.pdfShared': 'Invoice PDF ready to share',
    'billing.pdfFailed': 'Could not build the invoice PDF',
    'billing.shareText': 'Please find my invoice attached.',
    'billing.editValue': 'Set value',
    'billing.remove': 'Remove',
    'billing.noStockItems': 'No stock items yet — use manual entry.',
  },
  'ur': {
    'billing.book': 'بل بک',
    'billing.salesThisMonth': 'اس ماہ کی فروخت',
    'billing.report': 'رپورٹ',
    'billing.searchHint': 'بل تلاش کریں…',
    'billing.filterStatus': 'حیثیت کے لحاظ سے فلٹر',
    'billing.filterAll': 'تمام',
    'billing.filterPaid': 'ادا شدہ',
    'billing.filterDue': 'واجب الادا',
    'billing.filterNew': 'نیا',
    'billing.createNew': 'نیا بل بنائیں',
    'billing.billPrefix': 'بل نمبر ',
    'billing.item': 'آئٹم',
    'billing.items': 'آئٹمز',
    'billing.emptyTitle': 'ابھی کوئی بل نہیں',
    'billing.emptySub': 'اپنا پہلا بل بنائیں، وہ یہیں نظر آئے گا۔',
    'billing.billNo': 'بل نمبر',
    'billing.date': 'تاریخ',
    'billing.partyOptional': 'پارٹی (اختیاری)',
    'billing.noParty': 'کوئی پارٹی منتخب نہیں',
    'billing.pickParty': 'پارٹی چنیں',
    'billing.searchParty': 'پارٹیاں تلاش کریں…',
    'billing.clear': 'صاف کریں',
    'billing.addItem': 'آئٹم شامل کریں',
    'billing.fromStock': 'اسٹاک سے',
    'billing.manual': 'دستی اندراج',
    'billing.itemName': 'آئٹم کا نام',
    'billing.itemNameHint': 'مثلاً چینی 1 کلو',
    'billing.qty': 'تعداد',
    'billing.rate': 'قیمت',
    'billing.total': 'میزان',
    'billing.subtotal': 'ذیلی میزان',
    'billing.taxPct': 'ٹیکس ٪',
    'billing.discount': 'رعایت',
    'billing.grandTotal': 'کل میزان',
    'billing.note': 'نوٹ',
    'billing.noteHint': 'نوٹ لکھیں…',
    'billing.saveBill': 'بل محفوظ کریں',
    'billing.needItem': 'پہلے کم از کم ایک آئٹم شامل کریں',
    'billing.saved': 'بل محفوظ ہو گیا',
    'billing.invoice': 'انوائس',
    'billing.receiptNo': 'رسید نمبر',
    'billing.invoiceDate': 'انوائس کی تاریخ',
    'billing.billTo': 'وصول کنندہ',
    'billing.walkIn': 'عام گاہک',
    'billing.paymentInfo': 'ادائیگی کی تفصیل',
    'billing.paymentInfoBody':
        'نقد یا بینک ٹرانسفر سے ادائیگی کریں۔ ادائیگی کی تصدیق کے لیے یہ انوائس واٹس ایپ پر بھیجیں۔',
    'billing.terms': 'شرائط',
    'billing.termsBody':
        'فروخت شدہ سامان واپس نہیں ہوگا۔ بصورتِ دیگر معاہدہ، ادائیگی 7 دن کے اندر واجب ہے۔',
    'billing.signature': 'مجاز دستخط',
    'billing.theme': 'انوائس کا رنگ',
    'billing.whatsapp': 'واٹس ایپ',
    'billing.pdf': 'پی ڈی ایف',
    'billing.print': 'پرنٹ',
    'billing.markPaid': 'ادا شدہ کریں',
    'billing.markDue': 'واجب الادا کریں',
    'billing.statusPaid': 'ادا شدہ',
    'billing.statusDue': 'واجب الادا',
    'billing.statusNew': 'نیا',
    'billing.pdfShared': 'انوائس پی ڈی ایف بھیجنے کے لیے تیار ہے',
    'billing.pdfFailed': 'انوائس پی ڈی ایف نہیں بن سکی',
    'billing.shareText': 'میری انوائس منسلک ہے۔',
    'billing.editValue': 'قیمت درج کریں',
    'billing.remove': 'ہٹائیں',
    'billing.noStockItems': 'ابھی کوئی اسٹاک آئٹم نہیں — دستی اندراج استعمال کریں۔',
  },
};

/// Translate a `billing.*` key for the current [AppLocale].
/// Falls back to English, then the key itself.
String billingTr(String key) {
  final lang = AppLocale.current.value;
  final table = billingStrings[lang] ?? billingStrings['en']!;
  return table[key] ?? billingStrings['en']![key] ?? key;
}

/// "3 items" / "1 item" with the current locale's words.
String billingItemsLabel(int count) {
  final word =
      billingTr(count == 1 ? 'billing.item' : 'billing.items');
  return '$count $word';
}
