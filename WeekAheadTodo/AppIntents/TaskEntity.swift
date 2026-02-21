import WeekAheadShared
import Foundation
import AppIntents

/// App Intents용 Task 엔티티
struct TaskEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "태스크")
    static var defaultQuery = TaskEntityQuery()

    var id: UUID
    var title: String
    var dueDate: Date
    var estimatedMinutes: Int
    var status: String
    var priority: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(formatDate(dueDate)) · \(estimatedMinutes)분",
            image: .init(systemName: statusIcon)
        )
    }

    private var statusIcon: String {
        switch status {
        case "완료": return "checkmark.circle.fill"
        case "진행 중": return "circle.lefthalf.filled"
        default: return "circle"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Task 모델에서 TaskEntity 생성
    init(from task: Task) {
        self.id = task.id
        self.title = task.title
        self.dueDate = task.dueDate
        self.estimatedMinutes = task.estimatedMinutes
        self.status = task.status.rawValue
        self.priority = task.priority.rawValue
    }

    init(id: UUID, title: String, dueDate: Date, estimatedMinutes: Int, status: String, priority: String) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.estimatedMinutes = estimatedMinutes
        self.status = status
        self.priority = priority
    }
}

/// TaskEntity 쿼리 (검색 및 조회)
struct TaskEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [TaskEntity] {
        // UserDefaults에서 태스크 로드
        guard let data = UserDefaults.standard.data(forKey: "SavedTasks"),
              let tasks = try? JSONDecoder().decode([Task].self, from: data) else {
            return []
        }

        return tasks
            .filter { identifiers.contains($0.id) }
            .map { TaskEntity(from: $0) }
    }

    func suggestedEntities() async throws -> [TaskEntity] {
        // 오늘 할 일 제안
        guard let data = UserDefaults.standard.data(forKey: "SavedTasks"),
              let tasks = try? JSONDecoder().decode([Task].self, from: data) else {
            return []
        }

        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        return tasks
            .filter { $0.effectiveStartDate >= today && $0.effectiveStartDate < tomorrow }
            .filter { !$0.isCompleted }
            .prefix(10)
            .map { TaskEntity(from: $0) }
    }
}
