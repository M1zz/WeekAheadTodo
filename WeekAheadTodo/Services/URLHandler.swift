import Foundation
import SwiftUI

/// URL Scheme 핸들러
@MainActor
class URLHandler {

    /// URL Scheme 처리
    /// 지원 형식:
    /// - weekaheadtodo://addTask?title=회의&dueDate=2024-01-01T14:00:00Z&minutes=60
    /// - weekaheadtodo://openSection?section=today
    /// - weekaheadtodo://completeTask?id=UUID
    static func handle(url: URL, taskViewModel: TaskViewModel) -> Bool {

        guard url.scheme == "weekaheadtodo" else {
            return false
        }

        let host = url.host ?? ""
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        switch host {
        case "addTask":
            return handleAddTask(queryItems: queryItems, taskViewModel: taskViewModel)

        case "completeTask":
            return handleCompleteTask(queryItems: queryItems, taskViewModel: taskViewModel)

        case "openSection":
            return handleOpenSection(queryItems: queryItems)

        default:
            return false
        }
    }

    // MARK: - Add Task

    private static func handleAddTask(queryItems: [URLQueryItem], taskViewModel: TaskViewModel) -> Bool {

        // 필수 파라미터: title
        guard let title = queryItems.first(where: { $0.name == "title" })?.value, !title.isEmpty else {
            return false
        }

        // 선택 파라미터
        let dueDateString = queryItems.first(where: { $0.name == "dueDate" })?.value
        let minutesString = queryItems.first(where: { $0.name == "minutes" })?.value
        let description = queryItems.first(where: { $0.name == "description" })?.value ?? ""
        let priorityString = queryItems.first(where: { $0.name == "priority" })?.value

        // 날짜 파싱 (ISO8601 또는 상대적 날짜)
        let dueDate: Date
        if let dueDateString = dueDateString {
            if let parsedDate = ISO8601DateFormatter().date(from: dueDateString) {
                dueDate = parsedDate
            } else if let relativeDays = parseRelativeDate(dueDateString) {
                dueDate = Calendar.current.date(byAdding: .day, value: relativeDays, to: Date()) ?? Date()
            } else {
                dueDate = Date()
            }
        } else {
            dueDate = Date()
        }

        // 시간 파싱
        let estimatedMinutes = Int(minutesString ?? "60") ?? 60

        // 우선순위 파싱
        let priority: TaskPriority
        if let priorityString = priorityString {
            priority = TaskPriority(rawValue: priorityString) ?? .normal
        } else {
            priority = .normal
        }

        // 태스크 생성
        let task = Task(
            title: title,
            description: description,
            dueDate: dueDate,
            estimatedMinutes: estimatedMinutes,
            leadTimeDays: 0,
            taskType: .preparable,
            taskRole: .none,
            status: .notStarted,
            priority: priority
        )

        taskViewModel.addTask(task)

        return true
    }

    // MARK: - Complete Task

    private static func handleCompleteTask(queryItems: [URLQueryItem], taskViewModel: TaskViewModel) -> Bool {

        guard let idString = queryItems.first(where: { $0.name == "id" })?.value,
              let taskId = UUID(uuidString: idString) else {
            return false
        }

        guard let task = taskViewModel.tasks.first(where: { $0.id == taskId }) else {
            return false
        }

        taskViewModel.toggleTaskCompletion(task)

        return true
    }

    // MARK: - Open Section

    private static func handleOpenSection(queryItems: [URLQueryItem]) -> Bool {

        guard let section = queryItems.first(where: { $0.name == "section" })?.value else {
            return false
        }

        // AppStorage에 저장하여 ContentView가 자동으로 반영
        UserDefaults.standard.set(section, forKey: "selectedSection")

        return true
    }

    // MARK: - Helper

    /// 상대적 날짜 파싱 ("today", "tomorrow", "+3days")
    private static func parseRelativeDate(_ string: String) -> Int? {
        switch string.lowercased() {
        case "today", "오늘":
            return 0
        case "tomorrow", "내일":
            return 1
        case "다음주", "nextweek":
            return 7
        default:
            // "+3days" 형식
            if string.hasPrefix("+") {
                let numberString = string.dropFirst().replacingOccurrences(of: "days", with: "").trimmingCharacters(in: .whitespaces)
                return Int(numberString)
            }
            return nil
        }
    }
}
