/// Route-name constants. EVERY screen in the app registers its route here
/// and feature crews MUST navigate with these constants, never raw strings.
abstract final class Routes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const businessSetup = '/business-setup';
  static const lock = '/lock';
  static const home = '/home';
  static const parties = '/parties';
  static const partyAdd = '/party-add';
  static const ledger = '/ledger';
  static const transactionAdd = '/transaction-add';
  static const cash = '/cash';
  static const expense = '/expense';
  static const stock = '/stock';
  static const stockItem = '/stock-item';
  static const stockItemAdd = '/stock-item-add';
  static const bills = '/bills';
  static const billCreate = '/bill-create';
  static const billPreview = '/bill-preview';
  static const bank = '/bank';
  static const bankAdd = '/bank-add';
  static const bankLedger = '/bank-ledger';
  static const staff = '/staff';
  static const staffAdd = '/staff-add';
  static const staffProfile = '/staff-profile';
  static const reminders = '/reminders';
  static const reports = '/reports';
  static const backup = '/backup';
  static const businessCard = '/business-card';
  static const settings = '/settings';
  static const more = '/more';
}
