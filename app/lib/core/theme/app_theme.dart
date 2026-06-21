// Темы приложения Kaizen — источник правды: /docs/design-tokens.json
// Реализованы все 5 предустановленных тем + пользовательская тема (custom).
// Тема собирается из палитры единым билдером, чтобы все темы были консистентны.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'custom_theme_provider.dart' show CustomThemeConfig;

// Алгоритм вывода пользовательской палитры — часть этой библиотеки,
// чтобы получить доступ к приватному классу _Palette.
part 'custom_theme_palette.dart';

/// Ключи тем — соответствуют ключам в design-tokens.json + custom (6-я тема)
enum AppThemeKey {
  focus,
  calm,
  black,
  white,
  contrast,
  custom, // Пользовательская тема («Мой стиль»)
}

/// Человекочитаемые метки (из design-tokens.json .label)
extension AppThemeKeyLabel on AppThemeKey {
  String get label => switch (this) {
        AppThemeKey.focus => 'Focus (warm dark, default)',
        AppThemeKey.calm => 'Calm (low-saturation blue-green)',
        AppThemeKey.black => 'Black (OLED full-black)',
        AppThemeKey.white => 'White (clean light)',
        AppThemeKey.contrast => 'Contrast (accessibility, large type)',
        AppThemeKey.custom => 'My Theme',
      };

  String get prefsKey => name; // 'focus', 'calm', ..., 'custom'
}

/// Палитра одной темы (значения из design-tokens.json + 01-color.md).
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
  final Color surfaceElevated; // NEW: модалки, дропдауны, поповеры
  final Color text;
  final Color textMuted;
  final Color textFaint; // NEW: плейсхолдеры, disabled, timestamps
  final Color accent;
  final Color accentMuted; // NEW: выделение чипа, hover bg, selection highlight
  final Color onAccent; // цвет текста/иконок поверх accent
  final Color ember;
  final Color success; // NEW: завершение, стрики, позитивные состояния
  final Color border;
  final Color borderStrong; // NEW: фокусированные input, активные карточки
}

// --- Focus (тёплый тёмный, по умолчанию) ---
const _focusPalette = _Palette(
  brightness: Brightness.dark,
  bg: Color(0xFF141009),
  surface: Color(0xFF241D11),
  surfaceElevated: Color(0xFF2E2618),
  text: Color(0xFFF6EFE1),
  textMuted: Color(0xFF9E9070),
  textFaint: Color(0xFF736850),
  accent: Color(0xFFD9F24B),
  accentMuted: Color(0xFF26290F),
  onAccent: Color(0xFF141009),
  ember: Color(0xFFFF6A3D),
  success: Color(0xFF4BAF6F),
  border: Color(0xFF3A3020),
  borderStrong: Color(0xFF524630),
);

// --- Black (OLED full-black) ---
const _blackPalette = _Palette(
  brightness: Brightness.dark,
  bg: Color(0xFF000000),
  surface: Color(0xFF0E0E0E),
  surfaceElevated: Color(0xFF161616),
  text: Color(0xFFFFFFFF),
  textMuted: Color(0xFF8A8A8A),
  textFaint: Color(0xFF636363),
  accent: Color(0xFFC8FF4D),
  accentMuted: Color(0xFF1A1F0A),
  onAccent: Color(0xFF000000),
  ember: Color(0xFFFF6A3D),
  success: Color(0xFF4BAF6F),
  border: Color(0xFF1C1C1C),
  borderStrong: Color(0xFF2E2E2E),
);

// --- White (светлая) ---
const _whitePalette = _Palette(
  brightness: Brightness.light,
  bg: Color(0xFFFFFFFF),
  surface: Color(0xFFF5F4F1),
  surfaceElevated: Color(0xFFECEAE5),
  text: Color(0xFF16130E),
  textMuted: Color(0xFF6B675F),
  textFaint: Color(0xFF858178),
  accent: Color(0xFF2B2A26),
  accentMuted: Color(0xFFEDECEA),
  onAccent: Color(0xFFFFFFFF),
  ember: Color(0xFFE5533A),
  success: Color(0xFF1A7A3E),
  border: Color(0xFFE3E0DA),
  borderStrong: Color(0xFFC8C4BC),
);

// --- Calm (приглушённый сине-зелёный) ---
const _calmPalette = _Palette(
  brightness: Brightness.dark,
  bg: Color(0xFF11171A),
  surface: Color(0xFF18232A),
  surfaceElevated: Color(0xFF1F2E38),
  text: Color(0xFFE8F0F0),
  textMuted: Color(0xFF8AA0A0),
  textFaint: Color(0xFF617E7E),
  accent: Color(0xFF6FB6A3),
  accentMuted: Color(0xFF172628),
  onAccent: Color(0xFF11171A),
  ember: Color(0xFFE08A6B),
  success: Color(0xFF5AB594),
  border: Color(0xFF243640),
  borderStrong: Color(0xFF365060),
);

// --- Contrast (доступность, крупный шрифт) ---
const _contrastPalette = _Palette(
  brightness: Brightness.dark,
  bg: Color(0xFF000000),
  surface: Color(0xFF0A0A0A),
  surfaceElevated: Color(0xFF141414),
  text: Color(0xFFFFFFFF),
  textMuted: Color(0xFFD0D0D0),
  textFaint: Color(0xFFA0A0A0),
  accent: Color(0xFFFFE600),
  accentMuted: Color(0xFF2A2600),
  onAccent: Color(0xFF000000),
  ember: Color(0xFFFF5230),
  success: Color(0xFF00E5A0),
  border: Color(0xFFFFFFFF),
  borderStrong: Color(0xFFFFFFFF),
);

/// Фабрика ThemeData для каждой темы.
class AppTheme {
  AppTheme._();

  // --- Focus (тёплый тёмный, по умолчанию) — Fraunces + Hanken Grotesk ---
  static ThemeData focusTheme({double harshness = 0.0}) => _buildTheme(
        _focusPalette,
        bodyTextTheme: GoogleFonts.hankenGroteskTextTheme,
        displayFont: ({textStyle, color}) =>
            GoogleFonts.fraunces(textStyle: textStyle, color: color),
        harshness: harshness,
      );

  // --- Black (OLED) — Schibsted Grotesk для дисплея и текста ---
  static ThemeData blackTheme({double harshness = 0.0}) => _buildTheme(
        _blackPalette,
        bodyTextTheme: GoogleFonts.schibstedGroteskTextTheme,
        displayFont: ({textStyle, color}) =>
            GoogleFonts.schibstedGrotesk(textStyle: textStyle, color: color),
        harshness: harshness,
      );

  // --- White (светлая) — Instrument Serif (дисплей) + Plus Jakarta Sans (текст) ---
  static ThemeData whiteTheme({double harshness = 0.0}) => _buildTheme(
        _whitePalette,
        bodyTextTheme: GoogleFonts.plusJakartaSansTextTheme,
        displayFont: ({textStyle, color}) =>
            GoogleFonts.instrumentSerif(textStyle: textStyle, color: color),
        harshness: harshness,
      );

  // --- Calm (приглушённый сине-зелёный) — Newsreader (дисплей) + DM Sans (текст) ---
  static ThemeData calmTheme({double harshness = 0.0}) => _buildTheme(
        _calmPalette,
        bodyTextTheme: GoogleFonts.dmSansTextTheme,
        displayFont: ({textStyle, color}) =>
            GoogleFonts.newsreader(textStyle: textStyle, color: color),
        harshness: harshness,
      );

  // --- Contrast (доступность, крупный шрифт) — Atkinson Hyperlegible ---
  // Масштаб шрифта 1.15 (font_scale.contrast) применяется через MediaQuery.textScaler
  // в main.dart — это безопасно (TextTheme.apply падает на стилях с fontSize==null).
  static ThemeData contrastTheme({double harshness = 0.0}) => _buildTheme(
        _contrastPalette,
        bodyTextTheme: GoogleFonts.atkinsonHyperlegibleTextTheme,
        displayFont: ({textStyle, color}) =>
            GoogleFonts.atkinsonHyperlegible(textStyle: textStyle, color: color),
        isContrast: true,
        harshness: harshness,
      );

  /// Получить ThemeData по ключу темы (только предустановленные — без custom).
  /// harshness=0.0 по умолчанию → поведение как раньше.
  static ThemeData forKey(AppThemeKey key, {double harshness = 0.0}) =>
      switch (key) {
        AppThemeKey.focus => focusTheme(harshness: harshness),
        AppThemeKey.calm => calmTheme(harshness: harshness),
        AppThemeKey.black => blackTheme(harshness: harshness),
        AppThemeKey.white => whiteTheme(harshness: harshness),
        AppThemeKey.contrast => contrastTheme(harshness: harshness),
        // custom без config → откат на focus (защита от ошибочного вызова)
        AppThemeKey.custom => focusTheme(harshness: harshness),
      };

  /// Получить ThemeData с поддержкой custom-темы и реактивного harshness.
  /// Использовать в [themeDataProvider] вместо [forKey].
  /// harshness=0.0 → цвета ровно как раньше (обратная совместимость).
  static ThemeData forKeyWithCustom(
      AppThemeKey key, CustomThemeConfig? config, {double harshness = 0.0}) {
    if (key == AppThemeKey.custom) {
      // Нет сохранённой конфигурации → откат на focus
      if (config == null) return focusTheme(harshness: harshness);
      final result = CustomThemePalette.derive(config);
      return _buildTheme(
        result.palette,
        bodyTextTheme: GoogleFonts.hankenGroteskTextTheme,
        displayFont: ({textStyle, color}) =>
            GoogleFonts.fraunces(textStyle: textStyle, color: color),
        harshness: harshness,
      );
    }
    return forKey(key, harshness: harshness);
  }

  /// Универсальный билдер темы из палитры.
  ///
  /// [harshness] — 0.0..1.0; при 0 всё как раньше. При > 0 акцент
  /// интерполируется в сторону ember: Color.lerp(accent, ember, harshness*0.7).
  /// При MoodLevel.angry (harshness≥0.75) поверхности слегка «охлаждаются»
  /// (тонкий rgba-оверлей ember на surface). onAccent пересчитывается для
  /// сохранения контраста: при светлом ember берём тёмный текст, при тёмном — светлый.
  static ThemeData _buildTheme(
    _Palette p, {
    required TextTheme Function(TextTheme) bodyTextTheme,
    required TextStyle Function({TextStyle? textStyle, Color? color}) displayFont,
    bool isContrast = false,
    double harshness = 0.0,
  }) {
    // --- Реактивная «злая» тема ---
    // При harshness=0 нет никаких изменений (Color.lerp с t=0 = первый цвет).
    final resolvedAccent = harshness > 0.0
        ? Color.lerp(p.accent, p.ember, (harshness * 0.7).clamp(0.0, 1.0))!
        : p.accent;

    // onAccent: при высоком harshness ember светлый → нужен тёмный текст;
    // при тёмном ember (white theme) нужен светлый. Определяем по luminance.
    final resolvedOnAccent = harshness > 0.0
        ? (resolvedAccent.computeLuminance() > 0.35
            ? const Color(0xFF0A0A0A)  // тёмный текст поверх светлого
            : const Color(0xFFFAFAFA)) // светлый текст поверх тёмного
        : p.onAccent;

    // Лёгкое «охлаждение» поверхности при angry (harshness>=0.75): едва заметный тинт ember
    final angryOverlay = harshness >= 0.75 ? (harshness - 0.75) / 0.25 : 0.0;
    final resolvedSurface = angryOverlay > 0.0
        ? Color.lerp(p.surface, p.ember.withValues(alpha: 0.06), angryOverlay * 0.4)!
        : p.surface;

    // Пересобираем «рабочую» палитру с новыми цветами (остальные поля — без изменений).
    final rp = _Palette(
      brightness: p.brightness,
      bg: p.bg,
      surface: resolvedSurface,
      surfaceElevated: p.surfaceElevated,
      text: p.text,
      textMuted: p.textMuted,
      textFaint: p.textFaint,
      accent: resolvedAccent,
      accentMuted: p.accentMuted,
      onAccent: resolvedOnAccent,
      ember: p.ember,
      success: p.success,
      border: p.border,
      borderStrong: p.borderStrong,
    );

    // Всё остальное строится из effective (когда harshness=0, effective == p).
    // ignore: unused_local_variable (p используется выше для инициализации effective)
    final _Palette effective = rp;
    final TextTheme baseDefaults = effective.brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    final TextTheme baseTextTheme = bodyTextTheme(baseDefaults);

    TextStyle? display(TextStyle? base) => displayFont(textStyle: base, color: effective.text);

    // --- Универсальный типографический масштаб (02-type-space.md §1) ---
    // Contrast-тема: display/headline w700→w800, body letterSpacing +0.2, body lineHeight 1.60
    final FontWeight displayWeight = isContrast ? FontWeight.w800 : FontWeight.w700;
    final FontWeight headlineSmallWeight = isContrast ? FontWeight.w800 : FontWeight.w600;
    const double bodyHeight = 1.50;
    final double contrastBodyHeight = isContrast ? 1.60 : bodyHeight;
    const double bodyLetterSpacing = 0.0;
    final double contrastBodyLetterSpacing = isContrast ? 0.2 : bodyLetterSpacing;

    // Фолбэк-шрифты для хинди (деванагари), японского и корейского.
    // Шрифты вшиты как локальные ассеты (assets/fonts/) — не требуют сети,
    // рисуются сразу без "вспышки квадратиков". Имена семейств совпадают
    // с объявлением в pubspec.yaml flutter.fonts.
    const List<String> scriptFallbacks = [
      'Noto Sans Devanagari',
      'Noto Sans JP',
      'Noto Sans KR',
    ];

    // Вспомогательная функция: добавляет fontFamilyFallback к TextStyle.
    TextStyle? withFallback(TextStyle? style) {
      if (style == null) return null;
      return style.copyWith(fontFamilyFallback: scriptFallbacks);
    }

    final TextTheme mergedTextTheme = baseTextTheme.copyWith(
      // --- display (BOLD RESTYLE: 48→56, tight -0.8 tracking) ---
      displayLarge: withFallback(display(baseTextTheme.displayLarge)?.copyWith(
        fontSize: 56,
        fontWeight: displayWeight,
        height: 1.00,
        letterSpacing: -0.8,
        color: effective.text,
      )),
      // displayMedium / displaySmall — промежуточные ступени дисплея
      displayMedium: withFallback(display(baseTextTheme.displayMedium)?.copyWith(
        fontSize: 40,
        fontWeight: displayWeight,
        height: 1.05,
        letterSpacing: -0.5,
        color: effective.text,
      )),
      displaySmall: withFallback(display(baseTextTheme.displaySmall)?.copyWith(
        fontSize: 32,
        fontWeight: displayWeight,
        height: 1.08,
        letterSpacing: -0.3,
        color: effective.text,
      )),
      // --- headline slots — display font, BOLD RESTYLE ---
      // headlineLarge 34→40 (экранные заголовки — Today greeting, Plan month header)
      headlineLarge: withFallback(display(baseTextTheme.headlineLarge)?.copyWith(
        fontSize: 40,
        fontWeight: displayWeight,
        height: 1.05,
        letterSpacing: -0.5,
        color: effective.text,
      )),
      // headlineMedium 28→32 (секционные заголовки, заголовки модалок)
      headlineMedium: withFallback(display(baseTextTheme.headlineMedium)?.copyWith(
        fontSize: 32,
        fontWeight: displayWeight,
        height: 1.08,
        letterSpacing: -0.3,
        color: effective.text,
      )),
      // headlineSmall 22 → остаётся, но тоже display font
      headlineSmall: withFallback(display(baseTextTheme.headlineSmall)?.copyWith(
        fontSize: 22,
        fontWeight: headlineSmallWeight,
        height: 1.15,
        letterSpacing: -0.1,
        color: effective.text,
      )),
      // --- title roles — body font (без изменений в размерах) ---
      titleLarge: withFallback(baseTextTheme.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.20,
        letterSpacing: 0.0,
        color: effective.text,
      )),
      titleMedium: withFallback(baseTextTheme.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: 0.0,
        color: effective.text,
      )),
      titleSmall: withFallback(baseTextTheme.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: 0.1,
        color: effective.text,
      )),
      // --- body roles — body font (без изменений) ---
      bodyLarge: withFallback(baseTextTheme.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: contrastBodyHeight,
        letterSpacing: contrastBodyLetterSpacing,
        color: effective.text,
      )),
      bodyMedium: withFallback(baseTextTheme.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: contrastBodyHeight,
        letterSpacing: contrastBodyLetterSpacing,
        color: effective.text,
      )),
      bodySmall: withFallback(baseTextTheme.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.45,
        letterSpacing: isContrast ? 0.3 : 0.1,
        color: effective.textMuted,
      )),
      // --- label roles — body font; labelLarge w500→w600 для кнопок ---
      labelLarge: withFallback(baseTextTheme.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.20,
        letterSpacing: 0.4,
        color: effective.text,
      )),
      labelMedium: withFallback(baseTextTheme.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.20,
        letterSpacing: 0.4,
        color: effective.textMuted,
      )),
      labelSmall: withFallback(baseTextTheme.labelSmall?.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        height: 1.20,
        letterSpacing: 0.6,
        color: effective.textMuted,
      )),
    );

    final ColorScheme colorSchemeBase = effective.brightness == Brightness.dark
        ? const ColorScheme.dark()
        : const ColorScheme.light();
    final ColorScheme colorScheme = colorSchemeBase.copyWith(
      surface: effective.surface,
      primary: effective.accent,
      onPrimary: effective.onAccent,
      onSurface: effective.text,
      secondary: effective.ember,
      onSecondary: effective.onAccent,
      outline: effective.border,
      // surfaceContainerHighest используется LinearProgressIndicator как track color
      surfaceContainerHighest: effective.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: effective.brightness,
      scaffoldBackgroundColor: effective.bg,
      colorScheme: colorScheme,
      textTheme: mergedTextTheme,

      // --- AppBar (display font, чуть крупнее для editorial feel) ---
      appBarTheme: AppBarTheme(
        backgroundColor: effective.bg,
        foregroundColor: effective.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: display(
          const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        )?.copyWith(color: effective.text),
      ),

      // --- Bottom navigation ---
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: effective.surface,
        selectedItemColor: effective.accent,
        unselectedItemColor: effective.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: mergedTextTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: mergedTextTheme.labelSmall,
      ),

      // --- FAB ---
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: effective.accent,
        foregroundColor: effective.onAccent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        shape: const StadiumBorder(),
        extendedTextStyle:
            mergedTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),

      // --- Filled Button (primary CTA): h 48→52, горизонтальный отступ 24→28 ---
      // RECONCILIATION: 12dp radius per orchestrator override (not pill/stadium)
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          // labelLarge уже w600 в mergedTextTheme — берём напрямую
          textStyle: mergedTextTheme.labelLarge,
        ),
      ),

      // --- Outlined Button: h 48→52, боковой бордер — border (не borderStrong) ---
      // RECONCILIATION: 12dp radius per orchestrator override (not pill/stadium)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: effective.border),
          foregroundColor: effective.text,
          textStyle:
              mergedTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),

      // --- Text Button (лёгкие действия): w400 для контраста с filled ---
      // RECONCILIATION: 12dp radius per orchestrator override (not 8dp from spec, matching buttons)
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          foregroundColor: effective.textMuted,
          textStyle:
              mergedTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w400),
        ),
      ),

      // --- Divider ---
      dividerColor: effective.border,
      dividerTheme: DividerThemeData(
        color: effective.border,
        thickness: 1,
        space: 1,
      ),

      // --- Card: hairline border 0.5dp для лучшей структуры на тёмных темах ---
      cardColor: effective.surface,
      cardTheme: CardThemeData(
        color: effective.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: effective.border, width: 0.5),
        ),
      ),

      // --- Chip ---
      chipTheme: ChipThemeData(
        backgroundColor: effective.surface,
        selectedColor: effective.accent,
        disabledColor: effective.surface.withValues(alpha: 0.5),
        labelStyle: mergedTextTheme.labelMedium?.copyWith(color: effective.text),
        secondaryLabelStyle:
            mergedTextTheme.labelMedium?.copyWith(color: effective.onAccent),
        side: BorderSide(color: effective.border),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
        showCheckmark: false,
      ),

      // --- Input Decoration: padding 14→16v, border strong on focus (borderStrong) ---
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: effective.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: effective.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: effective.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: effective.borderStrong, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: effective.ember, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: effective.ember, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: effective.border.withValues(alpha: 0.38)),
        ),
        hintStyle: mergedTextTheme.bodyMedium?.copyWith(color: effective.textMuted),
        labelStyle: mergedTextTheme.bodySmall?.copyWith(color: effective.textMuted),
        floatingLabelStyle:
            mergedTextTheme.labelSmall?.copyWith(color: effective.accent),
        errorStyle: mergedTextTheme.labelSmall?.copyWith(color: effective.ember),
      ),

      // --- Bottom Sheet ---
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: effective.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        showDragHandle: true,
        dragHandleColor: effective.border,
        dragHandleSize: const Size(36, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // --- Snack Bar ---
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            effective.brightness == Brightness.dark ? effective.surface : effective.text,
        contentTextStyle: mergedTextTheme.bodyMedium?.copyWith(
          color: effective.brightness == Brightness.dark ? effective.text : effective.bg,
        ),
        actionTextColor: effective.accent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        dismissDirection: DismissDirection.horizontal,
      ),

      // --- Switch ---
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return effective.accent;
          return effective.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return effective.accent.withValues(alpha: 0.5);
          }
          return effective.border;
        }),
      ),

      // --- Segmented Button ---
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: effective.textMuted,
          selectedForegroundColor: effective.onAccent,
          selectedBackgroundColor: effective.accent,
          side: BorderSide(color: effective.border),
          shape: const StadiumBorder(),
          minimumSize: const Size(0, 40),
          textStyle: mergedTextTheme.labelMedium,
        ),
      ),

      // --- List Tile: больше воздуха — vertical 4→8, minVerticalPadding 8→12 ---
      listTileTheme: ListTileThemeData(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minVerticalPadding: 12,
        minLeadingWidth: 24,
        iconColor: effective.textMuted,
        titleTextStyle: mergedTextTheme.bodyLarge?.copyWith(color: effective.text),
        subtitleTextStyle:
            mergedTextTheme.bodySmall?.copyWith(color: effective.textMuted),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        selectedTileColor: effective.accent.withValues(alpha: 0.08),
      ),

      // --- Popup Menu (PopupMenuButton): непрозрачный фон, иначе контент просвечивает ---
      // Берём elevated-поверхность (модалки/дропдауны), как у карточек/боттом-шитов.
      popupMenuTheme: PopupMenuThemeData(
        color: effective.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        textStyle: mergedTextTheme.bodyMedium?.copyWith(color: effective.text),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: effective.border),
        ),
      ),

      // --- Dropdown Menu (DropdownMenu, Material 3): тот же непрозрачный фон ---
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(effective.surfaceElevated),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),

      extensions: [
        FocusThemeExtension(
          textMuted: effective.textMuted,
          ember: effective.ember,
          border: effective.border,
          // новые поля
          surfaceElevated: effective.surfaceElevated,
          textFaint: effective.textFaint,
          accentMuted: effective.accentMuted,
          success: effective.success,
          borderStrong: effective.borderStrong,
        ),
      ],
    );
  }
}

/// ThemeExtension — дополнительные цвета, не покрытые стандартным ColorScheme.
/// Имя историческое (введено для Focus), но используется всеми темами.
/// Новые поля добавлены по 01-color.md: surfaceElevated, textFaint, accentMuted,
/// success, borderStrong.
class FocusThemeExtension extends ThemeExtension<FocusThemeExtension> {
  const FocusThemeExtension({
    required this.textMuted,
    required this.ember,
    required this.border,
    // новые поля
    required this.surfaceElevated,
    required this.textFaint,
    required this.accentMuted,
    required this.success,
    required this.borderStrong,
  });

  // --- Существующие поля (имена/типы сохранены для обратной совместимости) ---
  final Color textMuted;
  final Color ember;
  final Color border;

  // --- Новые поля (01-color.md) ---
  final Color surfaceElevated;
  final Color textFaint;
  final Color accentMuted;
  final Color success;
  final Color borderStrong;

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
    );
  }
}
