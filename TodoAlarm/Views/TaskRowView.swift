//
//  TaskRowView.swift
//  TodoAlarm (iOS)
//
//  Task 행 컴포넌트
//

import SwiftUI

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

            // 시작/마감 시간 범위
            HStack(spacing: 4) {
                Image(systemName: isPastDue ? "exclamationmark.triangle.fill" : "clock.fill")
                    .foregroundStyle(isPastDue ? .red : .orange)
                    .font(.caption)

                Text(timeRangeText)
                    .font(.caption)
                    .foregroundStyle(isPastDue ? .red : .primary)
                    .fontWeight(.medium)

                if isPastDue {
                    Text("⚠️")
                        .font(.caption)
                }
            }

            // 예상 시간 + 프로젝트
            HStack(spacing: 12) {
                Label("\(task.estimatedMinutes)분", systemImage: "timer")
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

    private var isPastDue: Bool {
        task.dueDate < Date()
    }

    /// 예상 소요 시간을 기반으로 계산된 시작 시간
    private var calculatedStartTime: Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .minute, value: -task.estimatedMinutes, to: task.dueDate) ?? task.dueDate
    }

    /// 시간 범위 텍스트 (macOS처럼 HH:mm - HH:mm 형식)
    private var timeRangeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"

        let startTime = formatter.string(from: calculatedStartTime)
        let endTime = formatter.string(from: task.dueDate)

        return "\(startTime) - \(endTime)"
    }
}
