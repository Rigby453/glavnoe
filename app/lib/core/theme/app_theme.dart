// Темы приложения Kaizen — «Kaname» redesign v4.
// Источник правды: /docs/design-tokens.json v4 + /docs/REDESIGN-KANAME.md
//
// Ключевые изменения относительно v3:
//   • Тема = поверхности + текст + border ONLY. 4 темы: day/night/black/calm.
//   • Акцент ОТВЯЗАН от темы: 6 пользовательских акцентов (AccentKey).
//   • ОДИН шрифт (HankenGrotesk; TODO: Geist) для display и body, всех тем.
//   • Высокий контраст — НАСТРОЙКА (highContrast: bool), не отдельная тема.
//   • FocusThemeExtension: имя и все старые поля СОХРАНЕНЫ (106 файлов),
//     добавлены: accentTint, accentInk, danger, textSecondary.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'custom_theme_provider.dart' show CustomThemeConfig;

// Алгоритм вывода пользовательской палитры — часть этой библиотеки,
// чтобы получить доступ к приватному классу _Palette (нужен CustomThemePalette).
part 'custom_theme_palette.dart';

// ---------------------------------------------------------------------------
// Ключи акцентов (6 кураторских вариантов, выбираются пользователем)
// ---------------------------------------------------------------------------

/// 6 кураторских акцентов. Пользователь выбирает один, независимо от темы.
enum AccentKey { indigo, emerald, violet, ochre, rose, slate }

// ---------------------------------------------------------------------------
// Новые ключи тем (4 вместо 6 — v4 redesign)
// ---------------------------------------------------------------------------

/// Ключи тем Kaname v4. Значение по умолчанию = day.
enum AppThemeKey { day, night, black, calm }

/// Читаемые метки и ключи SharedPreferences.
extension AppThemeKeyLabel on AppThemeKey {
  String get label => switch (this) {
        AppThemeKey.day => 'Day',
        AppThemeKey.night => 'Night',
        AppThemeKey.black => 'Black',
        AppThemeKey.calm => 'Calm',
      };

  String get prefsKey => name; // 'day', 'night', 'black', 'calm'
}

// ---------------------------------------------------------------------------
// Внутренние структуры
// ---------------------------------------------------------------------------

/// Поверхности одной темы (точные hex из design-tokens.json §themes).
class _Surfaces {
  const _Surfaces({
    required this.brightness,
    required this.bg,
    required this.surface1,
    required this.surface2,
    required this.ink,
    required this.textSecondary,
    required this.textMuted,
    required this.textFaint,
    required this.border,
    required this.borderStrong,
  });

  final Brightness brightness;
  final Color bg;
  final Color surface1;     // основные карточки
  final Color surface2;     // поднятые поверхности (модалки, попапы)
  final Color ink;          // основной текст / иконки
  final Color textSecondary; // вторичный текст
  final Color textMuted;    // приглушённый текст
  final Color textFaint;    // плейсхолдеры, timestamps, disabled
  final Color border;       // границы по умолчанию (hairline)
  final Color borderStrong; // фокусированный input, активная карточка
}

/// Разрешённый акцент (light: из токенов напрямую; dark: вычисляется).
class _Accent {
  const _Accent({
    required this.accent,
    required this.tint,
    required this.ink,
    required this.on,
  });

  final Color accent; // заливка кнопок, иконок
  final Color tint;   // мягкий underlay
  final Color ink;    // текст на tint-фоне
  final Color on;     // текст/иконки поверх accent-заливки
}

// ---------------------------------------------------------------------------
// Таблицы поверхностей (hex из design-tokens.json §themes)
// ---------------------------------------------------------------------------

const _daySurfaces = _Surfaces(
  brightness: Brightness.light,
  bg: Color(0xFFF6F5F2),
  surface1: Color(0xFFFFFFFF),
  surface2: Color(0xFFFCFBF9),
  ink: Color(0xFF1B1A18),
  textSecondary: Color(0xFF6E6B66),
  textMuted: Color(0xFF8E8A85),
  textFaint: Color(0xFFB9B5B0),
  border: Color(0xFFE6E4DE),
  borderStrong: Color(0xFFD8D5CE),
);

const _nightSurfaces = _Surfaces(
  brightness: Brightness.dark,
  bg: Color(0xFF16140F),
  surface1: Color(0xFF201D17),
  surface2: Color(0xFF262219),
  ink: Color(0xFFF2EFE9),
  textSecondary: Color(0xFFA8A39A),
  textMuted: Color(0xFF827D74),
  textFaint: Color(0xFF5A554E),
  border: Color(0xFF2C2820),
  borderStrong: Color(0xFF3A352B),
);

const _blackSurfaces = _Surfaces(
  brightness: Brightness.dark,
  bg: Color(0xFF000000),
  surface1: Color(0xFF0D0D0D),
  surface2: Color(0xFF141414),
  ink: Color(0xFFFFFFFF),
  textSecondary: Color(0xFFB4B4B4),
  textMuted: Color(0xFF8A8A8A),
  textFaint: Color(0xFF555555),
  border: Color(0xFF1E1E1E),
  borderStrong: Color(0xFF2E2E2E),
);

const _calmSurfaces = _Surfaces(
  brightness: Brightness.light,
  bg: Color(0xFFEEF3F2),
  surface1: Color(0xFFFBFDFC),
  surface2: Color(0xFFF2F7F6),
  ink: Color(0xFF1A2422),
  textSecondary: Color(0xFF4F5E5B),
  textMuted: Color(0xFF6B7A77),
  textFaint: Color(0xFF9DACA9),
  border: Color(0xFFDCE6E4),
  borderStrong: Color(0xFFC7D4D1),
);

// ---------------------------------------------------------------------------
// Акцентный резолвер (design-tokens.json §accents)
// ---------------------------------------------------------------------------

/// Вычисляет _Accent для заданного ключа и яркости темы.
/// Для светлых тем — значения из токенов напрямую.
/// Для тёмных тем — tint и ink вычисляются на месте.
_Accent _accentFor(AccentKey key, Brightness brightness, Color surface1) {
  final isDark = brightness == Brightness.dark;

  switch (key) {
    case AccentKey.indigo:
      if (!isDark) {
        return const _Accent(
          accent: Color(0xFF4B57C9),
          tint: Color(0xFFECEDFA),
          ink: Color(0xFF3A45A8),
          on: Color(0xFFFFFFFF),
        );
      }
      const accent = Color(0xFF7E89E0);
      return _Accent(
        accent: accent,
        tint: Color.alphaBlend(accent.withValues(alpha: 0.16), surface1),
        ink: accent,
        on: const Color(0xFF15140F),
      );

    case AccentKey.emerald:
      if (!isDark) {
        return const _Accent(
          accent: Color(0xFF1D9E75),
          tint: Color(0xFFE1F5EE),
          ink: Color(0xFF0F6E56),
          on: Color(0xFFFFFFFF),
        );
      }
      const accent = Color(0xFF3FBF93);
      return _Accent(
        accent: accent,
        tint: Color.alphaBlend(accent.withValues(alpha: 0.16), surface1),
        ink: accent,
        on: const Color(0xFF15140F),
      );

    case AccentKey.violet:
      if (!isDark) {
        return const _Accent(
          accent: Color(0xFF7A4FC9),
          tint: Color(0xFFEFE9FB),
          ink: Color(0xFF5A33A8),
          on: Color(0xFFFFFFFF),
        );
      }
      const accent = Color(0xFFA488E6);
      return _Accent(
        accent: accent,
        tint: Color.alphaBlend(accent.withValues(alpha: 0.16), surface1),
        ink: accent,
        on: const Color(0xFF15140F),
      );

    case AccentKey.ochre:
      if (!isDark) {
        return const _Accent(
          accent: Color(0xFFB5772A),
          tint: Color(0xFFF7EEDD),
          ink: Color(0xFF7E4F10),
          on: Color(0xFFFFFFFF),
        );
      }
      const accent = Color(0xFFD9A04A);
      return _Accent(
        accent: accent,
        tint: Color.alphaBlend(accent.withValues(alpha: 0.16), surface1),
        ink: accent,
        on: const Color(0xFF15140F),
      );

    case AccentKey.rose:
      if (!isDark) {
        return const _Accent(
          accent: Color(0xFFC24E78),
          tint: Color(0xFFFBE9F0),
          ink: Color(0xFF923556),
          on: Color(0xFFFFFFFF),
        );
      }
      const accent = Color(0xFFE07AA0);
      return _Accent(
        accent: accent,
        tint: Color.alphaBlend(accent.withValues(alpha: 0.16), surface1),
        ink: accent,
        on: const Color(0xFF15140F),
      );

    case AccentKey.slate:
      if (!isDark) {
        return const _Accent(
          accent: Color(0xFF3F6E9E),
          tint: Color(0xFFE7EFF7),
          ink: Color(0xFF214B73),
          on: Color(0xFFFFFFFF),
        );
      }
      const accent = Color(0xFF6F9BC4);
      return _Accent(
        accent: accent,
        tint: Color.alphaBlend(accent.withValues(alpha: 0.16), surface1),
        ink: accent,
        on: const Color(0xFF15140F),
      );
  }
}

// ---------------------------------------------------------------------------
// _Palette — ОСТАВЛЕН для обратной совместимости с custom_theme_palette.dart.
// В основном потоке тем НЕ ИСПОЛЬЗУЕТСЯ начиная с Kaname v4.
// ---------------------------------------------------------------------------

/// Палитра одной темы (v3, необходима для CustomThemePalette в part-файле).
/// В v4 заменена на _Surfaces + _Accent; оставлена как dead-code-stub.
class _Palette {
  const _Palette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surfaceElevated,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.accent,
    required this.accentMuted,
    required this.onAccent,
    required this.ember,
    required this.success,
    required this.border,
    required this.borderStrong,
  });

  final Brightness brightness;
  final Color bg;
  final Color surface;
  final Color surfaceElevated;
  final Color text;
  final Color textMuted;
  final Color textFaint;
  final Color accent;
  final Color accentMuted;
  final Color onAccent;
  final Color ember;
  final Color success;
  final Color border;
  final Color borderStrong;
}

// ---------------------------------------------------------------------------
// AppTheme — фабрика ThemeData
// ---------------------------------------------------------------------------

/// Фабрика ThemeData для всех тем.
class AppTheme {
  AppTheme._();

  // --- Новый основной билдер (Kaname v4) ---

  /// Строит ThemeData из поверхностей темы + акцента + настроек доступности.
  ///
  /// [theme]       — одна из 4 тем (day/night/black/calm).
  /// [accent]      — один из 6 акцентов (по умолчанию indigo).
  /// [highContrast]— применяет шрифт Atkinson + увеличенный межстрочный интервал.
  /// [harshness]   — 0.0..1.0; при > 0 акцент плавно смещается в сторону ember.
  static ThemeData build({
    required AppThemeKey theme,
    AccentKey accent = AccentKey.indigo,
    bool highContrast = false,
    double harshness = 0.0,
  }) {
    final s = _surfacesFor(theme);
    final a = _accentFor(accent, s.brightness, s.surface1);
    return _buildNewTheme(s, a, highContrast: highContrast, harshness: harshness);
  }

  // --- Устаревшие compat-обёртки (сохраняют компиляцию 106 файлов и тестов) ---

  /// Focus (тёплый тёмный) → night.
  @Deprecated('Kaname redesign — use AppTheme.build(theme: AppThemeKey.night)')
  static ThemeData focusTheme({double harshness = 0.0}) =>
      build(theme: AppThemeKey.night, harshness: harshness);

  /// White (светлая) → day.
  @Deprecated('Kaname redesign — use AppTheme.build(theme: AppThemeKey.day)')
  static ThemeData whiteTheme({double harshness = 0.0}) =>
      build(theme: AppThemeKey.day, harshness: harshness);

  /// Black (OLED) → black.
  @Deprecated('Kaname redesign — use AppTheme.build(theme: AppThemeKey.black)')
  static ThemeData blackTheme({double harshness = 0.0}) =>
      build(theme: AppThemeKey.black, harshness: harshness);

  /// Calm → calm.
  @Deprecated('Kaname redesign — use AppTheme.build(theme: AppThemeKey.calm)')
  static ThemeData calmTheme({double harshness = 0.0}) =>
      build(theme: AppThemeKey.calm, harshness: harshness);

  /// Contrast (доступность) → day + highContrast: true.
  @Deprecated('Kaname redesign — use AppTheme.build(theme: AppThemeKey.day, highContrast: true)')
  static ThemeData contrastTheme({double harshness = 0.0}) =>
      build(theme: AppThemeKey.day, highContrast: true, harshness: harshness);

  /// Получить ThemeData по ключу (все 4 новые темы + compat для тестов/виджет-сервиса).
  @Deprecated('Kaname redesign — use AppTheme.build(theme: key)')
  static ThemeData forKey(AppThemeKey key, {double harshness = 0.0}) =>
      build(theme: key, harshness: harshness);

  /// Получить ThemeData с поддержкой custom-конфига.
  /// В Kaname v4 custom-тема → shim: возвращает day+indigo (Phase 4 заменит).
  @Deprecated('Kaname redesign — use AppTheme.build')
  static ThemeData forKeyWithCustom(
      AppThemeKey key, CustomThemeConfig? config, {double harshness = 0.0}) =>
      build(theme: key, harshness: harshness);

  // ---------------------------------------------------------------------------
  // Внутренний резолвер поверхностей
  // ---------------------------------------------------------------------------

  static _Surfaces _surfacesFor(AppThemeKey key) => switch (key) {
        AppThemeKey.day => _daySurfaces,
        AppThemeKey.night => _nightSurfaces,
        AppThemeKey.black => _blackSurfaces,
        AppThemeKey.calm => _calmSurfaces,
      };

  // ---------------------------------------------------------------------------
  // Основной строитель ThemeData (Kaname v4)
  // ---------------------------------------------------------------------------

  static ThemeData _buildNewTheme(
    _Surfaces s,
    _Accent a, {
    required bool highContrast,
    required double harshness,
  }) {
    final isLight = s.brightness == Brightness.light;

    // --- Статусные цвета (semantic, из §status токенов) ---
    final ember =
        isLight ? const Color(0xFFC2510C) : const Color(0xFFF0894B);
    final success =
        isLight ? const Color(0xFF1A7A3E) : const Color(0xFF46C08C);
    final danger =
        isLight ? const Color(0xFFC0362C) : const Color(0xFFE8685C);

    // --- Harshness: плавный сдвиг акцента в сторону ember ---
    final resolvedAccent = harshness > 0.0
        ? Color.lerp(a.accent, ember, (harshness * 0.7).clamp(0.0, 1.0))!
        : a.accent;

    // onAccent: при высоком harshness пересчитываем по luminance.
    final resolvedOnAccent = harshness > 0.0
        ? (resolvedAccent.computeLuminance() > 0.35
            ? const Color(0xFF0A0A0A)
            : const Color(0xFFFAFAFA))
        : a.on;

    // «Гневный» оверлей surface1 при harshness ≥ 0.75.
    final angryFactor = harshness >= 0.75 ? (harshness - 0.75) / 0.25 : 0.0;
    final resolvedSurface1 = angryFactor > 0.0
        ? Color.lerp(
            s.surface1, ember.withValues(alpha: 0.06), angryFactor * 0.4)!
        : s.surface1;

    // --- Шрифт ---
    // TODO(redesign): переключиться на Geist, когда google_fonts его экспортирует.
    final TextTheme baseDefaults = isLight
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;
    final TextTheme baseTT = highContrast
        ? GoogleFonts.atkinsonHyperlegibleTextTheme(baseDefaults)
        : GoogleFonts.hankenGroteskTextTheme(baseDefaults);

    // Параметры body для доступности
    final bodyHeight = highContrast ? 1.60 : 1.50;
    final bodyLetterSpacing = highContrast ? 0.2 : 0.0;

    // Fallback-шрифты для хинди / японского / корейского
    const scriptFallbacks = [
      'Noto Sans Devanagari',
      'Noto Sans JP',
      'Noto Sans KR',
    ];

    TextStyle? withFallback(TextStyle? style) {
      if (style == null) return null;
      return style.copyWith(fontFamilyFallback: scriptFallbacks);
    }

    final textTheme = baseTT.copyWith(
      // --- Display (w500, tight tracking) — из type_scale токенов ---
      displayLarge: withFallback(baseTT.displayLarge?.copyWith(
        fontSize: 40,
        height: 1.10,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.5,
        color: s.ink,
      )),
      displayMedium: withFallback(baseTT.displayMedium?.copyWith(
        fontSize: 32,
        height: 1.15,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.4,
        color: s.ink,
      )),
      displaySmall: withFallback(baseTT.displaySmall?.copyWith(
        fontSize: 28,
        height: 1.20,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.3,
        color: s.ink,
      )),
      // --- Headline ---
      headlineLarge: withFallback(baseTT.headlineLarge?.copyWith(
        fontSize: 24,
        height: 1.22,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.25,
        color: s.ink,
      )),
      headlineMedium: withFallback(baseTT.headlineMedium?.copyWith(
        fontSize: 22,
        height: 1.25,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
        color: s.ink,
      )),
      headlineSmall: withFallback(baseTT.headlineSmall?.copyWith(
        fontSize: 20,
        height: 1.30,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
        color: s.ink,
      )),
      // --- Title ---
      titleLarge: withFallback(baseTT.titleLarge?.copyWith(
        fontSize: 18,
        height: 1.35,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.0,
        color: s.ink,
      )),
      titleMedium: withFallback(baseTT.titleMedium?.copyWith(
        fontSize: 16,
        height: 1.40,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.0,
        color: s.ink,
      )),
      titleSmall: withFallback(baseTT.titleSmall?.copyWith(
        fontSize: 15,
        height: 1.45,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.0,
        color: s.ink,
      )),
      // --- Body (tabular figures для цифр) ---
      bodyLarge: withFallback(baseTT.bodyLarge?.copyWith(
        fontSize: 16,
        height: bodyHeight,
        fontWeight: FontWeight.w400,
        letterSpacing: bodyLetterSpacing,
        color: s.ink,
        fontFeatures: const [FontFeature.tabularFigures()],
      )),
      bodyMedium: withFallback(baseTT.bodyMedium?.copyWith(
        fontSize: 15,
        height: bodyHeight,
        fontWeight: FontWeight.w400,
        letterSpacing: bodyLetterSpacing,
        color: s.ink,
      )),
      bodySmall: withFallback(baseTT.bodySmall?.copyWith(
        fontSize: 13,
        height: 1.40,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        color: s.textMuted,
      )),
      // --- Label ---
      labelLarge: withFallback(baseTT.labelLarge?.copyWith(
        fontSize: 13,
        height: 1.40,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: s.ink,
        fontFeatures: const [FontFeature.tabularFigures()],
      )),
      labelMedium: withFallback(baseTT.labelMedium?.copyWith(
        fontSize: 12,
        height: 1.40,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: s.textMuted,
      )),
      labelSmall: withFallback(baseTT.labelSmall?.copyWith(
        fontSize: 11,
        height: 1.30,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
        color: s.textMuted,
      )),
    );

    // --- ColorScheme ---
    final colorSchemeBase =
        isLight ? const ColorScheme.light() : const ColorScheme.dark();
    final colorScheme = colorSchemeBase.copyWith(
      surface: resolvedSurface1,
      primary: resolvedAccent,
      onPrimary: resolvedOnAccent,
      onSurface: s.ink,
      secondary: ember,
      onSecondary: resolvedOnAccent,
      outline: s.border,
      // surfaceContainerHighest используется LinearProgressIndicator как track
      surfaceContainerHighest: s.border,
    );

    // --- FocusThemeExtension (имена полей сохранены для 106 файлов) ---
    final ext = FocusThemeExtension(
      textMuted: s.textMuted,
      ember: ember,
      border: s.border,
      surfaceElevated: s.surface2, // маппинг: старый surfaceElevated = новый surface2
      textFaint: s.textFaint,
      accentMuted: a.tint,         // маппинг: старый accentMuted = новый tint
      success: success,
      borderStrong: s.borderStrong,
      // Новые поля v4
      accentTint: a.tint,
      accentInk: a.ink,
      danger: danger,
      textSecondary: s.textSecondary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: s.brightness,
      scaffoldBackgroundColor: s.bg,
      colorScheme: colorScheme,
      textTheme: textTheme,

      // --- AppBar ---
      appBarTheme: AppBarTheme(
        backgroundColor: s.bg,
        foregroundColor: s.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.headlineSmall?.copyWith(color: s.ink),
      ),

      // --- Bottom navigation ---
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: s.surface1,
        selectedItemColor: resolvedAccent,
        unselectedItemColor: s.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle:
            textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: textTheme.labelSmall,
      ),

      // --- FAB ---
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: resolvedAccent,
        foregroundColor: resolvedOnAccent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        shape: const StadiumBorder(),
        extendedTextStyle:
            textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),

      // --- Filled Button (primary CTA): radius 12, h 52 ---
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      // --- Outlined Button: radius 12, h 52 ---
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: s.border),
          foregroundColor: s.ink,
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),

      // --- Text Button ---
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          foregroundColor: s.textMuted,
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w400),
        ),
      ),

      // --- Divider ---
      dividerColor: s.border,
      dividerTheme: DividerThemeData(
        color: s.border,
        thickness: 1,
        space: 1,
      ),

      // --- Card: hairline 0.5dp, R14 ---
      cardColor: s.surface1,
      cardTheme: CardThemeData(
        color: s.surface1,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: s.border, width: 0.5),
        ),
      ),

      // --- Chip ---
      chipTheme: ChipThemeData(
        backgroundColor: s.surface1,
        selectedColor: resolvedAccent,
        disabledColor: s.surface1.withValues(alpha: 0.5),
        labelStyle: textTheme.labelMedium?.copyWith(color: s.ink),
        secondaryLabelStyle:
            textTheme.labelMedium?.copyWith(color: resolvedOnAccent),
        side: BorderSide(color: s.border),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
        showCheckmark: false,
      ),

      // --- Input Decoration ---
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: s.surface1,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: s.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: s.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: s.borderStrong, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: ember, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: ember, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: s.border.withValues(alpha: 0.38)),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: s.textMuted),
        labelStyle: textTheme.bodySmall?.copyWith(color: s.textMuted),
        floatingLabelStyle:
            textTheme.labelSmall?.copyWith(color: resolvedAccent),
        errorStyle: textTheme.labelSmall?.copyWith(color: ember),
      ),

      // --- Bottom Sheet ---
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: s.surface1,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        showDragHandle: true,
        dragHandleColor: s.border,
        dragHandleSize: const Size(36, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // --- Snack Bar ---
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isLight ? s.ink : s.surface1,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isLight ? s.bg : s.ink,
        ),
        actionTextColor: resolvedAccent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        dismissDirection: DismissDirection.horizontal,
      ),

      // --- Switch ---
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return resolvedAccent;
          return s.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return resolvedAccent.withValues(alpha: 0.5);
          }
          return s.border;
        }),
      ),

      // --- Segmented Button ---
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: s.textMuted,
          selectedForegroundColor: resolvedOnAccent,
          selectedBackgroundColor: resolvedAccent,
          side: BorderSide(color: s.border),
          shape: const StadiumBorder(),
          minimumSize: const Size(0, 40),
          textStyle: textTheme.labelMedium,
        ),
      ),

      // --- List Tile ---
      listTileTheme: ListTileThemeData(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minVerticalPadding: 12,
        minLeadingWidth: 24,
        iconColor: s.textMuted,
        titleTextStyle:
            textTheme.bodyLarge?.copyWith(color: s.ink),
        subtitleTextStyle:
            textTheme.bodySmall?.copyWith(color: s.textMuted),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        selectedTileColor: resolvedAccent.withValues(alpha: 0.08),
      ),

      // --- Popup Menu ---
      popupMenuTheme: PopupMenuThemeData(
        color: s.surface2,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        textStyle: textTheme.bodyMedium?.copyWith(color: s.ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: s.border),
        ),
      ),

      // --- Dropdown Menu ---
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(s.surface2),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),

      extensions: [ext],
    );
  }
}

// ---------------------------------------------------------------------------
// FocusThemeExtension — ИМЯ И ВСЕ СТАРЫЕ ПОЛЯ СОХРАНЕНЫ (106 файлов).
// Новые поля добавлены с дефолтными значениями для совместимости с тестами.
// ---------------------------------------------------------------------------

/// ThemeExtension с дополнительными цветами, не покрытыми стандартным ColorScheme.
/// Имя «Focus» историческое — используется всеми темами.
/// В Kaname v4 добавлены: accentTint, accentInk, danger, textSecondary.
/// Старые поля (textMuted, ember, border, surfaceElevated, textFaint,
/// accentMuted, success, borderStrong) сохранены AS IS.
class FocusThemeExtension extends ThemeExtension<FocusThemeExtension> {
  const FocusThemeExtension({
    required this.textMuted,
    required this.ember,
    required this.border,
    required this.surfaceElevated,
    required this.textFaint,
    required this.accentMuted,
    required this.success,
    required this.borderStrong,
    // Новые поля v4 — опциональны для обратной совместимости с тестами
    this.accentTint = const Color(0xFFECEDFA),     // indigo light tint как fallback
    this.accentInk = const Color(0xFF3A45A8),      // indigo light ink как fallback
    this.danger = const Color(0xFFC0362C),          // status.light.danger
    this.textSecondary = const Color(0xFF6E6B66),  // day theme text_secondary
  });

  // --- Существующие поля (сохранены для обратной совместимости) ---
  final Color textMuted;
  final Color ember;
  final Color border;
  final Color surfaceElevated; // = surface2 в v4
  final Color textFaint;
  final Color accentMuted;    // = accentTint в v4 (маппинг)
  final Color success;
  final Color borderStrong;

  // --- Новые поля v4 ---
  final Color accentTint;
  final Color accentInk;
  final Color danger;
  final Color textSecondary;

  @override
  FocusThemeExtension copyWith({
    Color? textMuted,
    Color? ember,
    Color? border,
    Color? surfaceElevated,
    Color? textFaint,
    Color? accentMuted,
    Color? success,
    Color? borderStrong,
    Color? accentTint,
    Color? accentInk,
    Color? danger,
    Color? textSecondary,
  }) =>
      FocusThemeExtension(
        textMuted: textMuted ?? this.textMuted,
        ember: ember ?? this.ember,
        border: border ?? this.border,
        surfaceElevated: surfaceElevated ?? this.surfaceElevated,
        textFaint: textFaint ?? this.textFaint,
        accentMuted: accentMuted ?? this.accentMuted,
        success: success ?? this.success,
        borderStrong: borderStrong ?? this.borderStrong,
        accentTint: accentTint ?? this.accentTint,
        accentInk: accentInk ?? this.accentInk,
        danger: danger ?? this.danger,
        textSecondary: textSecondary ?? this.textSecondary,
      );

  @override
  FocusThemeExtension lerp(FocusThemeExtension? other, double t) {
    if (other == null) return this;
    return FocusThemeExtension(
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      ember: Color.lerp(ember, other.ember, t)!,
      border: Color.lerp(border, other.border, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      accentMuted: Color.lerp(accentMuted, other.accentMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      accentTint: Color.lerp(accentTint, other.accentTint, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
    );
  }
}
