import WeekAheadShared
import SwiftUI

/// 다가올 알림을 미리 볼 수 있는 뷰
struct NotificationPreviewView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var assistantService: ProactiveAssistantService

    @State private var currentTime = Date()

    // 알림 시간들 (오전 9시, 오후 3시, 저녁 9시)
    private let notificationTimes: [(hour: Int, minute: Int, label: String)] = [
        (9, 0, "오전 9시"),
        (15, 0, "오후 3시"),
        (21, 0, "저녁 9시")
    ]

    // 1초마다 현재 시간 업데이트
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 헤더
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(.blue)
                Text("다가올 알림")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()

                // 알림 활성화 상태 표시
                if notificationService.isNotificationEnabled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .help("알림 활성화됨")
                } else {
                    Image(systemName: "bell.slash.fill")
                        .foregroundColor(.gray)
                        .help("알림 비활성화됨")
                }
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // 비서 제안 섹션 (최상단)
                    if !assistantService.activeSuggestions.isEmpty {
                        assistantSuggestionsSection

                        Divider()
                            .padding(.vertical, 8)
                    }

                    if notificationService.isNotificationEnabled {
                        // 알림 활성화되어 있으면 다음 알림 시간들 표시
                        ForEach(Array(notificationTimes.enumerated()), id: \.offset) { index, time in
                            notificationTimeCard(hour: time.hour, minute: time.minute, label: time.label)
                        }

                        Divider()
                            .padding(.vertical, 8)

                        // 알림 필요한 태스크 미리보기
                        tasksNeedingAttentionSection
                    } else {
                        // 알림 비활성화되어 있으면 안내 메시지
                        VStack(spacing: 12) {
                            Image(systemName: "bell.slash")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)

                            Text("알림이 비활성화되어 있습니다")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            Text("설정에서 알림을 활성화하세요")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(32)
                    }
                }
                .padding(16)
            }
            .frame(width: 450, height: 500)
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }

    // MARK: - 알림 시간 카드

    @ViewBuilder
    private func notificationTimeCard(hour: Int, minute: Int, label: String) -> some View {
        let nextNotificationDate = nextOccurrence(hour: hour, minute: minute)
        let timeRemaining = timeRemainingString(until: nextNotificationDate)
        let isPast = nextNotificationDate < currentTime

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(isPast ? .gray : .blue)
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(timeRemaining)
                    .font(.callout)
                    .foregroundColor(isPast ? .gray : .orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isPast ? Color.gray.opacity(0.2) : Color.orange.opacity(0.2))
                    .cornerRadius(8)
            }

            // 예상 알림 내용
            if !isPast {
                let tasksCount = tasksNeedingAttention.count
                if tasksCount > 0 {
                    Text("\(tasksCount)개의 할 일이 확인 필요")
                        .font(.callout)
                        .foregroundColor(.secondary)
                } else {
                    Text("확인 필요한 할 일 없음")
                        .font(.callout)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - 비서 제안 섹션

    @ViewBuilder
    private var assistantSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("비서 제안")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(assistantService.activeSuggestions.count)개")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            ForEach(assistantService.activeSuggestions) { suggestion in
                AssistantSuggestionBannerView(
                    suggestion: suggestion,
                    onDismiss: {
                        assistantService.dismissSuggestion(suggestion)
                    },
                    onAction: { action in
                        // TODO: 액션 처리
                    }
                )
            }
        }
    }

    // MARK: - 태스크 미리보기 섹션

    @ViewBuilder
    private var tasksNeedingAttentionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
                Text("확인 필요한 할 일")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(tasksNeedingAttention.count)개")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            if tasksNeedingAttention.isEmpty {
                Text("모든 할 일이 정상 진행 중입니다!")
                    .font(.callout)
                    .foregroundColor(.green)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(tasksNeedingAttention.prefix(5)) { task in
                        taskPreviewRow(task)
                    }

                    if tasksNeedingAttention.count > 5 {
                        Text("외 \(tasksNeedingAttention.count - 5)개")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func taskPreviewRow(_ task: Task) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor(for: task))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.callout)
                    .lineLimit(1)

                Text(reasonForAttention(task))
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }

    // MARK: - Helper Functions

    /// 다음 알림 발생 시간 계산
    private func nextOccurrence(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let now = Date()

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0

        guard var date = calendar.date(from: components) else {
            return now
        }

        // 이미 지난 시간이면 내일로 설정
        if date <= now {
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }

        return date
    }

    /// 남은 시간 문자열
    private func timeRemainingString(until date: Date) -> String {
        let interval = date.timeIntervalSince(currentTime)

        if interval < 0 {
            return "지남"
        }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60

        if hours > 0 {
            return "\(hours)시간 \(minutes)분 후"
        } else if minutes > 0 {
            return "\(minutes)분 \(seconds)초 후"
        } else {
            return "\(seconds)초 후"
        }
    }

    /// 알림이 필요한 태스크 목록
    private var tasksNeedingAttention: [Task] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        var tasks: [Task] = []

        for task in viewModel.tasks where !task.isCompleted {
            // 1. 시작일이 지났는데 아직 시작 안한 일
            if task.effectiveStartDate < today && task.isNotStarted {
                tasks.append(task)
                continue
            }

            // 2. 오늘 해야 할 일이 아직 완료되지 않은 경우
            if calendar.isDate(task.effectiveStartDate, inSameDayAs: today) && !task.isCompleted {
                tasks.append(task)
                continue
            }

            // 3. 마감 1일 전 알림 (내일이 마감일)
            if calendar.isDate(task.dueDate, inSameDayAs: tomorrow) && !task.isCompleted {
                tasks.append(task)
                continue
            }

            // 4. 준비 태스크를 시작할 시간
            if task.isPreparation && calendar.isDate(task.effectiveStartDate, inSameDayAs: today) && !task.isCompleted {
                tasks.append(task)
                continue
            }
        }

        return tasks
    }

    /// 태스크 상태별 색상
    private func statusColor(for task: Task) -> Color {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if task.effectiveStartDate < today && task.isNotStarted {
            return .red // 늦음
        } else if calendar.isDate(task.dueDate, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: today)!) {
            return .orange // 내일 마감
        } else {
            return .blue // 정상
        }
    }

    /// 알림 필요 이유
    private func reasonForAttention(_ task: Task) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        if task.effectiveStartDate < today && task.isNotStarted {
            let daysOverdue = calendar.dateComponents([.day], from: task.effectiveStartDate, to: today).day ?? 0
            return "시작일이 \(daysOverdue)일 지남"
        } else if calendar.isDate(task.effectiveStartDate, inSameDayAs: today) {
            return "오늘 시작해야 함"
        } else if calendar.isDate(task.dueDate, inSameDayAs: tomorrow) {
            return "내일 마감"
        } else if task.isPreparation {
            return "준비 태스크"
        }

        return "확인 필요"
    }
}

// MARK: - Preview

#Preview {
    NotificationPreviewView()
        .environmentObject(TaskViewModel())
        .environmentObject(NotificationService.shared)
        .environmentObject(ProactiveAssistantService.shared)
}
