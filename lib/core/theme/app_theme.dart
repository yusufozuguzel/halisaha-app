import 'package:flutter/material.dart';

// ─── Sabit yeşil renk (her iki temada aynı) ───────────────────────────────────
const kGreen = Color(0xFF2EED7B);

// ─── Karanlık tema renk sabitleri ─────────────────────────────────────────────
const kDarkBg = Color(0xFF0F1712);
const kDarkCard = Color(0xFF16221A);
const kDarkCardBorder = Color(0xFF2A3D2F);
const kDarkLabel = Color(0xFF8BAF92);
const kDarkTextWhite = Color(0xFFE8F5EC);

// ─── Karanlık Tema ────────────────────────────────────────────────────────────
final darkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kDarkBg,
  cardColor: kDarkCard,
  colorScheme: const ColorScheme.dark(
    primary: kGreen,
    secondary: kGreen,
    surface: kDarkCard,
    onPrimary: kDarkBg,
    onSurface: Colors.white,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: kDarkCard,
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.selected) ? kGreen : Colors.white54,
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.selected)
          ? kGreen.withOpacity(0.3)
          : Colors.white12,
    ),
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Colors.white),
    bodySmall: TextStyle(color: Colors.white70),
  ),
  dividerColor: Colors.white12,
);

// ─── Aydınlık Tema ────────────────────────────────────────────────────────────
final lightTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: Colors.white,
  cardColor: const Color(0xFFF0F4F1),
  colorScheme: ColorScheme.light(
    primary: kGreen,
    secondary: kGreen,
    surface: const Color(0xFFF0F4F1),
    onPrimary: Colors.white,
    onSurface: Colors.black87,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Colors.black87,
    elevation: 0,
    shadowColor: Colors.black12,
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.selected) ? kGreen : Colors.grey,
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.selected)
          ? kGreen.withOpacity(0.3)
          : Colors.grey.withOpacity(0.2),
    ),
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Colors.black87),
    bodySmall: TextStyle(color: Colors.black54),
  ),
  dividerColor: Colors.black12,
);

// ─── AppColors: Context'e göre dinamik renk yardımcıları ─────────────────────
class AppColors {
  AppColors._();

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Sayfa arka plan rengi
  static Color bg(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  /// Kart arka plan rengi
  static Color card(BuildContext context) => Theme.of(context).cardColor;

  /// Bottom nav arka plan
  static Color navBg(BuildContext context) =>
      isDark(context) ? kDarkCard : Colors.white;

  /// Ana metin rengi
  static Color text(BuildContext context) =>
      isDark(context) ? Colors.white : Colors.black87;

  /// İkincil metin rengi
  static Color subText(BuildContext context) =>
      isDark(context) ? Colors.white54 : Colors.black45;

  /// Bölüm başlık etiketi
  static Color sectionLabel(BuildContext context) => isDark(context)
      ? Colors.white.withOpacity(0.4)
      : Colors.black.withOpacity(0.35);

  /// İnce kenar/border rengi
  static Color border(BuildContext context) => isDark(context)
      ? Colors.white.withOpacity(0.06)
      : Colors.black.withOpacity(0.08);

  /// Inputlarda kullanılan border
  static Color inputBorder(BuildContext context) =>
      isDark(context) ? kDarkCardBorder : Colors.black.withOpacity(0.12);

  /// Greenish-grey etiket rengi (input label vb.)
  static Color labelColor(BuildContext context) =>
      isDark(context) ? kDarkLabel : Colors.black54;

  /// Off-white → dark mode: E8F5EC, light mode: siyah
  static Color textWhite(BuildContext context) =>
      isDark(context) ? kDarkTextWhite : Colors.black87;

  /// Neon'un dim versiyonu (ikonların arka planı)
  static Color neonDim(BuildContext context) =>
      isDark(context) ? const Color(0xFF1A3325) : kGreen.withOpacity(0.1);

  /// Hafif overlay rengi
  static Color overlay(BuildContext context) => isDark(context)
      ? Colors.white.withOpacity(0.05)
      : Colors.black.withOpacity(0.04);

  /// Nav item pasif renk
  static Color navInactive(BuildContext context) => isDark(context)
      ? Colors.white.withOpacity(0.4)
      : Colors.black.withOpacity(0.4);

  /// Dropdown arkaplan
  static Color dropdownBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF1A2E1F) : Colors.white;
}
