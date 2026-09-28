import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import '../data/hive_service.dart';

/// PIN + lockout logic for the app lock.
///
/// The PIN is never stored in plain text — only its SHA-256 hash lives in
/// the `settings` box. Failed attempts are tracked there too; after
/// [maxAttempts] wrong tries the pad locks for [lockoutDuration].
/// (2-minute lockout was observed in competitor research; the 5-attempt
/// threshold is an [INFERRED] choice.)
///
/// Write-through memory cache: security reads ([verifyPin], [isPinSet],
/// [isLockedOut]) are served from memory first so the PIN pad never waits
/// on disk I/O. Writes update memory synchronously and persist to Hive in
/// the background ([unawaited]) — disk stays the source of truth across
/// restarts; the only risk window is a process kill within milliseconds of
/// a write, which at worst drops a lockout counter or a just-set PIN.
abstract final class LockService {
  // [INFERRED] number of wrong PINs before the lockout kicks in.
  static const int maxAttempts = 5;

  /// [INFERRED] cooldown after [maxAttempts] failures (matches the
  /// "locked for 2 minutes" behaviour seen in research).
  static const Duration lockoutDuration = Duration(minutes: 2);

  static const _pinLength = 4;
  static int get pinLength => _pinLength;

  static const _failuresKey = 'pinFailures';
  static const _lockoutUntilKey = 'pinLockoutUntil';

  // ------------------------------------------------------- memory cache
  // null / -1 / false = not loaded yet -> fall back to Hive (disk).
  static String? _memPinHash;
  static int _memFailures = -1;
  static String? _memLockoutUntil;
  static bool _memLockoutLoaded = false;

  /// Drops the memory cache (tests only). Disk is untouched.
  @visibleForTesting
  static void resetMemory() {
    _memPinHash = null;
    _memFailures = -1;
    _memLockoutUntil = null;
    _memLockoutLoaded = false;
  }

  /// Test-only: when true, [setPin], [clearPin], [recordFailedAttempt] and
  /// [clearLockout] update only the memory cache and skip Hive entirely.
  ///
  /// Why: in widget tests, Hive writes never complete (FakeAsync), and
  /// worse, Hive's [ReadWriteSync] chains every write onto the previous
  /// one — a single un-completable write permanently wedges that box for
  /// the rest of the test process, hanging every later test's setUp. With
  /// the bypass on, the memory cache (which every getter already prefers)
  /// is the sole source of truth and no write is ever started in the fake
  /// zone. Production keeps this false: background persistence stays on.
  @visibleForTesting
  static bool debugBypassPersistence = false;

  static void _persist(Future<void> Function() write) {
    if (debugBypassPersistence) return;
    unawaited(write());
  }

  // ---------------------------------------------------------------- hashing

  /// SHA-256 hex digest of [pin]. The raw PIN never touches disk.
  static String hashPin(String pin) {
    final bytes = utf8.encode('hisab-business-pin:$pin');
    return sha256.convert(bytes).toString();
  }

  /// Stores the hash of [pin] as the app PIN.
  static Future<void> setPin(String pin) async {
    _memPinHash = hashPin(pin);
    _persist(() => HiveService.setPinHash(_memPinHash!));
  }

  /// True when an app PIN exists.
  static bool get isPinSet {
    final h = _memPinHash ?? HiveService.pinHash;
    return h != null && h.isNotEmpty;
  }

  /// Checks [pin] against the stored hash using a constant-time compare.
  static bool verifyPin(String pin) {
    final stored = _memPinHash ?? HiveService.pinHash;
    if (stored == null || stored.isEmpty) return false;
    return _constantTimeEquals(stored, hashPin(pin));
  }

  /// Removes the app PIN (used when the user switches the lock off).
  static Future<void> clearPin() async {
    _memPinHash = null;
    _persist(() => HiveService.settings.delete('pinHash'));
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  // ---------------------------------------------------------------- lockout

  /// Wrong-PIN attempts since the last success or lockout reset.
  static int get failedAttempts => _memFailures >= 0
      ? _memFailures
      : HiveService.settings.get(_failuresKey) as int? ?? 0;

  /// Records one failed attempt; starts the lockout at [maxAttempts].
  static Future<void> recordFailedAttempt() async {
    final n = failedAttempts + 1;
    _memFailures = n;
    if (n >= maxAttempts) {
      _memLockoutUntil = DateTime.now().add(lockoutDuration).toIso8601String();
      _memLockoutLoaded = true;
    }
    _persist(() => _persistFailures(n));
  }

  static Future<void> _persistFailures(int n) async {
    await HiveService.settings.put(_failuresKey, n);
    if (n >= maxAttempts && _memLockoutUntil != null) {
      await HiveService.settings.put(_lockoutUntilKey, _memLockoutUntil);
    }
  }

  static String? get _lockoutUntilRaw => _memLockoutLoaded
      ? _memLockoutUntil
      : HiveService.settings.get(_lockoutUntilKey) as String?;

  /// True while the lockout is active. An expired lockout clears itself.
  static bool isLockedOut() {
    if (failedAttempts < maxAttempts) return false;
    final raw = _lockoutUntilRaw;
    if (raw == null) return false;
    final until = DateTime.tryParse(raw);
    if (until == null) return false;
    if (DateTime.now().isBefore(until)) return true;
    // Expired — reset quietly.
    clearLockout();
    return false;
  }

  /// How long the lockout still lasts, or null when not locked out.
  static Duration? lockoutRemaining() {
    if (failedAttempts < maxAttempts) return null;
    final raw = _lockoutUntilRaw;
    final until = raw == null ? null : DateTime.tryParse(raw);
    if (until == null) return null;
    final left = until.difference(DateTime.now());
    if (left.isNegative || left == Duration.zero) {
      clearLockout();
      return null;
    }
    return left;
  }

  /// Resets the failure counter and any active lockout.
  static Future<void> clearLockout() async {
    _memFailures = 0;
    _memLockoutUntil = null;
    _memLockoutLoaded = true;
    _persist(() => HiveService.settings.put(_failuresKey, 0));
    _persist(() => HiveService.settings.delete(_lockoutUntilKey));
  }

  // ---------------------------------------------------------------- biometrics

  static final LocalAuthentication _auth = LocalAuthentication();

  /// True when the device can check biometrics (never throws).
  static Future<bool> canUseBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// Shows the system biometric prompt. Returns true on success,
  /// false on failure/cancel. Never throws.
  static Future<bool> biometricAuthenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------- data reset

  /// Clears EVERY Hive box and re-seeds defaults (fresh start).
  /// Used only by the "Forgot PIN?" flow.
  static Future<void> resetEverything() => HiveService.resetAll();
}
