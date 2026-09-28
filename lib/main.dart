import 'package:flutter/material.dart';

import 'data/hive_service.dart';
import 'l10n/strings.dart';
import 'routes.dart';
import 'screens/backup.dart';
import 'screens/bank.dart';
import 'screens/bank_add.dart';
import 'screens/bank_ledger.dart';
import 'screens/bill_create.dart';
import 'screens/bill_preview.dart';
import 'screens/bills.dart';
import 'screens/business_card.dart';
import 'screens/business_setup.dart';
import 'screens/cash.dart';
import 'screens/expense.dart';
import 'screens/home_shell.dart';
import 'screens/ledger.dart';
import 'screens/lock.dart';
import 'screens/more.dart';
import 'screens/onboarding.dart';
import 'screens/parties.dart';
import 'screens/party_add.dart';
import 'screens/reminders.dart';
import 'screens/reports.dart';
import 'screens/settings.dart';
import 'screens/splash.dart';
import 'screens/staff.dart';
import 'screens/staff_add.dart';
import 'screens/staff_profile.dart';
import 'screens/stock.dart';
import 'screens/stock_item.dart';
import 'screens/stock_item_add.dart';
import 'screens/transaction_add.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init();
  AppLocale.current.value = HiveService.language;
  runApp(const HisabBusinessApp());
}

class HisabBusinessApp extends StatelessWidget {
  const HisabBusinessApp({super.key});

  /// Decides the first route after splash from persisted app state.
  static String initialRoute() {
    if (HiveService.firstRun) return Routes.onboarding;
    if (HiveService.hasPin) return Routes.lock;
    return Routes.home;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.current,
      builder: (context, lang, _) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: MaterialApp(
          title: 'Hisab Business',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: _themeMode(),
          initialRoute: Routes.splash,
          routes: {
            Routes.splash: (_) => const _SplashRouter(),
            Routes.onboarding: (_) => const OnboardingScreen(),
            Routes.businessSetup: (_) => const BusinessSetupScreen(),
            Routes.lock: (_) => const LockScreen(),
            Routes.home: (_) => const HomeShell(),
            Routes.parties: (_) => const PartiesScreen(),
            Routes.partyAdd: (_) => const PartyAddScreen(),
            Routes.ledger: (_) => const LedgerScreen(),
            Routes.transactionAdd: (_) => const TransactionAddScreen(),
            Routes.cash: (_) => const CashScreen(),
            Routes.expense: (_) => const ExpenseScreen(),
            Routes.stock: (_) => const StockScreen(),
            Routes.stockItem: (_) => const StockItemScreen(),
            Routes.stockItemAdd: (_) => const StockItemAddScreen(),
            Routes.bills: (_) => const BillsScreen(),
            Routes.billCreate: (_) => const BillCreateScreen(),
            Routes.billPreview: (_) => const BillPreviewScreen(),
            Routes.bank: (_) => const BankScreen(),
            Routes.bankAdd: (_) => const BankAddScreen(),
            Routes.bankLedger: (_) => const BankLedgerScreen(),
            Routes.staff: (_) => const StaffScreen(),
            Routes.staffAdd: (_) => const StaffAddScreen(),
            Routes.staffProfile: (_) => const StaffProfileScreen(),
            Routes.reminders: (_) => const RemindersScreen(),
            Routes.reports: (_) => const ReportsScreen(),
            Routes.backup: (_) => const BackupScreen(),
            Routes.businessCard: (_) => const BusinessCardScreen(),
            Routes.settings: (_) => const SettingsScreen(),
            Routes.more: (_) => const MoreScreen(),
          },
        ),
      ),
    );
  }

  ThemeMode _themeMode() {
    switch (HiveService.themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

/// Shows [SplashScreen] briefly, then routes by persisted app state:
/// first run → onboarding, PIN set → lock, otherwise → home.
class _SplashRouter extends StatefulWidget {
  const _SplashRouter();

  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      Navigator.of(context)
          .pushReplacementNamed(HisabBusinessApp.initialRoute());
    });
  }

  @override
  Widget build(BuildContext context) => const SplashScreen();
}
