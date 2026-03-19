import Foundation

/// 태스크의 시간 지평선 - 언제 처리해야 하는지
public enum TimeHorizon: String, CaseIterable, Codable {
    case today = "오늘"
    case thisWeek = "이번 주"
    case nextWeek = "다음 주"
    case later = "나중에"

    public var sortOrder: Int {
        switch self {
        case .today: return 0
        case .thisWeek: return 1
        case .nextWeek: return 2
        case .later: return 3
        }
    }
}

/// 태스크 유형 - 미리 할 수 있는지 여부 결정
public enum TaskType: String, CaseIterable, Codable {
    case preparable = "미리 가능"      // 회의 아젠다, 자료 준비 등
    case dateSpecific = "당일만 가능"  // 실제 회의 참석, 발표 등

    public var icon: String {
        switch self {
        case .preparable: return "clock.arrow.circlepath"
        case .dateSpecific: return "calendar.badge.clock"
        }
    }
}

/// 태스크 역할 - 태스크의 성격과 역할 구분
public enum TaskRole: String, CaseIterable {
    case none = ""               // 역할 없음 (기본값)
    case preparation = "준비"    // 메인 태스크를 위한 준비
    case followUp = "후속"       // 회의나 이벤트 이후 후속 조치
    case review = "검토"         // 검토, 피드백, 승인이 필요한 일
    case learning = "학습"       // 학습, 연구, 조사가 필요한 일
    case idea = "아이디어"       // 브레인스토밍, 기획, 고민이 필요한 일

    public var icon: String {
        switch self {
        case .none: return ""
        case .preparation: return "arrow.right.circle"
        case .followUp: return "arrow.turn.down.right"
        case .review: return "checkmark.circle.fill"
        case .learning: return "book.fill"
        case .idea: return "lightbulb.fill"
        }
    }

    public var color: String {
        switch self {
        case .none: return "gray"
        case .preparation: return "orange"
        case .followUp: return "green"
        case .review: return "yellow"
        case .learning: return "cyan"
        case .idea: return "pink"
        }
    }
}

// MARK: - TaskRole Migration Support
extension TaskRole: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        // 마이그레이션: "메인", "루틴" → "" (없음)으로 변환
        if rawValue == "메인" || rawValue == "루틴" {
            self = .none
        } else if let role = TaskRole(rawValue: rawValue) {
            self = role
        } else {
            // 알 수 없는 값은 기본값(없음)으로
            self = .none
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

/// 태스크 상태 - 진행 상태
public enum TaskStatus: String, CaseIterable, Codable {
    case notStarted = "시작 안함"
    case inProgress = "진행 중"
    case completed = "완료"

    public var icon: String {
        switch self {
        case .notStarted: return "circle"
        case .inProgress: return "circle.lefthalf.filled"
        case .completed: return "checkmark.circle.fill"
        }
    }

    public var color: String {
        switch self {
        case .notStarted: return "gray"
        case .inProgress: return "blue"
        case .completed: return "green"
        }
    }
}

/// 태스크 우선순위
public enum TaskPriority: String, CaseIterable, Codable {
    case low = "낮음"
    case normal = "보통"
    case high = "높음"
    case urgent = "긴급"

    public var icon: String {
        switch self {
        case .low: return "arrow.down"
        case .normal: return "equal"
        case .high: return "arrow.up"
        case .urgent: return "exclamationmark.2"
        }
    }

    public var color: String {
        switch self {
        case .low: return "gray"
        case .normal: return "blue"
        case .high: return "orange"
        case .urgent: return "red"
        }
    }
}

/// 체크인 응답 타입
public enum CheckinResponse: String, CaseIterable, Codable {
    case onTrack = "순조로움"       // 잘 진행 중
    case completed = "완료"         // 태스크 완료
    case needHelp = "문제 있음"     // 도움 필요/지연
    case postponed = "연기함"       // 나중에 처리

    public var icon: String {
        switch self {
        case .onTrack: return "checkmark.circle"
        case .completed: return "checkmark.circle.fill"
        case .needHelp: return "exclamationmark.triangle"
        case .postponed: return "arrow.clockwise"
        }
    }

    public var color: String {
        switch self {
        case .onTrack: return "green"
        case .completed: return "blue"
        case .needHelp: return "red"
        case .postponed: return "orange"
        }
    }
}

// MARK: - Subtask

/// 태스크의 하위 할 일
public struct Subtask: Identifiable, Codable, Hashable {
    public let id: UUID
    public var title: String
    public var isCompleted: Bool
    public var createdAt: Date
    public var scheduledDate: Date?  // 독립 일정 날짜 (드래그로 설정됨, nil이면 parent의 날짜 사용)

    public init(id: UUID = UUID(), title: String, isCompleted: Bool = false, scheduledDate: Date? = nil) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = Date()
        self.scheduledDate = scheduledDate
    }
}

/// 메인 태스크 모델
public struct Task: Identifiable {
    public let id: UUID
    public var title: String
    public var description: String
    public var dueDate: Date                    // 최종 마감일
    public var scheduledStartTime: Date?        // 캘린더 배치 시작 시간 (nil이면 dueDate - estimatedMinutes로 계산)
    public var estimatedMinutes: Int            // 예상 소요 시간 (분)
    public var leadTimeDays: Int                // 선행 소요 일수 (역산용)
    public var taskType: TaskType
    public var taskRole: TaskRole               // 메인 vs 준비
    public var status: TaskStatus               // 진행 상태
    public var priority: TaskPriority           // 우선순위
    public var projectId: UUID?                 // 프로젝트 ID
    public var parentTaskId: UUID?              // 상위 태스크 (서브태스크 지원)
    public var mainTaskId: UUID?                // 준비 태스크의 경우, 어떤 메인 태스크를 위한 것인지
    public var targetDate: Date?                // 준비 태스크의 경우, 메인 태스크의 실제 날짜
    public var createdAt: Date
    public var manualPriority: Int?             // 수동 우선순위 (nil = 자동 계산)

    // 캘린더 연동 관련
    public var calendarEventId: String?         // 원본 EKEvent ID
    public var isFromCalendarPattern: Bool = false  // 캘린더 패턴에서 생성되었는지
    public var patternId: UUID?                 // 어느 패턴에서 생성되었는지
    public var patternOccurrenceDate: Date?     // 패턴이 이 태스크를 생성한 원래 발생일 (사용자가 dueDate를 변경해도 유지)
    public var autoRecurring: Bool = false      // 자동 반복 생성 여부

    // 체크인 관련
    public var lastCheckinDate: Date?           // 마지막 체크인 시간
    public var consecutiveMissedCheckins: Int = 0  // 연속 미체크인 횟수

    // 완료 관련
    public var completedAt: Date?               // 완료된 시간

    // 수정 시각 (per-task 병합 동기화 기준)
    public var modifiedAt: Date                 // 마지막 수정 시각

    // 하위 할 일
    public var subtasks: [Subtask] = []

    // MIT (Most Important Task)
    public var isMIT: Bool = false

    // 위키 연결
    public var linkedWikiPageIds: [UUID] = []

    public init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        dueDate: Date,
        estimatedMinutes: Int = 30,
        leadTimeDays: Int = 0,
        taskType: TaskType = .preparable,
        taskRole: TaskRole = .none,
        status: TaskStatus = .notStarted,
        priority: TaskPriority = .normal,
        projectId: UUID? = nil,
        parentTaskId: UUID? = nil,
        mainTaskId: UUID? = nil,
        targetDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.dueDate = dueDate
        self.estimatedMinutes = estimatedMinutes
        self.leadTimeDays = leadTimeDays
        self.taskType = taskType
        self.taskRole = taskRole
        self.status = status
        self.priority = priority
        self.projectId = projectId
        self.parentTaskId = parentTaskId
        self.mainTaskId = mainTaskId
        self.targetDate = targetDate
        self.createdAt = Date()
        self.calendarEventId = nil
        self.patternId = nil
        self.modifiedAt = Date()
    }

    // MARK: - 시간 계산

    /// 캘린더 배치 실제 시작 시간 (scheduledStartTime이 있으면 사용, 없으면 dueDate - estimatedMinutes)
    public var actualStartTime: Date {
        if let scheduled = scheduledStartTime {
            return scheduled
        }
        return Calendar.current.date(byAdding: .minute, value: -estimatedMinutes, to: dueDate) ?? dueDate
    }

    /// 캘린더 배치 실제 종료 시간 (scheduledStartTime 기준)
    public var actualEndTime: Date {
        if let scheduled = scheduledStartTime {
            return Calendar.current.date(byAdding: .minute, value: estimatedMinutes, to: scheduled) ?? scheduled
        }
        return dueDate
    }

    // MARK: - 선행 작업 역산 로직

    /// 실제로 시작해야 하는 날짜 (마감일 - 선행 소요 일수)
    public var effectiveStartDate: Date {
        Calendar.current.date(byAdding: .day, value: -leadTimeDays, to: dueDate) ?? dueDate
    }

    /// 현재 시간 지평선 계산
    public var currentHorizon: TimeHorizon {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let startDate = calendar.startOfDay(for: effectiveStartDate)

        let daysUntilStart = calendar.dateComponents([.day], from: today, to: startDate).day ?? 0

        // 이미 시작해야 했거나 오늘 시작해야 함
        if daysUntilStart <= 0 {
            return .today
        }
        // 이번 주 내에 시작해야 함 (7일 이내)
        else if daysUntilStart <= 7 {
            return .thisWeek
        }
        // 다음 주에 시작 (8-14일)
        else if daysUntilStart <= 14 {
            return .nextWeek
        }
        // 그 이후
        else {
            return .later
        }
    }

    /// 마감까지 남은 일수
    public var daysUntilDue: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let due = calendar.startOfDay(for: dueDate)
        return calendar.dateComponents([.day], from: today, to: due).day ?? 0
    }

    /// 시작까지 남은 일수 (역산 기준)
    public var daysUntilStart: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: effectiveStartDate)
        return calendar.dateComponents([.day], from: today, to: start).day ?? 0
    }

    /// 긴급도 점수 (낮을수록 긴급)
    public var urgencyScore: Double {
        let daysLeft = Double(daysUntilStart)
        let effort = Double(estimatedMinutes) / 60.0  // 시간 단위

        // 남은 일수가 적고 소요 시간이 길수록 긴급
        if daysLeft <= 0 {
            return -100 + effort  // 이미 늦음
        }
        return daysLeft - (effort * 0.5)
    }

    /// 정렬 순서 (수동 우선순위 > 자동 긴급도)
    public var sortOrder: Int {
        if let manual = manualPriority {
            return manual
        }
        return Int(urgencyScore * 100)
    }

    /// 예상 소요 시간을 읽기 좋은 형식으로
    public var estimatedTimeFormatted: String {
        let hours = estimatedMinutes / 60
        let minutes = estimatedMinutes % 60

        if hours > 0 && minutes > 0 {
            return "\(hours)시간 \(minutes)분"
        } else if hours > 0 {
            return "\(hours)시간"
        } else {
            return "\(minutes)분"
        }
    }

    /// 마감일을 간단한 날짜 형식으로 (M/d)
    public var dueDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: dueDate)
    }

    /// 마감일을 요일 포함 형식으로 (M/d (요일))
    public var dueDateWithWeekday: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M/d"
        let dateString = dateFormatter.string(from: dueDate)

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = Locale(identifier: "ko_KR")
        weekdayFormatter.dateFormat = "E"
        let weekdayString = weekdayFormatter.string(from: dueDate)

        return "\(dateString) (\(weekdayString))"
    }

    /// D-day 형식 텍스트 (D-3, D-day, D+2 등)
    public var dDayText: String {
        let days = daysUntilDue
        if days > 0 {
            return "D-\(days)"
        } else if days == 0 {
            return "D-day"
        } else {
            return "D+\(abs(days))"
        }
    }

    /// D-day 형식 + 실제 날짜 조합 (D-3 (12/20 (수)))
    public var dDayWithDate: String {
        return "\(dDayText) (\(dueDateWithWeekday))"
    }

    /// 타겟 날짜를 간단한 날짜 형식으로 (M/d)
    public var targetDateFormatted: String? {
        guard let target = targetDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: target)
    }

    // MARK: - 준비 태스크 관련

    /// 준비 태스크인지 확인
    public var isPreparation: Bool {
        taskRole == .preparation
    }

    /// 타겟 날짜까지 남은 일수 (준비 태스크의 경우)
    public var daysUntilTarget: Int? {
        guard let target = targetDate else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let targetDay = calendar.startOfDay(for: target)
        return calendar.dateComponents([.day], from: today, to: targetDay).day
    }

    /// 타겟 날짜까지 남은 일수 텍스트 (준비 태스크 UI용)
    public var daysUntilTargetText: String? {
        guard let days = daysUntilTarget else { return nil }
        if days == 0 {
            return "오늘"
        } else if days == 1 {
            return "내일"
        } else if days > 0 {
            return "\(days)일 뒤"
        } else {
            return "지났음"
        }
    }

    // MARK: - 하위 할 일 관련

    /// 완료된 하위 할 일 수
    public var completedSubtaskCount: Int {
        subtasks.filter { $0.isCompleted }.count
    }

    /// 하위 할 일 진행률 텍스트 (예: "2/5")
    public var subtaskProgressText: String? {
        guard !subtasks.isEmpty else { return nil }
        return "\(completedSubtaskCount)/\(subtasks.count)"
    }

    /// 하위 할 일이 모두 완료되었는지
    public var allSubtasksCompleted: Bool {
        !subtasks.isEmpty && subtasks.allSatisfy { $0.isCompleted }
    }

    // MARK: - 상태 관련

    /// 완료 여부 (backward compatibility)
    public var isCompleted: Bool {
        status == .completed
    }

    /// 오늘 완료되었는지 확인
    public var isCompletedToday: Bool {
        guard isCompleted, let completedAt = completedAt else { return false }
        return Calendar.current.isDateInToday(completedAt)
    }

    /// 진행 중인지 확인
    public var isInProgress: Bool {
        status == .inProgress
    }

    /// 시작 안했는지 확인
    public var isNotStarted: Bool {
        status == .notStarted
    }

    /// 보고 태스크 여부 (자동 생성된 착수/중간/완료 보고 태스크)
    public var isReportTask: Bool {
        taskRole == .followUp && parentTaskId != nil &&
        (title.hasPrefix("✉️") || title.hasPrefix("📊") || title.hasPrefix("✅"))
    }

    /// 미시작 상태로 effectiveStartDate가 지난 일수. 2일 미만이면 nil
    public var staleDays: Int? {
        guard isNotStarted else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: effectiveStartDate)
        let days = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        return days >= 2 ? days : nil
    }
}

// MARK: - Task Codable Implementation (하위 호환성)

extension Task: Codable {
    public enum CodingKeys: String, CodingKey {
        case id, title, description, dueDate, estimatedMinutes, leadTimeDays
        case taskType, taskRole, status, priority
        case projectId, parentTaskId, mainTaskId, targetDate, createdAt
        case manualPriority
        case calendarEventId, isFromCalendarPattern, patternId, patternOccurrenceDate, autoRecurring
        case lastCheckinDate, consecutiveMissedCheckins
        case completedAt
        case subtasks
        case isMIT
        case linkedWikiPageIds
        case modifiedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // 필수 필드
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        dueDate = try container.decode(Date.self, forKey: .dueDate)
        estimatedMinutes = try container.decode(Int.self, forKey: .estimatedMinutes)
        leadTimeDays = try container.decode(Int.self, forKey: .leadTimeDays)
        taskType = try container.decode(TaskType.self, forKey: .taskType)
        taskRole = try container.decode(TaskRole.self, forKey: .taskRole)
        status = try container.decode(TaskStatus.self, forKey: .status)
        priority = try container.decode(TaskPriority.self, forKey: .priority)
        createdAt = try container.decode(Date.self, forKey: .createdAt)

        // 옵셔널 필드 (없으면 nil)
        projectId = try container.decodeIfPresent(UUID.self, forKey: .projectId)
        parentTaskId = try container.decodeIfPresent(UUID.self, forKey: .parentTaskId)
        mainTaskId = try container.decodeIfPresent(UUID.self, forKey: .mainTaskId)
        targetDate = try container.decodeIfPresent(Date.self, forKey: .targetDate)
        manualPriority = try container.decodeIfPresent(Int.self, forKey: .manualPriority)
        calendarEventId = try container.decodeIfPresent(String.self, forKey: .calendarEventId)
        patternId = try container.decodeIfPresent(UUID.self, forKey: .patternId)
        patternOccurrenceDate = try container.decodeIfPresent(Date.self, forKey: .patternOccurrenceDate)

        // Bool 필드 (없으면 기본값 false)
        isFromCalendarPattern = try container.decodeIfPresent(Bool.self, forKey: .isFromCalendarPattern) ?? false
        autoRecurring = try container.decodeIfPresent(Bool.self, forKey: .autoRecurring) ?? false

        // 체크인 필드 (없으면 기본값)
        lastCheckinDate = try container.decodeIfPresent(Date.self, forKey: .lastCheckinDate)
        consecutiveMissedCheckins = try container.decodeIfPresent(Int.self, forKey: .consecutiveMissedCheckins) ?? 0

        // 완료 필드
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)

        // 하위 할 일 (기존 데이터 호환: 없으면 빈 배열)
        subtasks = try container.decodeIfPresent([Subtask].self, forKey: .subtasks) ?? []

        // MIT (없으면 기본값 false)
        isMIT = try container.decodeIfPresent(Bool.self, forKey: .isMIT) ?? false

        // 위키 연결 (없으면 빈 배열)
        linkedWikiPageIds = try container.decodeIfPresent([UUID].self, forKey: .linkedWikiPageIds) ?? []

        // 수정 시각 (없으면 createdAt으로 fallback - 기존 데이터 호환)
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? createdAt
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(dueDate, forKey: .dueDate)
        try container.encode(estimatedMinutes, forKey: .estimatedMinutes)
        try container.encode(leadTimeDays, forKey: .leadTimeDays)
        try container.encode(taskType, forKey: .taskType)
        try container.encode(taskRole, forKey: .taskRole)
        try container.encode(status, forKey: .status)
        try container.encode(priority, forKey: .priority)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(projectId, forKey: .projectId)
        try container.encodeIfPresent(parentTaskId, forKey: .parentTaskId)
        try container.encodeIfPresent(mainTaskId, forKey: .mainTaskId)
        try container.encodeIfPresent(targetDate, forKey: .targetDate)
        try container.encodeIfPresent(manualPriority, forKey: .manualPriority)
        try container.encodeIfPresent(calendarEventId, forKey: .calendarEventId)
        try container.encode(isFromCalendarPattern, forKey: .isFromCalendarPattern)
        try container.encodeIfPresent(patternId, forKey: .patternId)
        try container.encodeIfPresent(patternOccurrenceDate, forKey: .patternOccurrenceDate)
        try container.encode(autoRecurring, forKey: .autoRecurring)

        // 체크인 필드
        try container.encodeIfPresent(lastCheckinDate, forKey: .lastCheckinDate)
        try container.encode(consecutiveMissedCheckins, forKey: .consecutiveMissedCheckins)

        // 완료 필드
        try container.encodeIfPresent(completedAt, forKey: .completedAt)

        // 하위 할 일
        try container.encode(subtasks, forKey: .subtasks)

        // MIT
        try container.encode(isMIT, forKey: .isMIT)

        // 위키 연결
        try container.encode(linkedWikiPageIds, forKey: .linkedWikiPageIds)

        // 수정 시각
        try container.encode(modifiedAt, forKey: .modifiedAt)
    }
}

// MARK: - 선행 작업 템플릿

/// 일반적인 선행 작업 패턴 (회의 준비, 발표 준비 등)
public struct TaskTemplate: Sendable {
    public let name: String
    public let subtasks: [(title: String, leadTimeDays: Int, estimatedMinutes: Int)]

    public static let meetingPreparation = TaskTemplate(
        name: "회의 준비",
        subtasks: [
            ("아젠다 초안 작성", 3, 30),
            ("참석자에게 아젠다 공유", 2, 10),
            ("필요 자료 수집", 2, 45),
            ("회의 자료 최종 검토", 1, 20)
        ]
    )

    public static let presentationPreparation = TaskTemplate(
        name: "발표 준비",
        subtasks: [
            ("발표 구조 기획", 5, 60),
            ("자료 조사 및 수집", 4, 90),
            ("슬라이드 초안 작성", 3, 120),
            ("슬라이드 디자인 정리", 2, 60),
            ("리허설", 1, 30)
        ]
    )

    public static let reportWriting = TaskTemplate(
        name: "보고서 작성",
        subtasks: [
            ("데이터 수집", 4, 60),
            ("초안 작성", 3, 90),
            ("검토 및 수정", 2, 45),
            ("최종 포맷팅", 1, 30)
        ]
    )

    public static let allTemplates: [TaskTemplate] = [
        .meetingPreparation,
        .presentationPreparation,
        .reportWriting
    ]
}

// MARK: - Project

/// 프로젝트 모델
public struct Project: Identifiable, Codable, Hashable {
    public var id: UUID = UUID()
    public var name: String
    public var color: String  // hex color
    public var icon: String   // SF Symbol name
    public var createdAt: Date = Date()

    public init(name: String, color: String = "#007AFF", icon: String = "folder.fill") {
        self.name = name
        self.color = color
        self.icon = icon
    }
}
