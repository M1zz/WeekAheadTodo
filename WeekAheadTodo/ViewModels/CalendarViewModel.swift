import Foundation
import EventKit

/// 캘린더 연동 및 패턴 감지 관리 ViewModel
@MainActor
class CalendarViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var isEnabled: Bool = false
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var isAnalyzing: Bool = false
    @Published var detectedPatterns: [RecurrencePattern] = []
    @Published var selectedPatterns: Set<UUID> = []
    @Published var hasNewPatterns: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var statusMessage: String?

    // 캘린더 선택
    @Published var availableCalendars: [EKCalendar] = []
    @Published var selectedCalendarIds: Set<String> = []

    // 캘린더 전체 가져오기
    @Published var importCalendarIds: Set<String> = []  // 전체 가져오기할 캘린더 ID들
    @Published var isImporting: Bool = false
    @Published var importWeeksAhead: Int = 4  // 향후 몇 주간의 이벤트를 가져올지

    // MARK: - Services

    let calendarService: CalendarService  // public for time block calculation
    private let patternService: PatternDetectionService
    private var patternManagementService: PatternManagementService?

    // MARK: - Initialization

    init() {
        self.calendarService = CalendarService()
        self.patternService = PatternDetectionService()
        updateAuthorizationStatus()
    }

    // MARK: - Service Injection

    /// Set pattern management service (called from ContentView)
    func setPatternManagementService(_ service: PatternManagementService) {
        self.patternManagementService = service
    }

    // MARK: - Authorization

    /// 권한 상태 업데이트
    func updateAuthorizationStatus() {
        authorizationStatus = calendarService.authorizationStatus
    }

    /// 캘린더 연동 활성화
    func enableIntegration() async {

        // 먼저 권한 상태 업데이트
        updateAuthorizationStatus()

        errorMessage = nil
        successMessage = nil
        statusMessage = "권한 확인 중..."
        var granted = false

        // 권한 상태에 따른 처리
        switch authorizationStatus {
        case .authorized, .fullAccess:
            // 이미 권한이 있는 경우 - 바로 진행
            statusMessage = "캘린더 목록 로딩 중..."
            granted = true

        case .denied, .restricted:
            // 권한 거부됨
            statusMessage = nil
            errorMessage = "캘린더 접근이 거부되었습니다. 아래 안내를 따라 시스템 설정에서 권한을 허용해주세요."
            return

        case .notDetermined:
            // 권한 요청 필요
            statusMessage = "권한 요청 중..."
            granted = await calendarService.requestAccess()
            updateAuthorizationStatus()

        case .writeOnly:
            statusMessage = nil
            errorMessage = "읽기 권한이 필요합니다."
            return

        @unknown default:
            statusMessage = nil
            errorMessage = "권한 상태를 확인할 수 없습니다."
            return
        }

        if granted {
            isEnabled = true

            // 사용 가능한 캘린더 목록 가져오기
            statusMessage = "캘린더 목록 로딩 중..."
            loadAvailableCalendars()

            statusMessage = "지난 3개월 일정 분석 중..."
            await analyzeCalendar()

            // 분석 완료 메시지
            statusMessage = nil
            if detectedPatterns.isEmpty {
                successMessage = "✅ 분석 완료! 반복 패턴이 감지되지 않았습니다."
            } else {
                successMessage = "✅ 분석 완료! \(detectedPatterns.count)개 패턴이 감지되었습니다."
            }
        } else {
            statusMessage = nil
            errorMessage = "캘린더 권한이 거부되었습니다. 아래 안내를 따라 시스템 설정에서 권한을 허용해주세요."
        }
    }

    // MARK: - Calendar Selection

    /// 사용 가능한 캘린더 목록 로드
    func loadAvailableCalendars() {
        availableCalendars = calendarService.getAvailableCalendars()
        // 기본값: 모든 캘린더 선택
        if selectedCalendarIds.isEmpty {
            selectedCalendarIds = Set(availableCalendars.map { $0.calendarIdentifier })
        }
    }

    /// 캘린더 선택/해제
    func toggleCalendarSelection(_ calendarId: String) {
        if selectedCalendarIds.contains(calendarId) {
            selectedCalendarIds.remove(calendarId)
        } else {
            selectedCalendarIds.insert(calendarId)
        }
    }

    /// 모든 캘린더 선택
    func selectAllCalendars() {
        selectedCalendarIds = Set(availableCalendars.map { $0.calendarIdentifier })
    }

    /// 모든 캘린더 선택 해제
    func deselectAllCalendars() {
        selectedCalendarIds = []
    }

    // MARK: - Pattern Analysis

    /// 캘린더 분석 시작
    func analyzeCalendar() async {

        guard calendarService.isAuthorized else {
            errorMessage = "캘린더 접근 권한이 필요합니다."
            return
        }

        isAnalyzing = true
        errorMessage = nil

        // 백그라운드에서 분석 수행
        let ekEvents = calendarService.fetchRecentEvents(calendarIdentifiers: selectedCalendarIds.isEmpty ? nil : selectedCalendarIds)

        if ekEvents.isEmpty {
        } else {
            for (index, event) in ekEvents.prefix(5).enumerated() {
            }
        }

        let calendarEvents = ekEvents.map { CalendarEvent(from: $0) }

        let patterns = patternService.analyzePatterns(events: calendarEvents)

        if !patterns.isEmpty {
            for (index, pattern) in patterns.enumerated() {
            }
        } else {
        }

        await MainActor.run {
            self.detectedPatterns = patterns
            self.hasNewPatterns = !patterns.isEmpty
            self.isAnalyzing = false

        }
    }

    /// 재분석
    func reanalyze() async {
        detectedPatterns = []
        selectedPatterns = []
        hasNewPatterns = false

        await analyzeCalendar()
    }

    // MARK: - Pattern Management

    /// 패턴 선택/해제
    func togglePatternSelection(_ patternId: UUID) {
        if selectedPatterns.contains(patternId) {
            selectedPatterns.remove(patternId)
        } else {
            selectedPatterns.insert(patternId)
        }
    }

    /// 패턴 선택
    func selectPattern(_ patternId: UUID) {
        selectedPatterns.insert(patternId)
    }

    /// 패턴 선택 해제
    func deselectPattern(_ patternId: UUID) {
        selectedPatterns.remove(patternId)
    }

    /// 모든 패턴 선택
    func selectAllPatterns() {
        selectedPatterns = Set(detectedPatterns.map { $0.id })
    }

    /// 모든 패턴 선택 해제
    func deselectAllPatterns() {
        selectedPatterns = []
    }

    /// 선택된 패턴 목록
    var selectedPatternsList: [RecurrencePattern] {
        detectedPatterns.filter { selectedPatterns.contains($0.id) }
    }

    /// 패턴 제거 (무시)
    func ignorePattern(_ patternId: UUID) {
        detectedPatterns.removeAll { $0.id == patternId }
        selectedPatterns.remove(patternId)

        if detectedPatterns.isEmpty {
            hasNewPatterns = false
        }
    }

    /// 모든 패턴 무시
    func ignoreAllPatterns() {
        detectedPatterns = []
        selectedPatterns = []
        hasNewPatterns = false
    }

    /// 패턴 업데이트 (사용자가 제안 수정 시)
    func updatePattern(_ patternId: UUID, suggestedTask: SuggestedTask) {
        if let index = detectedPatterns.firstIndex(where: { $0.id == patternId }) {
            var updatedPattern = detectedPatterns[index]
            var modifiedTask = suggestedTask
            modifiedTask.userModified = true
            updatedPattern.suggestedTask = modifiedTask
            detectedPatterns[index] = updatedPattern
        }
    }

    // MARK: - Pattern Approval

    /// 선택된 패턴 승인 (TaskViewModel에서 Task 생성)
    func approvePatterns(_ patternIds: Set<UUID>) {
        let patternsToApprove = detectedPatterns.filter { patternIds.contains($0.id) }

        // Save to SwiftData
        if let service = patternManagementService {
            for pattern in patternsToApprove {
                do {
                    try service.saveApprovedPattern(pattern)
                } catch {
                }
            }
        }

        // 실제 Task 생성은 TaskViewModel에서 수행
        // 여기서는 승인된 패턴 제거
        detectedPatterns.removeAll { patternIds.contains($0.id) }
        selectedPatterns.subtract(patternIds)

        if detectedPatterns.isEmpty {
            hasNewPatterns = false
        }
    }

    // MARK: - Status

    /// 연동 상태 문자열
    var statusString: String {
        if isAnalyzing {
            return "분석 중..."
        } else if !calendarService.isAuthorized {
            switch authorizationStatus {
            case .notDetermined:
                return "미연동"
            case .denied:
                return "권한 거부됨"
            case .restricted:
                return "제한됨"
            default:
                return "미연동"
            }
        } else if detectedPatterns.isEmpty {
            return "패턴 없음"
        } else {
            return "\(detectedPatterns.count)개 패턴 감지됨"
        }
    }

    /// 패턴 검토 가능 여부
    var canReviewPatterns: Bool {
        !detectedPatterns.isEmpty && !isAnalyzing
    }

    /// 연동 활성화 가능 여부
    var canEnableIntegration: Bool {
        !isEnabled && (authorizationStatus == .notDetermined || authorizationStatus == .denied)
    }

    // MARK: - Reset

    /// 캘린더 연동 초기화 (모든 설정 및 감지된 패턴 제거)
    func resetCalendarIntegration() {

        // 연동 비활성화
        isEnabled = false

        // 패턴 및 선택 초기화
        detectedPatterns = []
        selectedPatterns = []
        hasNewPatterns = false

        // 캘린더 선택 초기화
        selectedCalendarIds = []

        // 메시지 초기화
        errorMessage = nil
        successMessage = nil
        statusMessage = nil

    }

    // MARK: - Calendar Import (전체 가져오기)

    /// 선택한 캘린더의 모든 이벤트를 태스크로 가져오기
    func importAllEventsFromCalendars(to taskViewModel: TaskViewModel) async {

        guard !importCalendarIds.isEmpty else {
            errorMessage = "가져올 캘린더를 선택해주세요."
            return
        }

        guard calendarService.isAuthorized else {
            errorMessage = "캘린더 접근 권한이 필요합니다."
            return
        }

        isImporting = true
        errorMessage = nil
        statusMessage = "이벤트 가져오는 중..."


        // 향후 N주간의 이벤트 가져오기
        let calendar = Calendar.current
        let startDate = Date()
        guard let endDate = calendar.date(byAdding: .weekOfYear, value: importWeeksAhead, to: startDate) else {
            errorMessage = "날짜 계산 오류"
            isImporting = false
            statusMessage = nil
            return
        }


        // 이벤트 가져오기
        let ekEvents = calendarService.fetchEvents(
            from: startDate,
            to: endDate,
            calendarIdentifiers: importCalendarIds
        )

        if ekEvents.isEmpty {
            await MainActor.run {
                successMessage = "가져올 이벤트가 없습니다."
                isImporting = false
                statusMessage = nil
            }
            return
        }

        // 이벤트를 Task로 변환
        var createdCount = 0
        var skippedCount = 0

        for event in ekEvents {
            // 이미 가져온 이벤트인지 확인 (calendarEventId로 중복 체크)
            let alreadyExists = taskViewModel.tasks.contains { task in
                task.calendarEventId == event.eventIdentifier
            }

            if alreadyExists {
                skippedCount += 1
                continue
            }

            // 이벤트 시간 계산
            let startTime = event.startDate ?? Date()
            let endTime = event.endDate ?? startTime
            let duration = Int(endTime.timeIntervalSince(startTime) / 60) // 분 단위

            // Task 생성
            let task = Task(
                title: event.title ?? "제목 없음",
                description: "📅 \(event.calendar.title)에서 가져옴",
                dueDate: endTime,
                estimatedMinutes: max(30, duration), // 최소 30분
                leadTimeDays: 0,
                taskType: .dateSpecific,  // 캘린더 이벤트는 당일만 가능
                taskRole: .none,
                status: .notStarted
            )

            var calendarTask = task
            calendarTask.calendarEventId = event.eventIdentifier
            calendarTask.isFromCalendarPattern = false  // 패턴이 아닌 직접 가져오기
            calendarTask.scheduledStartTime = startTime
            calendarTask.targetDate = startTime

            taskViewModel.addTask(calendarTask)
            createdCount += 1

        }

        await MainActor.run {
            successMessage = "✅ \(createdCount)개 이벤트를 가져왔습니다" + (skippedCount > 0 ? " (\(skippedCount)개 중복 제외)" : "")
            isImporting = false
            statusMessage = nil
        }

    }

    /// 캘린더 전체 가져오기 선택/해제
    func toggleCalendarImport(_ calendarId: String) {
        if importCalendarIds.contains(calendarId) {
            importCalendarIds.remove(calendarId)
        } else {
            importCalendarIds.insert(calendarId)
        }
    }

    // MARK: - Debugging

    /// 디버깅 정보 출력
    func printDebugInfo() {
    }
}
