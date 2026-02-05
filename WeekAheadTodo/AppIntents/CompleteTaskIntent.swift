import Foundation
import AppIntents

/// 태스크 완료 Intent
struct CompleteTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "태스크 완료"
    static var description = IntentDescription("태스크를 완료 처리합니다")

    @Parameter(title: "태스크")
    var task: TaskEntity

    static var parameterSummary: some ParameterSummary {
        Summary("'\(\.$task)'을(를) 완료")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        print("📱 [CompleteTaskIntent] 태스크 완료 처리 시작")
        print("   태스크: \(task.title)")

        // UserDefaults에서 태스크 로드
        guard let data = UserDefaults.standard.data(forKey: "SavedTasks"),
              var tasks = try? JSONDecoder().decode([Task].self, from: data) else {
            return .result(dialog: "태스크를 찾을 수 없습니다")
        }

        // 태스크 찾아서 완료 처리
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else {
            return .result(dialog: "태스크를 찾을 수 없습니다")
        }

        tasks[index].status = .completed
        tasks[index].completedAt = Date()

        // UserDefaults에 저장
        if let encoded = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encoded, forKey: "SavedTasks")
            print("✅ [CompleteTaskIntent] 태스크 완료 처리 완료")
        }

        return .result(dialog: IntentDialog("'\(task.title)'을(를) 완료했습니다"))
    }
}
