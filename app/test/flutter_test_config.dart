// Глобальная конфигурация flutter_test — выполняется перед каждым test-файлом.
// google_fonts в тестах пытается скачивать шрифты по сети → получает 400 →
// выбрасывает исключение → падает тест. Отключаем сетевую загрузку.
import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
