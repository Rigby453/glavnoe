// TimelineProvider для KaizenWidget.
// Читает данные из App Group UserDefaults (suite: "group.com.kaizen.app"),
// парсит поля §8 WIDGET.md, строит Timeline с записями на будущее
// (чтобы away-эмоция обновлялась без запуска приложения, §7).

import WidgetKit
import SwiftUI

// MARK: - Константы

/// Suite name App Group: должен совпадать с настройкой capability в Xcode
/// (Runner target + KaizenWidget Extension оба получают "group.com.kaizen.app").
let kAppGroupSuiteName = "group.com.kaizen.app"

// MARK: - Ключи UserDefaults (совпадают с полями §8 WIDGET.md + dart widget_service.dart)

private enum UDKey {
    static let nextItems      = "next_items"        // JSON-строка
    static let mainDone       = "main_done"          // Int
    static let mainTotal      = "main_total"         // Int
    static let streak         = "streak"             // String (число)
    static let kaiEmotion     = "kai_emotion"        // String
    static let isHarsh        = "is_harsh"           // Bool (хранится как 1/0 или Bool)
    static let themeAccent    = "theme_accent"       // String "#RRGGBB"
    static let themeBg        = "theme_bg"
    static let themeSurface   = "theme_surface"
    static let themeText      = "theme_text"
    static let themeTextMuted = "theme_text_muted"
    static let lastOpenedAt   = "last_opened_at"     // ISO 8601 String
}

// MARK: - Provider

struct KaizenWidgetProvider: TimelineProvider {

    // MARK: Placeholder (быстрая заглушка при первой установке виджета)

    func placeholder(in context: Context) -> KaizenEntry {
        return .placeholder
    }

    // MARK: Snapshot (предпросмотр в галерее виджетов)

    func getSnapshot(in context: Context, completion: @escaping (KaizenEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
        } else {
            completion(readEntry(at: Date()))
        }
    }

    // MARK: Timeline

    /// Строим Timeline с несколькими записями, чтобы:
    ///   1. Kai переходил в `away` через 2 дня без открытия приложения (§7).
    ///   2. Данные обновлялись хотя бы раз в час (ближайшие пункты дня).
    ///
    /// Политика: .atEnd — после истечения последней записи WidgetKit запрашивает
    /// новый timeline (Flutter-приложение тоже шлёт обновление при resume).
    func getTimeline(in context: Context, completion: @escaping (Timeline<KaizenEntry>) -> Void) {
        let now = Date()

        // Читаем сохранённые данные Flutter-приложения.
        let baseEntry = readEntry(at: now)

        var entries: [KaizenEntry] = []

        // Запись «сейчас» — с актуальной эмоцией.
        entries.append(baseEntry)

        // Запись через 1 час — данные те же, но emotion пересчитывается
        // (ближайшие пункты могут уже пройти, away-счётчик растёт).
        if let entry1h = makeEntry(base: baseEntry, offsetHours: 1) {
            entries.append(entry1h)
        }

        // Запись через 24 ч — на случай если приложение не открывали весь день.
        if let entry24h = makeEntry(base: baseEntry, offsetHours: 24) {
            entries.append(entry24h)
        }

        // Запись через 48 ч — граница перехода в `away` (§4 WIDGET.md).
        if let entry48h = makeEntry(base: baseEntry, offsetHours: 48) {
            entries.append(entry48h)
        }

        // После последней записи WidgetKit снова запросит timeline.
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }

    // MARK: Чтение из App Group UserDefaults

    private func readEntry(at date: Date) -> KaizenEntry {
        let ud = UserDefaults(suiteName: kAppGroupSuiteName)

        // --- next_items ---
        var nextItems: [NextItem] = []
        if let jsonStr = ud?.string(forKey: UDKey.nextItems),
           let data = jsonStr.data(using: .utf8),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
            nextItems = arr.compactMap { dict in
                guard let time = dict["time"], let title = dict["title"] else { return nil }
                return NextItem(time: time, title: title, type: dict["type"] ?? "task")
            }
        }

        // --- Счётчики главных задач ---
        let mainDone  = ud?.integer(forKey: UDKey.mainDone)  ?? 0
        let mainTotal = ud?.integer(forKey: UDKey.mainTotal) ?? 0

        // --- Стрик (может быть сохранён как строка «7» или просто число) ---
        let streakRaw = ud?.string(forKey: UDKey.streak) ?? "0"
        let streak = Int(streakRaw) ?? 0

        // --- last_opened_at ---
        let lastOpenedAt = parseISO(ud?.string(forKey: UDKey.lastOpenedAt))

        // --- Эмоция (пересчитываем для текущего date) ---
        let savedEmotion = KaiEmotion(rawValue: ud?.string(forKey: UDKey.kaiEmotion) ?? "") ?? .neutral
        let emotion = resolveEmotion(
            saved: savedEmotion,
            lastOpenedAt: lastOpenedAt,
            at: date
        )

        // --- Harsh ---
        // Flutter пишет Bool через MethodChannel как Int (1/0) или напрямую Bool.
        let isHarshInt  = ud?.integer(forKey: UDKey.isHarsh) ?? 0
        let isHarshBool = ud?.bool(forKey: UDKey.isHarsh) || isHarshInt == 1

        // --- Тема ---
        let theme = WidgetTheme(
            accent:    Color(hex: ud?.string(forKey: UDKey.themeAccent)    ?? "#D9F24B"),
            bg:        Color(hex: ud?.string(forKey: UDKey.themeBg)        ?? "#141009"),
            surface:   Color(hex: ud?.string(forKey: UDKey.themeSurface)   ?? "#241D11"),
            text:      Color(hex: ud?.string(forKey: UDKey.themeText)      ?? "#F6EFE1"),
            textMuted: Color(hex: ud?.string(forKey: UDKey.themeTextMuted) ?? "#9E9070")
        )

        return KaizenEntry(
            date: date,
            nextItems: nextItems,
            mainDone: mainDone,
            mainTotal: mainTotal,
            streak: streak,
            kaiEmotion: emotion,
            isHarsh: isHarshBool,
            theme: theme,
            lastOpenedAt: lastOpenedAt
        )
    }

    // MARK: Вспомогательные методы

    /// Создаёт следующую запись timeline с учётом прошедшего времени.
    private func makeEntry(base: KaizenEntry, offsetHours: Int) -> KaizenEntry? {
        guard let futureDate = Calendar.current.date(
            byAdding: .hour, value: offsetHours, to: base.date
        ) else { return nil }

        // Пересчитываем эмоцию для будущего момента времени.
        let futureEmotion = resolveEmotion(
            saved: base.kaiEmotion,
            lastOpenedAt: base.lastOpenedAt,
            at: futureDate
        )

        return KaizenEntry(
            date: futureDate,
            nextItems: base.nextItems,
            mainDone: base.mainDone,
            mainTotal: base.mainTotal,
            streak: base.streak,
            kaiEmotion: futureEmotion,
            isHarsh: base.isHarsh,
            theme: base.theme,
            lastOpenedAt: base.lastOpenedAt
        )
    }

    /// Away-логика §4 WIDGET.md: если прошло >= 2 дней с lastOpenedAt → away.
    /// Иначе возвращает сохранённую эмоцию.
    private func resolveEmotion(
        saved: KaiEmotion,
        lastOpenedAt: Date?,
        at date: Date
    ) -> KaiEmotion {
        guard let last = lastOpenedAt else { return saved }
        let days = Calendar.current.dateComponents([.day], from: last, to: date).day ?? 0
        if days >= 2 { return .away }
        return saved
    }

    /// Парсит ISO 8601 строку в Date.
    private func parseISO(_ s: String?) -> Date? {
        guard let s = s else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: s) { return d }
        // Fallback без дробных секунд.
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: s)
    }
}
