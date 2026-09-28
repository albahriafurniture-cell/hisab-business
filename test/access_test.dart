import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hisab_business/data/hive_service.dart';
import 'package:hisab_business/data/models.dart';
import 'package:hisab_business/l10n/access_l10n.dart';
import 'package:hisab_business/l10n/strings.dart';
import 'package:hisab_business/routes.dart';
import 'package:hisab_business/screens/business_setup.dart';
import 'package:hisab_business/screens/lock.dart';
import 'package:hisab_business/screens/onboarding.dart';
import 'package:hisab_business/services/lock_service.dart';

import 'boot_test.dart'; // temp-Hive boot helper: initTestHive()

/// Access-crew tests (onboarding, business setup, app lock).
/// Boots the real HiveService against a temp dir via boot_test.dart.
void main() {
  setUpAll(() async {
    await initTestHive();
    AppLocale.current.value = 'en';
    // LockService persistence bypass: widget tests run in FakeAsync where
    // Hive writes never complete (and would wedge the box's write queue).
    // The memory cache is the source of truth for every getter.
    LockService.debugBypassPersistence = true;
  });

  setUp(() async {
    // Hive writes never complete inside testWidgets' FakeAsync zone, so
    // drive the cleanup in the real async zone. LockService's memory cache
    // is reset (with debugBypassPersistence on, mem is the only state that
    // matters — LockService never touches Hive in these tests).
    await TestWidgetsFlutterBinding.ensureInitialized().runAsync(() async {
      await HiveService.settings.delete('pinHash');
      await HiveService.business.clear();
      await HiveService.setFirstRun(true);
    });
    LockService.resetMemory();
    await LockService.clearLockout();
  });

  // ------------------------------------------------------------ test app

  MaterialApp testApp(
      {String initial = Routes.onboarding, Object? initialArgs}) {
    Route<dynamic> gen(RouteSettings s) {
      final Widget child;
      switch (s.name) {
        case Routes.onboarding:
          child = const OnboardingScreen();
        case Routes.businessSetup:
          child = const BusinessSetupScreen();
        case Routes.lock:
          child = const LockScreen();
        default:
          child = const Scaffold(body: Text('HOME'));
      }
      return MaterialPageRoute(builder: (_) => child, settings: s);
    }

    return MaterialApp(
      onGenerateRoute: gen,
      onGenerateInitialRoutes: (name) => [
        MaterialPageRoute(
          builder: (_) => _InitialChild(route: initial),
          settings: RouteSettings(name: name, arguments: initialArgs),
        ),
      ],
    );
  }

  Future<void> enterPin(WidgetTester tester, String pin) async {
    for (final c in pin.split('')) {
      await tester.tap(find.text(c));
      await tester.pump(const Duration(milliseconds: 80));
    }
    // The lock screen waits ~160ms for the 4th dot to paint before judging.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  /// Phone-sized portrait viewport for lock-screen tests. The PIN pad is
  /// width-driven (keypad keys scale with screen width), so the default
  /// 800x600 test surface overflows; a phone viewport matches the real
  /// form factor and keeps the layout exception-free.
  void usePhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  // ------------------------------------------------------------ lock_service

  group('LockService', () {
    test('hashPin is a stable 64-char hex digest', () {
      final h1 = LockService.hashPin('1234');
      expect(h1, LockService.hashPin('1234'));
      expect(h1.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(h1), isTrue);
      expect(LockService.hashPin('4321'), isNot(h1));
    });

    test('setPin / verifyPin round-trip, then clearPin', () async {
      await LockService.setPin('2468');
      expect(LockService.isPinSet, isTrue);
      expect(LockService.verifyPin('2468'), isTrue);
      expect(LockService.verifyPin('0000'), isFalse);
      await LockService.clearPin();
      expect(LockService.isPinSet, isFalse);
      expect(LockService.verifyPin('2468'), isFalse);
    });

    test('lockout after maxAttempts failures, then expiry + reset', () async {
      expect(LockService.isLockedOut(), isFalse);
      for (var i = 0; i < LockService.maxAttempts - 1; i++) {
        await LockService.recordFailedAttempt();
      }
      expect(LockService.failedAttempts, LockService.maxAttempts - 1);
      expect(LockService.isLockedOut(), isFalse);

      await LockService.recordFailedAttempt();
      expect(LockService.isLockedOut(), isTrue);
      expect(LockService.lockoutRemaining(), isNotNull);

      // Simulate the 2-minute window passing.
      await HiveService.settings.put(
          'pinLockoutUntil',
          DateTime.now()
              .subtract(const Duration(seconds: 1))
              .toIso8601String());
      LockService.resetMemory();
      expect(LockService.isLockedOut(), isFalse);
      expect(LockService.failedAttempts, 0);

      await LockService.recordFailedAttempt();
      await LockService.clearLockout();
      expect(LockService.failedAttempts, 0);
      expect(LockService.isLockedOut(), isFalse);
    });
  });

  // ------------------------------------------------------------ l10n

  test('accessStrings has en+ur for every key', () {
    final en = accessStrings['en']!;
    final ur = accessStrings['ur']!;
    expect(en.keys.toSet(), ur.keys.toSet());
    for (final k in en.keys) {
      expect(accessTr(k), isNot(k));
    }
  });

  // ------------------------------------------------------------ onboarding

  testWidgets('onboarding: swipe through pages, Get Started -> setup',
      (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text(accessTr('access.onb1.title')), findsOneWidget);

    await tester.fling(
        find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text(accessTr('access.onb2.title')), findsOneWidget);

    await tester.fling(
        find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text(accessTr('access.onb3.title')), findsOneWidget);

    await tester.tap(find.text(accessTr('access.getStarted')));
    await tester.pumpAndSettle();
    expect(find.byType(BusinessSetupScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding: Skip jumps straight to setup', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text(accessTr('access.skip')));
    await tester.pumpAndSettle();
    expect(find.byType(BusinessSetupScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ------------------------------------------------------------ business setup

  testWidgets('business setup: validation, category pick, save -> lock create',
      (tester) async {
    // The flow lands on the lock screen: use a phone viewport (see helper).
    usePhoneViewport(tester);

    await tester.pumpWidget(testApp(initial: Routes.businessSetup));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Empty name -> validation error, no navigation.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('This field is required'), findsOneWidget);
    expect(find.byType(BusinessSetupScreen), findsOneWidget);

    // Fill the form.
    await tester.enterText(
        find.byType(TextFormField).first, 'Ahmed Kiryana Store');
    await tester.tap(find.text(accessTr('access.biz.choose')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(accessTr('access.cat.kiryana')));
    await tester.pumpAndSettle();
    expect(find.text(accessTr('access.cat.kiryana')), findsWidgets);

    // The save writes to Hive, which never completes inside testWidgets'
    // FakeAsync zone: tap in the real async zone and let the write finish.
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Landed on the lock screen in create mode; business persisted.
    expect(find.byType(LockScreen), findsOneWidget);
    expect(find.text(accessTr('access.lock.createTitle')), findsOneWidget);
    final b = HiveService.currentBusiness;
    expect(b, isNotNull);
    expect(b!.name, 'Ahmed Kiryana Store');
    expect(b.category, 'kiryana');
    expect(HiveService.businessId, b.id);
    expect(HiveService.firstRun, isFalse);
  });

  testWidgets('business setup: edit mode prefills, saves, then pops',
      (tester) async {
    final now = DateTime.now();
    // Hive writes need the real async zone (see setUp note).
    await TestWidgetsFlutterBinding.ensureInitialized().runAsync(() async {
      await HiveService.business.put(
          'b-edit-1',
          BusinessProfile(
              id: 'b-edit-1',
              name: 'Old Name',
              category: 'pharmacy',
              phone: '0300111222',
              address: 'Addr',
              ownerName: 'Owner',
              createdAt: now));
      await HiveService.setBusinessId('b-edit-1');
      await HiveService.setFirstRun(false);
    });

    await tester.pumpWidget(MaterialApp(
      home: Builder(
          builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pushNamed('/s',
                        arguments: const {'mode': 'edit'}),
                    child: const Text('OPEN'),
                  ),
                ),
              )),
      onGenerateRoute: (s) => s.name == '/s'
          ? MaterialPageRoute(
              builder: (_) => const BusinessSetupScreen(), settings: s)
          : null,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(find.text(accessTr('access.biz.editTitle')), findsOneWidget);
    final nameField =
        tester.widget<TextFormField>(find.byType(TextFormField).first);
    expect(nameField.controller!.text, 'Old Name');
    expect(find.text(accessTr('access.cat.pharmacy')), findsWidgets);

    await tester.enterText(find.byType(TextFormField).first, 'New Name');
    // Save writes to Hive: tap in the real async zone (see create test).
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();
    expect(find.text('OPEN'), findsOneWidget); // popped back
    expect(HiveService.currentBusiness!.name, 'New Name');
    expect(HiveService.firstRun, isFalse); // edit mode never flips this
    expect(tester.takeException(), isNull);
  });

  // ------------------------------------------------------------ lock: create

  testWidgets('lock create: matching PINs -> home, PIN stored',
      (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
        testApp(initial: Routes.lock, initialArgs: const {'mode': 'create'}));
    await tester.pumpAndSettle();
    expect(find.text(accessTr('access.lock.createTitle')), findsOneWidget);

    await enterPin(tester, '1234');
    expect(find.text(accessTr('access.lock.confirmBody')), findsOneWidget);

    await enterPin(tester, '1234');
    expect(find.text('HOME'), findsOneWidget);
    expect(LockService.verifyPin('1234'), isTrue);
    // Let the "PIN saved" toast auto-dismiss (its 2s timer is still pending).
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('lock create: mismatch shows error and restarts', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
        testApp(initial: Routes.lock, initialArgs: const {'mode': 'create'}));
    await tester.pumpAndSettle();

    await enterPin(tester, '1234');
    await enterPin(tester, '5678');
    expect(find.text(accessTr('access.lock.mismatch')), findsOneWidget);
    expect(find.byType(LockScreen), findsOneWidget);
    expect(LockService.isPinSet, isFalse);
  });

  // ------------------------------------------------------------ lock: enter

  testWidgets('lock enter: wrong PIN errors, right PIN -> home',
      (tester) async {
    usePhoneViewport(tester);
    await LockService.setPin('1234');
    await tester.pumpWidget(
        testApp(initial: Routes.lock, initialArgs: const {'mode': 'enter'}));
    await tester.pumpAndSettle();
    expect(find.text(accessTr('access.lock.enterTitle')), findsOneWidget);
    // No fingerprint button when biometrics are off.
    expect(find.byIcon(Icons.fingerprint), findsNothing);
    // Forgot PIN link is present.
    expect(find.text(accessTr('access.lock.forgot')), findsOneWidget);

    await enterPin(tester, '1111');
    expect(find.text(accessTr('access.lock.wrong')), findsOneWidget);
    expect(find.byType(LockScreen), findsOneWidget);

    await enterPin(tester, '1234');
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('lock enter: 5 wrong PINs -> 2-minute lockout UI',
      (tester) async {
    usePhoneViewport(tester);
    await LockService.setPin('1234');
    await tester.pumpWidget(
        testApp(initial: Routes.lock, initialArgs: const {'mode': 'enter'}));
    await tester.pumpAndSettle();

    for (var i = 0; i < LockService.maxAttempts; i++) {
      for (final c in '1111'.split('')) {
        await tester.tap(find.text(c));
        await tester.pump(const Duration(milliseconds: 80));
      }
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(tester.takeException(), isNull);
    expect(LockService.isLockedOut(), isTrue);
    // Countdown message visible (partial match; seconds vary).
    expect(
        find.byWidgetPredicate((w) =>
            w is Text && (w.data ?? '').contains('Try again in')),
        findsOneWidget);

    // Expire the lockout through the service; the ticking timer clears UI.
    await LockService.clearLockout();
    await tester.pump(const Duration(seconds: 2));
    expect(LockService.isLockedOut(), isFalse);
    expect(
        find.byWidgetPredicate((w) =>
            w is Text && (w.data ?? '').contains('Try again in')),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lock enter: Forgot PIN dialog opens and cancels',
      (tester) async {
    usePhoneViewport(tester);
    await LockService.setPin('1234');
    await tester.pumpWidget(
        testApp(initial: Routes.lock, initialArgs: const {'mode': 'enter'}));
    await tester.pumpAndSettle();

    await tester.tap(find.text(accessTr('access.lock.forgot')));
    await tester.pumpAndSettle();
    expect(find.text(accessTr('access.lock.forgotTitle')), findsOneWidget);
    expect(find.text(accessTr('access.lock.forgotBody')), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text(accessTr('access.lock.forgotTitle')), findsNothing);
    // Data untouched.
    expect(LockService.isPinSet, isTrue);
    expect(tester.takeException(), isNull);
  });

  // ------------------------------------------------------------ lock: change

  testWidgets('lock change: old PIN -> new PIN twice -> popped, PIN updated',
      (tester) async {
    usePhoneViewport(tester);
    await LockService.setPin('1234');
    await tester.pumpWidget(MaterialApp(
      onGenerateRoute: (s) {
        if (s.name == Routes.lock) {
          return MaterialPageRoute(
              builder: (_) => const LockScreen(), settings: s);
        }
        return MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('SETTINGS')),
            settings: s);
      },
      initialRoute: '/',
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SETTINGS')); // placeholder tap target
    // Push the change screen manually with arguments.
    final ctx = tester.element(find.text('SETTINGS'));
    Navigator.of(ctx)
        .pushNamed(Routes.lock, arguments: const {'mode': 'change'});
    await tester.pumpAndSettle();

    expect(find.text(accessTr('access.lock.changeOld')), findsWidgets);
    await enterPin(tester, '9999'); // wrong old PIN
    expect(find.text(accessTr('access.lock.wrong')), findsOneWidget);
    await enterPin(tester, '1234'); // right old PIN
    expect(find.text(accessTr('access.lock.changeNew')), findsWidgets);

    await enterPin(tester, '5678');
    await enterPin(tester, '5678');
    expect(find.text('SETTINGS'), findsOneWidget); // popped
    expect(LockService.verifyPin('5678'), isTrue);
    expect(LockService.verifyPin('1234'), isFalse);
    // Let the "PIN changed" toast auto-dismiss (its 2s timer is pending).
    await tester.pump(const Duration(seconds: 3));
  });

  // ------------------------------------------------------------ lock: verify

  testWidgets('lock verify: correct PIN pops true', (tester) async {
    usePhoneViewport(tester);
    await LockService.setPin('1234');
    bool? result;
    await tester.pumpWidget(MaterialApp(
      onGenerateRoute: (s) {
        if (s.name == Routes.lock) {
          return MaterialPageRoute(
              builder: (_) => const LockScreen(), settings: s);
        }
        return MaterialPageRoute(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await Navigator.of(ctx).pushNamed(Routes.lock,
                      arguments: const {'mode': 'verify'}) as bool?;
                },
                child: const Text('OPEN'),
              ),
            ),
          ),
          settings: s,
        );
      },
      initialRoute: '/',
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    expect(find.text(accessTr('access.lock.verifyTitle')), findsOneWidget);

    await enterPin(tester, '1234');
    expect(result, isTrue);
    expect(tester.takeException(), isNull);
  });
}

/// Wraps the initial route so [testApp] can inject [initialArgs] into the
/// initial [RouteSettings] (MaterialApp has no initialRouteArguments).
class _InitialChild extends StatelessWidget {
  final String route;
  const _InitialChild({required this.route});

  @override
  Widget build(BuildContext context) {
    switch (route) {
      case Routes.onboarding:
        return const OnboardingScreen();
      case Routes.businessSetup:
        return const BusinessSetupScreen();
      case Routes.lock:
        return const LockScreen();
      default:
        return const Scaffold(body: Text('HOME'));
    }
  }
}
