import SwiftUI

/// 선제적 제안 배너 뷰
struct AssistantSuggestionBannerView: View {
    let suggestion: AssistantSuggestion
    let onDismiss: () -> Void
    let onAction: (SuggestionAction) -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 메인 콘텐츠
            VStack(alignment: .leading, spacing: 8) {
                // 헤더 (아이콘 + 타이틀)
                HStack(spacing: 8) {
                    Image(systemName: suggestion.priority.icon)
                        .foregroundColor(Color(suggestion.priority.color))
                        .font(.title3)

                    Text(suggestion.title)
                        .font(.headline)
                        .foregroundColor(Color(suggestion.priority.color))

                    Spacer()

                    // X 버튼 공간 확보
                    if suggestion.dismissible {
                        Color.clear
                            .frame(width: 24, height: 24)
                    }
                }

                // 메시지
                Text(suggestion.message)
                    .font(.callout)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                // 액션 버튼들
                if !suggestion.actionButtons.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(suggestion.actionButtons) { action in
                            Button(action: {
                                onAction(action)
                            }) {
                                Text(action.title)
                                    .font(.callout)
                            }
                            .buttonStyle(actionButtonStyle(for: action))
                        }
                    }
                }
            }
            .padding(12)
            .padding(.trailing, suggestion.dismissible ? 8 : 0) // X 버튼 공간 추가 확보

            // X 버튼을 우측 상단에 배치
            if suggestion.dismissible {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.body)
                }
                .buttonStyle(.plain)
                .padding(8)
            }
        }
        .background(backgroundColor)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(suggestion.priority.color).opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .frame(maxWidth: 500) // 카드 최대 너비 제한
    }

    private var backgroundColor: Color {
        switch suggestion.priority {
        case .urgent:
            return Color.red.opacity(0.08)
        case .high:
            return Color.orange.opacity(0.08)
        case .medium:
            return Color.blue.opacity(0.08)
        case .low:
            return Color.gray.opacity(0.05)
        }
    }

    private func actionButtonStyle(for action: SuggestionAction) -> some ButtonStyle {
        switch action.actionType {
        case .addTask, .viewTasks, .reschedule:
            return .borderedProminent
        case .dismiss:
            return .bordered
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        AssistantSuggestionBannerView(
            suggestion: AssistantSuggestion(
                type: .meetingPreparationMissing,
                title: "⚠️ 준비 부족",
                message: "내일 '주간 회의'가 있는데 준비가 30%만 완료됐어요.\n\n남은 준비:\n• 아젠다 작성\n• 자료 준비",
                priority: .high,
                actionButtons: [
                    SuggestionAction(title: "준비 태스크 보기", actionType: .viewTasks),
                    SuggestionAction(title: "나중에", actionType: .dismiss)
                ]
            ),
            onDismiss: {},
            onAction: { _ in }
        )

        AssistantSuggestionBannerView(
            suggestion: AssistantSuggestion(
                type: .capacityOverload,
                title: "🚨 오늘 할 일 과부하",
                message: "오늘 할 일이 2시간 30분 초과됐어요.\n일부 태스크를 내일로 미루거나 시간을 조정해보세요.",
                priority: .urgent,
                actionButtons: [
                    SuggestionAction(title: "태스크 재배치", actionType: .reschedule),
                    SuggestionAction(title: "무시", actionType: .dismiss)
                ]
            ),
            onDismiss: {},
            onAction: { _ in }
        )

        AssistantSuggestionBannerView(
            suggestion: AssistantSuggestion(
                type: .idleTime,
                title: "💡 여유 시간 활용",
                message: "오늘 2시간 정도 여유가 있어요.\n미리 할 수 있는 일:\n\n• 보고서 초안 (1시간)\n• 자료 조사 (30분)",
                priority: .low,
                actionButtons: [
                    SuggestionAction(title: "미리 하기", actionType: .viewTasks),
                    SuggestionAction(title: "나중에", actionType: .dismiss)
                ]
            ),
            onDismiss: {},
            onAction: { _ in }
        )
    }
    .padding()
}
