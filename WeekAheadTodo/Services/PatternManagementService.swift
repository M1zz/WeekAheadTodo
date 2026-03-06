import WeekAheadShared
import Foundation
import SwiftData

@MainActor
class PatternManagementService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - CRUD Operations

    /// Save approved pattern to SwiftData
    func saveApprovedPattern(_ pattern: RecurrencePattern) throws {
        let approvedPattern = ApprovedPattern(from: pattern)
        modelContext.insert(approvedPattern)
        try modelContext.save()
    }

    /// Fetch all approved patterns
    func fetchAllPatterns() throws -> [ApprovedPattern] {
        let descriptor = FetchDescriptor<ApprovedPattern>(
            sortBy: [SortDescriptor(\.approvedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetch active patterns only
    func fetchActivePatterns() throws -> [ApprovedPattern] {
        let descriptor = FetchDescriptor<ApprovedPattern>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\.nextOccurrenceDate)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetch patterns by calendar
    func fetchPatterns(forCalendar calendar: String) throws -> [ApprovedPattern] {
        let descriptor = FetchDescriptor<ApprovedPattern>(
            predicate: #Predicate { pattern in
                pattern.primaryCalendar == calendar
            }
        )
        return try modelContext.fetch(descriptor)
    }

    /// Update pattern
    func updatePattern(_ pattern: ApprovedPattern) throws {
        pattern.isUserModified = true
        try modelContext.save()
    }

    /// Toggle pattern active state
    func togglePatternActive(_ pattern: ApprovedPattern) throws {
        pattern.isActive.toggle()
        try modelContext.save()
    }

    /// Delete pattern
    func deletePattern(_ pattern: ApprovedPattern) throws {
        modelContext.delete(pattern)
        try modelContext.save()
    }

    // MARK: - Task Generation

    /// Get patterns that need task generation
    func getPatternsNeedingTaskGeneration() throws -> [ApprovedPattern] {
        let now = Date()
        let fiveWeeksFromNow = Calendar.current.date(byAdding: .day, value: 35, to: now)!


        // 모든 패턴 조회
        let allDescriptor = FetchDescriptor<ApprovedPattern>()
        let allPatterns = try modelContext.fetch(allDescriptor)
        allPatterns.forEach { pattern in
        }

        // 앞으로 5주 이내 발생하는 활성 패턴 (중복 체크는 TaskViewModel에서)
        let descriptor = FetchDescriptor<ApprovedPattern>(
            predicate: #Predicate { pattern in
                pattern.isActive == true &&
                pattern.nextOccurrenceDate <= fiveWeeksFromNow
            }
        )
        let needingGeneration = try modelContext.fetch(descriptor)
        needingGeneration.forEach { pattern in
        }
        return needingGeneration
    }

    /// Mark pattern as having generated task
    func markTaskGenerated(for pattern: ApprovedPattern) throws {
        pattern.lastGeneratedTaskDate = Date()
        if pattern.isFlexibleSchedule {
            // 유동 일정: 다음 날짜를 자동 계산하지 않고 사용자가 직접 설정하도록 대기
            pattern.isActive = false
        } else {
            pattern.updateNextOccurrence()
        }
        try modelContext.save()
    }

    /// 유동 패턴의 다음 발생일을 사용자가 직접 설정하고 활성화
    func setNextOccurrence(for pattern: ApprovedPattern, date: Date) throws {
        pattern.nextOccurrenceDate = date
        pattern.isActive = true
        try modelContext.save()
    }

    // MARK: - Statistics

    func getPatternCount() throws -> Int {
        let descriptor = FetchDescriptor<ApprovedPattern>()
        return try modelContext.fetchCount(descriptor)
    }

    func getActivePatternCount() throws -> Int {
        let descriptor = FetchDescriptor<ApprovedPattern>(
            predicate: #Predicate { $0.isActive == true }
        )
        return try modelContext.fetchCount(descriptor)
    }
}
