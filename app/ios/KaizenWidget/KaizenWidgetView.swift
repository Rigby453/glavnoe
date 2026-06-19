// SwiftUI-вьюхи виджета для трёх размеров (§3 WIDGET.md).
// Дизайн повторяет Android (каталог app/android/app/src/main/res/layout/).
//
// Kai-PNG: белые глаза, тинтируются accent через .renderingMode(.template)
//          + .foregroundColor(entry.theme.accent) — как iOS WidgetKit позволяет.
// Стрик — theme.textMuted (нейтрально, НЕ accent, §5 WIDGET.md, §5 design-tokens).
// Фон — theme.surface, скругление radius 24 (§5 WIDGET.md).
//
// Deep-link: тап виджета → открывает приложение по URL kaizen://widget/today
// (нужно зарегистрировать URL scheme в Runner Info.plist, см. SETUP-ios-widget.md).

import SwiftUI
import WidgetKit

// MARK: - Корневая вьюха (роутинг по WidgetFamily)

struct KaizenWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: KaizenEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            MediumWidgetView(entry: entry)
        }
    }
}

// MARK: - Малый 2×2 (1 пункт + X/Y + стрик + Kai-уголок)

struct SmallWidgetView: View {
    let entry: KaizenEntry

    private var item: NextItem? { entry.nextItems.first }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Фон
            entry.theme.surface
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(alignment: .leading, spacing: 0) {
                // Время ближайшего пункта (крупно)
                Text(item?.time ?? "--:--")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(entry.theme.text)
                    .lineLimit(1)

                // Название
                Text(item?.title ?? "Nothing today")
                    .font(.system(size: 14))
                    .foregroundColor(entry.theme.text)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)

                Spacer()

                // Нижняя строка: X/Y главных + стрик
                HStack {
                    // X/Y главных (accent-цвет для маркера)
                    if entry.mainTotal > 0 {
                        Text("\(entry.mainDone)/\(entry.mainTotal)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(entry.theme.text)
                    }
                    Spacer()
                    // Стрик — нейтральный цвет (textMuted), не accent
                    if entry.streak > 0 {
                        Text("\(entry.streak)d")
                            .font(.system(size: 12))
                            .foregroundColor(entry.theme.textMuted)
                    }
                }
            }
            .padding(14)
            .padding(.bottom, 8) // отступ от Kai-уголка

            // Kai выглядывает из нижнего правого угла (peek)
            KaiPeekView(entry: entry, size: 44)
                .offset(x: 10, y: 10) // частично выходит за край
        }
        .widgetURL(URL(string: "kaizen://widget/today"))
    }
}

// MARK: - Средний 4×2 (2 пункта + кольцо X/Y + стрик + Kai справа-сверху)

struct MediumWidgetView: View {
    let entry: KaizenEntry

    var body: some View {
        ZStack(alignment: .topTrailing) {
            entry.theme.surface

            HStack(alignment: .top, spacing: 0) {
                // Левая колонка: задачи
                VStack(alignment: .leading, spacing: 0) {
                    // Заголовок + стрик
                    HStack {
                        Text("UP NEXT")
                            .font(.system(size: 10, weight: .medium))
                            .kerning(0.8)
                            .foregroundColor(entry.theme.textMuted)
                        Spacer()
                        if entry.streak > 0 {
                            Text("\(entry.streak)d")
                                .font(.system(size: 11))
                                .foregroundColor(entry.theme.textMuted)
                        }
                    }

                    Spacer(minLength: 8)

                    // Пункт 1
                    if let item = entry.nextItems.first {
                        TaskRowView(item: item, theme: entry.theme, fontSize: 14)
                    } else {
                        Text("Today is free")
                            .font(.system(size: 14))
                            .foregroundColor(entry.theme.textMuted)
                    }

                    // Разделитель
                    if entry.nextItems.count > 1 {
                        Divider()
                            .background(Color(hex: "#3A3020"))
                            .padding(.vertical, 4)
                    }

                    // Пункт 2
                    if entry.nextItems.count > 1 {
                        TaskRowView(item: entry.nextItems[1], theme: entry.theme, fontSize: 14)
                    }

                    Spacer(minLength: 6)

                    // X/Y главных
                    if entry.mainTotal > 0 {
                        HStack(spacing: 4) {
                            Circle()
                                .trim(from: 0, to: mainFraction)
                                .stroke(entry.theme.accent, lineWidth: 2)
                                .frame(width: 12, height: 12)
                                .rotationEffect(.degrees(-90))
                            Text("\(entry.mainDone)/\(entry.mainTotal) main")
                                .font(.system(size: 11))
                                .foregroundColor(entry.theme.text)
                        }
                    }
                }
                .padding(.leading, 14)
                .padding(.vertical, 14)
                .padding(.trailing, 56) // отступ под Kai
            }

            // Kai выглядывает из верхнего правого угла
            KaiPeekView(entry: entry, size: 52)
                .offset(x: 10, y: -10)
        }
        .widgetURL(URL(string: "kaizen://widget/today"))
    }

    private var mainFraction: CGFloat {
        guard entry.mainTotal > 0 else { return 0 }
        return CGFloat(entry.mainDone) / CGFloat(entry.mainTotal)
    }
}

// MARK: - Большой 4×4 (мини-расписание до 4 пунктов + X/Y + стрик + Kai + кнопка +)

struct LargeWidgetView: View {
    let entry: KaizenEntry

    var body: some View {
        ZStack(alignment: .topTrailing) {
            entry.theme.surface

            VStack(alignment: .leading, spacing: 0) {
                // Шапка: Today + стрик
                HStack {
                    Text("TODAY")
                        .font(.system(size: 11, weight: .medium))
                        .kerning(0.8)
                        .foregroundColor(entry.theme.textMuted)
                    Spacer()
                    if entry.streak > 0 {
                        Text("\(entry.streak)d")
                            .font(.system(size: 12))
                            .foregroundColor(entry.theme.textMuted)
                    }
                }

                // X/Y главных
                if entry.mainTotal > 0 {
                    HStack(spacing: 4) {
                        // Полукольцо — accent
                        Circle()
                            .trim(from: 0, to: mainFraction)
                            .stroke(entry.theme.accent, lineWidth: 2)
                            .frame(width: 14, height: 14)
                            .rotationEffect(.degrees(-90))
                        Text("\(entry.mainDone)/\(entry.mainTotal) main")
                            .font(.system(size: 13))
                            .foregroundColor(entry.theme.text)
                    }
                    .padding(.top, 4)
                }

                // Разделитель
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(hex: "#3A3020"))
                    .padding(.vertical, 10)

                // Список пунктов (до 4)
                if entry.nextItems.isEmpty {
                    Spacer()
                    Text("Nothing scheduled")
                        .font(.system(size: 14))
                        .foregroundColor(entry.theme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                } else {
                    let visible = Array(entry.nextItems.prefix(4))
                    ForEach(visible) { item in
                        TaskRowView(item: item, theme: entry.theme, fontSize: 14)
                            .padding(.vertical, 3)
                    }
                    // «Ещё N» если больше 4
                    let extra = entry.nextItems.count - 4
                    if extra > 0 {
                        Text("+\(extra) more")
                            .font(.system(size: 12))
                            .foregroundColor(entry.theme.textMuted)
                            .padding(.top, 2)
                    }
                }

                Spacer()

                // Кнопка «+» (добавить задачу, §2 WIDGET.md)
                HStack {
                    Spacer()
                    Link(destination: URL(string: "kaizen://add-task")!) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(entry.theme.text)
                            .frame(width: 32, height: 32)
                            .background(entry.theme.text.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .padding(.top, 8)
            }
            .padding(16)
            .padding(.trailing, 56) // отступ под Kai в правом углу

            // Kai выглядывает из верхнего правого угла
            KaiPeekView(entry: entry, size: 60)
                .offset(x: 10, y: -12)
        }
        .widgetURL(URL(string: "kaizen://widget/today"))
    }

    private var mainFraction: CGFloat {
        guard entry.mainTotal > 0 else { return 0 }
        return CGFloat(entry.mainDone) / CGFloat(entry.mainTotal)
    }
}

// MARK: - Строка задачи

/// Одна строка: время (bold) + тип-маркер + название (ellipsis).
struct TaskRowView: View {
    let item: NextItem
    let theme: WidgetTheme
    let fontSize: CGFloat

    var body: some View {
        HStack(spacing: 4) {
            Text(item.time)
                .font(.system(size: fontSize - 1, weight: .bold))
                .foregroundColor(theme.text)
                .frame(width: 44, alignment: .leading)
                .lineLimit(1)

            Text(typeIcon)
                .font(.system(size: fontSize - 2))
                .foregroundColor(theme.textMuted)
                .frame(width: 16)

            Text(item.title)
                .font(.system(size: fontSize))
                .foregroundColor(theme.text)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Иконка-символ по типу пункта.
    private var typeIcon: String {
        switch item.type {
        case "exam":     return "⚑"
        case "event":    return "◈"
        case "deadline": return "!"
        default:         return "•"    // task
        }
    }
}

// MARK: - Kai peek (выглядывает из угла)

/// Kai PNG: белые глаза тинтируются accent через .renderingMode(.template).
/// PNG-файлы должны лежать в Asset Catalog KaizenWidget/Assets.xcassets
/// (имена: kai_neutral, kai_success, kai_anxious, kai_away,
///  и *_harsh варианты: kai_neutral_harsh и т.д.)
struct KaiPeekView: View {
    let entry: KaizenEntry
    let size: CGFloat

    var body: some View {
        Image(kaiImageName)
            .renderingMode(.template)          // белые пиксели = прозрачная маска
            .resizable()
            .scaledToFit()
            .foregroundColor(entry.theme.accent) // accent = цвет глаз, §3 MASCOT.md
            .frame(width: size, height: size)
            .accessibilityLabel("Kai")
    }

    /// Имя PNG-ассета в Asset Catalog.
    private var kaiImageName: String {
        let base: String
        switch entry.kaiEmotion {
        case .neutral:  base = "kai_neutral"
        case .success:  base = "kai_success"
        case .anxious:  base = "kai_anxious"
        case .away:     base = "kai_away"
        }
        return entry.isHarsh ? "\(base)_harsh" : base
    }
}
