import SwiftUI

// MARK: - Assistant Suggestion Banner View

/// 선제적 제안 배너 뷰
struct AssistantSuggestionBannerView: View {
    let suggestion: AssistantSuggestion
    let onDismiss: () -> Void
    let onAction: (SuggestionAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더
            HStack(spacing: 8) {
                Image(systemName: suggestion.priority.icon)
                    .foregroundColor(Color(suggestion.priority.color))
                    .font(.title3)

                Text(suggestion.title)
                    .font(.headline)
                    .foregroundColor(Color(suggestion.priority.color))

                Spacer()

                if suggestion.dismissible {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
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
                        if action.actionType == .addTask || action.actionType == .viewTasks || action.actionType == .reschedule {
                            Button(action: {
                                onAction(action)
                            }) {
                                Text(action.title)
                                    .font(.callout)
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button(action: {
                                onAction(action)
                            }) {
                                Text(action.title)
                                    .font(.callout)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(backgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(suggestion.priority.color), lineWidth: 2)
        )
    }

    private var backgroundColor: Color {
        switch suggestion.priority {
        case .urgent:
            return Color.red.opacity(0.1)
        case .high:
            return Color.orange.opacity(0.1)
        case .medium:
            return Color.blue.opacity(0.1)
        case .low:
            return Color.gray.opacity(0.05)
        }
    }
}

// MARK: - Assistant History View

@MainActor
struct AssistantHistoryView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @State private var suggestions: [AssistantSuggestion] = []

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("알림 히스토리")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("\(suggestions.count)개의 제안")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if !suggestions.isEmpty {
                    Button(action: {
                        ProactiveAssistantService.shared.clearHistory()
                        suggestions = []
                    }) {
                        Label("모두 삭제", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // 히스토리 리스트
            if suggestions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bell.slash.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary.opacity(0.5))

                    Text("아직 제안이 없어요")
                        .font(.title2)
                        .foregroundColor(.secondary)

                    Text("비서가 상황을 분석하여 유용한 제안을 해드릴게요")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(suggestions) { suggestion in
                            AssistantHistoryRow(
                                suggestion: suggestion,
                                onDelete: {
                                    ProactiveAssistantService.shared.removeFromHistory(suggestion)
                                    suggestions = ProactiveAssistantService.shared.suggestionHistory
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            suggestions = ProactiveAssistantService.shared.suggestionHistory
        }
    }
}

// MARK: - Assistant History Row

struct AssistantHistoryRow: View {
    let suggestion: AssistantSuggestion
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 우선순위 아이콘
            Image(systemName: suggestion.priority.icon)
                .font(.title2)
                .foregroundColor(priorityColor(suggestion.priority))
                .frame(width: 32)

            // 제안 내용
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.headline)

                Text(suggestion.message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // 타임스탬프 (제안이 생성된 시간)
                Text(timeAgo(from: suggestion.createdAt))
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 삭제 버튼
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("히스토리에서 삭제")
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private func timeAgo(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)

        if let days = components.day, days > 0 {
            return "\(days)일 전"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)시간 전"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)분 전"
        } else {
            return "방금 전"
        }
    }

    private func priorityColor(_ priority: SuggestionPriority) -> Color {
        switch priority {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }
}
