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

        print("🔍 [PatternService] 현재 시각: \(now.formatted(date: .abbreviated, time: .shortened))")
        print("🔍 [PatternService] 5주 후: \(fiveWeeksFromNow.formatted(date: .abbreviated, time: .shortened))")

        // 모든 패턴 조회
        let allDescriptor = FetchDescriptor<ApprovedPattern>()
        let allPatterns = try modelContext.fetch(allDescriptor)
        print("📊 [PatternService] 전체 패턴 개수: \(allPatterns.count)")
        allPatterns.forEach { pattern in
            print("  - '\(pattern.taskTitle)': isActive=\(pattern.isActive), nextOccurrenceDate=\(pattern.nextOccurrenceDate.formatted(date: .abbreviated, time: .shortened)), lastGenerated=\(pattern.lastGeneratedTaskDate?.formatted(date: .abbreviated, time: .shortened) ?? "없음")")
        }

        // 앞으로 5주 이내 발생하는 활성 패턴 (중복 체크는 TaskViewModel에서)
        let descriptor = FetchDescriptor<ApprovedPattern>(
            predicate: #Predicate { pattern in
                pattern.isActive == true &&
                pattern.nextOccurrenceDate <= fiveWeeksFromNow
            }
        )
        let needingGeneration = try modelContext.fetch(descriptor)
        print("✅ [PatternService] Task 생성 대상 패턴: \(needingGeneration.count)개 (중복 체크 전)")
        needingGeneration.forEach { pattern in
            print("  ➡️ '\(pattern.taskTitle)' - \(pattern.nextOccurrenceDate.formatted(date: .abbreviated, time: .shortened))")
        }
        return needingGeneration
    }

    /// Mark pattern as having generated task
    func markTaskGenerated(for pattern: ApprovedPattern) throws {
        pattern.lastGeneratedTaskDate = Date()
        pattern.updateNextOccurrence()
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
