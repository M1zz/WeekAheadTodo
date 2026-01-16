import Foundation
import SwiftUI
import CloudKit

/// 앱의 핵심 비즈니스 로직을 담당하는 ViewModel
@MainActor
class TaskViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var tasks: [Task] = [] {
        didSet {
            saveTasks()
        }
    }

    @Published var projects: [Project] = [] {
        didSet {
            saveProjects()
        }
    }

    @Published var timeBlockManager: WeeklyTimeBlockManager
    @Published var dailyAvailableHours: Double = 6.0
    @Published var selectedDate: Date = Date()
    @Published var showingAddTask = false
    @Published var selectedHorizon: TimeHorizon? = nil

    // MARK: - Time Block Settings
    @Published var workHoursPerDay: Double = 9.0 {
        didSet {
            UserDefaults.standard.set(workHoursPerDay, forKey: workHoursKey)
        }
    }
    @Published var lunchBreakMinutes: Int = 60 {
        didSet {
            UserDefaults.standard.set(lunchBreakMinutes, forKey: lunchBreakKey)
        }
    }
    @Published var useCalendarForTimeBlocks: Bool = false {
        didSet {
            UserDefaults.standard.set(useCalendarForTimeBlocks, forKey: useCalendarKey)
        }
    }
    @Published var timeBlockCalendarIds: Set<String> = [] {
        didSet {
            if let encoded = try? JSONEncoder().encode(Array(timeBlockCalendarIds)) {
                UserDefaults.standard.set(encoded, forKey: timeBlockCalendarIdsKey)
            }
        }
    }

    // MARK: - Future Preparation Goal
    @Published var targetDaysAhead: Int = 7 {
        didSet {
            UserDefaults.standard.set(targetDaysAhead, forKey: targetDaysAheadKey)
        }
    }

    @Published var weekStartDay: Int = 1 {
        didSet {
            UserDefaults.standard.set(weekStartDay, forKey: "weekStartDay")
        }
    }

    // MARK: - CloudKit
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?

    private var container: CKContainer?
    private var database: CKDatabase?

    // Calendar reference for time block calculation
    weak var calendarViewModel: CalendarViewModel?

    // Notification service reference
    var notificationService: NotificationService?

    // MARK: - Persistence

    private let tasksKey = "SavedTasks"
    private let syncDateKey = "LastCloudSyncDate"
    private let workHoursKey = "WorkHoursPerDay"
    private let lunchBreakKey = "LunchBreakMinutes"
    private let useCalendarKey = "UseCalendarForTimeBlocks"
    private let timeBlockCalendarIdsKey = "TimeBlockCalendarIds"
    private let targetDaysAheadKey = "TargetDaysAhead"

    // MARK: - Initialization

    init() {
        // Initialize CloudKit (optional, may fail if not configured)
        do {
            self.container = CKContainer.default()
            self.database = container?.privateCloudDatabase
            print("✅ CloudKit initialized successfully")
        } catch {
            print("⚠️ CloudKit initialization failed: \(error)")
            print("⚠️ Cloud sync features will be disabled")
        }

        self.timeBlockManager = WeeklyTimeBlockManager(defaultDailyMinutes: 360)

        // Load settings from UserDefaults
        if let savedDate = UserDefaults.standard.object(forKey: syncDateKey) as? Date {
            self.lastSyncDate = savedDate
        }

        self.workHoursPerDay = UserDefaults.standard.object(forKey: workHoursKey) as? Double ?? 9.0
        self.lunchBreakMinutes = UserDefaults.standard.object(forKey: lunchBreakKey) as? Int ?? 60
        self.useCalendarForTimeBlocks = UserDefaults.standard.bool(forKey: useCalendarKey)
        self.targetDaysAhead = UserDefaults.standard.object(forKey: targetDaysAheadKey) as? Int ?? 7
        self.weekStartDay = UserDefaults.standard.object(forKey: "weekStartDay") as? Int ?? 1

        if let data = UserDefaults.standard.data(forKey: timeBlockCalendarIdsKey),
           let ids = try? JSONDecoder().decode([String].self, from: data) {
            self.timeBlockCalendarIds = Set(ids)
        }

        loadTasks()
        loadProjects()
        print("✅ TaskViewModel initialized")
    }

    private func saveTasks() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(tasks)
            UserDefaults.standard.set(data, forKey: tasksKey)
            print("✅ Tasks saved: \(tasks.count)개")

            // 태스크가 변경되면 알림 스케줄 갱신
            _Concurrency.Task {
                await updateNotificationSchedule()
            }
        } catch {
            print("❌ Failed to save tasks: \(error)")
        }
    }

    private func loadTasks() {
        guard let data = UserDefaults.standard.data(forKey: tasksKey) else {
            print("ℹ️ No saved tasks found")
            return
        }

        do {
            let decoder = JSONDecoder()
            tasks = try decoder.decode([Task].self, from: data)
            print("✅ Tasks loaded: \(tasks.count)개")
        } catch {
            print("❌ Failed to load tasks: \(error)")
            tasks = []
        }
    }

    // MARK: - Project Persistence

    private let projectsKey = "projects"

    private func saveProjects() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(projects)
            UserDefaults.standard.set(data, forKey: projectsKey)
            print("✅ Projects saved: \(projects.count)개")
        } catch {
            print("❌ Failed to save projects: \(error)")
        }
    }

    private func loadProjects() {
        guard let data = UserDefaults.standard.data(forKey: projectsKey) else {
            print("ℹ️ No saved projects found")
            return
        }

        do {
            let decoder = JSONDecoder()
            projects = try decoder.decode([Project].self, from: data)
            print("✅ Projects loaded: \(projects.count)개")
        } catch {
            print("❌ Failed to load projects: \(error)")
            projects = []
        }
    }

    // MARK: - Computed Properties
    
    /// 시간 지평선별로 그룹화된 태스크
    var tasksByHorizon: [TimeHorizon: [Task]] {
        Dictionary(grouping: tasks.filter { !$0.isCompleted }) { $0.currentHorizon }
    }
    
    /// 오늘 할 일 (역산 결과 기준) - 완료된 것 포함
    var todayTasks: [Task] {
        tasks
            .filter { $0.currentHorizon == .today }
            .sorted { $0.urgencyScore < $1.urgencyScore }
    }

    /// 오늘 할 일 중 미완료만
    var todayIncompleteTasks: [Task] {
        todayTasks.filter { !$0.isCompleted }
    }

    /// 이번 주 할 일 - 완료된 것 포함
    var thisWeekTasks: [Task] {
        tasks
            .filter { $0.currentHorizon == .thisWeek }
            .sorted { $0.effectiveStartDate < $1.effectiveStartDate }
    }

    /// 이번 주 할 일 중 미완료만
    var thisWeekIncompleteTasks: [Task] {
        thisWeekTasks.filter { !$0.isCompleted }
    }

    /// 다음 주 할 일 - 완료된 것 포함
    var nextWeekTasks: [Task] {
        tasks
            .filter { $0.currentHorizon == .nextWeek }
            .sorted { $0.effectiveStartDate < $1.effectiveStartDate }
    }

    /// 다음 주 할 일 중 미완료만
    var nextWeekIncompleteTasks: [Task] {
        nextWeekTasks.filter { !$0.isCompleted }
    }

    /// 언젠가 할 일 (다음 주 이후의 태스크)
    var somedayTasks: [Task] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let nextWeekEnd = calendar.date(byAdding: .day, value: 14, to: today)!

        return tasks
            .filter { $0.dueDate > nextWeekEnd }
            .sorted { $0.dueDate < $1.dueDate } // 마감일 가까운 순
    }

    /// 언젠가 할 일 중 미완료만
    var somedayIncompleteTasks: [Task] {
        somedayTasks.filter { !$0.isCompleted }
    }

    /// 미리 할 수 있는 태스크 (다음 주 이후 + preparable 타입)
    var preparableFutureTasks: [Task] {
        tasks
            .filter { 
                !$0.isCompleted && 
                $0.taskType == .preparable && 
                ($0.currentHorizon == .nextWeek || $0.currentHorizon == .later)
            }
            .sorted { $0.effectiveStartDate < $1.effectiveStartDate }
    }
    
    /// 오늘 가용 시간 (분)
    var todayAvailableMinutes: Int {
        Int(dailyAvailableHours * 60)
    }
    
    /// 오늘 사용된 시간 (분) - 미완료 태스크만
    var todayUsedMinutes: Int {
        todayIncompleteTasks.reduce(0) { $0 + $1.estimatedMinutes }
    }
    
    /// 오늘 남은 시간 (분)
    var todayRemainingMinutes: Int {
        todayAvailableMinutes - todayUsedMinutes
    }
    
    /// 오늘 용량 초과 여부
    var isTodayOverCapacity: Bool {
        todayRemainingMinutes < 0
    }
    
    /// 오늘 용량 사용률
    var todayUtilization: Double {
        guard todayAvailableMinutes > 0 else { return 0 }
        return Double(todayUsedMinutes) / Double(todayAvailableMinutes)
    }
    
    // MARK: - Task CRUD
    
    func addTask(_ task: Task) {
        tasks.append(task)
        allocateTaskToTimeBlock(task)
    }
    
    func addTaskWithSubtasks(mainTask: Task, template: TaskTemplate) {
        // 메인 태스크 추가 (role을 main으로 설정)
        var main = mainTask
        main.taskRole = .main
        tasks.append(main)

        // 템플릿 기반 준비 태스크 생성
        for subtask in template.subtasks {
            let sub = Task(
                title: subtask.title,
                dueDate: mainTask.dueDate,
                estimatedMinutes: subtask.estimatedMinutes,
                leadTimeDays: subtask.leadTimeDays,
                taskType: .preparable,
                taskRole: .preparation,              // 준비 태스크로 설정
                parentTaskId: main.id,
                mainTaskId: main.id,                 // 메인 태스크 연결
                targetDate: main.dueDate             // 타겟 날짜 설정
            )
            tasks.append(sub)
            allocateTaskToTimeBlock(sub)
        }
    }
    
    func toggleTaskCompletion(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            // Cycle through: notStarted -> inProgress -> completed -> notStarted
            switch tasks[index].status {
            case .notStarted:
                tasks[index].status = .inProgress
            case .inProgress:
                tasks[index].status = .completed
            case .completed:
                tasks[index].status = .notStarted
            }
        }
    }
    
    func deleteTask(_ task: Task) {
        deleteTasks([task])
    }

    /// 여러 태스크를 한 번에 삭제
    func deleteTasks(_ tasksToDelete: [Task]) {
        // 메인 태스크 삭제 시: 연결된 준비 태스크들도 함께 삭제
        // 준비 태스크 삭제 시: 해당 태스크만 삭제 (메인 태스크는 유지)
        var allTaskIdsToDelete: Set<UUID> = Set(tasksToDelete.map { $0.id })

        for task in tasksToDelete {
            if task.isMain {
                // 메인 태스크 삭제: 이 메인을 위한 준비 태스크들 찾기
                let preparationTaskIds = tasks
                    .filter { $0.mainTaskId == task.id }
                    .map { $0.id }
                allTaskIdsToDelete.formUnion(preparationTaskIds)
            }

            // 레거시 서브태스크도 함께 삭제 (parentTaskId 기반)
            let childTaskIds = tasks
                .filter { $0.parentTaskId == task.id }
                .map { $0.id }
            allTaskIdsToDelete.formUnion(childTaskIds)
        }

        // 태스크 삭제
        tasks.removeAll { allTaskIdsToDelete.contains($0.id) }

        // 시간 블록에서도 제거
        for i in 0..<timeBlockManager.blocks.count {
            timeBlockManager.blocks[i].allocatedTasks.removeAll { allTaskIdsToDelete.contains($0) }
        }
    }
    
    func updateTask(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        }
    }
    
    // MARK: - Time Block Management
    
    /// 태스크를 적절한 시간 블록에 배정
    private func allocateTaskToTimeBlock(_ task: Task) {
        let targetDate = task.effectiveStartDate
        
        if let blockIndex = timeBlockManager.blockIndex(for: targetDate) {
            timeBlockManager.blocks[blockIndex].allocatedTasks.append(task.id)
        }
    }
    
    /// 오늘 여유 시간에 미리 할 수 있는 일 추천
    func recommendPreparableTasks() -> [Task] {
        guard todayRemainingMinutes > 0 else { return [] }
        
        var recommendations: [Task] = []
        var remainingCapacity = todayRemainingMinutes
        
        for task in preparableFutureTasks {
            if task.estimatedMinutes <= remainingCapacity {
                recommendations.append(task)
                remainingCapacity -= task.estimatedMinutes
            }
            
            // 최대 3개까지만 추천
            if recommendations.count >= 3 {
                break
            }
        }
        
        return recommendations
    }
    
    /// 용량 초과 시 재배치 제안
    func suggestReallocation() -> [(task: Task, suggestedDate: Date)] {
        guard isTodayOverCapacity else { return [] }
        
        var suggestions: [(Task, Date)] = []
        var excessMinutes = -todayRemainingMinutes
        
        // 긴급도가 낮은 순서로 밀어내기
        let sortedTasks = todayTasks.sorted { $0.urgencyScore > $1.urgencyScore }
        
        for task in sortedTasks {
            guard excessMinutes > 0 else { break }
            
            // preparable 타입만 밀어내기 가능
            if task.taskType == .preparable {
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
                if let availableDate = timeBlockManager.earliestAvailableDate(for: task, allTasks: tasks, startingFrom: tomorrow) {
                    suggestions.append((task, availableDate))
                    excessMinutes -= task.estimatedMinutes
                }
            }
        }
        
        return suggestions
    }
    
    // MARK: - Weekly Overview
    
    /// 특정 날짜에 해야 할 태스크들
    func tasks(for date: Date) -> [Task] {
        let calendar = Calendar.current
        return tasks.filter { task in
            !task.isCompleted &&
            calendar.isDate(task.effectiveStartDate, inSameDayAs: date)
        }
    }
    
    /// 특정 날짜의 총 예상 시간
    func totalMinutes(for date: Date) -> Int {
        tasks(for: date).reduce(0) { $0 + $1.estimatedMinutes }
    }
    
    /// 앞으로 2주간 일별 워크로드
    func weeklyWorkload() -> [(date: Date, minutes: Int, capacity: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return (0..<14).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: today)!
            let minutes = totalMinutes(for: date)
            let capacity = timeBlockManager.block(for: date)?.availableMinutes ?? todayAvailableMinutes
            return (date, minutes, capacity)
        }
    }
    
    // MARK: - Calendar Pattern Integration

    /// 캘린더 패턴에서 Task 생성
    func createTaskFromPattern(_ pattern: RecurrencePattern) {
        let suggested = pattern.suggestedTask

        // 다음 발생 날짜 계산
        let nextOccurrence = suggested.recurrenceRule?.nextOccurrenceDate ?? Calendar.current.date(byAdding: .day, value: 7, to: Date())!

        // Task 생성 (캘린더 패턴 태스크는 메인 태스크)
        let task = Task(
            title: suggested.title,
            description: "캘린더 패턴에서 자동 생성됨",
            dueDate: nextOccurrence,
            estimatedMinutes: suggested.estimatedMinutes,
            leadTimeDays: suggested.leadTimeDays,
            taskType: suggested.taskType,
            taskRole: .main,  // 캘린더 패턴 태스크는 메인 태스크
            status: .notStarted
        )

        // 캘린더 관련 속성 설정
        var calendarTask = task
        calendarTask.isFromCalendarPattern = true
        calendarTask.patternId = pattern.id
        calendarTask.autoRecurring = suggested.recurrenceRule != nil

        // 원본 이벤트 ID 저장 (가장 최근 이벤트)
        if let latestEvent = pattern.events.sorted(by: { $0.startDate > $1.startDate }).first {
            calendarTask.calendarEventId = latestEvent.id
        }

        addTask(calendarTask)

        print("✅ 캘린더 패턴에서 Task 생성: \(calendarTask.title)")
    }

    /// 여러 패턴에서 Task 생성
    func createTasksFromPatterns(_ patterns: [RecurrencePattern]) {
        for pattern in patterns {
            createTaskFromPattern(pattern)
        }
    }

    /// 캘린더 기반 Task인지 확인
    func isCalendarTask(_ task: Task) -> Bool {
        return task.isFromCalendarPattern
    }

    /// 캘린더 기반 Task 목록
    var calendarTasks: [Task] {
        tasks.filter { $0.isFromCalendarPattern }
    }

    // MARK: - Auto Task Generation

    /// Generate tasks from approved patterns (called on app launch or periodic check)
    func generateTasksFromApprovedPatterns(patternService: PatternManagementService) async {
        print("🔄 [TaskViewModel] generateTasksFromApprovedPatterns 시작")
        do {
            let patternsNeedingTasks = try patternService.getPatternsNeedingTaskGeneration()

            print("📋 [TaskViewModel] Found \(patternsNeedingTasks.count) patterns needing task generation")

            for pattern in patternsNeedingTasks {
                print("🔍 [TaskViewModel] Pattern: '\(pattern.taskTitle)', frequency: \(pattern.frequency.rawValue)")

                // 앞으로 5주간의 발생일을 계산
                let calendar = Calendar.current
                var currentOccurrence = pattern.nextOccurrenceDate
                let fiveWeeksFromNow = calendar.date(byAdding: .day, value: 35, to: Date())!

                var occurrenceCount = 0
                while currentOccurrence <= fiveWeeksFromNow && occurrenceCount < 10 {
                    print("  📅 Checking occurrence: \(currentOccurrence.formatted(date: .abbreviated, time: .omitted))")

                    // 해당 패턴과 날짜에 대한 Task가 이미 존재하는지 확인
                    let alreadyExists = tasks.contains { task in
                        task.patternId == pattern.id &&
                        calendar.isDate(task.dueDate, inSameDayAs: currentOccurrence)
                    }

                    if !alreadyExists {
                        // Create task (패턴에서 생성되는 태스크는 메인 태스크)
                        let task = Task(
                            title: pattern.taskTitle,
                            description: "자동 생성됨 (반복 패턴)",
                            dueDate: currentOccurrence,
                            estimatedMinutes: pattern.estimatedMinutes,
                            leadTimeDays: pattern.leadTimeDays,
                            taskType: pattern.taskType,
                            taskRole: .main,  // 패턴 태스크는 메인 태스크
                            status: .notStarted
                        )

                        var calendarTask = task
                        calendarTask.isFromCalendarPattern = true
                        calendarTask.patternId = pattern.id
                        calendarTask.autoRecurring = true

                        addTask(calendarTask)
                        let dueDateStr = task.dueDate.formatted(date: .abbreviated, time: .omitted)
                        let startDateStr = task.effectiveStartDate.formatted(date: .abbreviated, time: .omitted)
                        print("  ✅ Created task - dueDate: \(dueDateStr), effectiveStartDate: \(startDateStr)")
                    } else {
                        print("  ⏭️ Task already exists, skipping")
                    }

                    // 다음 발생일 계산
                    switch pattern.frequency {
                    case .daily:
                        currentOccurrence = calendar.date(byAdding: .day, value: pattern.recurrenceInterval, to: currentOccurrence) ?? currentOccurrence
                    case .weekly:
                        currentOccurrence = calendar.date(byAdding: .weekOfYear, value: pattern.recurrenceInterval, to: currentOccurrence) ?? currentOccurrence
                    case .biweekly:
                        currentOccurrence = calendar.date(byAdding: .weekOfYear, value: 2 * pattern.recurrenceInterval, to: currentOccurrence) ?? currentOccurrence
                    case .monthly:
                        currentOccurrence = calendar.date(byAdding: .month, value: pattern.recurrenceInterval, to: currentOccurrence) ?? currentOccurrence
                    }

                    occurrenceCount += 1
                }
            }

            print("📊 [TaskViewModel] 최종 Task 개수: \(tasks.count)")
        } catch {
            print("❌ [TaskViewModel] Error generating tasks from patterns: \(error)")
        }
    }

    // MARK: - Preparation Task Management

    /// 특정 메인 태스크의 준비 태스크들 조회
    func preparationTasks(for mainTask: Task) -> [Task] {
        tasks.filter { $0.mainTaskId == mainTask.id && $0.isPreparation }
            .sorted { $0.effectiveStartDate < $1.effectiveStartDate }
    }

    /// 준비 태스크가 연결된 메인 태스크 조회
    func mainTask(for preparationTask: Task) -> Task? {
        guard let mainId = preparationTask.mainTaskId else { return nil }
        return tasks.first { $0.id == mainId }
    }

    /// 메인 태스크의 준비도 계산 (완료된 준비 태스크 비율)
    func preparationProgress(for mainTask: Task) -> (completed: Int, total: Int, percentage: Int) {
        let preps = preparationTasks(for: mainTask)
        guard !preps.isEmpty else { return (0, 0, 0) }

        let completed = preps.filter { $0.isCompleted }.count
        let total = preps.count
        let percentage = Int(Double(completed) / Double(total) * 100)

        return (completed, total, percentage)
    }

    /// 오늘 완료한 태스크들이 준비하는 미래 태스크들
    func futureTasksPreparedToday() -> [(preparationTask: Task, mainTask: Task)] {
        let completedToday = tasks.filter { task in
            task.isCompleted &&
            task.isPreparation &&
            Calendar.current.isDateInToday(task.createdAt) // 오늘 완료한 것만
        }

        return completedToday.compactMap { prep in
            guard let main = mainTask(for: prep) else { return nil }
            return (prep, main)
        }
    }

    // MARK: - Cloud Sync

    /// 클라우드에 저장
    func saveToCloud() async throws {
        guard let database = database else {
            throw NSError(domain: "CloudKit", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "CloudKit이 초기화되지 않았습니다. iCloud 설정을 확인하세요."
            ])
        }

        print("☁️ Starting cloud save...")
        isSyncing = true
        syncError = nil

        defer { isSyncing = false }

        // Delete existing records first
        try await deleteAllCloudRecords()

        // Convert tasks to CKRecords and save
        let records = tasks.map { taskToCKRecord($0) }
        for batch in records.chunked(into: 200) {
            try await saveBatch(batch)
        }

        // Update last sync date
        lastSyncDate = Date()
        UserDefaults.standard.set(lastSyncDate, forKey: syncDateKey)

        print("☁️ Successfully saved \(tasks.count) tasks to cloud")
    }

    /// 클라우드에서 복원
    func restoreFromCloud() async throws {
        guard let database = database else {
            throw NSError(domain: "CloudKit", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "CloudKit이 초기화되지 않았습니다. iCloud 설정을 확인하세요."
            ])
        }

        print("☁️ Starting cloud restore...")
        isSyncing = true
        syncError = nil

        defer { isSyncing = false }

        let query = CKQuery(recordType: "Task", predicate: NSPredicate(value: true))
        var cloudTasks: [Task] = []

        let (results, _) = try await fetchRecords(query: query)
        cloudTasks = results

        tasks = cloudTasks
        lastSyncDate = Date()
        UserDefaults.standard.set(lastSyncDate, forKey: syncDateKey)

        print("✅ Restored \(cloudTasks.count) tasks from cloud")
    }

    /// 데이터 초기화 (로컬 + 클라우드)
    func resetAllData() async throws {
        tasks = []
        UserDefaults.standard.removeObject(forKey: tasksKey)
        try await deleteAllCloudRecords()
        print("✅ All data has been reset")
    }

    /// 로컬 데이터만 초기화
    func resetLocalData() {
        tasks = []
        UserDefaults.standard.removeObject(forKey: tasksKey)
        print("✅ Local data has been reset")
    }

    // MARK: - CloudKit Helper Methods

    private func saveBatch(_ records: [CKRecord]) async throws {
        guard let database = database else {
            throw NSError(domain: "CloudKit", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "CloudKit database not available"
            ])
        }
        try await database.modifyRecords(saving: records, deleting: [])
    }

    private func deleteAllCloudRecords() async throws {
        guard let database = database else { return }

        do {
            let query = CKQuery(recordType: "Task", predicate: NSPredicate(value: true))
            let (recordIDs, _) = try await fetchRecordIDs(query: query)

            guard !recordIDs.isEmpty else { return }

            for batch in recordIDs.chunked(into: 200) {
                try await database.modifyRecords(saving: [], deleting: batch)
            }
        } catch let error as CKError {
            // "Unknown Item" 에러는 레코드가 없다는 의미이므로 무시
            if error.code == .unknownItem {
                print("⚠️ No Task records found in CloudKit (this is normal if you haven't saved to cloud yet)")
                return
            }
            throw error
        }
    }

    private func fetchRecords(query: CKQuery) async throws -> ([Task], CKQueryOperation.Cursor?) {
        guard let database = database else {
            throw NSError(domain: "CloudKit", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "CloudKit database not available"
            ])
        }

        let (results, cursor) = try await database.records(matching: query)
        let tasks = results.compactMap { _, result in
            try? result.get()
        }.compactMap { ckRecordToTask($0) }
        return (tasks, cursor)
    }

    private func fetchRecordIDs(query: CKQuery) async throws -> ([CKRecord.ID], CKQueryOperation.Cursor?) {
        guard let database = database else {
            throw NSError(domain: "CloudKit", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "CloudKit database not available"
            ])
        }

        let (results, cursor) = try await database.records(matching: query, desiredKeys: [])
        let ids = results.map { id, _ in id }
        return (ids, cursor)
    }

    private func taskToCKRecord(_ task: Task) -> CKRecord {
        let recordID = CKRecord.ID(recordName: task.id.uuidString)
        let record = CKRecord(recordType: "Task", recordID: recordID)

        record["title"] = task.title as CKRecordValue
        record["taskDescription"] = task.description as CKRecordValue
        record["dueDate"] = task.dueDate as CKRecordValue
        record["estimatedMinutes"] = task.estimatedMinutes as CKRecordValue
        record["leadTimeDays"] = task.leadTimeDays as CKRecordValue
        record["taskType"] = task.taskType.rawValue as CKRecordValue
        record["taskRole"] = task.taskRole.rawValue as CKRecordValue
        record["status"] = task.status.rawValue as CKRecordValue
        record["priority"] = task.priority.rawValue as CKRecordValue
        record["createdAt"] = task.createdAt as CKRecordValue

        if let parentId = task.parentTaskId {
            record["parentTaskId"] = parentId.uuidString as CKRecordValue
        }
        if let mainId = task.mainTaskId {
            record["mainTaskId"] = mainId.uuidString as CKRecordValue
        }
        if let targetDate = task.targetDate {
            record["targetDate"] = targetDate as CKRecordValue
        }

        return record
    }

    private func ckRecordToTask(_ record: CKRecord) -> Task? {
        guard
            let title = record["title"] as? String,
            let dueDate = record["dueDate"] as? Date,
            let estimatedMinutes = record["estimatedMinutes"] as? Int,
            let leadTimeDays = record["leadTimeDays"] as? Int,
            let taskTypeRaw = record["taskType"] as? String,
            let taskType = TaskType(rawValue: taskTypeRaw),
            let taskRoleRaw = record["taskRole"] as? String,
            let taskRole = TaskRole(rawValue: taskRoleRaw),
            let statusRaw = record["status"] as? String,
            let status = TaskStatus(rawValue: statusRaw),
            let createdAt = record["createdAt"] as? Date
        else {
            return nil
        }

        let taskDescription = record["taskDescription"] as? String ?? ""
        let parentTaskId = (record["parentTaskId"] as? String).flatMap { UUID(uuidString: $0) }
        let mainTaskId = (record["mainTaskId"] as? String).flatMap { UUID(uuidString: $0) }
        let targetDate = record["targetDate"] as? Date

        // priority는 optional로 처리 (기존 레코드 호환성)
        let priorityRaw = record["priority"] as? String
        let priority = priorityRaw.flatMap { TaskPriority(rawValue: $0) } ?? .normal

        return Task(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            title: title,
            description: taskDescription,
            dueDate: dueDate,
            estimatedMinutes: estimatedMinutes,
            leadTimeDays: leadTimeDays,
            taskType: taskType,
            taskRole: taskRole,
            status: status,
            priority: priority,
            parentTaskId: parentTaskId,
            mainTaskId: mainTaskId,
            targetDate: targetDate
        )
    }

    // MARK: - Utilities

    func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60

        if hours > 0 && mins > 0 {
            return "\(hours)시간 \(mins)분"
        } else if hours > 0 {
            return "\(hours)시간"
        } else {
            return "\(mins)분"
        }
    }

    // MARK: - Calendar-Based Time Block Calculation

    /// 캘린더 이벤트를 기반으로 타임 블록 업데이트
    /// - 근무 시간 - 캘린더 이벤트 시간 - 점심시간 = 실제 가용 시간
    func updateTimeBlocksWithCalendar() {
        guard useCalendarForTimeBlocks else {
            print("ℹ️ [TaskViewModel] 캘린더 기반 타임 블록이 비활성화됨")
            // 캘린더를 사용하지 않으면 기본 설정 사용
            updateTimeBlocksWithFixedHours()
            return
        }

        guard !timeBlockCalendarIds.isEmpty else {
            print("⚠️ [TaskViewModel] 타임 블록용 캘린더가 선택되지 않음")
            updateTimeBlocksWithFixedHours()
            return
        }

        guard let calendarVM = calendarViewModel else {
            print("⚠️ [TaskViewModel] CalendarViewModel 참조 없음")
            updateTimeBlocksWithFixedHours()
            return
        }

        print("📊 [TaskViewModel] 캘린더 기반 타임 블록 업데이트 시작")

        let workMinutes = Int(workHoursPerDay * 60)

        for i in 0..<timeBlockManager.blocks.count {
            let date = timeBlockManager.blocks[i].date

            // 캘린더 이벤트 시간 가져오기
            let eventMinutes = calendarVM.calendarService.calculateEventDuration(
                for: date,
                calendarIdentifiers: timeBlockCalendarIds
            )

            // 실제 가용 시간 = 근무 시간 - 캘린더 이벤트 - 점심시간
            let availableMinutes = max(0, workMinutes - eventMinutes - lunchBreakMinutes)

            timeBlockManager.blocks[i].availableMinutes = availableMinutes

            print("  \(date.formatted(date: .abbreviated, time: .omitted)): 근무 \(workMinutes)분 - 일정 \(eventMinutes)분 - 점심 \(lunchBreakMinutes)분 = 가용 \(availableMinutes)분")
        }

        print("✅ [TaskViewModel] 타임 블록 업데이트 완료")
    }

    /// 고정된 시간으로 타임 블록 업데이트 (캘린더 미사용)
    private func updateTimeBlocksWithFixedHours() {
        let fixedMinutes = Int(dailyAvailableHours * 60)

        for i in 0..<timeBlockManager.blocks.count {
            timeBlockManager.blocks[i].availableMinutes = fixedMinutes
        }

        print("✅ [TaskViewModel] 고정 시간으로 타임 블록 업데이트: \(fixedMinutes)분/일")
    }

    /// 캘린더 ViewModel 연결
    func setCalendarViewModel(_ calendarVM: CalendarViewModel) {
        self.calendarViewModel = calendarVM
        print("✅ [TaskViewModel] CalendarViewModel 연결됨")

        // 연결 후 즉시 타임 블록 업데이트
        if useCalendarForTimeBlocks {
            updateTimeBlocksWithCalendar()
        }
    }

    // MARK: - Notification Management

    /// NotificationService 연결
    func setNotificationService(_ service: NotificationService) {
        self.notificationService = service
        print("✅ [TaskViewModel] NotificationService 연결됨")

        // 연결 후 즉시 알림 스케줄 업데이트
        _Concurrency.Task {
            await updateNotificationSchedule()
        }
    }

    /// 알림 스케줄 갱신
    func updateNotificationSchedule() async {
        guard let service = notificationService else {
            print("ℹ️ [TaskViewModel] NotificationService가 연결되지 않음")
            return
        }

        await service.scheduleNotifications(for: tasks)
    }

    /// 알림 기능 활성화/비활성화
    func setNotificationEnabled(_ enabled: Bool) {
        notificationService?.setNotificationEnabled(enabled)
    }

    /// 알림 권한 요청
    func requestNotificationAuthorization() async throws {
        guard let service = notificationService else {
            throw NSError(domain: "TaskViewModel", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "NotificationService가 초기화되지 않았습니다."
            ])
        }

        try await service.requestAuthorization()
    }

    // MARK: - Project Management

    func addProject(_ project: Project) {
        projects.append(project)
    }

    func deleteProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        // 프로젝트에 속한 태스크들의 projectId 제거
        for i in tasks.indices {
            if tasks[i].projectId == project.id {
                tasks[i].projectId = nil
            }
        }
    }

    func updateProject(_ project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        }
    }

    func tasks(for projectId: UUID) -> [Task] {
        tasks.filter { $0.projectId == projectId }
    }

    func incompleteTasks(for projectId: UUID) -> [Task] {
        tasks.filter { $0.projectId == projectId && !$0.isCompleted }
    }
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
