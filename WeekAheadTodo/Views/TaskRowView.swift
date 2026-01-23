import SwiftUI

// MARK: - Task Row View

struct TaskRowView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    let task: Task

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var isHovered = false
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 12) {
            // 진행 중 표시 바 (왼쪽)
            if task.isInProgress {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue)
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

                    if task.priority == .urgent || task.priority == .high {
                        Image(systemName: task.priority.icon)
                            .font(.callout)
                            .foregroundColor(Color(task.priority.color))
                    }
                }

                HStack(spacing: 8) {
                    Label(task.estimatedTimeFormatted, systemImage: "clock")
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

                    urgencyIndicator
                }
                .font(.callout)
                .foregroundColor(.secondary)
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
