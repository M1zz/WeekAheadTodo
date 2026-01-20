import SwiftUI

// MARK: - Date Range Helpers

extension ContentView {
    static func weekDateRange(for date: Date, weekStartDay: Int) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)

        let daysFromStart = (weekday - weekStartDay + 7) % 7

        guard let weekStart = calendar.date(byAdding: .day, value: -daysFromStart, to: calendar.startOfDay(for: date)),
              let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else {
            return (calendar.startOfDay(for: date), calendar.startOfDay(for: date))
        }

        return (weekStart, weekEnd)
    }

    static func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d"

        return "\(formatter.string(from: start)) ~ \(formatter.string(from: end))"
    }
}

// MARK: - Dynamic Font Support

struct FontScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    var fontScale: CGFloat {
        get { self[FontScaleKey.self] }
        set { self[FontScaleKey.self] = newValue }
    }
}

struct FontSizeCalculator {
    static let baseSizes: [Font.TextStyle: CGFloat] = [
        .title: 28,
        .title2: 22,
        .title3: 20,
        .headline: 18,
        .body: 18,
        .callout: 18,
        .subheadline: 18,
        .footnote: 18,
        .caption: 18,
        .caption2: 18,
        .largeTitle: 34
    ]

    static func fontSize(for style: Font.TextStyle, level: Int) -> CGFloat {
        let baseSize = baseSizes[style] ?? 18
        let increase = CGFloat((level - 1) * 2)
        return max(18, baseSize + increase)
    }

    static func dynamicTypeSize(for level: Int) -> DynamicTypeSize {
        switch level {
        case 1: return .large
        case 2: return .xLarge
        case 3: return .xxLarge
        case 4: return .xxxLarge
        case 5: return .accessibility1
        case 6: return .accessibility2
        default: return .large
        }
    }
}

struct DynamicFontModifier: ViewModifier {
    @AppStorage("appFontSizeLevel") private var appFontSizeLevel: Int = 1

    func body(content: Content) -> some View {
        let dynamicTypeSize = FontSizeCalculator.dynamicTypeSize(for: appFontSizeLevel)

        return content
            .dynamicTypeSize(dynamicTypeSize)
    }
}

extension View {
    func applyDynamicFont() -> some View {
        self.modifier(DynamicFontModifier())
    }

    func scaledFont(_ textStyle: Font.TextStyle = .body, design: Font.Design = .default) -> some View {
        self.modifier(ScaledFontModifier(textStyle: textStyle, design: design))
    }
}

struct ScaledFontModifier: ViewModifier {
    @Environment(\.fontScale) var fontScale
    let textStyle: Font.TextStyle
    let design: Font.Design

    func body(content: Content) -> some View {
        content.font(.system(textStyle, design: design))
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

extension Font {
    static func scaled(_ style: TextStyle, scale: CGFloat = 1.0) -> Font {
        return .system(style).weight(.regular)
    }
}
