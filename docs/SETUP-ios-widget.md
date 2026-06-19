# Kaizen iOS Widget — Setup Guide (Mac + Xcode)

> Этот файл описывает ручные шаги, которые ОБЯЗАТЕЛЬНО выполняются на Mac с Xcode.
> Все Swift-исходники уже лежат в репо — их только нужно добавить в Xcode-проект.
> НЕ редактируй project.pbxproj вручную — только через Xcode UI.

---

## Что уже сделано в репо

| Файл | Роль |
|------|------|
| `app/ios/KaizenWidget/KaizenWidget.swift` | `@main` бандл, `Widget`, три размера, Preview |
| `app/ios/KaizenWidget/Provider.swift` | `TimelineProvider`: читает App Group UserDefaults, строит Timeline |
| `app/ios/KaizenWidget/KaizenEntry.swift` | Модель данных entry + хелпер `Color(hex:)` |
| `app/ios/KaizenWidget/KaizenWidgetView.swift` | SwiftUI-вьюхи: `SmallWidgetView`, `MediumWidgetView`, `LargeWidgetView`, `KaiPeekView` |
| `app/ios/KaizenWidget/Assets.xcassets/` | Asset Catalog с 8 imageset-заглушками (Contents.json без PNG-файлов) |
| `app/ios/Runner/AppDelegate.swift` | MethodChannel `kaizen/widget` → App Group UserDefaults + `WidgetCenter.reloadAllTimelines()` |
| `app/lib/services/widget/widget_service.dart` | Dart-сторона: iOS-ветка вызывает тот же `_channel.invokeMethod('updateWidget', payload)` |

---

## Шаг 1 — Создать Widget Extension target в Xcode

1. Открой `app/ios/Runner.xcworkspace` в Xcode.
2. `File → New → Target…` → выбери **Widget Extension**.
3. Настройки:
   - **Product Name:** `KaizenWidget`
   - **Bundle Identifier:** `com.kaizen.app.KaizenWidget`
   - **Team:** твой Apple Developer account
   - **Language:** Swift
   - **Include Configuration Intent:** NO (используем `StaticConfiguration`)
   - **Embed in Application:** Runner
4. Xcode предложит добавить схему — нажми **Cancel** (не нужна отдельная схема для сборки).

> После создания Xcode генерирует шаблонные файлы в `Runner/KaizenWidget/`. Удали их все
> (или переиспользуй, заменив содержимым) — реальные файлы уже в `ios/KaizenWidget/`.

---

## Шаг 2 — Добавить Swift-файлы в target

1. В Project Navigator: правый клик на группу `KaizenWidget` → **Add Files to "Runner"…**
2. Выбери все 4 `.swift` файла из `app/ios/KaizenWidget/`:
   - `KaizenWidget.swift`
   - `Provider.swift`
   - `KaizenEntry.swift`
   - `KaizenWidgetView.swift`
3. В диалоге:
   - **Destination:** включено (Copy items if needed — можно оставить)
   - **Added to targets:** поставь галочку ТОЛЬКО на `KaizenWidget` (не Runner)
4. Нажми **Add**.

---

## Шаг 3 — Подключить Assets.xcassets к target

1. В Project Navigator: правый клик → **Add Files to "Runner"…**
2. Выбери `app/ios/KaizenWidget/Assets.xcassets`.
3. Added to targets: только `KaizenWidget`.
4. Нажми **Add**.

---

## Шаг 4 — Добавить Kai PNG в Asset Catalog

Исходные PNG-файлы лежат в `app/assets/kai_widget/`:
```
kai_neutral.png
kai_neutral_harsh.png
kai_success.png
kai_success_harsh.png
kai_anxious.png
kai_anxious_harsh.png
kai_away.png
kai_away_harsh.png
```
Это PNG 384px с белыми глазами и прозрачным фоном (xxxhdpi, из генератора).

Для каждого из 8 вариантов:
1. В Xcode открой `KaizenWidget/Assets.xcassets`.
2. Найди нужный imageset (уже создан через Contents.json в репо), например `kai_neutral`.
3. Перетащи `kai_neutral.png` в слот **3x** (384px — это @3x).
4. Для слотов **1x** и **2x** можно использовать тот же файл или сгенерировать масштабированные
   версии (128px для 1x, 256px для 2x) скриптом:
   ```bash
   # На Mac, в директории app/assets/kai_widget/:
   sips -Z 128 kai_neutral.png --out kai_neutral@1x.png
   sips -Z 256 kai_neutral.png --out kai_neutral@2x.png
   ```
5. Проверь что `rendering-intent = template` в Contents.json — это позволяет тинтировать
   белые пиксели accent-цветом через `.renderingMode(.template).foregroundColor(accent)`.

---

## Шаг 5 — App Groups capability

### Runner target:
1. Выбери Runner в Project Navigator → Target: Runner → **Signing & Capabilities**.
2. Нажми `+` → **App Groups**.
3. Добавь: `group.com.kaizen.app` (должен совпадать с `kAppGroupSuiteName` в `Provider.swift`
   и `AppDelegate.swift`).

### KaizenWidget Extension target:
1. Выбери KaizenWidget → **Signing & Capabilities**.
2. Нажми `+` → **App Groups**.
3. Добавь ту же группу: `group.com.kaizen.app`.

> Обе цели (Runner и Extension) должны использовать одну и ту же App Group и иметь
> одинаковый Team для App Groups capability.

---

## Шаг 6 — URL Scheme для deep-link виджета

Тапы из виджета открывают приложение по URL:
- `kaizen://widget/today` — тап по телу виджета
- `kaizen://add-task` — кнопка `+` в большом виджете

Чтобы приложение открывалось:
1. Runner target → **Info** tab → **URL Types** → нажми `+`.
2. Identifier: `com.kaizen.app`
3. URL Schemes: `kaizen`

В коде Flutter (main.dart или go_router) обработай входящий URL через
`getInitialUri()` / `uriLinkStream` из пакета `app_links` (или `uni_links`).
Это отдельная задача — виджет работает и без неё, просто откроет приложение на главном экране.

---

## Шаг 7 — Минимальная версия iOS

WidgetKit требует iOS 14+.

1. Runner target → **General** → **Minimum Deployments** → iOS 14.0 (или выше).
2. KaizenWidget Extension → то же самое.

Текущий `Runner.xcodeproj` может иметь другую версию — проверь и обнови если нужно.

---

## Шаг 8 — Проверить сборку

1. Выбери схему **Runner** (не KaizenWidget отдельно).
2. Сборка: `Cmd+B`.
3. Убедись что нет ошибок в Swift-файлах.
4. Запусти на симуляторе iPhone → долгое нажатие на рабочем столе → добавить виджет → Kaizen.
5. Проверь все три размера (small/medium/large).

---

## Шаг 9 — Проверить data-bridge

1. Запусти приложение Kaizen на симуляторе.
2. Добавь несколько задач через Today-экран.
3. Сверни приложение — виджет должен обновиться (WidgetCenter.reloadAllTimelines() вызывается
   при `refreshHomeWidget()`).
4. Если данные не появились: в симуляторе открой `AppGroup UserDefaults` через Console.app
   или Instruments → убедись что ключи `next_items`, `main_done` и т.д. записаны.

---

## Шаг 10 — Тест away-эмоции

1. Измени `last_opened_at` в UserDefaults на дату 3 дня назад (через lldb или тестовый код).
2. Подожди следующего timeline-update виджета (или принудительно через `WidgetCenter.shared.reloadAllTimelines()`).
3. Kai должен переключиться на `kai_away.png`.

---

## Архитектурные решения (к сведению)

### Почему не `home_widget` пакет?

Рассматривались два пути:
1. **`home_widget` пакет** (pub.dev) — кроссплатформенный, пишет в App Group UserDefaults через готовый плагин.
2. **Кастомный MethodChannel** — уже реализован для Android; iOS добавляется одним Swift-файлом.

Выбран **кастомный MethodChannel** по следующим причинам:
- Android-сторона уже работает через `MethodChannel('kaizen/widget')`.
- Добавление `home_widget` потребовало бы замены существующего Android-кода или дублирования логики.
- Кастомный путь не добавляет зависимость в `pubspec.yaml`.
- Swift-обработчик в AppDelegate тривиален (~40 строк).

Если в будущем понадобится `home_widget` (например, для изображений через `saveWidgetData`
или periodic background refresh), его можно добавить параллельно, не ломая Android.

### App Group suite name

`group.com.kaizen.app` — зафиксировано в:
- `app/ios/KaizenWidget/Provider.swift` (`kAppGroupSuiteName`)
- `app/ios/Runner/AppDelegate.swift` (`kAppGroupSuiteName`)
- Этот документ

Изменение suite name требует правки в обоих Swift-файлах.

---

## Что НЕ проверено без Mac/Xcode

- Корректность Swift-синтаксиса (компиляция Swift 5.9+ с WidgetKit).
- Реальная запись/чтение App Group UserDefaults.
- `WidgetCenter.shared.reloadAllTimelines()` действительно перезагружает виджет.
- Работа `FlutterImplicitEngineBridge` + `FlutterImplicitEngineDelegate` в AppDelegate
  (зависит от версии Flutter Engine; если метод отсутствует — см. альтернативу ниже).
- Rendering intent `template` + `.foregroundColor(accent)` на реальном виджете.
- Deep-link через `kaizen://` URL scheme.
- Поведение Timeline на физическом устройстве.

### Альтернатива для AppDelegate если `FlutterImplicitEngineBridge` отсутствует

В некоторых версиях Flutter Engine используется `FlutterViewController` напрямую:

```swift
override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
        name: "kaizen/widget",
        binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
        // ... та же логика handleUpdateWidget
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
}
```

Если текущий `AppDelegate` (с `FlutterImplicitEngineDelegate`) уже работает в проекте —
можно просто добавить `channel.setMethodCallHandler` в `didInitializeImplicitFlutterEngine`.
