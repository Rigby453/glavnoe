// Стаб для не-web платформ (мобильные/desktop).
// dart:js_interop недоступен вне web-компиляции, поэтому здесь просто
// no-op — реальная реализация лежит в web_visibility_web.dart и выбирается
// условным экспортом в web_visibility.dart.

/// Регистрирует [onVisible] как обработчик возврата страницы в видимость.
/// На не-web платформах слушать нечего — возвращает no-op отписку.
void Function() registerVisibilityListener(void Function() onVisible) {
  return () {};
}
