import WeekAheadShared
import SwiftUI

// MARK: - Upcoming Reminders View

struct UpcomingRemindersView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @State private var showingEditTask: Task?

    // 마감이 지난 태스크
    private var overdueTasks: [Task] {
        viewModel.tasks.filter { task in
            !task.isCompleted && task.daysUntilDue < 0
        }.sorted { $0.daysUntilDue < $1.daysUntilDue }
    }

    // 오늘 마감인 태스크
    private var dueTodayTasks: [Task] {
        viewModel.tasks.filter { task in
            !task.isCompleted && task.daysUntilDue == 0
        }.sorted { $0.dueDate < $1.dueDate }
    }

    // 내일 마감인 태스크
    private var dueTomorrowTasks: [Task] {
        viewModel.tasks.filter { task in
            !task.isCompleted && task.daysUntilDue == 1
        }.sorted { $0.dueDate < $1.dueDate }
    }

    // 3일 내 마감인 태스크 (내일 제외)
    private var dueWithin3DaysTasks: [Task] {
        viewModel.tasks.filter { task in
            !task.isCompleted && task.daysUntilDue > 1 && task.daysUntilDue <= 3
        }.sorted { $0.daysUntilDue < $1.daysUntilDue }
    }

    // 시작해야 할 태스크 (시작일이 지났지만 마감은 아직)
    private var shouldStartTasks: [Task] {
        viewModel.tasks.filter { task in
            !task.isCompleted &&
            task.daysUntilStart <= 0 &&
            task.daysUntilDue > 3 &&
            task.leadTimeDays > 0
        }.sorted { $0.daysUntilDue < $1.daysUntilDue }
    }

    // 곧 시작해야 할 태스크 (시작일이 3일 이내)
    private var startingSoonTasks: [Task] {
        viewModel.tasks.filter { task in
            !task.isCompleted &&
            task.daysUntilStart > 0 &&
            task.daysUntilStart <= 3 &&
            task.leadTimeDays > 0
        }.sorted { $0.daysUntilStart < $1.daysUntilStart }
    }

    private var hasAnyReminders: Bool {
        !overdueTasks.isEmpty ||
        !dueTodayTasks.isEmpty ||
        !dueTomorrowTasks.isEmpty ||
        !dueWithin3DaysTasks.isEmpty ||
        !shouldStartTasks.isEmpty ||
        !startingSoonTasks.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            header

            Divider()

            if hasAnyReminders {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // 마감 지난 태스크
                        if !overdueTasks.isEmpty {
                            reminderSection(
                                title: "마감이 지났어요!",
                                subtitle: "아직 완료되지 않은 태스크가 있어요",
                                icon: "exclamationmark.triangle.fill",
                                color: .red,
                                tasks: overdueTasks
                            )
                        }

                        // 오늘 마감
                        if !dueTodayTasks.isEmpty {
                            reminderSection(
                                title: "오늘이 마감이에요!",
                                subtitle: "오늘 안에 끝내야 해요",
                                icon: "flame.fill",
                                color: .orange,
                                tasks: dueTodayTasks
                            )
                        }

                        // 내일 마감
                        if !dueTomorrowTasks.isEmpty {
                            reminderSection(
                                title: "내일 마감이에요",
                                subtitle: "하루 남았어요, 준비되셨나요?",
                                icon: "clock.badge.exclamationmark.fill",
                                color: .yellow,
                                tasks: dueTomorrowTasks
                            )
                        }

                        // 3일 내 마감
                        if !dueWithin3DaysTasks.isEmpty {
                            reminderSection(
                                title: "곧 마감이에요",
                                subtitle: "며칠 안에 마감인 태스크들이에요",
                                icon: "calendar.badge.clock",
                                color: .blue,
                                tasks: dueWithin3DaysTasks
                            )
                        }

                        // 시작해야 할 태스크
                        if !shouldStartTasks.isEmpty {
                            reminderSection(
                                title: "시작하셔야 해요!",
                                subtitle: "준비 시간이 필요한 태스크예요",
                                icon: "arrow.right.circle.fill",
                                color: .purple,
                                tasks: shouldStartTasks
                            )
                        }

                        // 곧 시작해야 할 태스크
                        if !startingSoonTasks.isEmpty {
                            reminderSection(
                                title: "곧 시작해야 해요",
                                subtitle: "미리 준비하면 좋을 것 같아요",
                                icon: "hourglass",
                                color: .teal,
                                tasks: startingSoonTasks
                            )
                        }
                    }
                    .padding(24)
                }
            } else {
                emptyState
            }
        }
        .frame(minWidth: 500)
        .sheet(item: $showingEditTask) { task in
            EditTaskView(task: task)
                .environmentObject(viewModel)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("잊지 않으셨죠?")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .lineLimit(1)

                Text(greetingMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(minWidth: 350)

            Spacer()

            // 총 리마인더 수
            if hasAnyReminders {
                let totalCount = overdueTasks.count + dueTodayTasks.count +
                                dueTomorrowTasks.count + dueWithin3DaysTasks.count +
                                shouldStartTasks.count + startingSoonTasks.count

                Text("\(totalCount)개의 알림")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(overdueTasks.isEmpty ? Color.blue : Color.red)
                    .clipShape(Capsule())
            }
        }
        .padding(24)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Greeting Message

    private var greetingMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())

        if !overdueTasks.isEmpty {
            return "마감이 지난 태스크가 있어요. 확인해 주세요!"
        } else if !dueTodayTasks.isEmpty {
            return "오늘 마감인 태스크가 있어요. 화이팅!"
        } else if hasAnyReminders {
            if hour < 12 {
                return "좋은 아침이에요! 오늘의 일정을 확인해 보세요."
            } else if hour < 18 {
                return "좋은 오후에요! 다가오는 일정을 확인해 보세요."
            } else {
                return "좋은 저녁이에요! 내일을 위해 미리 확인해 보세요."
            }
        } else {
            return "모든 태스크가 잘 관리되고 있어요!"
        }
    }

    // MARK: - Reminder Section

    @ViewBuilder
    private func reminderSection(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        tasks: [Task]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 섹션 헤더
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(color)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(minWidth: 250)

                Spacer()

                Text("\(tasks.count)개")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            // 태스크 목록
            VStack(spacing: 8) {
                ForEach(tasks) { task in
                    ReminderTaskRow(task: task, accentColor: color) {
                        showingEditTask = task
                    } onToggle: {
                        viewModel.toggleTaskCompletion(task)
                    }
                }
            }
        }
        .padding(16)
        .background(color.opacity(0.08))
        .cornerRadius(12)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("훌륭해요!")
                .font(.title)
                .fontWeight(.bold)

            Text("다가오는 마감이나 시작해야 할 태스크가 없어요.\n모든 일정이 잘 관리되고 있습니다.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

// MARK: - Reminder Task Row

struct ReminderTaskRow: View {
    let task: Task
    let accentColor: Color
    let onEdit: () -> Void
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 체크박스
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(task.isCompleted ? .green : accentColor)
            }
            .buttonStyle(.plain)

            // 태스크 정보
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    // D-Day 표시
                    Text(task.dDayText)
                        .font(.callout)
                        .foregroundColor(dDayColor)
                        .lineLimit(1)

                    if task.estimatedMinutes > 0 {
                        Text("·")
                            .foregroundColor(.secondary)
                        Text(formatMinutes(task.estimatedMinutes))
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    if task.leadTimeDays > 0 {
                        Text("·")
                            .foregroundColor(.secondary)
                        Text("\(task.leadTimeDays)일 전부터")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minWidth: 200)

            Spacer()

            // 우선순위 표시
            if task.priority != .normal {
                priorityBadge
            }

            // 편집 버튼
            Button(action: onEdit) {
                Image(systemName: "chevron.right")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(minWidth: 400)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var dDayColor: Color {
        if task.daysUntilDue < 0 {
            return .red
        } else if task.daysUntilDue == 0 {
            return .orange
        } else if task.daysUntilDue <= 3 {
            return .yellow
        } else {
            return .secondary
        }
    }

    private var priorityBadge: some View {
        Text(task.priority.rawValue)
            .font(.callout)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(priorityColor.opacity(0.15))
            .foregroundColor(priorityColor)
            .cornerRadius(6)
    }

    private var priorityColor: Color {
        switch task.priority {
        case .urgent: return .red
        case .high: return .orange
        case .normal: return .blue
        case .low: return .gray
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)시간 \(mins)분"
        } else if hours > 0 {
            return "\(hours)시간"
        } else {
            return "\(mins)분"
        }
    }
}
