//
//  TaskRowView.swift
//  TodoAlarm (iOS)
//
//  Task 행 컴포넌트
//

import SwiftUI

// Swift Concurrency Task와 구분
typealias TaskModel = Task

struct TaskRowView: View {
    let task: TaskModel
    @EnvironmentObject var viewModel: TaskViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 제목 + 우선순위
            HStack {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .font(.body)

                Text(task.title)
                    .font(.callout)
                    .fontWeight(.medium)

                Spacer()

                if task.priority != .normal {
                    Image(systemName: priorityIcon)
                        .foregroundStyle(priorityColor)
                        .font(.caption)
                }
            }

            // 마감일 + 예상 시간 + 프로젝트
            HStack(spacing: 12) {
                Label(dueDateText, systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label("\(task.estimatedMinutes)분", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let projectName = viewModel.projectName(for: task.projectId) {
                    Label(projectName, systemImage: "folder")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }

            // 설명 (있으면 표시)
            if !task.description.isEmpty {
                Text(task.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Computed Properties

    private var statusIcon: String {
        switch task.status {
        case .notStarted: return "circle"
        case .inProgress: return "circle.lefthalf.filled"
        case .completed: return "checkmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch task.status {
        case .notStarted: return .gray
        case .inProgress: return .blue
        case .completed: return .green
        }
    }

    private var priorityIcon: String {
        switch task.priority {
        case .low: return "arrow.down"
        case .normal: return "minus"
        case .high: return "arrow.up"
        case .urgent: return "exclamationmark.2"
        }
    }

    private var priorityColor: Color {
        switch task.priority {
        case .low: return .gray
        case .normal: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }

    private var dueDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d (E)"
        return formatter.string(from: task.dueDate)
    }
}
