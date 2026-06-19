// Модель данных для одного снапшота виджета.
// Читается из App Group UserDefaults в Provider.swift, передаётся в View.

import SwiftUI
import WidgetKit

// MARK: - Вспомогательные типы

/// Один ближайший пункт дня (из поля next_items §8 WIDGET.md).
struct NextItem: Identifiable {
    let id = UUID()
    let time: String   // "14:30"
    let title: String  // "Лекция"
    let type: String   // task / event / exam / deadline
}

/// Эмоция Kai (§4 WIDGET.md).
enum KaiEmotion: String {
    case neutral
    case success
    case anxious
    case away
}

/// Цвета активной темы — читаются из data-bridge §8.
struct WidgetTheme {
    let accent: Color
    let bg: Color
    let surface: Color
    let text: Color
    let textMuted: Color
}

// MARK: - Entry

/// TimelineEntry — снапшот данных для одного момента времени.
struct KaizenEntry: TimelineEntry {
    let date: Date

    // Ближайшие пункты дня (до 4).
    let nextItems: [NextItem]

    // Прогресс главных задач.
    let mainDone: Int
    let mainTotal: Int

    // Стрик (число, показываем как "7d" или "🔥7").
    let streak: Int

    // Эмоция Kai и флаг harsh-тона.
    let kaiEmotion: KaiEmotion
    let isHarsh: Bool

    // Цвета темы.
    let theme: WidgetTheme

    // Для away-логики в следующих timeline-записях.
    let lastOpenedAt: Date?
}

// MARK: - Placeholder/empty

extension KaizenEntry {
    /// Заглушка до загрузки реальных данных (placeholder/snapshot).
    static var placeholder: KaizenEntry {
        KaizenEntry(
            date: Date(),
            nextItems: [
                NextItem(time: "14:30", title: "Lecture", type: "event"),
                NextItem(time: "16:00", title: "Essay draft", type: "task"),
            ],
            mainDone: 1,
            mainTotal: 3,
            streak: 7,
            kaiEmotion: .neutral,
            isHarsh: false,
            theme: WidgetTheme.focusFallback,
            lastOpenedAt: Date()
        )
    }

    /// Пустое состояние — задач нет.
    static var empty: KaizenEntry {
        KaizenEntry(
            date: Date(),
            nextItems: [],
            mainDone: 0,
            mainTotal: 0,
            streak: 0,
            kaiEmotion: .neutral,
            isHarsh: false,
            theme: WidgetTheme.focusFallback,
            lastOpenedAt: Date()
        )
    }
}

// MARK: - Тема-фоллбэк (focus, §5 design-tokens)

extension WidgetTheme {
    /// Focus-тема как значения по умолчанию, если UserDefaults пусты.
    static let focusFallback = WidgetTheme(
        accent: Color(hex: "#D9F24B"),
        bg: Color(hex: "#141009"),
        surface: Color(hex: "#241D11"),
        text: Color(hex: "#F6EFE1"),
        textMuted: Color(hex: "#9E9070")
    )
}

// MARK: - Хелпер hex → Color

extension Color {
    /// Конвертирует hex-строку (#RRGGBB или #AARRGGBB) в SwiftUI Color.
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 200, 200, 200)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
