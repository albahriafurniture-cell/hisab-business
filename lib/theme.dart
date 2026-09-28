import 'package:flutter/material.dart';

/// Hisab Business design tokens — 100% original palette.
/// "Warm shopkeeper" language: warm off-white page, deep ink text,
/// one strong tandoor-orange brand, green/red reserved for money direction.
///
/// Chosen brand: #EB5E1C ("tandoor orange"). Money semantics:
///   GREEN = money IN  (you got cash / you will give / payable-to-you)
///   RED   = money OUT (you gave cash / you will get / receivable-from-you)
/// This matches the dominant khata-app convention users already know.
abstract final class HBColors {
  // Brand
  static const primary = Color(0xFFEB5E1C);
  static const primaryDeep = Color(0xFFC74812);
  static const primarySoft = Color(0xFFFFEFE3); // tile tints
  static const primarySofter = Color(0xFFFFF7F0); // light card bg
  static const gradientTop = Color(0xFFFF8A2A);
  static const gradientBottom = Color(0xFFEB5E1C);

  // Money semantics
  static const moneyIn = Color(0xFF1E9E50);
  static const moneyInSoft = Color(0xFFE4F6EA);
  static const moneyInDeep = Color(0xFF127A3C);
  static const moneyOut = Color(0xFFE0443A);
  static const moneyOutSoft = Color(0xFFFDE6E4);
  static const moneyOutDeep = Color(0xFFB3261E);

  // Light neutrals
  static const page = Color(0xFFF7F6F2);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF22211F);
  static const muted = Color(0xFF8A8780);
  static const hairline = Color(0xFFE8E5DE);

  // Dark neutrals
  static const pageDark = Color(0xFF151311);
  static const cardDark = Color(0xFF211E1A);
  static const inkDark = Color(0xFFF4F1EA);
  static const mutedDark = Color(0xFF9C968C);
  static const hairlineDark = Color(0xFF38332C);
  static const primarySoftDark = Color(0xFF3A2417);
  static const moneyInSoftDark = Color(0xFF1B3325);
  static const moneyOutSoftDark = Color(0xFF3B211E);

  // Extras
  static const infoBlue = Color(0xFF1D7FE0);
  static const infoSoft = Color(0xFFE3EFFE);
  static const amber = Color(0xFFF5A623);
  static const purple = Color(0xFF7C5CE0);
}

ThemeData buildLightTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: HBColors.primary,
      primary: HBColors.primary,
      surface: HBColors.page,
    ),
    scaffoldBackgroundColor: HBColors.page,
    cardColor: HBColors.card,
    dividerColor: HBColors.hairline,
    appBarTheme: const AppBarTheme(
      backgroundColor: HBColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
    ),
    textTheme: base.textTheme.copyWith(
      headlineSmall:
          const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      titleMedium:
          const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      bodyMedium: const TextStyle(fontSize: 14),
      labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: HBColors.muted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: HBColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        textStyle:
            const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: HBColors.primary,
        side: const BorderSide(color: HBColors.primary),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        textStyle:
            const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: HBColors.primary,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: HBColors.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: HBColors.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: HBColors.primary, width: 2),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: HBColors.primary,
      unselectedItemColor: HBColors.muted,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 12),
    ),
  );
}

ThemeData buildDarkTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: HBColors.primary,
      brightness: Brightness.dark,
      primary: HBColors.primary,
      surface: HBColors.pageDark,
    ),
    scaffoldBackgroundColor: HBColors.pageDark,
    cardColor: HBColors.cardDark,
    dividerColor: HBColors.hairlineDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: HBColors.cardDark,
      foregroundColor: HBColors.inkDark,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: HBColors.inkDark),
    ),
    textTheme: base.textTheme.copyWith(
      headlineSmall: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.bold, color: HBColors.inkDark),
      titleMedium: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600, color: HBColors.inkDark),
      bodyMedium: const TextStyle(fontSize: 14, color: HBColors.inkDark),
      labelSmall: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: HBColors.mutedDark),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: HBColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        textStyle:
            const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: HBColors.primary,
        side: const BorderSide(color: HBColors.primary),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        textStyle:
            const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: HBColors.primary,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: HBColors.cardDark,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: HBColors.hairlineDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: HBColors.hairlineDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: HBColors.primary, width: 2),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: HBColors.cardDark,
      selectedItemColor: HBColors.primary,
      unselectedItemColor: HBColors.mutedDark,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 12),
    ),
  );
}

/// Color for a money amount by direction. [isIn] = money moved toward the
/// business (got / in / deposit / paid). [isDark] picks dark-mode variant.
Color moneyColor(bool isIn, {bool isDark = false}) =>
    isIn ? HBColors.moneyIn : HBColors.moneyOut;

/// Soft tint background paired with [moneyColor].
Color moneySoft(bool isIn, {bool isDark = false}) => isDark
    ? (isIn ? HBColors.moneyInSoftDark : HBColors.moneyOutSoftDark)
    : (isIn ? HBColors.moneyInSoft : HBColors.moneyOutSoft);
