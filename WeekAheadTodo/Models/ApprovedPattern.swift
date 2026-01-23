import Foundation
import SwiftData

@Model
final class ApprovedPattern {
    // MARK: - Identity
    @Attribute(.unique) var id: UUID
    var patternType: String  // PatternType.rawValue for Codable compatibility

    // MARK: - Pattern Metadata
    var approvedAt: Date
    var lastGeneratedTaskDate: Date?
    var detectedAt: Date
    var confidenceScore: Double

    // MARK: - Calendar Information
    var calendarTitles: [String]
    var primaryCalendar: String

    // MARK: - Recurrence Information
    var recurrenceFrequency: String  // RecurrenceFrequency.rawValue
    var recurrenceInterval: Int
    var recurrenceDaysOfWeek: [Int]?
    var nextOccurrenceDate: Date

    // MARK: - Task Generation Settings
    var taskTitle: String
    var estimatedMinutes: Int
    var leadTimeDays: Int
    var taskTypeRaw: String  // TaskType.rawValue

    // MARK: - State Management
    var isActive: Bool  // Enable/disable pattern
    var isUserModified: Bool  // Track if user edited the suggested values

    // MARK: - Sample Events (for reference)
    var sampleEventTitles: [String]
    var sampleEventDates: [Date]

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
