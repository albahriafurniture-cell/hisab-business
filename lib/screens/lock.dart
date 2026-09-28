import 'dart:async';

import 'package:flutter/material.dart';

import '../data/hive_service.dart';
import '../l10n/access_l10n.dart';
import '../l10n/strings.dart';
import '../routes.dart';
import '../services/lock_service.dart';
import '../theme.dart';
import '../widgets/hb_chrome.dart';

/// App-lock screen. Mode comes from route arguments
/// `{'mode': 'create'|'enter'|'change'|'verify'}` and defaults to `'enter'`.
///
///   - create : pick a new 4-digit PIN, then confirm it → home.
///   - enter  : verify the stored PIN (with lockout + optional biometric) → home.
///   - change : verify the old PIN, then pick a new one → pop.
///   - verify : one-shot PIN check (e.g. before switching the lock off) →
///              pops `true` on success.
///
/// The constructor stays const because `routes.dart`/`main.dart` register the
/// screen without arguments; the mode is read from [ModalRoute] settings.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  /// Route name for this screen.
  static const routeName = Routes.lock;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with SingleTickerProviderStateMixin {
  String _mode = 'enter';
  bool _ready = false;

  String _pin = '';
  String _firstPin = '';
  int _step = 0; // create: 0 enter, 1 confirm · change: 0 old, 1 new, 2 confirm
  String? _error;

  bool _lockedOut = false;
  Duration? _remaining;
  Timer? _timer;

  bool _biometricAvailable = false;

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _shakeX = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: -12), weight: 1),
    TweenSequenceItem(tween: Tween(begin: -12, end: 12), weight: 2),
    TweenSequenceItem(tween: Tween(begin: 12, end: -8), weight: 2),
    TweenSequenceItem(tween: Tween(begin: -8, end: 0), weight: 1),
  ]).animate(CurvedAnimation(parent: _shake, curve: Curves.easeOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final m = args['mode'];
      if (m is String && const {'create', 'enter', 'change', 'verify'}.contains(m)) {
        _mode = m;
      }
    }
    if (LockService.isLockedOut()) _startLockout();
    if (_mode == 'enter' && HiveService.biometricEnabled) {
      LockService.canUseBiometrics().then((v) {
        if (mounted) setState(() => _biometricAvailable = v);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shake.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ titles

  String get _title => switch (_mode) {
        'create' => accessTr('access.lock.createTitle'),
        'change' => accessTr('access.lock.changeOld'),
        'verify' => accessTr('access.lock.verifyTitle'),
        _ => accessTr('access.lock.enterTitle'),
      };

  String get _subtitle => switch ((_mode, _step)) {
        ('create', 0) => accessTr('access.lock.createBody'),
        ('create', _) => accessTr('access.lock.confirmBody'),
        ('change', 0) => accessTr('access.lock.changeOld'),
        ('change', 1) => accessTr('access.lock.changeNew'),
        ('change', _) => accessTr('access.lock.confirmBody'),
        ('verify', _) => accessTr('access.lock.verifyBody'),
        _ => accessTr('access.lock.enterBody'),
      };

  // ------------------------------------------------------------------ keypad

  void _press(String key) {
    if (_lockedOut) return;
    setState(() {
      _error = null;
      if (key == 'del') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else if (_pin.length < LockService.pinLength) {
        _pin += key;
      }
    });
    if (_pin.length == LockService.pinLength && key != 'del') {
      // Let the fourth dot paint before judging the PIN.
      Future.delayed(const Duration(milliseconds: 160), () {
        if (mounted) _complete();
      });
    }
  }

  Future<void> _complete() async {
    final pin = _pin;
    if (pin.length != LockService.pinLength) return;
    if (LockService.isLockedOut()) {
      _startLockout();
      return;
    }
    switch (_mode) {
      case 'create':
        await _createStep(pin);
      case 'change':
        await _changeStep(pin);
      default:
        await _verifyStep(pin); // enter + verify
    }
  }

  Future<void> _createStep(String pin) async {
    if (_step == 0) {
      setState(() {
        _firstPin = pin;
        _pin = '';
        _step = 1;
      });
      return;
    }
    if (pin == _firstPin) {
      await LockService.setPin(pin);
      if (!mounted) return;
      HBToast.show(context, message: accessTr('access.lock.pinSaved'));
      Navigator.of(context).pushReplacementNamed(Routes.home);
    } else {
      _fail(accessTr('access.lock.mismatch'));
      setState(() {
        _step = 0;
        _firstPin = '';
      });
    }
  }

  Future<void> _changeStep(String pin) async {
    if (_step == 0) {
      if (LockService.verifyPin(pin)) {
        setState(() {
          _pin = '';
          _step = 1;
        });
      } else {
        await _wrongPin();
      }
      return;
    }
    if (_step == 1) {
      setState(() {
        _firstPin = pin;
        _pin = '';
        _step = 2;
      });
      return;
    }
    if (pin == _firstPin) {
      await LockService.setPin(pin);
      if (!mounted) return;
      HBToast.show(context, message: accessTr('access.lock.pinChanged'));
      Navigator.of(context).pop();
    } else {
      _fail(accessTr('access.lock.mismatch'));
      setState(() {
        _step = 1;
        _firstPin = '';
      });
    }
  }

  Future<void> _verifyStep(String pin) async {
    if (LockService.verifyPin(pin)) {
      await LockService.clearLockout();
      if (!mounted) return;
      if (_mode == 'verify') {
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).pushReplacementNamed(Routes.home);
      }
    } else {
      await _wrongPin();
    }
  }

  Future<void> _wrongPin() async {
    await LockService.recordFailedAttempt();
    if (LockService.isLockedOut()) {
      _startLockout();
    } else {
      _fail(accessTr('access.lock.wrong'));
    }
  }

  void _fail(String message) {
    setState(() {
      _error = message;
      _pin = '';
    });
    _shake.forward(from: 0);
  }

  void _startLockout() {
    _timer?.cancel();
    setState(() {
      _lockedOut = true;
      _pin = '';
      _error = null;
      _remaining = LockService.lockoutRemaining();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = LockService.lockoutRemaining();
      if (!mounted) return;
      if (left == null) {
        _timer?.cancel();
        setState(() {
          _lockedOut = false;
          _remaining = null;
        });
      } else {
        setState(() => _remaining = left);
      }
    });
  }

  // ------------------------------------------------------------------ actions

  Future<void> _tryBiometric() async {
    final ok = await LockService.biometricAuthenticate(
        accessTr('access.lock.bioReason'));
    if (!mounted) return;
    if (ok) {
      await LockService.clearLockout();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(Routes.home);
    } else {
      HBToast.show(context,
          message: accessTr('access.lock.bioFailed'),
          tint: HBColors.moneyOutSoft);
    }
  }

  Future<void> _forgotPin() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(accessTr('access.lock.forgotTitle')),
        content: Text(accessTr('access.lock.forgotBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr(context, 'action.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(accessTr('access.lock.forgotConfirm'),
                style: const TextStyle(color: HBColors.moneyOutDeep)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await LockService.resetEverything();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(Routes.onboarding);
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.current,
      builder: (context, lang, child) => Scaffold(
        appBar: HBAppBar(
          title: _title,
          showBack: _mode == 'change' || _mode == 'verify',
        ),
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _shakeX,
            builder: (context, child) => Transform.translate(
              offset: Offset(_shakeX.value, 0),
              child: child,
            ),
            child: Column(
              children: [
                const SizedBox(height: 28),
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [
                      HBColors.gradientTop,
                      HBColors.gradientBottom
                    ]),
                  ),
                  child: const Icon(Icons.lock_outline,
                      color: Colors.white, size: 34),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(_subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 15, color: HBColors.muted)),
                ),
                const SizedBox(height: 28),
                _Dots(count: LockService.pinLength, filled: _pin.length, error: _error != null),
                const SizedBox(height: 8),
                SizedBox(
                  height: 24,
                  child: _lockedOut
                      ? Builder(builder: (context) {
                          final tooMany = accessTr('access.lock.tooMany')
                              .replaceAll(
                                  '{m}',
                                  LockService.lockoutDuration.inMinutes
                                      .toString());
                          final retry = accessTr('access.lock.retryIn')
                              .replaceAll('{s}',
                                  (_remaining?.inSeconds ?? 0).toString());
                          return Text('$tooMany $retry',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: HBColors.moneyOutDeep, fontSize: 13));
                        })
                      : (_error == null
                          ? null
                          : Text(_error!,
                              style: const TextStyle(
                                  color: HBColors.moneyOutDeep,
                                  fontSize: 13))),
                ),
                const Spacer(),
                _Keypad(onKey: _press, enabled: !_lockedOut),
                const SizedBox(height: 12),
                if (_mode == 'enter' && _biometricAvailable && !_lockedOut)
                  TextButton.icon(
                    onPressed: _tryBiometric,
                    icon: const Icon(Icons.fingerprint,
                        color: HBColors.primary),
                    label: Text(accessTr('access.lock.bioHint'),
                        style:
                            const TextStyle(color: HBColors.primary)),
                  ),
                if ((_mode == 'enter' || _mode == 'verify') && !_lockedOut)
                  TextButton(
                    onPressed: _forgotPin,
                    child: Text(accessTr('access.lock.forgot'),
                        style: const TextStyle(color: HBColors.muted)),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int filled;
  final bool error;

  const _Dots(
      {required this.count, required this.filled, required this.error});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(horizontal: 10),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled
                  ? (error ? HBColors.moneyOut : HBColors.primary)
                  : Colors.transparent,
              border: Border.all(
                color: error ? HBColors.moneyOut : HBColors.primary,
                width: 2,
              ),
            ),
          ),
      ],
    );
  }
}

class _Keypad extends StatelessWidget {
  final void Function(String key) onKey;
  final bool enabled;

  const _Keypad({required this.onKey, required this.enabled});

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del'];
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 64),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.4,
        children: [
          for (final k in keys)
            k.isEmpty
                ? const SizedBox.shrink()
                : _KeyButton(
                    label: k,
                    onTap: enabled ? () => onKey(k) : null,
                  ),
        ],
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _KeyButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).brightness == Brightness.dark
                ? HBColors.cardDark
                : const Color(0xFFF1EFEA),
          ),
          child: Center(
            child: label == 'del'
                ? const Icon(Icons.backspace_outlined,
                    color: HBColors.muted)
                : Text(label,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}
