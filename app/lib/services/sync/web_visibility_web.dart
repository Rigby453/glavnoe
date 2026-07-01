// Web-реализация: слушаем document.visibilitychange напрямую через DOM API.
//
// Почему не через AppLifecycleListener (main.dart): движок Flutter-web
// транслирует visibilitychange в ui.AppLifecycleState.resumed НАПРЯМУЮ из
// состояния hidden (см. флаттер-движок lib/web_ui/.../app_lifecycle_state.dart,
// _visibilityChangeListener), минуя промежуточное inactive. Это невалидный
// переход с точки зрения state-machine, которую использует
// AppLifecycleListener (там ассерт требует hidden -> inactive -> resumed) —
// поэтому onResume на web ненадёжен (в debug — assert, в release — недетерминировано
// в зависимости от порядка событий focus/visibilitychange). Слушаем DOM-событие
// сами, независимо от Flutter-биндинга.
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Регистрирует [onVisible] — вызывается каждый раз, когда вкладка становится
/// видимой (document.hidden == false после visibilitychange).
/// Возвращает функцию отписки — обязательно вызвать её при dispose, иначе
/// слушатель на document переживёт виджет (утечка).
void Function() registerVisibilityListener(void Function() onVisible) {
  void handler(web.Event event) {
    if (!web.document.hidden) {
      onVisible();
    }
  }

  final jsHandler = handler.toJS;
  web.document.addEventListener('visibilitychange', jsHandler);
  return () => web.document.removeEventListener('visibilitychange', jsHandler);
}
