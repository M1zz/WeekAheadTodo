import Foundation

/// 태스크의 시간 지평선 - 언제 처리해야 하는지
enum TimeHorizon: String, CaseIterable, Codable {
    case today = "오늘"
    case thisWeek = "이번 주"
    case nextWeek = "다음 주"
    case later = "나중에"
    
    var sortOrder: Int {
        switch self {
        case .today: return 0
        case .thisWeek: return 1
        case .nextWeek: return 2
        case .later: return 3
        }
    }
}

/// 태스크 유형 - 미리 할 수 있는지 여부 결정
enum TaskType: String, CaseIterable, Codable {
    case preparable = "미리 가능"      // 회의 아젠다, 자료 준비 등
    case dateSpecific = "당일만 가능"  // 실제 회의 참석, 발표 등

    var icon: String {
        switch self {
        case .preparable: return "clock.arrow.circlepath"
        case .dateSpecific: return "calendar.badge.clock"
        }
    }
}

/// 태스크 역할 - 태스크의 성격과 역할 구분
enum TaskRole: String, CaseIterable {
    case none = ""               // 역할 없음 (기본값)
    case preparation = "준비"    // 메인 태스크를 위한 준비
    case followUp = "후속"       // 회의나 이벤트 이후 후속 조치
    case review = "검토"         // 검토, 피드백, 승인이 필요한 일
    case learning = "학습"       // 학습, 연구, 조사가 필요한 일
    case idea = "아이디어"       // 브레인스토밍, 기획, 고민이 필요한 일

    var icon: String {
        switch self {
        case .none: return ""
        case .preparation: return "arrow.right.circle"
        case .followUp: return "arrow.turn.down.right"
        case .review: return "checkmark.circle.fill"
        case .learning: return "book.fill"
        case .idea: return "lightbulb.fill"
        }
    }

    var color: String {
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
    init(from decoder: Decoder) throws {
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

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

/// 태스크 상태 - 진행 상태
enum TaskStatus: String, CaseIterable, Codable {
    case notStarted = "시작 안함"
    case inProgress = "진행 중"
    case completed = "완료"

    var icon: String {
        switch self {
        case .notStarted: return "circle"
        case .inProgress: return "circle.lefthalf.filled"
        case .completed: return "checkmark.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .notStarted: return "gray"
        case .inProgress: return "blue"
        case .completed: return "green"
        }
    }
}

/// 태스크 우선순위
enum TaskPriority: String, CaseIterable, Codable {
    case low = "낮음"
    case normal = "보통"
    case high = "높음"
    case urgent = "긴급"

    var icon: String {
        switch self {
        case .low: return "arrow.down"
        case .normal: return "equal"
        case .high: return "arrow.up"
        case .urgent: return "exclamationmark.2"
        }
    }

    var color: String {
        switch self {
        case .low: return "gray"
        case .normal: return "blue"
        case .high: return "orange"
        case .urgent: return "red"
        }
    }
}

/// 체크인 응답 타입
enum CheckinResponse: String, CaseIterable, Codable {
    case onTrack = "순조로움"       // 잘 진행 중
    case completed = "완료"         // 태스크 완료
    case needHelp = "문제 있음"     // 도움 필요/지연
    case postponed = "연기함"       // 나중에 처리

    var icon: String {
        switch self {
        case .onTrack: return "checkmark.circle"
        case .completed: return "checkmark.circle.fill"
        case .needHelp: return "exclamationmark.triangle"
        case .postponed: return "arrow.clockwise"
        }
    }

    var color: String {
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
struct Subtask: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var createdAt: Date

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = Date()
    }
}

/// 메인 태스크 모델
struct Task: Identifiable {
    let id: UUID
    var title: String
    var description: String
    var dueDate: Date                    // 최종 마감일
    var scheduledStartTime: Date?        // 캘린더 배치 시작 시간 (nil이면 dueDate - estimatedMinutes로 계산)
    var estimatedMinutes: Int            // 예상 소요 시간 (분)
    var leadTimeDays: Int                // 선행 소요 일수 (역산용)
    var taskType: TaskType
    var taskRole: TaskRole               // 메인 vs 준비
    var status: TaskStatus               // 진행 상태
    var priority: TaskPriority           // 우선순위
    var projectId: UUID?                 // 프로젝트 ID
    var parentTaskId: UUID?              // 상위 태스크 (서브태스크 지원)
    var mainTaskId: UUID?                // 준비 태스크의 경우, 어떤 메인 태스크를 위한 것인지
    var targetDate: Date?                // 준비 태스크의 경우, 메인 태스크의 실제 날짜
    var createdAt: Date
    var manualPriority: Int?             // 수동 우선순위 (nil = 자동 계산)

    // 캘린더 연동 관련
    var calendarEventId: String?         // 원본 EKEvent ID
    var isFromCalendarPattern: Bool = false  // 캘린더 패턴에서 생성되었는지
    var patternId: UUID?                 // 어느 패턴에서 생성되었는지
    var autoRecurring: Bool = false      // 자동 반복 생성 여부

    // 체크인 관련
    var lastCheckinDate: Date?           // 마지막 체크인 시간
    var consecutiveMissedCheckins: Int = 0  // 연속 미체크인 횟수

    // 완료 관련
    var completedAt: Date?               // 완료된 시간

    // 하위 할 일
    var subtasks: [Subtask] = []

    init(
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
    }
    
    // MARK: - 시간 계산

    /// 캘린더 배치 실제 시작 시간 (scheduledStartTime이 있으면 사용, 없으면 dueDate - estimatedMinutes)
    var actualStartTime: Date {
        if let scheduled = scheduledStartTime {
            return scheduled
        }
        return Calendar.current.date(byAdding: .minute, value: -estimatedMinutes, to: dueDate) ?? dueDate
    }

    /// 캘린더 배치 실제 종료 시간 (scheduledStartTime 기준)
    var actualEndTime: Date {
        if let scheduled = scheduledStartTime {
            return Calendar.current.date(byAdding: .minute, value: estimatedMinutes, to: scheduled) ?? scheduled
        }
        return dueDate
    }

    // MARK: - 선행 작업 역산 로직

    /// 실제로 시작해야 하는 날짜 (마감일 - 선행 소요 일수)
    var effectiveStartDate: Date {
        Calendar.current.date(byAdding: .day, value: -leadTimeDays, to: dueDate) ?? dueDate
    }
    
    /// 현재 시간 지평선 계산
    var currentHorizon: TimeHorizon {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let startDate = calendar.startOfDay(for: effectiveStartDate)

        let daysUntilStart = calendar.dateComponents([.day], from: today, to: startDate).day ?? 0

        // 로깅
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        dateFormatter.locale = Locale(identifier: "ko_KR")


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
    var daysUntilDue: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let due = calendar.startOfDay(for: dueDate)
        return calendar.dateComponents([.day], from: today, to: due).day ?? 0
    }
    
    /// 시작까지 남은 일수 (역산 기준)
    var daysUntilStart: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: effectiveStartDate)
        return calendar.dateComponents([.day], from: today, to: start).day ?? 0
    }
    
    /// 긴급도 점수 (낮을수록 긴급)
    var urgencyScore: Double {
        let daysLeft = Double(daysUntilStart)
        let effort = Double(estimatedMinutes) / 60.0  // 시간 단위

        // 남은 일수가 적고 소요 시간이 길수록 긴급
        if daysLeft <= 0 {
            return -100 + effort  // 이미 늦음
        }
        return daysLeft - (effort * 0.5)
    }

    /// 정렬 순서 (수동 우선순위 > 자동 긴급도)
    var sortOrder: Int {
        if let manual = manualPriority {
            return manual
        }
        return Int(urgencyScore * 100)
    }

    /// 예상 소요 시간을 읽기 좋은 형식으로
    var estimatedTimeFormatted: String {
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
    var dueDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: dueDate)
    }

    /// 마감일을 요일 포함 형식으로 (M/d (요일))
    var dueDateWithWeekday: String {
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
    var dDayText: String {
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
    var dDayWithDate: String {
        return "\(dDayText) (\(dueDateWithWeekday))"
    }

    /// 타겟 날짜를 간단한 날짜 형식으로 (M/d)
    var targetDateFormatted: String? {
        guard let target = targetDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: target)
    }

    // MARK: - 준비 태스크 관련

    /// 준비 태스크인지 확인
    var isPreparation: Bool {
        taskRole == .preparation
    }

    /// 타겟 날짜까지 남은 일수 (준비 태스크의 경우)
    var daysUntilTarget: Int? {
        guard let target = targetDate else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let targetDay = calendar.startOfDay(for: target)
        return calendar.dateComponents([.day], from: today, to: targetDay).day
    }

    /// 타겟 날짜까지 남은 일수 텍스트 (준비 태스크 UI용)
    var daysUntilTargetText: String? {
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
    var completedSubtaskCount: Int {
        subtasks.filter { $0.isCompleted }.count
    }

    /// 하위 할 일 진행률 텍스트 (예: "2/5")
    var subtaskProgressText: String? {
        guard !subtasks.isEmpty else { return nil }
        return "\(completedSubtaskCount)/\(subtasks.count)"
    }

    /// 하위 할 일이 모두 완료되었는지
    var allSubtasksCompleted: Bool {
        !subtasks.isEmpty && subtasks.allSatisfy { $0.isCompleted }
    }

    // MARK: - 상태 관련

    /// 완료 여부 (backward compatibility)
    var isCompleted: Bool {
        status == .completed
    }

    /// 오늘 완료되었는지 확인
    var isCompletedToday: Bool {
        guard isCompleted, let completedAt = completedAt else { return false }
        return Calendar.current.isDateInToday(completedAt)
    }

    /// 진행 중인지 확인
    var isInProgress: Bool {
        status == .inProgress
    }

    /// 시작 안했는지 확인
    var isNotStarted: Bool {
        status == .notStarted
    }
}

// MARK: - Task Codable Implementation (하위 호환성)

extension Task: Codable {
    enum CodingKeys: String, CodingKey {
        case id, title, description, dueDate, estimatedMinutes, leadTimeDays
        case taskType, taskRole, status, priority
        case projectId, parentTaskId, mainTaskId, targetDate, createdAt
        case manualPriority
        case calendarEventId, isFromCalendarPattern, patternId, autoRecurring
        case lastCheckinDate, consecutiveMissedCheckins
        case completedAt
        case subtasks
    }

    init(from decoder: Decoder) throws {
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
    }

    func encode(to encoder: Encoder) throws {
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
        try container.encode(autoRecurring, forKey: .autoRecurring)

        // 체크인 필드
        try container.encodeIfPresent(lastCheckinDate, forKey: .lastCheckinDate)
        try container.encode(consecutiveMissedCheckins, forKey: .consecutiveMissedCheckins)

        // 완료 필드
        try container.encodeIfPresent(completedAt, forKey: .completedAt)

        // 하위 할 일
        try container.encode(subtasks, forKey: .subtasks)
    }
}

// MARK: - 선행 작업 템플릿

/// 일반적인 선행 작업 패턴 (회의 준비, 발표 준비 등)
struct TaskTemplate {
    let name: String
    let subtasks: [(title: String, leadTimeDays: Int, estimatedMinutes: Int)]
    
    static let meetingPreparation = TaskTemplate(
        name: "회의 준비",
        subtasks: [
            ("아젠다 초안 작성", 3, 30),
            ("참석자에게 아젠다 공유", 2, 10),
            ("필요 자료 수집", 2, 45),
            ("회의 자료 최종 검토", 1, 20)
        ]
    )
    
    static let presentationPreparation = TaskTemplate(
        name: "발표 준비",
        subtasks: [
            ("발표 구조 기획", 5, 60),
            ("자료 조사 및 수집", 4, 90),
            ("슬라이드 초안 작성", 3, 120),
            ("슬라이드 디자인 정리", 2, 60),
            ("리허설", 1, 30)
        ]
    )
    
    static let reportWriting = TaskTemplate(
        name: "보고서 작성",
        subtasks: [
            ("데이터 수집", 4, 60),
            ("초안 작성", 3, 90),
            ("검토 및 수정", 2, 45),
            ("최종 포맷팅", 1, 30)
        ]
    )
    
    static let allTemplates: [TaskTemplate] = [
        .meetingPreparation,
        .presentationPreparation,
        .reportWriting
    ]
}

// MARK: - Project

/// 프로젝트 모델
struct Project: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var color: String  // hex color
    var icon: String   // SF Symbol name
    var createdAt: Date = Date()

    init(name: String, color: String = "#007AFF", icon: String = "folder.fill") {
        self.name = name
        self.color = color
        self.icon = icon
    }
}
