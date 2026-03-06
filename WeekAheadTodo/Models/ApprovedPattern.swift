import WeekAheadShared
import Foundation
import SwiftData

@Model
final class ApprovedPattern {
    // MARK: - Identity
    var id: UUID = UUID()
    var patternType: String = "weeklyFixedDay"

    // MARK: - Pattern Metadata
    var approvedAt: Date = Date()
    var lastGeneratedTaskDate: Date?
    var detectedAt: Date = Date()
    var confidenceScore: Double = 0.0

    // MARK: - Calendar Information
    var calendarTitles: [String] = []
    var primaryCalendar: String = ""

    // MARK: - Recurrence Information
    var recurrenceFrequency: String = "weekly"
    var recurrenceInterval: Int = 1
    var recurrenceDaysOfWeek: [Int]?
    var nextOccurrenceDate: Date = Date()

    // MARK: - Task Generation Settings
    var taskTitle: String = ""
    var estimatedMinutes: Int = 30
    var leadTimeDays: Int = 0
    var taskTypeRaw: String = "미리 가능"

    // MARK: - State Management
    var isActive: Bool = true
    var isUserModified: Bool = false
    /// 매주 있지만 요일이 고정되지 않아 사용자가 매번 직접 날짜를 지정해야 하는 패턴
    var isFlexibleSchedule: Bool = false

    // MARK: - Sample Events (for reference)
    var sampleEventTitles: [String] = []
    var sampleEventDates: [Date] = []

    /// 사용자가 직접 패턴을 수동 생성할 때 사용하는 초기화
    init(
        taskTitle: String,
        estimatedMinutes: Int,
        leadTimeDays: Int,
        taskType: TaskType,
        frequency: RecurrenceFrequency,
        daysOfWeek: [Int]?,
        nextOccurrenceDate: Date,
        isFlexibleSchedule: Bool = false
    ) {
        self.id = UUID()
        self.patternType = frequency == .daily ? PatternType.dailySameTime.rawValue : PatternType.weeklyFixedDay.rawValue
        self.approvedAt = Date()
        self.detectedAt = Date()
        self.confidenceScore = 1.0
        self.calendarTitles = []
        self.primaryCalendar = "수동 추가"
        self.recurrenceFrequency = frequency.rawValue
        self.recurrenceInterval = 1
        self.recurrenceDaysOfWeek = daysOfWeek
        self.nextOccurrenceDate = nextOccurrenceDate
        self.taskTitle = taskTitle
        self.estimatedMinutes = estimatedMinutes
        self.leadTimeDays = leadTimeDays
        self.taskTypeRaw = taskType.rawValue
        self.isActive = true
        self.isUserModified = true
        self.isFlexibleSchedule = isFlexibleSchedule
        self.sampleEventTitles = []
        self.sampleEventDates = []
    }

    init(from pattern: RecurrencePattern) {
        self.id = pattern.id
        self.patternType = pattern.type.rawValue
        self.approvedAt = Date()
        self.detectedAt = pattern.detectedAt
        self.confidenceScore = pattern.confidenceScore

        // Calendar info
        self.calendarTitles = pattern.calendarTitles
        self.primaryCalendar = pattern.primaryCalendar

        // Recurrence
        let rule = pattern.suggestedTask.recurrenceRule
        self.recurrenceFrequency = rule?.frequency.rawValue ?? "weekly"
        self.recurrenceInterval = rule?.interval ?? 1
        self.recurrenceDaysOfWeek = rule?.daysOfWeek
        self.nextOccurrenceDate = rule?.nextOccurrenceDate ?? Date()

        // Task settings
        self.taskTitle = pattern.suggestedTask.title
        self.estimatedMinutes = pattern.suggestedTask.estimatedMinutes
        self.leadTimeDays = pattern.suggestedTask.leadTimeDays
        self.taskTypeRaw = pattern.suggestedTask.taskType.rawValue

        // State
        self.isActive = true
        self.isUserModified = pattern.suggestedTask.userModified

        // Sample events (store first 5)
        self.sampleEventTitles = pattern.events.prefix(5).map { $0.title }
        self.sampleEventDates = pattern.events.prefix(5).map { $0.startDate }
    }

    // MARK: - Computed Properties

    var taskType: TaskType {
        TaskType(rawValue: taskTypeRaw) ?? .preparable
    }

    var patternTypeEnum: PatternType {
        PatternType(rawValue: patternType) ?? .weeklyFixedDay
    }

    var frequency: RecurrenceFrequency {
        RecurrenceFrequency(rawValue: recurrenceFrequency) ?? .weekly
    }

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

    // Calculate next occurrence based on frequency
    func calculateNextOccurrence() -> Date {
        let calendar = Calendar.current
        switch frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: recurrenceInterval, to: nextOccurrenceDate) ?? nextOccurrenceDate
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: recurrenceInterval, to: nextOccurrenceDate) ?? nextOccurrenceDate
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2 * recurrenceInterval, to: nextOccurrenceDate) ?? nextOccurrenceDate
        case .monthly:
            return calendar.date(byAdding: .month, value: recurrenceInterval, to: nextOccurrenceDate) ?? nextOccurrenceDate
        }
    }

    func updateNextOccurrence() {
        self.nextOccurrenceDate = calculateNextOccurrence()
    }
}
