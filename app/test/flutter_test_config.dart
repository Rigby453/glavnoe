// Глобальная конфигурация flutter_test — выполняется перед каждым test-файлом.
// google_fonts в тестах пытается скачивать шрифты по сети → получает 400 →
// выбрасывает исключение → падает тест. Отключаем сетевую загрузку.
import 'dart:async';

import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  // Инициализируем locale-данные intl для всех тестов: production делает это в
  // main() через applyIntlLocale(), но main() в тестах не вызывается. Без этого
  // DateFormat без явной локали бросает LocaleDataException, когда
  // Intl.defaultLocale выставлен в неинициализированную локаль (флаки по порядку).
  await initializeDateFormatting();
  await testMain();
}
