import Foundation
import EventKit

/// 캘린더 이벤트 모델 (EKEvent 래퍼)
struct CalendarEvent: Identifiable, Codable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let calendarTitle: String
    let isAllDay: Bool

    // MARK: - Computed Properties

    /// 이벤트 지속 시간 (분)
    var durationMinutes: Int {
        Int(duration / 60)
    }

    /// 요일 (1 = 일요일, 2 = 월요일, ..., 7 = 토요일)
    var dayOfWeek: Int {
        Calendar.current.component(.weekday, from: startDate)
    }

    /// 요일 이름 (한글)
    var dayOfWeekString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: startDate)
    }

    /// 시간대 (아침/오전/오후/저녁)
    var timeOfDay: String {
        let hour = Calendar.current.component(.hour, from: startDate)
        switch hour {
        case 0..<6:
            return "새벽"
        case 6..<9:
            return "아침"
        case 9..<12:
            return "오전"
        case 12..<18:
            return "오후"
        case 18..<22:
            return "저녁"
        default:
            return "밤"
        }
    }

    /// 시작 시간 (HH:mm 형식)
    var startTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: startDate)
    }

    /// 월 내 몇 번째 주인지 (1~5)
    var weekOfMonth: Int {
        Calendar.current.component(.weekOfMonth, from: startDate)
    }

    /// 시작 날짜만 (날짜 비교용)
    var startDateDay: Date {
        Calendar.current.startOfDay(for: startDate)
    }

    // MARK: - Initialization

    /// EKEvent에서 CalendarEvent 생성
    init(from ekEvent: EKEvent) {
        self.id = ekEvent.eventIdentifier
        self.title = ekEvent.title ?? "(제목 없음)"
        self.startDate = ekEvent.startDate
        self.endDate = ekEvent.endDate
        self.duration = ekEvent.endDate.timeIntervalSince(ekEvent.startDate)
        self.calendarTitle = ekEvent.calendar?.title ?? "기본 캘린더"
        self.isAllDay = ekEvent.isAllDay
    }

    /// 직접 생성 (테스트용)
    init(
        id: String = UUID().uuidString,
        title: String,
        startDate: Date,
        endDate: Date,
        calendarTitle: String = "기본 캘린더",
        isAllDay: Bool = false
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.duration = endDate.timeIntervalSince(startDate)
        self.calendarTitle = calendarTitle
        self.isAllDay = isAllDay
    }

    // MARK: - Utilities

    /// 이벤트 요약 정보
    var summary: String {
        "\(title) | \(dayOfWeekString) \(startTimeFormatted) (\(durationMinutes)분)"
    }

    /// 두 이벤트의 시작 시간 차이 (분)
    func timeOffsetMinutes(to other: CalendarEvent) -> Int {
        let diff = other.startDate.timeIntervalSince(self.startDate)
        return abs(Int(diff / 60))
    }

    /// 두 이벤트가 같은 시간대인지 확인 (tolerance: 분 단위)
    func isSameTimeRange(as other: CalendarEvent, tolerance: Int = 30) -> Bool {
        let hourDiff = abs(Calendar.current.component(.hour, from: startDate) - Calendar.current.component(.hour, from: other.startDate))
        let minuteDiff = abs(Calendar.current.component(.minute, from: startDate) - Calendar.current.component(.minute, from: other.startDate))

        let totalMinuteDiff = hourDiff * 60 + minuteDiff
        return totalMinuteDiff <= tolerance
    }
}

// MARK: - Array Extension

extension Array where Element == CalendarEvent {
    /// 날짜 순으로 정렬
    func sortedByDate() -> [CalendarEvent] {
        self.sorted { $0.startDate < $1.startDate }
    }

    /// 특정 날짜 범위의 이벤트만 필터링
    func filtered(from startDate: Date, to endDate: Date) -> [CalendarEvent] {
        self.filter { event in
            event.startDate >= startDate && event.startDate < endDate
        }
    }

    /// 제목으로 그룹화
    func groupedByTitle() -> [String: [CalendarEvent]] {
        Dictionary(grouping: self) { $0.title }
    }

    /// 요일별로 그룹화
    func groupedByDayOfWeek() -> [Int: [CalendarEvent]] {
        Dictionary(grouping: self) { $0.dayOfWeek }
    }
}
