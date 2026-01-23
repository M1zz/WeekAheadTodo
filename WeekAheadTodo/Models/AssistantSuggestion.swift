import Foundation

/// 선제적 제안 유형
enum SuggestionType: String, Codable {
    case meetingPreparationMissing = "회의 준비 누락"
    case capacityOverload = "용량 초과"
    case followUpNeeded = "후속 조치 필요"
    case deadlineRisk = "마감 위험"
    case idleTime = "여유 시간"
}

/// 제안 우선순위
enum SuggestionPriority: Int, Codable {
    case low = 0
    case medium = 1
    case high = 2
    case urgent = 3

    var color: String {
        switch self {
        case .low: return "gray"
        case .medium: return "blue"
        case .high: return "orange"
        case .urgent: return "red"
        }
    }

    var icon: String {
        switch self {
        case .low: return "info.circle"
        case .medium: return "exclamationmark.circle"
        case .high: return "exclamationmark.triangle"
        case .urgent: return "exclamationmark.octagon"
        }
    }
}

/// 제안 액션
struct SuggestionAction: Identifiable, Codable {
    let id: UUID
    let title: String
    let actionType: ActionType

    enum ActionType: String, Codable {
        case addTask = "태스크 추가"
        case viewTasks = "태스크 보기"
        case reschedule = "재배치"
        case dismiss = "무시"
    }

    init(id: UUID = UUID(), title: String, actionType: ActionType) {
        self.id = id
        self.title = title
        self.actionType = actionType
    }
}

/// 선제적 제안 모델
struct AssistantSuggestion: Identifiable, Codable {
    let id: UUID
    let type: SuggestionType
    let title: String
    let message: String
    let priority: SuggestionPriority
    let relatedTaskIds: [UUID]
    let actionButtons: [SuggestionAction]
    let dismissible: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        type: SuggestionType,
        title: String,
        message: String,
        priority: SuggestionPriority,
        relatedTaskIds: [UUID] = [],
        actionButtons: [SuggestionAction] = [],
        dismissible: Bool = true
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
        self.priority = priority
        self.relatedTaskIds = relatedTaskIds
        self.actionButtons = actionButtons
        self.dismissible = dismissible
        self.createdAt = Date()
    }

    /// 제안의 고유 키 (같은 유형의 제안은 하나만 표시)
    var uniqueKey: String {
        "\(type.rawValue)-\(relatedTaskIds.sorted().map { $0.uuidString }.joined(separator: "-"))"
    }
}
