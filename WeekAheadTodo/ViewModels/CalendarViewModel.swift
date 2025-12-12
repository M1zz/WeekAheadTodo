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

    // MARK: - Services

    private let calendarService: CalendarService
    private let patternService: PatternDetectionService

    // MARK: - Initialization

    init() {
        self.calendarService = CalendarService()
        self.patternService = PatternDetectionService()
        updateAuthorizationStatus()
    }

    // MARK: - Authorization

    /// 권한 상태 업데이트
    func updateAuthorizationStatus() {
        authorizationStatus = calendarService.authorizationStatus
    }

    /// 캘린더 연동 활성화
    func enableIntegration() async {
        print("\n" + String(repeating: "=", count: 60))
        print("🚀 캘린더 연동 활성화 시작")
        print(String(repeating: "=", count: 60))

        // 먼저 권한 상태 업데이트
        updateAuthorizationStatus()
        print("📋 현재 권한 상태: \(calendarService.authorizationStatusString)")

        errorMessage = nil
        successMessage = nil
        statusMessage = "권한 확인 중..."
        var granted = false

        // 권한 상태에 따른 처리
        switch authorizationStatus {
        case .authorized, .fullAccess:
            // 이미 권한이 있는 경우 - 바로 진행
            print("✅ 권한 이미 승인됨 - 바로 연동 활성화")
            statusMessage = "캘린더 목록 로딩 중..."
            granted = true

        case .denied, .restricted:
            // 권한 거부됨
            print("❌ 권한이 거부되어 있음")
            statusMessage = nil
            errorMessage = "캘린더 접근이 거부되었습니다. 아래 안내를 따라 시스템 설정에서 권한을 허용해주세요."
            print(String(repeating: "=", count: 60) + "\n")
            return

        case .notDetermined:
            // 권한 요청 필요
            print("🔐 캘린더 권한 요청 중...")
            statusMessage = "권한 요청 중..."
            granted = await calendarService.requestAccess()
            updateAuthorizationStatus()
            print("📋 권한 요청 결과: \(granted ? "✅ 승인됨" : "❌ 거부됨")")

        case .writeOnly:
            print("⚠️ Write-Only 권한은 패턴 감지에 사용할 수 없음")
            statusMessage = nil
            errorMessage = "읽기 권한이 필요합니다."
            print(String(repeating: "=", count: 60) + "\n")
            return

        @unknown default:
            print("⚠️ 알 수 없는 권한 상태")
            statusMessage = nil
            errorMessage = "권한 상태를 확인할 수 없습니다."
            print(String(repeating: "=", count: 60) + "\n")
            return
        }

        if granted {
            isEnabled = true
            print("✅ 캘린더 연동 활성화됨")

            // 사용 가능한 캘린더 목록 가져오기
            print("📋 캘린더 목록 로딩 중...")
            statusMessage = "캘린더 목록 로딩 중..."
            loadAvailableCalendars()

            print("📊 캘린더 분석 시작...")
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
            print("❌ 캘린더 권한 거부됨")
            statusMessage = nil
            errorMessage = "캘린더 권한이 거부되었습니다. 아래 안내를 따라 시스템 설정에서 권한을 허용해주세요."
        }
        print(String(repeating: "=", count: 60) + "\n")
    }

    // MARK: - Calendar Selection

    /// 사용 가능한 캘린더 목록 로드
    func loadAvailableCalendars() {
        availableCalendars = calendarService.getAvailableCalendars()
        // 기본값: 모든 캘린더 선택
        if selectedCalendarIds.isEmpty {
            selectedCalendarIds = Set(availableCalendars.map { $0.calendarIdentifier })
            print("  ✅ 모든 캘린더 선택됨: \(selectedCalendarIds.count)개")
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
        print("\n" + String(repeating: "-", count: 60))
        print("📊 캘린더 분석 시작")
        print(String(repeating: "-", count: 60))

        guard calendarService.isAuthorized else {
            print("❌ 캘린더 접근 권한 없음")
            errorMessage = "캘린더 접근 권한이 필요합니다."
            return
        }

        print("✅ 권한 확인 완료 - 분석 진행")
        print("🎯 선택된 캘린더: \(selectedCalendarIds.count)개")
        isAnalyzing = true
        errorMessage = nil

        // 백그라운드에서 분석 수행
        print("🔍 EventKit에서 이벤트 가져오는 중...")
        let ekEvents = calendarService.fetchRecentEvents(calendarIdentifiers: selectedCalendarIds.isEmpty ? nil : selectedCalendarIds)
        print("📥 가져온 EKEvent 개수: \(ekEvents.count)")

        if ekEvents.isEmpty {
            print("⚠️ 경고: 가져온 이벤트가 없습니다!")
            print("   - 캘린더 앱에 일정이 있는지 확인하세요")
            print("   - 지난 3개월 내의 일정이 있는지 확인하세요")
        } else {
            print("📋 이벤트 샘플 (처음 5개):")
            for (index, event) in ekEvents.prefix(5).enumerated() {
                print("   \(index + 1). [\(event.calendar.title)] \(event.title ?? "제목 없음")")
                print("      시작: \(event.startDate?.formatted() ?? "N/A")")
            }
        }

        print("🔄 CalendarEvent 모델로 변환 중...")
        let calendarEvents = ekEvents.map { CalendarEvent(from: $0) }
        print("✅ 변환 완료: \(calendarEvents.count)개")

        print("🔍 패턴 감지 서비스 실행 중...")
        let patterns = patternService.analyzePatterns(events: calendarEvents)
        print("📊 패턴 분석 완료: \(patterns.count)개 패턴 감지됨")

        if !patterns.isEmpty {
            print("📋 감지된 패턴 목록:")
            for (index, pattern) in patterns.enumerated() {
                print("   \(index + 1). [\(pattern.type.rawValue)] \(pattern.suggestedTask.title)")
                print("      - 이벤트 수: \(pattern.events.count)")
                print("      - 신뢰도: \(pattern.confidencePercent)%")
            }
        } else {
            print("⚠️ 감지된 패턴이 없습니다")
        }

        await MainActor.run {
            self.detectedPatterns = patterns
            self.hasNewPatterns = !patterns.isEmpty
            self.isAnalyzing = false

            print("✅ UI 업데이트 완료")
        }
        print(String(repeating: "-", count: 60) + "\n")
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

    // MARK: - Debugging

    /// 디버깅 정보 출력
    func printDebugInfo() {
        print("=== 캘린더 연동 상태 ===")
        print("활성화: \(isEnabled)")
        print("권한: \(calendarService.authorizationStatusString)")
        print("분석 중: \(isAnalyzing)")
        print("감지된 패턴: \(detectedPatterns.count)개")
        print("선택된 패턴: \(selectedPatterns.count)개")
        print("====================")
    }
}
