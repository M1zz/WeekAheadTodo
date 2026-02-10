import Foundation
import EventKit

/// EventKit을 사용한 캘린더 접근 서비스
///
/// ## 접근 수준
/// - **Full Access**: 일정을 읽고, 생성, 수정, 삭제할 수 있습니다
/// - 이 앱은 일정 패턴 분석을 위해 **읽기 전용**으로 Full Access를 사용합니다
/// - 앱은 캘린더 일정을 절대 수정하거나 삭제하지 않습니다
///
/// ## 왜 Full Access가 필요한가?
/// - EventKit은 읽기 전용 접근을 제공하지 않습니다
/// - 일정을 읽으려면 Full Access 권한이 필요합니다
/// - Write-Only Access는 일정을 읽을 수 없어 패턴 분석이 불가능합니다
@MainActor
class CalendarService: ObservableObject {

    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined

    // IMPORTANT: eventStore 인스턴스를 유지해야 합니다
    // Apple 문서: "Releasing an event store instance before other EventKit objects may result in an error"
    private let eventStore = EKEventStore()

    init() {
        updateAuthorizationStatus()
    }

    // MARK: - Authorization

    /// 현재 권한 상태 업데이트
    func updateAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    /// 캘린더 접근 권한 요청
    /// - Returns: 권한이 승인되면 true, 거부되거나 에러 발생 시 false
    ///
    /// ## 접근 수준
    /// - macOS 14.0+: `requestFullAccessToEvents()` 사용
    /// - 이전 버전: `requestAccess(to:)` 사용 (deprecated이지만 호환성 유지)
    func requestAccess() async -> Bool {
        do {
            let granted: Bool

            if #available(macOS 14.0, *) {
                // macOS 14.0+ (iOS 17+): 최신 API 사용
                granted = try await eventStore.requestFullAccessToEvents()
            } else {
                // 이전 버전: deprecated API 사용 (호환성)
                granted = try await withCheckedThrowingContinuation { continuation in
                    eventStore.requestAccess(to: .event) { granted, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: granted)
                        }
                    }
                }
            }

            // 권한 상태 업데이트
            await MainActor.run {
                updateAuthorizationStatus()
            }

            return granted

        } catch {
            await MainActor.run {
                updateAuthorizationStatus()
            }
            return false
        }
    }

    // MARK: - Calendar Management

    /// 사용 가능한 캘린더 목록 가져오기
    func getAvailableCalendars() -> [EKCalendar] {
        guard isAuthorized else {
            return []
        }

        let calendars = eventStore.calendars(for: .event)
        for (index, calendar) in calendars.enumerated() {
        }
        return calendars
    }

    // MARK: - Fetch Events

    /// 지정된 기간의 캘린더 이벤트 가져오기 (선택된 캘린더만)
    /// - Parameters:
    ///   - startDate: 시작 날짜
    ///   - endDate: 종료 날짜
    ///   - calendarIdentifiers: 선택된 캘린더 ID 목록 (nil이면 모든 캘린더)
    /// - Returns: EKEvent 배열
    ///
    /// ## 권한 요구사항
    /// - Full Access 권한 필요 (읽기를 위해)
    /// - 권한이 없으면 빈 배열 반환
    ///
    /// ## 안전성
    /// - 읽기 전용으로만 사용됨 (일정을 수정하거나 삭제하지 않음)
    func fetchEvents(from startDate: Date, to endDate: Date, calendarIdentifiers: Set<String>? = nil) -> [EKEvent] {

        // 1. 권한 확인
        guard isAuthorized else {
            return []
        }

        // 2. 캘린더 목록 가져오기
        var calendars = eventStore.calendars(for: .event)

        // 선택된 캘린더만 필터링
        if let selectedIds = calendarIdentifiers, !selectedIds.isEmpty {
            calendars = calendars.filter { selectedIds.contains($0.calendarIdentifier) }
        } else {
        }

        guard !calendars.isEmpty else {
            return []
        }

        for (index, calendar) in calendars.enumerated() {
        }

        // 3. 이벤트 검색 (predicate 사용)
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        let events = eventStore.events(matching: predicate)

        // 4. 결과 로깅
        if events.isEmpty {
        } else {
            let calendarGroups = Dictionary(grouping: events) { $0.calendar.title }
            for (calendarName, calendarEvents) in calendarGroups.sorted(by: { $0.key < $1.key }) {
            }
        }

        return events
    }

    /// 최근 3개월의 이벤트 가져오기
    /// - Parameter calendarIdentifiers: 선택된 캘린더 ID 목록 (nil이면 모든 캘린더)
    /// - Returns: 지난 3개월 간의 EKEvent 배열
    ///
    /// ## 분석 기간
    /// - 오늘부터 3개월 전까지의 이벤트
    /// - 패턴 감지를 위한 충분한 데이터 확보
    func fetchRecentEvents(calendarIdentifiers: Set<String>? = nil) -> [EKEvent] {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .month, value: -3, to: endDate) else {
            return []
        }

        if let selectedIds = calendarIdentifiers, !selectedIds.isEmpty {
        }
        return fetchEvents(from: startDate, to: endDate, calendarIdentifiers: calendarIdentifiers)
    }

    // MARK: - Utilities

    /// 권한 상태 문자열 (디버깅용)
    var authorizationStatusString: String {
        switch authorizationStatus {
        case .notDetermined:
            return "미결정"
        case .restricted:
            return "제한됨"
        case .denied:
            return "거부됨"
        case .authorized, .fullAccess:
            return "승인됨"
        case .writeOnly:
            return "쓰기 전용"
        @unknown default:
            return "알 수 없음"
        }
    }

    /// 권한 요청이 가능한지 확인
    var canRequestAccess: Bool {
        authorizationStatus == .notDetermined
    }

    /// 권한이 승인되었는지 확인
    var isAuthorized: Bool {
        authorizationStatus == .fullAccess || authorizationStatus == .authorized
    }

    // MARK: - Time Block Calculation

    /// 특정 날짜의 캘린더 이벤트 총 시간 계산 (분 단위)
    /// - Parameters:
    ///   - date: 계산할 날짜
    ///   - calendarIdentifiers: 포함할 캘린더 ID 목록
    /// - Returns: 해당 날짜의 이벤트 총 시간 (분)
    func calculateEventDuration(for date: Date, calendarIdentifiers: Set<String>) -> Int {
        guard isAuthorized else {
            return 0
        }

        guard !calendarIdentifiers.isEmpty else {
            return 0
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return 0
        }

        // 선택된 캘린더만 필터링
        let selectedCalendars = eventStore.calendars(for: .event).filter {
            calendarIdentifiers.contains($0.calendarIdentifier)
        }

        guard !selectedCalendars.isEmpty else {
            return 0
        }

        // 해당 날짜의 이벤트 가져오기
        let predicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: selectedCalendars
        )

        let events = eventStore.events(matching: predicate)

        // 전일 이벤트 제외하고 총 시간 계산
        var totalMinutes = 0
        for event in events {
            // 전일 이벤트는 시간 계산에서 제외
            guard !event.isAllDay else { continue }

            let eventStart = max(event.startDate, startOfDay)
            let eventEnd = min(event.endDate, endOfDay)

            let duration = eventEnd.timeIntervalSince(eventStart)
            totalMinutes += Int(duration / 60)
        }

        return totalMinutes
    }

    /// 여러 날짜의 캘린더 이벤트 시간 계산
    /// - Parameters:
    ///   - dates: 계산할 날짜 배열
    ///   - calendarIdentifiers: 포함할 캘린더 ID 목록
    /// - Returns: [날짜: 총 시간(분)] 딕셔너리
    func calculateEventDurations(for dates: [Date], calendarIdentifiers: Set<String>) -> [Date: Int] {
        var result: [Date: Int] = [:]
        let calendar = Calendar.current

        for date in dates {
            let startOfDay = calendar.startOfDay(for: date)
            let minutes = calculateEventDuration(for: startOfDay, calendarIdentifiers: calendarIdentifiers)
            result[startOfDay] = minutes
        }

        return result
    }

    // MARK: - Create Events

    /// 캘린더에 이벤트 생성
    /// - Parameters:
    ///   - title: 이벤트 제목
    ///   - startDate: 시작 날짜/시간
    ///   - endDate: 종료 날짜/시간
    ///   - notes: 메모 (선택)
    ///   - calendarIdentifier: 캘린더 ID (nil이면 기본 캘린더)
    /// - Returns: 성공 여부
    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        notes: String? = nil,
        calendarIdentifier: String? = nil
    ) async -> Bool {
        guard isAuthorized else {
            return false
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.notes = notes

        // 캘린더 선택
        if let calendarId = calendarIdentifier {
            if let calendar = eventStore.calendars(for: .event).first(where: { $0.calendarIdentifier == calendarId }) {
                event.calendar = calendar
            } else {
                event.calendar = eventStore.defaultCalendarForNewEvents
            }
        } else {
            event.calendar = eventStore.defaultCalendarForNewEvents
        }

        do {
            try eventStore.save(event, span: .thisEvent)
            return true
        } catch {
            return false
        }
    }

    /// 여러 이벤트를 한 번에 생성
    /// - Parameters:
    ///   - events: 생성할 이벤트 정보 배열 [(제목, 시작, 종료, 메모)]
    ///   - calendarIdentifier: 캘린더 ID (nil이면 기본 캘린더)
    /// - Returns: (성공 개수, 실패 개수)
    func createEvents(
        _ events: [(title: String, startDate: Date, endDate: Date, notes: String?)],
        calendarIdentifier: String? = nil
    ) async -> (success: Int, failure: Int) {
        var successCount = 0
        var failureCount = 0

        for eventInfo in events {
            let success = await createEvent(
                title: eventInfo.title,
                startDate: eventInfo.startDate,
                endDate: eventInfo.endDate,
                notes: eventInfo.notes,
                calendarIdentifier: calendarIdentifier
            )

            if success {
                successCount += 1
            } else {
                failureCount += 1
            }
        }

        return (successCount, failureCount)
    }
}
