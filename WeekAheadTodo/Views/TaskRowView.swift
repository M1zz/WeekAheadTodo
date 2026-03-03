import WeekAheadShared
import SwiftUI

// MARK: - Task Row View

struct TaskRowView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    let task: Task

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var isHovered = false
    @State private var isPulsing = false
    @State private var isSubtasksExpanded = false
    @State private var pomodoroSeconds: Int = 25 * 60
    @State private var isPomodoroActive: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 12) {
            // 진행 중 표시 바 (왼쪽)
            if task.isInProgress {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue)
                    .frame(width: 4)
                    .padding(.vertical, -12)
                    .padding(.leading, -12)
            } else if task.isMIT {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.yellow.opacity(0.8))
                    .frame(width: 4)
                    .padding(.vertical, -12)
                    .padding(.leading, -12)
            }

            Button(action: { viewModel.toggleTaskCompletion(task) }) {
                ZStack {
                    // 진행 중일 때 펄스 효과
                    if task.isInProgress {
                        Circle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 32, height: 32)
                            .scaleEffect(isPulsing ? 1.3 : 1.0)
                            .opacity(isPulsing ? 0 : 0.5)
                            .animation(
                                Animation.easeInOut(duration: 1.5)
                                    .repeatForever(autoreverses: false),
                                value: isPulsing
                            )
                    }

                    Image(systemName: task.isInProgress ? "play.circle.fill" : task.status.icon)
                        .font(.title2)
                        .foregroundColor(statusColor)
                }
            }
            .buttonStyle(.plain)
            .help(task.status.rawValue)
            .onAppear {
                if task.isInProgress {
                    isPulsing = true
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    // 진행 중 뱃지
                    if task.isInProgress {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.callout)
                            Text("진행 중")
                                .font(.callout)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    }

                    if task.taskRole != .none {
                        HStack(spacing: 4) {
                            Image(systemName: task.taskRole.icon)
                                .font(.callout)
                            Text(task.taskRole.rawValue)
                                .font(.callout)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(roleColor.opacity(0.15))
                        .foregroundColor(roleColor)
                        .cornerRadius(4)
                    }

                    Text(task.title)
                        .font(.body)
                        .fontWeight(task.isInProgress ? .semibold : .regular)
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)

                    if let progressText = task.subtaskProgressText {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isSubtasksExpanded.toggle()
                            }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: isSubtasksExpanded ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 9, weight: .semibold))
                                Text(progressText)
                                    .font(.callout)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(task.allSubtasksCompleted ? Color.green.opacity(0.15) : Color.secondary.opacity(0.12))
                            .foregroundColor(task.allSubtasksCompleted ? .green : .secondary)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }

                    if task.priority == .urgent || task.priority == .high {
                        Image(systemName: task.priority.icon)
                            .font(.callout)
                            .foregroundColor(Color(task.priority.color))
                    }
                }

                HStack(spacing: 8) {
                    Label(task.estimatedTimeFormatted, systemImage: "clock")

                    if let targetDate = task.targetDate, !task.isPreparation {
                        Label(targetDate.formatted(.dateTime.hour().minute()), systemImage: "clock.fill")
                            .foregroundColor(.blue.opacity(0.8))
                    }

                    Label(task.dueDateWithWeekday, systemImage: "calendar")

                    if task.leadTimeDays > 0 {
                        Label("D-\(task.leadTimeDays)", systemImage: "arrow.left.circle")
                            .foregroundColor(.orange)
                    }

                    if task.isPreparation {
                        if let daysText = task.daysUntilTargetText {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.right.circle.fill")
                                Text("\(daysText) 준비")
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                        }
                    }

                    if let staleDays = task.staleDays {
                        HStack(spacing: 3) {
                            Image(systemName: "clock.badge.exclamationmark")
                            Text("\(staleDays)일 방치")
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.12))
                        .foregroundColor(.red)
                        .cornerRadius(4)
                    }

                    urgencyIndicator
                }
                .font(.callout)
                .foregroundColor(.secondary)

                // 뽀모도로 타이머 (진행 중 태스크에만 표시)
                if task.isInProgress {
                    HStack(spacing: 8) {
                        Button(action: { isPomodoroActive.toggle() }) {
                            HStack(spacing: 4) {
                                Image(systemName: isPomodoroActive ? "pause.fill" : "play.fill")
                                    .font(.system(size: 10))
                                Text(pomodoroFormatted)
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(isPomodoroActive ? Color.orange : Color.orange.opacity(0.15))
                            .foregroundColor(isPomodoroActive ? .white : .orange)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)

                        if pomodoroSeconds < 25 * 60 {
                            Button(action: {
                                pomodoroSeconds = 25 * 60
                                isPomodoroActive = false
                            }) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Spacer()

            if isHovered {
                HStack(spacing: 8) {
                    Button(action: { showingEditSheet = true }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("수정")

                    Button(action: { showingDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("삭제")
                }
            }

            // MIT 별 버튼 (항상 맨 오른쪽 고정)
            Button(action: { viewModel.toggleMIT(task) }) {
                Image(systemName: task.isMIT ? "star.fill" : "star")
                    .font(.title3)
                    .foregroundColor(task.isMIT ? .yellow : .gray.opacity(0.35))
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(task.isMIT ? Color.yellow.opacity(0.18) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .help(task.isMIT ? "핵심 해제 (포커스 모드에서 제외)" : "포커스 모드 핵심 태스크로 설정 (최대 3개)")
        }
        .padding(12)
        .background(taskBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(task.isInProgress ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 2)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .sheet(isPresented: $showingEditSheet) {
            EditTaskView(task: task)
        }
        .alert("이 할 일을 삭제하시겠습니까?", isPresented: $showingDeleteAlert) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) {
                viewModel.deleteTask(task)
            }
        } message: {
            Text("\"\(task.title)\"을(를) 삭제합니다. 이 작업은 되돌릴 수 없습니다.")
        }

        // 세부 항목 장려 메시지 (오늘 해야 하지만 아직 시작 못 한 일정에만 표시)
        if task.isNotStarted && task.subtasks.isEmpty && task.currentHorizon == .today {
            Button(action: { showingEditSheet = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.dashed")
                        .font(.callout)
                    Text("세부 항목을 추가하면 시작하기 쉬워져요")
                        .font(.callout)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.blue.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.blue.opacity(0.05))
            }
            .buttonStyle(.plain)
        }

        // 하위 할 일 목록 (펼침)
        if isSubtasksExpanded && !task.subtasks.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(task.subtasks) { subtask in
                    HStack(spacing: 8) {
                        Button(action: {
                            viewModel.toggleSubtaskCompletion(taskId: task.id, subtaskId: subtask.id)
                        }) {
                            Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.callout)
                                .foregroundColor(subtask.isCompleted ? .green : .gray)
                        }
                        .buttonStyle(.plain)

                        Text(subtask.title)
                            .font(.callout)
                            .strikethrough(subtask.isCompleted)
                            .foregroundColor(subtask.isCompleted ? .secondary : .primary)

                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
            .padding(.leading, 40)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
        } // VStack 닫기
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard isPomodoroActive else {
                if pomodoroSeconds == 0 { isPomodoroActive = false }
                return
            }
            if pomodoroSeconds > 0 {
                pomodoroSeconds -= 1
            } else {
                isPomodoroActive = false
            }
        }
        .onChange(of: task.isInProgress) { _, isInProgress in
            if !isInProgress {
                isPomodoroActive = false
                pomodoroSeconds = 25 * 60
            }
        }
    }

    private var pomodoroFormatted: String {
        let m = pomodoroSeconds / 60
        let s = pomodoroSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private var statusColor: Color {
        switch task.status {
        case .notStarted: return .gray
        case .inProgress: return .blue
        case .completed: return .green
        }
    }

    private var taskBackground: Color {
        if task.isCompleted {
            return Color.green.opacity(0.05)
        } else if task.isInProgress {
            return Color.blue.opacity(0.08)
        } else if task.isMIT {
            return Color.yellow.opacity(0.06)
        } else {
            return Color(NSColor.controlBackgroundColor)
        }
    }

    private var roleColor: Color {
        switch task.taskRole {
        case .none:
            return .clear
        case .preparation:
            return .orange
        case .followUp:
            return .green
        case .review:
            return .yellow
        case .learning:
            return .cyan
        case .idea:
            return .pink
        }
    }

    @ViewBuilder
    private var urgencyIndicator: some View {
        if task.daysUntilStart <= 0 {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
        } else if task.daysUntilStart <= 2 {
            Circle()
                .fill(Color.orange)
                .frame(width: 8, height: 8)
        }
    }
}

// MARK: - Compact Task Row (for Calendar View)

struct CompactTaskRow: View {
    @EnvironmentObject var viewModel: TaskViewModel
    let task: Task

    var body: some View {
        Button(action: {
            viewModel.toggleTaskCompletion(task)
        }) {
            HStack(spacing: 6) {
                // 진행 중 표시 바
                if task.isInProgress {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.blue)
                        .frame(width: 3)
                        .padding(.vertical, -4)
                }

                Image(systemName: task.isInProgress ? "play.circle.fill" : task.status.icon)
                    .font(.callout)
                    .foregroundColor(statusColor)

                if task.isInProgress {
                    Text("진행 중")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(3)
                }

                Text(task.title)
                    .font(.callout)
                    .fontWeight(task.isInProgress ? .medium : .regular)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                    .lineLimit(1)

                Spacer()

                if task.priority == .urgent || task.priority == .high {
                    Image(systemName: task.priority.icon)
                        .font(.callout)
                        .foregroundColor(Color(task.priority.color))
                }

                Text(task.estimatedTimeFormatted)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(compactBackground)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(task.isInProgress ? Color.blue.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var compactBackground: Color {
        if task.isCompleted {
            return Color.clear
        } else if task.isInProgress {
            return Color.blue.opacity(0.1)
        } else {
            return Color.gray.opacity(0.05)
        }
    }

    private var statusColor: Color {
        switch task.status {
        case .notStarted: return .gray
        case .inProgress: return .blue
        case .completed: return .green
        }
    }
}
