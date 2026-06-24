import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import '../theme/theme_provider.dart';

const _kLocaleKey = 'app_locale';

/// Применяет локаль к глобальному intl-состоянию.
/// Вызывать при старте (из main) и при каждой смене языка пользователем.
/// [locale] — тег вида 'ru', 'en', 'pt-BR', 'es-ES' и т.д.
Future<void> applyIntlLocale(String localeTag) async {
  // Загружаем таблицы дат для указанной локали.
  // initializeDateFormatting — идемпотентна (повторный вызов безопасен).
  await initializeDateFormatting(localeTag);
  // Глобальный дефолт: все DateFormat без явной локали будут использовать его.
  Intl.defaultLocale = localeTag;
}

final localeNotifierProvider =
    NotifierProvider<LocaleNotifier, Locale>(() => LocaleNotifier());

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final saved = prefs.getString(_kLocaleKey);

    // Строим объект Locale из сохранённого тега
    final Locale locale;
    if (saved == null) {
      locale = const Locale('en');
    } else {
      // Полный тег вида 'pt-BR', 'es-ES', или просто 'en'
      final parts = saved.split('-');
      if (parts.length >= 2) {
        locale = Locale(parts[0], parts[1]);
      } else {
        locale = Locale(parts[0]);
      }
    }

    // Синхронно выставляем Intl.defaultLocale — данные уже загружены
    // через applyIntlLocale() в main() до первого кадра.
    Intl.defaultLocale = localeTag(locale);
    return locale;
  }

  Future<void> setLocale(Locale locale) async {
    // Загружаем таблицы дат и обновляем глобальный дефолт до изменения state,
    // чтобы первый rebuild уже видел правильную локаль.
    await applyIntlLocale(localeTag(locale));
    state = locale;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_kLocaleKey, localeTag(locale));
  }
}

/// Упорядоченный список всех поддерживаемых локалей приложения.
const supportedLocales = [
  Locale('en'),
  Locale('ru'),
  Locale('de'),
  Locale('fr'),
  Locale('it'),
  Locale('pt', 'BR'),
  Locale('id'),
  Locale('hi'),
  Locale('ja'),
  Locale('ko'),
  Locale('es'),
  Locale('es', 'ES'),
];

/// Упорядоченный список {locale, displayName} для пикеров UI.
/// Используем List, а не Map, чтобы поддерживать два варианта 'es' как отдельные пункты.
class LocaleEntry {
  const LocaleEntry(this.locale, this.displayName);
  final Locale locale;
  final String displayName;
}

/// Список локалей отсортирован по displayName (String.compareTo):
/// латиница A→Z, затем кириллица/деванагари/CJK.
/// Ожидаемый порядок: Bahasa Indonesia, Deutsch, English,
/// Español (España), Español (Latinoamérica), Français, Italiano,
/// Português (Brasil), Русский, हिन्दी, 日本語, 한국어.
const List<LocaleEntry> localeEntries = [
  LocaleEntry(Locale('id'), 'Bahasa Indonesia'),
  LocaleEntry(Locale('de'), 'Deutsch'),
  LocaleEntry(Locale('en'), 'English'),
  LocaleEntry(Locale('es', 'ES'), 'Español (España)'),
  LocaleEntry(Locale('es'), 'Español (Latinoamérica)'),
  LocaleEntry(Locale('fr'), 'Français'),
  LocaleEntry(Locale('it'), 'Italiano'),
  LocaleEntry(Locale('pt', 'BR'), 'Português (Brasil)'),
  LocaleEntry(Locale('ru'), 'Русский'),
  LocaleEntry(Locale('hi'), 'हिन्दी'),
  LocaleEntry(Locale('ja'), '日本語'),
  LocaleEntry(Locale('ko'), '한국어'),
];

/// Канонический тег для Locale: 'pt-BR', 'es-ES', 'en', 'ru' и т.д.
String localeTag(Locale locale) {
  if (locale.countryCode != null && locale.countryCode!.isNotEmpty) {
    return '${locale.languageCode}-${locale.countryCode}';
  }
  return locale.languageCode;
}

