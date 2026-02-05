import Foundation
import AppIntents

/// 태스크 목록 조회 Intent
struct ListTasksIntent: AppIntent {
    static var title: LocalizedStringResource = "오늘 할 일 확인"
    static var description = IntentDescription("오늘 할 일 목록을 확인합니다")

    @Parameter(title: "완료된 태스크 포함", default: false)
    var includeCompleted: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("오늘 할 일 확인") {
            \.$includeCompleted
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<[TaskEntity]> & ProvidesDialog {
        print("📱 [ListTasksIntent] 태스크 조회 시작")

        // UserDefaults에서 태스크 로드
        guard let data = UserDefaults.standard.data(forKey: "SavedTasks"),
              let tasks = try? JSONDecoder().decode([Task].self, from: data) else {
            return .result(value: [], dialog: "저장된 태스크가 없습니다")
        }

        // 오늘 할 일 필터링
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        let todayTasks = tasks.filter { task in
            let effectiveStart = task.effectiveStartDate
            let isToday = effectiveStart >= today && effectiveStart < tomorrow

            if includeCompleted {
                return isToday
            } else {
                return isToday && !task.isCompleted
            }
        }

        let taskEntities = todayTasks.map { TaskEntity(from: $0) }

        print("✅ [ListTasksIntent] \(taskEntities.count)개 태스크 조회 완료")

        let message: String
        if taskEntities.isEmpty {
            message = includeCompleted ? "오늘 할 일이 없습니다" : "오늘 남은 할 일이 없습니다"
        } else {
            message = includeCompleted
                ? "오늘 할 일이 \(taskEntities.count)개 있습니다"
                : "오늘 남은 할 일이 \(taskEntities.count)개 있습니다"
        }

        return .result(value: taskEntities, dialog: IntentDialog(message))
    }
}
