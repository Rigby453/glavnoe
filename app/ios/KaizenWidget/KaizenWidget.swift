// @main точка входа WidgetKit Extension.
// Объявляет бандл виджетов и один Widget с тремя поддерживаемыми размерами.
//
// Bundle ID Extension: com.kaizen.app.KaizenWidget
// (должен совпадать с настройкой в Xcode Widget Extension target, см. SETUP-ios-widget.md)

import WidgetKit
import SwiftUI

// MARK: - Один Widget

struct KaizenWidget: Widget {
    /// Идентификатор конфигурации — используется системой для хранения пользовательских настроек.
    let kind: String = "KaizenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KaizenWidgetProvider()) { entry in
            KaizenWidgetEntryView(entry: entry)
                // Фон виджета — theme.surface (читается из entry).
                // containerBackground задаёт фон системного контейнера (iOS 17+).
                .containerBackground(entry.theme.surface, for: .widget)
        }
        .configurationDisplayName("Kaizen")
        .description("Your tasks for today at a glance.")
        .supportedFamilies([
            .systemSmall,   // 2×2 — малый
            .systemMedium,  // 4×2 — средний
            .systemLarge,   // 4×4 — большой
        ])
    }
}

// MARK: - Bundle (точка входа @main)

@main
struct KaizenWidgetBundle: WidgetBundle {
    var body: some Widget {
        KaizenWidget()
        // Позже можно добавить дополнительные тематические мини-виджеты (§10 WIDGET.md):
        // KaizenFoodWidget()
        // KaizenStreakWidget()
    }
}

// MARK: - Preview (Xcode Canvas, не влияет на runtime)

#Preview(as: .systemMedium) {
    KaizenWidget()
} timeline: {
    KaizenEntry.placeholder
    KaizenEntry.empty
}
