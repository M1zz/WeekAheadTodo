import WeekAheadShared
import Foundation
import SwiftUI

// MARK: - Week Section 정의

/// 마크다운에서 파싱된 Week/Day 섹션
enum WeekSection: Equatable, Hashable {
    case specific(week: Int, day: Int?)  // Week 1, Week 1 Day 2
    case week0                          // 이번 주 (기본)
    case week1_2                        // 1-2주
    case week3                          // 3주

    /// 오늘로부터 며칠 뒤에 due date를 설정할지
    func daysFromNow(startDate: Date = Date()) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: startDate)

        switch self {
        case .specific(let week, let day):
            // Day 번호 - 1 = 시작일로부터의 offset
            // Day 1 = 시작일 (0일 후), Day 2 = 시작일 + 1일, Day 8 = 시작일 + 7일
            // Day 0 = 시작일 - 1일 (준비단계)
            if let day = day {
                return day - 1
            } else {
                // Day 정보가 없는 경우 (실제로는 발생하지 않음)
                return week * 7
            }

        case .week0:
            return -1  // 준비단계 - 시작일 전날
        case .week1_2:
            return 10  // 1-2주 평균
        case .week3:
            return 21  // 3주
        }
    }

    /// UI 표시용 이름
    var displayName: String {
        switch self {
        case .specific(let week, let day):
            if let day = day {
                // Day 0 또는 Week 0은 준비단계
                if day == 0 || week == 0 {
                    return "준비단계 (Day \(day))"
                }
                return "Week \(week) Day \(day)"
            } else {
                if week == 0 {
                    return "준비단계"
                }
                return "Week \(week)"
            }
        case .week0:
            return "준비단계"
        case .week1_2:
            return "Week 1-2"
        case .week3:
            return "Week 3"
        }
    }
}

// MARK: - 파싱 결과 구조체

/// 파싱된 개별 태스크 (편집 가능)
class ParsedTask: ObservableObject, Identifiable {
    let id = UUID()
    let title: String
    @Published var dueDate: Date
    @Published var estimatedMinutes: Int
    @Published var leadTimeDays: Int
    @Published var isCompleted: Bool
    let weekSection: WeekSection
    let originalLine: Int

    init(
        title: String,
        dueDate: Date,
        estimatedMinutes: Int = 30,
        leadTimeDays: Int = 0,
        isCompleted: Bool = false,
        weekSection: WeekSection,
        originalLine: Int = 0
    ) {
        self.title = title
        self.dueDate = dueDate
        self.estimatedMinutes = estimatedMinutes
        self.leadTimeDays = leadTimeDays
        self.isCompleted = isCompleted
        self.weekSection = weekSection
        self.originalLine = originalLine
    }
}

/// 파싱 에러
struct ParseError {
    let line: Int
    let message: String
}

/// 마크다운 파싱 결과
struct MarkdownParseResult {
    let tasks: [ParsedTask]
    let errors: [ParseError]
    let startDate: Date
}

// MARK: - Markdown Parser

/// 마크다운 Todo 리스트 파서
class MarkdownParser {

    // MARK: - Public Methods

    /// 마크다운 텍스트를 파싱하여 태스크 리스트와 에러를 반환
    func parse(_ markdown: String, startDate: Date = Date()) -> MarkdownParseResult {
        var tasks: [ParsedTask] = []
        var errors: [ParseError] = []
        var currentSection: WeekSection = .week0  // 기본값
        var currentWeek: Int? = nil  // 현재 Week 번호 추적

        let lines = markdown.components(separatedBy: .newlines)
        let calendar = Calendar.current
        let baseDate = calendar.startOfDay(for: startDate)

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // 빈 줄은 건너뛰기
            guard !trimmedLine.isEmpty else { continue }

            // Week/Day 섹션 감지
            if let (section, week) = detectWeekDaySection(trimmedLine) {
                currentSection = section
                currentWeek = week
                continue
            }

            // 체크박스 항목 파싱
            if let (title, isCompleted) = parseCheckboxItem(trimmedLine) {
                // 제목이 빈 문자열인지 확인
                if title.isEmpty {
                    errors.append(ParseError(
                        line: lineNumber,
                        message: "빈 태스크 제목"
                    ))
                    continue
                }

                // Due date 계산
                let daysOffset = currentSection.daysFromNow(startDate: baseDate)
                guard let dueDate = calendar.date(byAdding: .day, value: daysOffset, to: baseDate) else {
                    errors.append(ParseError(
                        line: lineNumber,
                        message: "날짜 계산 실패"
                    ))
                    continue
                }

                let task = ParsedTask(
                    title: title,
                    dueDate: dueDate,
                    estimatedMinutes: 30,
                    leadTimeDays: 0,
                    isCompleted: isCompleted,
                    weekSection: currentSection,
                    originalLine: lineNumber
                )

                tasks.append(task)
            }
        }

        return MarkdownParseResult(tasks: tasks, errors: errors, startDate: baseDate)
    }

    // MARK: - Private Methods

    /// Week 및 Day 섹션 헤더를 감지하여 (WeekSection, week번호) 튜플 반환
    private func detectWeekDaySection(_ line: String) -> (WeekSection, Int?)? {
        // 헤더가 아니면 nil 반환
        guard line.hasPrefix("#") else { return nil }

        // 헤더 마커(#)와 공백 제거
        let headerText = line
            .replacingOccurrences(of: "^#{1,6}\\s*", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
            .lowercased()

        // Month 및 Week 섹션은 무시 (Day만 파싱)
        if headerText.range(of: "month", options: .caseInsensitive) != nil {
            return nil
        }

        if headerText.range(of: "week", options: .caseInsensitive) != nil {
            return nil
        }

        // Day X 패턴만 파싱 (일자별 처리)
        if let dayMatch = headerText.range(of: "day\\s*(\\d+)", options: .regularExpression) {
            let matched = String(headerText[dayMatch])
            if let dayNum = extractNumber(from: matched, pattern: "day\\s*(\\d+)") {
                // Day 번호로 Week 자동 계산
                // Day 1-7 → Week 1, Day 8-14 → Week 2, Day 15-21 → Week 3
                let weekNum = (dayNum + 6) / 7
                return (.specific(week: weekNum, day: dayNum), weekNum)
            }
        }

        return nil
    }

    /// 정규식에서 숫자 추출
    private func extractNumber(from text: String, pattern: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }

        let nsString = text as NSString
        let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))

        guard let match = results.first, match.numberOfRanges > 1 else {
            return nil
        }

        let numberRange = match.range(at: 1)
        let numberString = nsString.substring(with: numberRange)
        return Int(numberString)
    }

    /// 체크박스 항목을 파싱하여 (제목, 완료여부) 튜플 반환
    private func parseCheckboxItem(_ line: String) -> (title: String, isCompleted: Bool)? {
        // 정규식: - [ ] 또는 - [x] 또는 - [X]
        // 들여쓰기도 허용
        let pattern = "^\\s*-\\s*\\[([\\sxX])\\]\\s*(.+)$"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }

        let nsString = line as NSString
        let results = regex.matches(in: line, options: [], range: NSRange(location: 0, length: nsString.length))

        guard let match = results.first else {
            return nil
        }

        // 체크 상태 추출 ([ ], [x], [X])
        let checkmarkRange = match.range(at: 1)
        let checkmark = nsString.substring(with: checkmarkRange)
        let isCompleted = checkmark.lowercased() == "x"

        // 제목 추출
        let titleRange = match.range(at: 2)
        let title = nsString.substring(with: titleRange)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // 제목이 너무 길면 잘라내기 (200자 제한)
        let maxLength = 200
        let finalTitle = title.count > maxLength
            ? String(title.prefix(maxLength)) + "..."
            : title

        return (finalTitle, isCompleted)
    }
}
