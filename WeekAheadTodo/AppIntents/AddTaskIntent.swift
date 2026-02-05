import Foundation
import AppIntents

/// 태스크 추가 Intent
struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "태스크 추가"
    static var description = IntentDescription("새로운 태스크를 추가합니다")

    @Parameter(title: "제목")
    var title: String

    @Parameter(title: "마감일", default: Date())
    var dueDate: Date

    @Parameter(title: "예상 시간 (분)", default: 60)
    var estimatedMinutes: Int

    @Parameter(title: "우선순위", default: .normal)
    var priority: TaskPriorityOption

    static var parameterSummary: some ParameterSummary {
        Summary("'\(\.$title)'을(를) \(\.$dueDate)까지 추가") {
            \.$estimatedMinutes
            \.$priority
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        print("📱 [AddTaskIntent] 태스크 추가 시작")
        print("   제목: \(title)")
        print("   마감일: \(dueDate)")
        print("   예상 시간: \(estimatedMinutes)분")

        // UserDefaults에서 기존 태스크 로드
        var tasks: [Task] = []
        if let data = UserDefaults.standard.data(forKey: "SavedTasks"),
           let loadedTasks = try? JSONDecoder().decode([Task].self, from: data) {
            tasks = loadedTasks
        }

        // 새 태스크 생성
        let task = Task(
            title: title,
            description: "Siri로 생성됨",
            dueDate: dueDate,
            estimatedMinutes: estimatedMinutes,
            leadTimeDays: 0,
            taskType: .preparable,
            taskRole: .none,
            status: .notStarted,
            priority: priority.toTaskPriority()
        )

        tasks.append(task)

        // UserDefaults에 저장
        if let encoded = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encoded, forKey: "SavedTasks")
            print("✅ [AddTaskIntent] 태스크 저장 완료")
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        dateFormatter.locale = Locale(identifier: "ko_KR")

        return .result(
            dialog: IntentDialog("'\(title)'을(를) \(dateFormatter.string(from: dueDate))까지 추가했습니다")
        )
    }
}

/// 우선순위 옵션 (App Intents용)
enum TaskPriorityOption: String, AppEnum {
    case low = "낮음"
    case normal = "보통"
    case high = "높음"
    case urgent = "긴급"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "우선순위")

    static var caseDisplayRepresentations: [TaskPriorityOption: DisplayRepresentation] {
        [
            .low: "낮음",
            .normal: "보통",
            .high: "높음",
            .urgent: "긴급"
        ]
    }

    func toTaskPriority() -> TaskPriority {
        switch self {
        case .low: return .low
        case .normal: return .normal
        case .high: return .high
        case .urgent: return .urgent
        }
    }
}
