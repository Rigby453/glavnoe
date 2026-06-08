// Темы приложения Kaizen — источник правды: /docs/design-tokens.json
// Реализованы все 5 тем: focus (по умолчанию), calm, black (OLED), white, contrast.
// Тема собирается из палитры единым билдером, чтобы все темы были консистентны.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ключи тем — соответствуют ключам в design-tokens.json
enum AppThemeKey {
  focus,
  calm,
  black,
  white,
  contrast,
}

/// Человекочитаемые метки (из design-tokens.json .label)
extension AppThemeKeyLabel on AppThemeKey {
  String get label => switch (this) {
        AppThemeKey.focus => 'Focus (warm dark, default)',
        AppThemeKey.calm => 'Calm (low-saturation blue-green)',
        AppThemeKey.black => 'Black (OLED full-black)',
        AppThemeKey.white => 'White (clean light)',
        AppThemeKey.contrast => 'Contrast (accessibility, large type)',
      };

  String get prefsKey => name; // 'focus', 'calm', etc.
}

/// Палитра одной темы (значения из design-tokens.json).
class _Palette {
  const _Palette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.ember,
    required this.border,
  });

  final Brightness brightness;
  final Color bg;
  final Color surface;
  final Color text;
  final Color textMuted;
  final Color accent;
  final Color onAccent; // цвет текста/иконок поверх accent
  final Color ember;
  final Color border;
}

const _focusPalette = _Palette(
  brightness: Brightness.dark,
  bg: Color(0xFF141009),
  surface: Color(0xFF241D11),
  text: Color(0xFFF6EFE1),
  textMuted: Color(0xFF9E9070),
  accent: Color(0xFFD9F24B),
  onAccent: Color(0xFF141009),
  ember: Color(0xFFFF6A3D),
  border: Color(0xFF3A3020),
);

const _blackPalette = _Palette(
  brightness: Brightness.dark,
  bg: Color(0xFF000000),
  surface: Color(0xFF0E0E0E),
  text: Color(0xFFFFFFFF),
  textMuted: Color(0xFF8A8A8A),
  accent: Color(0xFFC8FF4D),
  onAccent: Color(0xFF000000),
  ember: Color(0xFFFF6A3D),
  border: Color(0xFF1C1C1C),
);

const _whitePalette = _Palette(
  brightness: Brightness.light,
  bg: Color(0xFFFFFFFF),
  surface: Color(0xFFF5F4F1),
  text: Color(0xFF16130E),
  textMuted: Color(0xFF6B675F),
  accent: Color(0xFF2B2A26),
  onAccent: Color(0xFFFFFFFF),
  ember: Color(0xFFE5533A),
  border: Color(0xFFE3E0DA),
);

const _calmPalette = _Palette(
  brightness: Brightness.dark,
  bg: Color(0xFF11171A),
  surface: Color(0xFF18232A),
  text: Color(0xFFE8F0F0),
  textMuted: Color(0xFF8AA0A0),
  accent: Color(0xFF6FB6A3),
  onAccent: Color(0xFF11171A),
  ember: Color(0xFFE08A6B),
  border: Color(0xFF243640),
);

const _contrastPalette = _Palette(
  brightness: Brightness.dark,
  bg: Color(0xFF000000),
  surface: Color(0xFF0A0A0A),
  text: Color(0xFFFFFFFF),
  textMuted: Color(0xFFD0D0D0),
  accent: Color(0xFFFFE600),
  onAccent: Color(0xFF000000),
  ember: Color(0xFFFF5230),
  border: Color(0xFFFFFFFF),
);

/// Фабрика ThemeData для каждой темы.
class AppTheme {
  AppTheme._();

  // --- Focus (тёплый тёмный, по умолчанию) — Fraunces + Hanken Grotesk ---
  static ThemeData get focusTheme => _buildTheme(
        _focusPalette,
        bodyTextTheme: GoogleFonts.hankenGroteskTextTheme,
        displayFont: ({textStyle, color}) =>
            GoogleFonts.fraunces(textStyle: textStyle, color: color),
      );

  // --- Black (OLED) — Schibsted Grotesk для дисплея и текста ---
  static ThemeData get blackTheme => _buildTheme(
        _blackPalette,
        bodyTextTheme: GoogleFonts.schibstedGroteskTextTheme,
        displayFont: ({textStyle, color}) =>
            GoogleFonts.schibstedGrotesk(textStyle: textStyle, color: color),
      );

  // --- White (светлая) — Instrument Serif (дисплей) + Geist (текст) ---
  // Geist отсутствует в текущей версии google_fonts → подставляем Inter
  // (близкий нейтральный гротеск). TODO: вернуть Geist, когда появится в пакете.
  static ThemeData get whiteTheme => _buildTheme(
        _whitePalette,
        bodyTextTheme: GoogleFonts.interTextTheme,
        displayFont: ({textStyle, color}) =>
            GoogleFonts.instrumentSerif(textStyle: textStyle, color: color),
      );

  // --- Calm (приглушённый сине-зелёный) — Newsreader (дисплей) + Mulish (текст) ---
  static ThemeData get calmTheme => _buildTheme(
        _calmPalette,
        bodyTextTheme: GoogleFonts.mulishTextTheme,
        displayFont: ({textStyle, color}) =>
            GoogleFonts.newsreader(textStyle: textStyle, color: color),
      );

  // --- Contrast (доступность, крупный шрифт) — Atkinson Hyperlegible ---
  // Масштаб шрифта 1.15 (font_scale.contrast) применяется через MediaQuery.textScaler
  // в main.dart — это безопасно (TextTheme.apply падает на стилях с fontSize==null).
  static ThemeData get contrastTheme => _buildTheme(
        _contrastPalette,
        bodyTextTheme: GoogleFonts.atkinsonHyperlegibleTextTheme,
        displayFont: ({textStyle, color}) =>
            GoogleFonts.atkinsonHyperlegible(textStyle: textStyle, color: color),
      );

  /// Получить ThemeData по ключу темы
  static ThemeData forKey(AppThemeKey key) => switch (key) {
        AppThemeKey.focus => focusTheme,
        AppThemeKey.calm => calmTheme,
        AppThemeKey.black => blackTheme,
        AppThemeKey.white => whiteTheme,
        AppThemeKey.contrast => contrastTheme,
      };

  /// Универсальный билдер темы из палитры.
  static ThemeData _buildTheme(
    _Palette p, {
    required TextTheme Function(TextTheme) bodyTextTheme,
    required TextStyle Function({TextStyle? textStyle, Color? color}) displayFont,
  }) {
    final TextTheme baseDefaults = p.brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    final TextTheme baseTextTheme = bodyTextTheme(baseDefaults);

    TextStyle? display(TextStyle? base) => displayFont(textStyle: base, color: p.text);

    final TextTheme mergedTextTheme = baseTextTheme.copyWith(
      displayLarge: display(baseTextTheme.displayLarge),
      displayMedium: display(baseTextTheme.displayMedium),
      displaySmall: display(baseTextTheme.displaySmall),
      headlineLarge: display(baseTextTheme.headlineLarge),
      headlineMedium: display(baseTextTheme.headlineMedium),
      headlineSmall: display(baseTextTheme.headlineSmall),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: p.text),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: p.text),
      bodySmall: baseTextTheme.bodySmall?.copyWith(color: p.textMuted),
      labelLarge: baseTextTheme.labelLarge?.copyWith(color: p.text),
      labelMedium: baseTextTheme.labelMedium?.copyWith(color: p.textMuted),
      labelSmall: baseTextTheme.labelSmall?.copyWith(color: p.textMuted),
    );

    final ColorScheme base = p.brightness == Brightness.dark
        ? const ColorScheme.dark()
        : const ColorScheme.light();
    final ColorScheme colorScheme = base.copyWith(
      surface: p.surface,
      primary: p.accent,
      onPrimary: p.onAccent,
      onSurface: p.text,
      secondary: p.ember,
      onSecondary: p.onAccent,
      outline: p.border,
      surfaceContainerHighest: p.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      scaffoldBackgroundColor: p.bg,
      colorScheme: colorScheme,
      textTheme: mergedTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.text,
        elevation: 0,
        titleTextStyle: display(const TextStyle(fontSize: 20))
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.surface,
        selectedItemColor: p.accent,
        unselectedItemColor: p.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
      ),
      dividerColor: p.border,
      cardColor: p.surface,
      cardTheme: CardThemeData(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // radius.md
          side: BorderSide(color: p.border),
        ),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), // radius.sm
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: p.accent),
        ),
        hintStyle: TextStyle(color: p.textMuted),
        labelStyle: TextStyle(color: p.textMuted),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.accent,
        labelStyle: TextStyle(color: p.text),
        side: BorderSide(color: p.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999), // radius.pill
        ),
      ),
      extensions: [
        FocusThemeExtension(
          textMuted: p.textMuted,
          ember: p.ember,
          border: p.border,
        ),
      ],
    );
  }
}

/// ThemeExtension — дополнительные цвета, не покрытые стандартным ColorScheme.
/// Имя историческое (введено для Focus), но используется всеми темами.
class FocusThemeExtension extends ThemeExtension<FocusThemeExtension> {
  const FocusThemeExtension({
    required this.textMuted,
    required this.ember,
    required this.border,
  });

  final Color textMuted;
  final Color ember;
  final Color border;

  @override
  FocusThemeExtension copyWith({
    Color? textMuted,
    Color? ember,
    Color? border,
  }) =>
      FocusThemeExtension(
        textMuted: textMuted ?? this.textMuted,
        ember: ember ?? this.ember,
        border: border ?? this.border,
      );

  @override
  FocusThemeExtension lerp(FocusThemeExtension? other, double t) {
    if (other == null) return this;
    return FocusThemeExtension(
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      ember: Color.lerp(ember, other.ember, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}
