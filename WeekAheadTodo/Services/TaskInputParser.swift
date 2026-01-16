import Foundation

/// 자연어 입력을 파싱하여 태스크 정보 추출
struct ParsedTaskInfo {
    var title: String
    var dueDate: Date?
    var estimatedMinutes: Int?
    var priority: TaskPriority?
    var leadTimeDays: Int?
}

class TaskInputParser {

    /// 자연어 입력을 파싱
    static func parse(_ input: String) -> ParsedTaskInfo {
        var result = ParsedTaskInfo(title: input)
        var cleanedTitle = input

        // 1. 마감일 파싱
        if let (date, range) = extractDueDate(from: input) {
            result.dueDate = date
            cleanedTitle = cleanedTitle.replacingOccurrences(
                of: String(input[range]),
                with: ""
            )
        }

        // 2. 예상 시간 파싱
        if let (minutes, range) = extractEstimatedTime(from: input) {
            result.estimatedMinutes = minutes
            cleanedTitle = cleanedTitle.replacingOccurrences(
                of: String(input[range]),
                with: ""
            )
        }

        // 3. 우선순위 파싱
        if let (priority, range) = extractPriority(from: input) {
            result.priority = priority
            cleanedTitle = cleanedTitle.replacingOccurrences(
                of: String(input[range]),
                with: ""
            )
        }

        // 4. 선행 일수 파싱
        if let (days, range) = extractLeadTimeDays(from: input) {
            result.leadTimeDays = days
            cleanedTitle = cleanedTitle.replacingOccurrences(
                of: String(input[range]),
                with: ""
            )
        }

        // 제목 정리 (앞뒤 공백, 중복 공백 제거)
        result.title = cleanedTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return result
    }

    // MARK: - 마감일 파싱

    private static func extractDueDate(from input: String) -> (Date, Range<String.Index>)? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // 패턴: "오늘까지", "내일까지", "모레까지"
        let patterns: [(String, Int)] = [
            ("오늘까지", 0),
            ("오늘", 0),
            ("내일까지", 1),
            ("내일", 1),
            ("모레까지", 2),
            ("모레", 2),
            ("글피까지", 3),
            ("글피", 3)
        ]

        for (pattern, daysToAdd) in patterns {
            if let range = input.range(of: pattern) {
                if let date = calendar.date(byAdding: .day, value: daysToAdd, to: today) {
                    return (date, range)
                }
            }
        }

        // 패턴: "이번주 금요일", "다음주 월요일"
        let weekdayPatterns: [(String, String, Int)] = [
            ("이번주", "월요일", 2),
            ("이번주", "화요일", 3),
            ("이번주", "수요일", 4),
            ("이번주", "목요일", 5),
            ("이번주", "금요일", 6),
            ("이번주", "토요일", 7),
            ("이번주", "일요일", 1),
            ("다음주", "월요일", 2),
            ("다음주", "화요일", 3),
            ("다음주", "수요일", 4),
            ("다음주", "목요일", 5),
            ("다음주", "금요일", 6),
            ("다음주", "토요일", 7),
            ("다음주", "일요일", 1)
        ]

        for (weekPrefix, dayName, targetWeekday) in weekdayPatterns {
            let fullPattern = "\(weekPrefix) \(dayName)"
            if let range = input.range(of: fullPattern) {
                let isNextWeek = weekPrefix == "다음주"
                if let date = getNextWeekday(targetWeekday, isNextWeek: isNextWeek) {
                    return (date, range)
                }
            }

            // "까지" 포함 패턴도 체크
            let patternWithSuffix = "\(fullPattern)까지"
            if let range = input.range(of: patternWithSuffix) {
                let isNextWeek = weekPrefix == "다음주"
                if let date = getNextWeekday(targetWeekday, isNextWeek: isNextWeek) {
                    return (date, range)
                }
            }
        }

        // 패턴: "3일 후", "5일후"
        let daysLaterPattern = "([0-9]+)일\\s*후"
        if let match = input.range(of: daysLaterPattern, options: .regularExpression),
           let daysString = input[match].components(separatedBy: "일").first,
           let days = Int(daysString.trimmingCharacters(in: .whitespaces)),
           let date = calendar.date(byAdding: .day, value: days, to: today) {
            return (date, match)
        }

        return nil
    }

    private static func getNextWeekday(_ targetWeekday: Int, isNextWeek: Bool) -> Date? {
        let calendar = Calendar.current
        let today = Date()
        let currentWeekday = calendar.component(.weekday, from: today)

        var daysToAdd = targetWeekday - currentWeekday
        if daysToAdd < 0 || (daysToAdd == 0 && isNextWeek) {
            daysToAdd += 7
        }
        if isNextWeek && daysToAdd < 7 {
            daysToAdd += 7
        }

        return calendar.date(byAdding: .day, value: daysToAdd, to: calendar.startOfDay(for: today))
    }

    // MARK: - 예상 시간 파싱

    private static func extractEstimatedTime(from input: String) -> (Int, Range<String.Index>)? {
        // 패턴: "3시간", "30분", "1시간 30분"

        // "시간" 패턴
        let hoursPattern = "([0-9]+)시간"
        if let match = input.range(of: hoursPattern, options: .regularExpression),
           let hoursString = input[match].components(separatedBy: "시간").first,
           let hours = Int(hoursString.trimmingCharacters(in: .whitespaces)) {

            // 분 패턴도 같이 있는지 확인
            let minutesPattern = "([0-9]+)분"
            if let minutesMatch = input.range(of: minutesPattern, options: .regularExpression),
               minutesMatch.lowerBound > match.lowerBound,
               let minutesString = input[minutesMatch].components(separatedBy: "분").first,
               let minutes = Int(minutesString.trimmingCharacters(in: .whitespaces)) {
                // "3시간 30분" 형태
                let combinedRange = match.lowerBound..<minutesMatch.upperBound
                return (hours * 60 + minutes, combinedRange)
            }

            return (hours * 60, match)
        }

        // "분" 패턴만
        let minutesPattern = "([0-9]+)분"
        if let match = input.range(of: minutesPattern, options: .regularExpression),
           let minutesString = input[match].components(separatedBy: "분").first,
           let minutes = Int(minutesString.trimmingCharacters(in: .whitespaces)) {
            return (minutes, match)
        }

        return nil
    }

    // MARK: - 우선순위 파싱

    private static func extractPriority(from input: String) -> (TaskPriority, Range<String.Index>)? {
        let patterns: [(String, TaskPriority)] = [
            ("긴급", .urgent),
            ("매우중요", .urgent),
            ("매우 중요", .urgent),
            ("중요", .high),
            ("높음", .high),
            ("보통", .normal),
            ("낮음", .low)
        ]

        for (pattern, priority) in patterns {
            if let range = input.range(of: pattern, options: .caseInsensitive) {
                return (priority, range)
            }
        }

        return nil
    }

    // MARK: - 선행 일수 파싱

    private static func extractLeadTimeDays(from input: String) -> (Int, Range<String.Index>)? {
        // 패턴: "3일전", "3일 전", "5일전부터"
        let patterns = [
            "([0-9]+)일\\s*전부터",
            "([0-9]+)일\\s*전"
        ]

        for pattern in patterns {
            if let match = input.range(of: pattern, options: .regularExpression),
               let daysString = input[match].components(separatedBy: "일").first,
               let days = Int(daysString.trimmingCharacters(in: .whitespaces)) {
                return (days, match)
            }
        }

        return nil
    }
}
