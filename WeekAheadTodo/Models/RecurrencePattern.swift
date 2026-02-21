import WeekAheadShared
import Foundation

/// 반복 패턴 유형
enum PatternType: String, Codable, CaseIterable {
    case weeklyFixedDay = "매주 고정 요일"
    case biweeklyMonthly = "격주/월간 반복"
    case dailySameTime = "매일 같은 시간"
    case similarTitle = "제목 유사도 기반"

    var icon: String {
        switch self {
        case .weeklyFixedDay:
            return "calendar.badge.clock"
        case .biweeklyMonthly:
            return "calendar.badge.plus"
        case .dailySameTime:
            return "clock.arrow.circlepath"
        case .similarTitle:
            return "doc.text.magnifyingglass"
        }
    }

    var sortOrder: Int {
        switch self {
        case .weeklyFixedDay: return 1
        case .biweeklyMonthly: return 2
        case .dailySameTime: return 3
        case .similarTitle: return 4
        }
    }
}

/// 반복 빈도
enum RecurrenceFrequency: String, Codable {
    case daily = "매일"
    case weekly = "매주"
    case biweekly = "격주"
    case monthly = "매월"
}

/// 반복 규칙
struct RecurrenceRule: Codable, Equatable {
    let frequency: RecurrenceFrequency
    let interval: Int
    let daysOfWeek: [Int]?
    let nextOccurrenceDate: Date

    var description: String {
        switch frequency {
        case .daily:
            return "매일"
        case .weekly:
            if let days = daysOfWeek, let firstDay = days.first {
                return "매주 \(dayOfWeekString(firstDay))"
            }
            return "매주"
        case .biweekly:
            if let days = daysOfWeek, let firstDay = days.first {
                return "격주 \(dayOfWeekString(firstDay))"
            }
            return "격주"
        case .monthly:
            return "매월"
        }
    }

    private func dayOfWeekString(_ dayOfWeek: Int) -> String {
        let days = ["일요일", "월요일", "화요일", "수요일", "목요일", "금요일", "토요일"]
        return days[safe: dayOfWeek - 1] ?? "알 수 없음"
    }
}

/// Task 생성 제안
struct SuggestedTask: Codable, Equatable {
    var title: String
    var estimatedMinutes: Int
    var leadTimeDays: Int
    var taskType: TaskType
    var recurrenceRule: RecurrenceRule?
    var userModified: Bool = false

    /// 예상 시간 포맷팅
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
}

/// 감지된 반복 패턴
struct RecurrencePattern: Identifiable, Codable {
    let id: UUID
    let type: PatternType
    let events: [CalendarEvent]
    let confidenceScore: Double
    var suggestedTask: SuggestedTask
    let detectedAt: Date

    // MARK: - Computed Properties

    /// 패턴에 포함된 캘린더 목록 (중복 제거)
    var calendarTitles: [String] {
        Array(Set(events.map { $0.calendarTitle })).sorted()
    }

    /// 주요 캘린더 (가장 많은 이벤트가 있는 캘린더)
    var primaryCalendar: String {
        let calendarCounts = Dictionary(grouping: events) { $0.calendarTitle }
            .mapValues { $0.count }
        return calendarCounts.max(by: { $0.value < $1.value })?.key ?? "알 수 없음"
    }

    /// 패턴 빈도 설명
    var frequency: String {
        switch type {
        case .weeklyFixedDay:
            if let firstEvent = events.first {
                return "매주 \(firstEvent.dayOfWeekString) \(firstEvent.startTimeFormatted)"
            }
            return "매주 반복"

        case .biweeklyMonthly:
            let avgInterval = calculateAverageInterval()
            if avgInterval >= 28 && avgInterval <= 31 {
                return "매월 반복"
            } else if avgInterval >= 12 && avgInterval <= 16 {
                return "격주 반복"
            }
            return "정기적 반복"

        case .dailySameTime:
            if let firstEvent = events.first {
                return "매일 \(firstEvent.startTimeFormatted)"
            }
            return "매일 반복"

        case .similarTitle:
            return "\(events.count)회 반복"
        }
    }

    /// 시간대 설명
    var timeRange: String {
        guard let firstEvent = events.first else {
            return "시간 미정"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        let startTime = formatter.string(from: firstEvent.startDate)
        let endTime = formatter.string(from: firstEvent.endDate)

        return "\(startTime) - \(endTime)"
    }

    /// 감지 근거 (특성 목록)
    var detectedCharacteristics: [String] {
        var characteristics: [String] = []

        characteristics.append("\(events.count)회 감지")

        switch type {
        case .weeklyFixedDay:
            let avgInterval = calculateAverageInterval()
            characteristics.append("평균 간격: \(String(format: "%.1f", avgInterval))일")
            characteristics.append("시간 일관성: \(String(format: "%.0f", timeConsistency() * 100))%")

        case .biweeklyMonthly:
            let avgInterval = calculateAverageInterval()
            characteristics.append("평균 간격: \(String(format: "%.1f", avgInterval))일")
            let titleSim = averageTitleSimilarity()
            characteristics.append("제목 유사도: \(String(format: "%.0f", titleSim * 100))%")

        case .dailySameTime:
            let avgInterval = calculateAverageInterval()
            characteristics.append("평균 간격: \(String(format: "%.1f", avgInterval))일")
            characteristics.append("시간대: \(events.first?.timeOfDay ?? "미정")")

        case .similarTitle:
            let titleSim = averageTitleSimilarity()
            characteristics.append("제목 유사도: \(String(format: "%.0f", titleSim * 100))%")
            characteristics.append("시간 일관성: \(String(format: "%.0f", timeConsistency() * 100))%")
        }

        return characteristics
    }

    /// 신뢰도 퍼센트 (0~100)
    var confidencePercent: Int {
        Int(confidenceScore * 100)
    }

    /// 신뢰도 색상
    var confidenceColor: String {
        if confidenceScore >= 0.8 {
            return "green"
        } else if confidenceScore >= 0.6 {
            return "blue"
        } else if confidenceScore >= 0.4 {
            return "orange"
        } else {
            return "red"
        }
    }

    /// 최근 5개의 이벤트 날짜 (최신순)
    var recentEventDates: [Date] {
        let sortedEvents = events.sorted { $0.startDate > $1.startDate }
        return Array(sortedEvents.prefix(5)).map { $0.startDate }
    }

    /// 최근 5개의 이벤트 날짜를 포맷팅한 문자열
    var recentEventDatesFormatted: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M/d"

        let dateStrings = recentEventDates.map { dateFormatter.string(from: $0) }

        if dateStrings.isEmpty {
            return "날짜 없음"
        }

        return dateStrings.joined(separator: ", ")
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        type: PatternType,
        events: [CalendarEvent],
        confidenceScore: Double,
        suggestedTask: SuggestedTask,
        detectedAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.events = events
        self.confidenceScore = confidenceScore
        self.suggestedTask = suggestedTask
        self.detectedAt = detectedAt
    }

    // MARK: - Utilities

    /// 평균 간격 (일)
    private func calculateAverageInterval() -> Double {
        guard events.count >= 2 else { return 0 }

        let sortedEvents = events.sorted { $0.startDate < $1.startDate }
        var intervals: [Double] = []

        for i in 0..<(sortedEvents.count - 1) {
            let interval = sortedEvents[i + 1].startDate.timeIntervalSince(sortedEvents[i].startDate)
            intervals.append(interval / 86400.0) // 초 → 일
        }

        return intervals.reduce(0, +) / Double(intervals.count)
    }

    /// 시간 일관성 (0.0 ~ 1.0)
    private func timeConsistency() -> Double {
        guard events.count >= 2 else { return 1.0 }

        let calendar = Calendar.current
        let hours = events.map { calendar.component(.hour, from: $0.startDate) }
        let minutes = events.map { calendar.component(.minute, from: $0.startDate) }

        let hourStdDev = standardDeviation(hours.map { Double($0) })
        let minuteStdDev = standardDeviation(minutes.map { Double($0) })

        // 표준편차가 낮을수록 일관성이 높음
        let consistency = max(0, 1.0 - (hourStdDev / 12.0 + minuteStdDev / 60.0))
        return min(1.0, consistency)
    }

    /// 평균 제목 유사도
    private func averageTitleSimilarity() -> Double {
        guard events.count >= 2 else { return 1.0 }

        var similarities: [Double] = []
        let titles = events.map { $0.title }

        for i in 0..<titles.count {
            for j in (i + 1)..<titles.count {
                let similarity = titleSimilarity(titles[i], titles[j])
                similarities.append(similarity)
            }
        }

        return similarities.isEmpty ? 0 : similarities.reduce(0, +) / Double(similarities.count)
    }
}

// MARK: - Helper Functions

/// 표준편차 계산
private func standardDeviation(_ values: [Double]) -> Double {
    guard values.count > 1 else { return 0 }

    let mean = values.reduce(0, +) / Double(values.count)
    let squaredDiffs = values.map { pow($0 - mean, 2) }
    let variance = squaredDiffs.reduce(0, +) / Double(values.count)

    return sqrt(variance)
}

/// 제목 유사도 계산 (Levenshtein distance 기반)
func titleSimilarity(_ a: String, _ b: String) -> Double {
    let normalizedA = a.lowercased().trimmingCharacters(in: .whitespaces)
    let normalizedB = b.lowercased().trimmingCharacters(in: .whitespaces)

    let distance = levenshteinDistance(normalizedA, normalizedB)
    let maxLength = max(normalizedA.count, normalizedB.count)

    guard maxLength > 0 else { return 1.0 }

    return 1.0 - (Double(distance) / Double(maxLength))
}

/// Levenshtein distance 계산
private func levenshteinDistance(_ a: String, _ b: String) -> Int {
    // 빈 문자열 처리
    if a.isEmpty { return b.count }
    if b.isEmpty { return a.count }

    let a = Array(a)
    let b = Array(b)

    var matrix = [[Int]](repeating: [Int](repeating: 0, count: b.count + 1), count: a.count + 1)

    for i in 0...a.count {
        matrix[i][0] = i
    }

    for j in 0...b.count {
        matrix[0][j] = j
    }

    // 1...a.count는 a.count가 0일 때 에러 발생 (1...0은 유효하지 않음)
    // 위에서 빈 문자열을 먼저 처리했으므로 여기서는 안전함
    for i in 1...a.count {
        for j in 1...b.count {
            let cost = a[i - 1] == b[j - 1] ? 0 : 1
            matrix[i][j] = min(
                matrix[i - 1][j] + 1,       // 삭제
                matrix[i][j - 1] + 1,       // 삽입
                matrix[i - 1][j - 1] + cost // 치환
            )
        }
    }

    return matrix[a.count][b.count]
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
