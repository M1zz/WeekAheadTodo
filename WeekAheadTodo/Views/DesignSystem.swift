import SwiftUI

// MARK: - Design System
// 앱 전반의 간격·모서리·색상·카드 스타일을 한 곳에서 관리하여 시각적 일관성을 유지한다.
// 사용 예: `.card()`, `.card(tint: DS.Color.warning)`, `padding(DS.Spacing.lg)`

enum DS {

    // MARK: - 간격 (4pt 그리드)
    enum Spacing {
        /// 4pt
        static let xs: CGFloat = 4
        /// 8pt
        static let sm: CGFloat = 8
        /// 12pt
        static let md: CGFloat = 12
        /// 16pt — 카드 기본 안쪽 여백
        static let lg: CGFloat = 16
        /// 24pt — 화면 가장자리 기본 여백
        static let xl: CGFloat = 24
        /// 32pt
        static let xxl: CGFloat = 32
    }

    // MARK: - 모서리 둥글기
    enum Radius {
        /// 8pt — 작은 요소(배지, 버튼)
        static let small: CGFloat = 8
        /// 12pt — 카드 기본
        static let medium: CGFloat = 12
        /// 16pt — 큰 컨테이너
        static let large: CGFloat = 16
    }

    // MARK: - 의미론적 색상
    /// 색은 "의미"로만 쓴다. 임의로 .blue/.orange 등을 직접 쓰지 말고 여기를 참조한다.
    enum Color {
        /// 기본 강조 / 정보 / 진행 중
        static let accent = SwiftUI.Color.blue
        /// 완료 / 여유 시간
        static let success = SwiftUI.Color.green
        /// 주의 / 용량 초과 / 마감 임박
        static let warning = SwiftUI.Color.orange
        /// 긴급 / 마감 지남 / 도움 필요
        static let danger = SwiftUI.Color.red
        /// 핵심(MIT) / 추천 — 사용자가 "지금 주목할 것"
        static let highlight = SwiftUI.Color.yellow
    }
}

// MARK: - 카드 스타일

private struct CardStyle: ViewModifier {
    var tint: Color?
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous)
                    .fill(tint?.opacity(0.08) ?? Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous)
                    .stroke(tint?.opacity(0.25) ?? Color.clear, lineWidth: tint == nil ? 0 : 1)
            )
    }
}

extension View {
    /// 앱 전반에서 일관된 카드 컨테이너 스타일.
    /// - Parameters:
    ///   - tint: 의미색 틴트(예: `DS.Color.warning`). nil이면 기본 배경.
    ///   - padding: 안쪽 여백 (기본 16pt)
    func card(tint: Color? = nil, padding: CGFloat = DS.Spacing.lg) -> some View {
        modifier(CardStyle(tint: tint, padding: padding))
    }
}

// MARK: - 섹션 헤더

/// 카드/섹션 위에 올리는 일관된 제목 헤더.
struct SectionHeader: View {
    let title: String
    var systemImage: String? = nil
    var tint: Color = .secondary
    var accessory: AnyView? = nil

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundColor(tint)
            }
            Text(title)
                .font(.headline)
            Spacer()
            if let accessory {
                accessory
            }
        }
    }
}
