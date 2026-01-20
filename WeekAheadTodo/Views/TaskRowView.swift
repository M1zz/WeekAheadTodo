import SwiftUI

// MARK: - Task Row View

struct TaskRowView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    let task: Task

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: { viewModel.toggleTaskCompletion(task) }) {
                Image(systemName: task.status.icon)
                    .font(.title2)
                    .foregroundColor(statusColor)
            }
            .buttonStyle(.plain)
            .help(task.status.rawValue)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
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
        .background(task.isCompleted ? Color.green.opacity(0.05) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
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
                Image(systemName: task.status.icon)
                    .font(.callout)
                    .foregroundColor(statusColor)

                Text(task.title)
                    .font(.callout)
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
            .background(task.isCompleted ? Color.clear : Color.gray.opacity(0.05))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    private var statusColor: Color {
        switch task.status {
        case .notStarted: return .gray
        case .inProgress: return .blue
        case .completed: return .green
        }
    }
}
