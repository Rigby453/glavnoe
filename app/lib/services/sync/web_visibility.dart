// Условный экспорт: на web (dart:js_interop доступен только там) слушаем
// document.visibilitychange; на остальных платформах — no-op стаб.
// Не импортируется напрямую фичами — используется только sync_trigger_service.dart.
export 'web_visibility_stub.dart'
    if (dart.library.js_interop) 'web_visibility_web.dart';
