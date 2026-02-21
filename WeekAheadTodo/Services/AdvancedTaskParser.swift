import WeekAheadShared
import Foundation

/// 고급 자연어 파싱 (시간대, 복잡한 날짜 표현)
class AdvancedTaskParser {

    /// 기본 파서와 함께 사용하여 더 자세한 정보 추출
    static func enhanceParsedInfo(_ info: ParsedTaskInfo, from input: String) -> ParsedTaskInfo {
        var result = info

        // 시간대 파싱 (dueDate가 있으면 시간 추가)
        if let baseDate = result.dueDate, let (hour, minute) = extractTime(from: input) {
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
            components.hour = hour
            components.minute = minute
            if let dateWithTime = calendar.date(from: components) {
                result.dueDate = dateWithTime
            }
        }

        // 복잡한 날짜 표현 (기본 파서에서 못 찾은 경우)
        if result.dueDate == nil, let date = extractComplexDate(from: input) {
            result.dueDate = date
        }

        // 컨텍스트 기반 예상 시간 (명시되지 않은 경우)
        if result.estimatedMinutes == nil, let minutes = inferEstimatedTime(from: input) {
            result.estimatedMinutes = minutes
        }

        return result
    }

    // MARK: - 시간대 파싱

    /// "오후 2시", "14시 30분", "오전 9시" 등 파싱
    private static func extractTime(from input: String) -> (hour: Int, minute: Int)? {
        // 패턴 1: "오전/오후 N시 M분"
        let patterns = [
            "오후\\s*([0-9]{1,2})시\\s*([0-9]{1,2})분",
            "오전\\s*([0-9]{1,2})시\\s*([0-9]{1,2})분",
            "오후\\s*([0-9]{1,2})시",
            "오전\\s*([0-9]{1,2})시",
            "([0-9]{1,2})시\\s*([0-9]{1,2})분",
            "([0-9]{1,2})시"
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let nsInput = input as NSString
            guard let match = regex.firstMatch(in: input, range: NSRange(location: 0, length: nsInput.length)) else { continue }

            let isPM = input.contains("오후")
            let isAM = input.contains("오전")

            // 시 추출
            let hourRange = match.range(at: 1)
            guard hourRange.location != NSNotFound else { continue }
            let hourString = nsInput.substring(with: hourRange)
            guard var hour = Int(hourString) else { continue }

            // 분 추출
            var minute = 0
            if match.numberOfRanges > 2 {
                let minuteRange = match.range(at: 2)
                if minuteRange.location != NSNotFound {
                    let minuteString = nsInput.substring(with: minuteRange)
                    minute = Int(minuteString) ?? 0
                }
            }

            // 오후 처리 (12시간제 → 24시간제)
            if isPM && hour < 12 {
                hour += 12
            } else if isAM && hour == 12 {
                hour = 0
            }

            return (hour, minute)
        }

        return nil
    }

    // MARK: - 복잡한 날짜 표현

    /// "다다음주", "2주 후", "한달 후", "분기말" 등
    private static func extractComplexDate(from input: String) -> Date? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // "N주 후", "N달 후", "N개월 후"
        let relativePatterns: [(String, Calendar.Component)] = [
            ("([0-9]+)주\\s*후", .weekOfYear),
            ("([0-9]+)달\\s*후", .month),
            ("([0-9]+)개월\\s*후", .month)
        ]

        for (pattern, component) in relativePatterns {
            if let match = input.range(of: pattern, options: .regularExpression),
               let numberString = input[match].components(separatedBy: CharacterSet.decimalDigits.inverted).first(where: { !$0.isEmpty }),
               let number = Int(numberString),
               let date = calendar.date(byAdding: component, value: number, to: today) {
                return date
            }
        }

        // 특수 표현
        let specialPatterns: [(String, Int, Calendar.Component)] = [
            ("다다음주", 2, .weekOfYear),
            ("다음달", 1, .month),
            ("다다음달", 2, .month),
            ("한달후", 1, .month),
            ("한 달 후", 1, .month),
            ("이번달말", 0, .month),  // 이번 달 마지막 날
            ("다음달말", 1, .month),  // 다음 달 마지막 날
        ]

        for (pattern, value, component) in specialPatterns {
            if input.contains(pattern) {
                if pattern.hasSuffix("말") {
                    // 월말 처리
                    if let startOfMonth = calendar.date(byAdding: component, value: value, to: today),
                       let range = calendar.range(of: .day, in: .month, for: startOfMonth),
                       let lastDay = calendar.date(bySetting: .day, value: range.count, of: startOfMonth) {
                        return lastDay
                    }
                } else {
                    if let date = calendar.date(byAdding: component, value: value, to: today) {
                        return date
                    }
                }
            }
        }

        return nil
    }

    // MARK: - 컨텍스트 기반 예상 시간

    /// 태스크 제목에서 예상 시간 추론
    private static func inferEstimatedTime(from input: String) -> Int? {
        let keywords: [(String, Int)] = [
            // 회의
            ("회의", 60),
            ("미팅", 60),
            ("meeting", 60),

            // 작성/문서
            ("보고서", 120),
            ("문서", 90),
            ("작성", 60),
            ("정리", 45),

            // 이메일
            ("이메일", 30),
            ("메일", 30),

            // 통화
            ("전화", 15),
            ("통화", 20),

            // 검토
            ("검토", 45),
            ("리뷰", 45),
            ("확인", 15),

            // 개발
            ("구현", 180),
            ("개발", 180),
            ("코딩", 120),
            ("버그수정", 60),
            ("디버깅", 90),

            // 학습
            ("공부", 120),
            ("학습", 90),
            ("읽기", 60),

            // 발표
            ("발표", 30),
            ("프레젠테이션", 30),
            ("PT", 30),

            // 준비
            ("준비", 60),

            // 짧은 작업
            ("확인", 10),
            ("체크", 10)
        ]

        let lowerInput = input.lowercased()
        for (keyword, minutes) in keywords {
            if lowerInput.contains(keyword.lowercased()) {
                return minutes
            }
        }

        return nil
    }

    // MARK: - 반복 패턴 감지

    /// "매일", "매주 월요일", "격주" 등 반복 패턴 감지
    static func extractRecurrencePattern(from input: String) -> String? {
        let patterns = [
            "매일",
            "매주",
            "격주",
            "매달",
            "매월",
            "매년",
            "매주 월요일",
            "매주 화요일",
            "매주 수요일",
            "매주 목요일",
            "매주 금요일"
        ]

        for pattern in patterns {
            if input.contains(pattern) {
                return pattern
            }
        }

        return nil
    }

    // MARK: - 태그 추출

    /// "#프로젝트", "#긴급" 등 해시태그 추출
    static func extractHashtags(from input: String) -> [String] {
        let pattern = "#([가-힣a-zA-Z0-9_]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let nsInput = input as NSString
        let matches = regex.matches(in: input, range: NSRange(location: 0, length: nsInput.length))

        return matches.compactMap { match in
            let range = match.range(at: 1)
            guard range.location != NSNotFound else { return nil }
            return nsInput.substring(with: range)
        }
    }
}
