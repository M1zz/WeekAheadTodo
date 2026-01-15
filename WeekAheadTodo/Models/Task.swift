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

/// 태스크 역할 - 메인 실행 태스크 vs 준비 태스크
enum TaskRole: String, CaseIterable, Codable {
    case main = "메인"           // 실제 실행해야 하는 일 (회의, 발표, 마감)
    case preparation = "준비"    // 메인 태스크를 위한 준비

    var icon: String {
        switch self {
        case .main: return "star.fill"
        case .preparation: return "arrow.right.circle"
        }
    }

    var color: String {
        switch self {
        case .main: return "blue"
        case .preparation: return "orange"
        }
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

/// 메인 태스크 모델
struct Task: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var dueDate: Date                    // 최종 마감일
    var estimatedMinutes: Int            // 예상 소요 시간 (분)
    var leadTimeDays: Int                // 선행 소요 일수 (역산용)
    var taskType: TaskType
    var taskRole: TaskRole               // 메인 vs 준비
    var status: TaskStatus               // 진행 상태
    var parentTaskId: UUID?              // 상위 태스크 (서브태스크 지원)
    var mainTaskId: UUID?                // 준비 태스크의 경우, 어떤 메인 태스크를 위한 것인지
    var targetDate: Date?                // 준비 태스크의 경우, 메인 태스크의 실제 날짜
    var createdAt: Date

    // 캘린더 연동 관련
    var calendarEventId: String?         // 원본 EKEvent ID
    var isFromCalendarPattern: Bool = false  // 캘린더 패턴에서 생성되었는지
    var patternId: UUID?                 // 어느 패턴에서 생성되었는지
    var autoRecurring: Bool = false      // 자동 반복 생성 여부
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        dueDate: Date,
        estimatedMinutes: Int = 30,
        leadTimeDays: Int = 0,
        taskType: TaskType = .preparable,
        taskRole: TaskRole = .main,
        status: TaskStatus = .notStarted,
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
        self.parentTaskId = parentTaskId
        self.mainTaskId = mainTaskId
        self.targetDate = targetDate
        self.createdAt = Date()
    }
    
    // MARK: - 선행 작업 역산 로직
    
    /// 실제로 시작해야 하는 날짜 (마감일 - 선행 소요 일수)
    var effectiveStartDate: Date {
        Calendar.current.date(byAdding: .day, value: -leadTimeDays, to: dueDate) ?? dueDate
    }
    
    /// 현재 시간 지평선 계산
    var currentHorizon: TimeHorizon {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
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

    /// 메인 태스크인지 확인
    var isMain: Bool {
        taskRole == .main
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

    // MARK: - 상태 관련

    /// 완료 여부 (backward compatibility)
    var isCompleted: Bool {
        status == .completed
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
