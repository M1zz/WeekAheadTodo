import Foundation
import SwiftUI
import CloudKit
import Combine

/// 앱의 핵심 비즈니스 로직을 담당하는 ViewModel
@MainActor
class TaskViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var tasks: [Task] = [] {
        didSet {
            saveTasks()
            triggerAutoBackup()
        }
    }

    @Published var projects: [Project] = [] {
        didSet {
            saveProjects()
            triggerAutoBackup()
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

    // MARK: - Calendar Display Settings
    @Published var calendarStartHour: Int = 6 {
        didSet {
            UserDefaults.standard.set(calendarStartHour, forKey: calendarStartHourKey)
        }
    }

    @Published var calendarEndHour: Int = 22 {
        didSet {
            UserDefaults.standard.set(calendarEndHour, forKey: calendarEndHourKey)
        }
    }

    // MARK: - Drag Preview
    @Published var dragPreview: DragPreviewInfo? = nil
    @Published var currentDraggingTaskId: UUID? = nil  // 현재 드래그 중인 태스크 ID

    // MARK: - CloudKit
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var isAutoBackupEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isAutoBackupEnabled, forKey: autoBackupEnabledKey)
        }
    }
    @Published var lastAutoBackupDate: Date?

    // MARK: - Checkin
    @Published var pendingCheckinTaskId: UUID? = nil  // 체크인 UI 표시 대상 태스크

    private var container: CKContainer?
    private var database: CKDatabase?

    // MARK: - Auto Backup
    private var autoBackupTimer: Timer?
    private var lastChangeDate: Date?
    private let autoBackupDelay: TimeInterval = 10.0 // 10초 후 자동 백업

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
    private let calendarStartHourKey = "CalendarStartHour"
    private let calendarEndHourKey = "CalendarEndHour"
    private let autoBackupEnabledKey = "AutoBackupEnabled"

    // MARK: - Initialization

    init() {
        print("🚀 [TaskViewModel.init] 시작")

        // Initialize CloudKit (optional, may fail if not configured)
        // iOS와 같은 Container 사용 (명시적 지정)
        self.container = CKContainer(identifier: "iCloud.com.weekahead.todo")
        self.database = container?.privateCloudDatabase
        print("✅ [macOS TaskViewModel.init] CloudKit initialized successfully")
        print("   Container ID: \(container?.containerIdentifier ?? "nil")")
        print("   Database: privateCloudDatabase")

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
        self.calendarStartHour = UserDefaults.standard.object(forKey: calendarStartHourKey) as? Int ?? 6
        self.calendarEndHour = UserDefaults.standard.object(forKey: calendarEndHourKey) as? Int ?? 22

        if let data = UserDefaults.standard.data(forKey: timeBlockCalendarIdsKey),
           let ids = try? JSONDecoder().decode([String].self, from: data) {
            self.timeBlockCalendarIds = Set(ids)
        }

        // Auto backup 설정 로드 (기본값: true)
        self.isAutoBackupEnabled = UserDefaults.standard.object(forKey: autoBackupEnabledKey) as? Bool ?? true
        print("   자동 백업: \(isAutoBackupEnabled ? "활성화" : "비활성화")")

        print("   📂 loadTasks() 호출...")
        loadTasks()
        print("   📂 loadProjects() 호출...")
        loadProjects()

        // 체크인 관련 옵저버 등록
        setupCheckinObservers()

        print("✅ [TaskViewModel.init] TaskViewModel initialized")
        print("   최종 태스크 개수: \(tasks.count)")
        print("   최종 프로젝트 개수: \(projects.count)")

        // 태스크 시간 데이터 마이그레이션 (scheduledStartTime 기반으로 dueDate 동기화)
        migrateTaskTimes()
    }

    // MARK: - Task Time Migration

    /// 캘린더 배치 정보를 기반으로 dueDate를 동기화
    /// scheduledStartTime이 설정된 경우, dueDate = scheduledStartTime + estimatedMinutes로 자동 계산
    private func migrateTaskTimes() {
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔄 [TaskViewModel] 태스크 시간 데이터 마이그레이션 시작")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        var migrationCount = 0
        let calendar = Calendar.current

        for index in tasks.indices {
            let task = tasks[index]

            // scheduledStartTime이 있으면 dueDate를 재계산
            if let startTime = task.scheduledStartTime {
                let calculatedDueDate = calendar.date(byAdding: .minute, value: task.estimatedMinutes, to: startTime) ?? startTime

                // dueDate가 계산된 값과 다르면 동기화
                if !calendar.isDate(task.dueDate, equalTo: calculatedDueDate, toGranularity: .minute) {
                    print("   🔧 [\(task.title)]")
                    print("      scheduledStartTime: \(formatDate(startTime))")
                    print("      estimatedMinutes: \(task.estimatedMinutes)분")
                    print("      기존 dueDate: \(formatDate(task.dueDate))")
                    print("      새 dueDate: \(formatDate(calculatedDueDate))")

                    tasks[index].dueDate = calculatedDueDate
                    migrationCount += 1
                }
            }
            // scheduledStartTime이 없고 dueDate가 자정(00:00)인 경우
            else if isDueDateMidnight(task.dueDate) {
                // dueDate에서 estimatedMinutes를 빼서 scheduledStartTime 생성
                let calculatedStartTime = calendar.date(byAdding: .minute, value: -task.estimatedMinutes, to: task.dueDate) ?? task.dueDate

                print("   🔧 [\(task.title)]")
                print("      dueDate가 자정: \(formatDate(task.dueDate))")
                print("      estimatedMinutes: \(task.estimatedMinutes)분")
                print("      계산된 scheduledStartTime: \(formatDate(calculatedStartTime))")

                tasks[index].scheduledStartTime = calculatedStartTime
                migrationCount += 1
            }
        }

        if migrationCount > 0 {
            print("\n✅ [TaskViewModel] 마이그레이션 완료: \(migrationCount)개 태스크 수정됨")
            saveTasks()
            print("   💾 변경사항 저장 완료")
        } else {
            print("\n✅ [TaskViewModel] 마이그레이션 불필요 (모든 태스크가 올바른 상태)")
        }

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }

    /// dueDate가 자정(00:00)인지 확인
    private func isDueDateMidnight(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        return components.hour == 0 && components.minute == 0 && components.second == 0
    }

    /// 날짜 포맷팅 (로깅용)
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }

    // MARK: - Checkin Observer Setup

    private func setupCheckinObservers() {
        // 체크인 응답 수신 옵저버
        NotificationCenter.default.addObserver(
            forName: .taskCheckinReceived,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let taskId = userInfo["taskId"] as? UUID,
                  let responseRaw = userInfo["response"] as? String,
                  let response = CheckinResponse(rawValue: responseRaw) else {
                return
            }

            self.handleCheckinResponse(taskId: taskId, response: response)
        }

        // 체크인 UI 표시 요청 옵저버
        NotificationCenter.default.addObserver(
            forName: .showCheckinUI,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let taskId = userInfo["taskId"] as? UUID else {
                return
            }

            // 해당 태스크의 체크인 UI 표시 요청
            self.pendingCheckinTaskId = taskId
        }
    }

    private func saveTasks() {
        do {
            print("💾 [TaskViewModel.saveTasks] 시작 - 저장할 태스크: \(tasks.count)개")
            print("   호출 스택:")
            Thread.callStackSymbols.prefix(5).forEach { print("   \($0)") }

            // 기존 데이터를 백업으로 저장 (마이그레이션 실패 시 복구용)
            if let existingData = UserDefaults.standard.data(forKey: tasksKey) {
                UserDefaults.standard.set(existingData, forKey: "\(tasksKey)_backup")
                print("   📦 백업 저장 완료")
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted  // 디버깅 용이성
            let data = try encoder.encode(tasks)
            UserDefaults.standard.set(data, forKey: tasksKey)
            print("✅ [TaskViewModel.saveTasks] Tasks saved: \(tasks.count)개")

            // 태스크가 변경되면 알림 스케줄 갱신
            _Concurrency.Task {
                await updateNotificationSchedule()
            }
        } catch {
            print("❌ [TaskViewModel.saveTasks] Failed to save tasks: \(error)")
            print("   Error details: \(error.localizedDescription)")
        }
    }

    private func loadTasks() {
        print("📂 [TaskViewModel.loadTasks] 시작")
        print("   호출 스택:")
        Thread.callStackSymbols.prefix(5).forEach { print("   \($0)") }

        guard let data = UserDefaults.standard.data(forKey: tasksKey) else {
            print("ℹ️ [TaskViewModel.loadTasks] No saved tasks found in UserDefaults")
            return
        }

        print("   📦 UserDefaults에서 데이터 발견: \(data.count) bytes")

        do {
            let decoder = JSONDecoder()
            tasks = try decoder.decode([Task].self, from: data)
            print("✅ [TaskViewModel.loadTasks] Tasks loaded: \(tasks.count)개")
            if tasks.count > 0 {
                print("   첫 번째 태스크: \(tasks[0].title)")
            }
        } catch {
            print("❌ [TaskViewModel.loadTasks] Failed to load tasks: \(error)")
            print("   Error details: \(error.localizedDescription)")

            // 백업에서 복구 시도
            if let backupData = UserDefaults.standard.data(forKey: "\(tasksKey)_backup") {
                print("⚠️ [TaskViewModel.loadTasks] Attempting to restore from backup...")
                print("   📦 백업 데이터 크기: \(backupData.count) bytes")
                do {
                    let decoder = JSONDecoder()
                    tasks = try decoder.decode([Task].self, from: backupData)
                    print("✅ [TaskViewModel.loadTasks] Tasks restored from backup: \(tasks.count)개")

                    // 복구 성공 시 백업을 현재 데이터로 저장
                    saveTasks()
                } catch {
                    print("❌ [TaskViewModel.loadTasks] Backup restore also failed: \(error)")
                    print("   Starting with empty task list")
                    tasks = []
                }
            } else {
                print("   No backup found, starting with empty task list")
                tasks = []
            }
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
        print("\n╔════════════════════════════════════════════════════════╗")
        print("║  TaskViewModel.todayTasks 계산 시작                    ║")
        print("╚════════════════════════════════════════════════════════╝")
        print("   📊 전체 태스크 개수: \(tasks.count)개\n")

        let result = tasks
            .filter { task in
                let horizon = task.currentHorizon
                let isToday = horizon == .today
                if !isToday {
                    print("   ❌ 제외: \"\(task.title)\" → \(horizon.rawValue)")
                }
                return isToday
            }
            .sorted { $0.sortOrder < $1.sortOrder }

        print("\n╔════════════════════════════════════════════════════════╗")
        print("║  TaskViewModel.todayTasks 계산 완료                    ║")
        print("╚════════════════════════════════════════════════════════╝")
        print("   ✅ 오늘 할 일: \(result.count)개")
        for (index, task) in result.enumerated() {
            let statusIcon = task.isCompleted ? "✅" : "⏳"
            print("   [\(index + 1)] \(statusIcon) \(task.title)")
        }
        print("════════════════════════════════════════════════════════\n")

        return result
    }

    /// 오늘 할 일 중 미완료만
    var todayIncompleteTasks: [Task] {
        todayTasks.filter { !$0.isCompleted }
    }

    /// 이번 주 할 일 - 완료된 것 포함 (주 시작 요일 기준)
    var thisWeekTasks: [Task] {
        let calendar = Calendar.current
        let today = Date()
        let weekRange = getWeekDateRange(for: today)

        return tasks
            .filter { task in
                let startDate = task.effectiveStartDate
                return startDate >= weekRange.start && startDate <= weekRange.end
            }
            .sorted { $0.effectiveStartDate < $1.effectiveStartDate }
    }

    /// 이번 주 할 일 중 미완료만
    var thisWeekIncompleteTasks: [Task] {
        thisWeekTasks.filter { !$0.isCompleted }
    }

    /// 다음 주 할 일 - 완료된 것 포함 (주 시작 요일 기준)
    var nextWeekTasks: [Task] {
        let calendar = Calendar.current
        let today = Date()
        guard let nextWeekDate = calendar.date(byAdding: .weekOfYear, value: 1, to: today) else {
            return []
        }
        let weekRange = getWeekDateRange(for: nextWeekDate)

        return tasks
            .filter { task in
                let startDate = task.effectiveStartDate
                return startDate >= weekRange.start && startDate <= weekRange.end
            }
            .sorted { $0.effectiveStartDate < $1.effectiveStartDate }
    }

    /// 다음 주 할 일 중 미완료만
    var nextWeekIncompleteTasks: [Task] {
        nextWeekTasks.filter { !$0.isCompleted }
    }

    /// 주 범위 계산 (weekStartDay 설정 반영)
    private func getWeekDateRange(for date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)

        // weekStartDay: 1=일요일, 2=월요일
        let daysFromStart = (weekday - weekStartDay + 7) % 7

        guard let weekStart = calendar.date(byAdding: .day, value: -daysFromStart, to: calendar.startOfDay(for: date)),
              let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else {
            return (calendar.startOfDay(for: date), calendar.startOfDay(for: date))
        }

        return (calendar.startOfDay(for: weekStart), calendar.startOfDay(for: weekEnd))
    }

    /// 언젠가 할 일 (다음 주 이후의 태스크)
    var somedayTasks: [Task] {
        let calendar = Calendar.current
        let today = Date()
        guard let nextWeekDate = calendar.date(byAdding: .weekOfYear, value: 1, to: today) else {
            return []
        }
        let nextWeekRange = getWeekDateRange(for: nextWeekDate)

        return tasks
            .filter { task in
                let startDate = task.effectiveStartDate
                return startDate > nextWeekRange.end
            }
            .sorted { $0.dueDate < $1.dueDate } // 마감일 가까운 순
    }

    /// 언젠가 할 일 중 미완료만
    var somedayIncompleteTasks: [Task] {
        somedayTasks.filter { !$0.isCompleted }
    }

    /// 미리 할 수 있는 태스크 (내일 이후 + preparable 타입)
    var preparableFutureTasks: [Task] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        return tasks
            .filter {
                !$0.isCompleted &&
                $0.taskType == .preparable &&
                $0.dueDate >= tomorrow  // 내일 이후의 모든 태스크
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
        // 일반 태스크 추가 (role을 main으로 설정)
        var main = mainTask
        main.taskRole = .none
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
                mainTaskId: main.id,                 // 일반 태스크 연결
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
                tasks[index].completedAt = nil
            case .inProgress:
                tasks[index].status = .completed
                tasks[index].completedAt = Date()  // 완료 시간 기록
            case .completed:
                tasks[index].status = .notStarted
                tasks[index].completedAt = nil     // 완료 취소 시 초기화
            }
        }
    }
    
    func deleteTask(_ task: Task) {
        deleteTasks([task])
    }

    /// 여러 태스크를 한 번에 삭제
    func deleteTasks(_ tasksToDelete: [Task]) {
        // 일반 태스크 삭제 시: 연결된 준비 태스크들도 함께 삭제
        // 준비 태스크 삭제 시: 해당 태스크만 삭제 (일반 태스크는 유지)
        var allTaskIdsToDelete: Set<UUID> = Set(tasksToDelete.map { $0.id })

        for task in tasksToDelete {
            if !task.isPreparation {
                // 일반 태스크 삭제: 이 메인을 위한 준비 태스크들 찾기
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

    /// 오늘 태스크 순서를 수동으로 재조정
    func reorderTodayTasks(from source: IndexSet, to destination: Int) {
        var reorderedTasks = todayTasks
        reorderedTasks.move(fromOffsets: source, toOffset: destination)

        // 새 순서에 따라 manualPriority 할당 (0, 1, 2, ...)
        for (index, task) in reorderedTasks.enumerated() {
            if let taskIndex = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[taskIndex].manualPriority = index
            }
        }
    }

    /// 모든 태스크의 수동 우선순위 초기화 (자동 정렬로 복귀)
    func resetManualPriorities() {
        for index in 0..<tasks.count {
            tasks[index].manualPriority = nil
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

        // Task 생성 (캘린더 패턴 태스크는 일반 태스크)
        let task = Task(
            title: suggested.title,
            description: "캘린더 패턴에서 자동 생성됨",
            dueDate: nextOccurrence,
            estimatedMinutes: suggested.estimatedMinutes,
            leadTimeDays: suggested.leadTimeDays,
            taskType: suggested.taskType,
            taskRole: .none,  // 캘린더 패턴 태스크는 일반 태스크
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
                        // Create task (패턴에서 생성되는 태스크는 일반 태스크)
                        let task = Task(
                            title: pattern.taskTitle,
                            description: "자동 생성됨 (반복 패턴)",
                            dueDate: currentOccurrence,
                            estimatedMinutes: pattern.estimatedMinutes,
                            leadTimeDays: pattern.leadTimeDays,
                            taskType: pattern.taskType,
                            taskRole: .none,  // 패턴 태스크는 일반 태스크
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

    /// 특정 일반 태스크의 준비 태스크들 조회
    func preparationTasks(for mainTask: Task) -> [Task] {
        tasks.filter { $0.mainTaskId == mainTask.id && $0.isPreparation }
            .sorted { $0.effectiveStartDate < $1.effectiveStartDate }
    }

    /// 준비 태스크가 연결된 일반 태스크 조회
    func mainTask(for preparationTask: Task) -> Task? {
        guard let mainId = preparationTask.mainTaskId else { return nil }
        return tasks.first { $0.id == mainId }
    }

    /// 일반 태스크의 준비도 계산 (완료된 준비 태스크 비율)
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

    /// 데이터 비교 결과
    struct DataComparisonResult {
        let localTaskCount: Int
        let cloudTaskCount: Int
        let localProjectCount: Int
        let cloudProjectCount: Int

        var taskCountDifference: Int {
            abs(localTaskCount - cloudTaskCount)
        }

        var projectCountDifference: Int {
            abs(localProjectCount - cloudProjectCount)
        }

        var taskDifferencePercentage: Double {
            let maxCount = max(localTaskCount, cloudTaskCount)
            guard maxCount > 0 else { return 0 }
            return Double(taskCountDifference) / Double(maxCount) * 100
        }

        var projectDifferencePercentage: Double {
            let maxCount = max(localProjectCount, cloudProjectCount)
            guard maxCount > 0 else { return 0 }
            return Double(projectCountDifference) / Double(maxCount) * 100
        }

        /// 차이가 큰지 여부 (태스크 10개 이상 차이 또는 30% 이상 차이)
        var hasSignificantDifference: Bool {
            return taskCountDifference >= 10 || taskDifferencePercentage >= 30
        }
    }

    /// 클라우드 데이터 미리보기
    struct CloudDataPreview {
        let taskCount: Int
        let projectCount: Int
        let lastSyncDate: Date?

        var isEmpty: Bool {
            taskCount == 0 && projectCount == 0
        }
    }

    /// 클라우드 데이터 미리보기 가져오기
    func getCloudDataPreview() async throws -> CloudDataPreview {
        guard let database = database else {
            throw NSError(domain: "CloudKit", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "CloudKit이 초기화되지 않았습니다. iCloud 설정을 확인하세요."
            ])
        }

        print("🔍 [TaskViewModel.getCloudDataPreview] 클라우드 데이터 미리보기 가져오기...")

        // Get saved recordNames from UserDefaults
        var taskRecordNames = UserDefaults.standard.stringArray(forKey: "cloudTaskRecordNames") ?? []
        var projectRecordNames = UserDefaults.standard.stringArray(forKey: "cloudProjectRecordNames") ?? []
        let lastSync = UserDefaults.standard.object(forKey: syncDateKey) as? Date

        print("   📦 UserDefaults에 저장된 개수: 태스크 \(taskRecordNames.count)개, 프로젝트 \(projectRecordNames.count)개")

        // recordNames가 없으면 실제로 CloudKit에서 확인
        if taskRecordNames.isEmpty {
            print("   ⚠️ recordNames가 비어있음. CKQuery로 실제 개수 확인 중...")
            let query = CKQuery(recordType: "Task", predicate: NSPredicate(value: true))
            do {
                let results = try await database.records(matching: query, desiredKeys: ["title"])
                taskRecordNames = results.matchResults.compactMap { (recordID, result) in
                    guard (try? result.get()) != nil else { return nil }
                    return recordID.recordName
                }
                print("   ✅ 실제 CloudKit에서 \(taskRecordNames.count)개 태스크 발견")
            } catch {
                print("   ⚠️ CKQuery 실패: \(error)")
                // 에러가 나도 계속 진행 (빈 배열로)
            }
        }

        if projectRecordNames.isEmpty {
            print("   ⚠️ recordNames가 비어있음. CKQuery로 실제 개수 확인 중...")
            let query = CKQuery(recordType: "Project", predicate: NSPredicate(value: true))
            do {
                let results = try await database.records(matching: query, desiredKeys: ["name"])
                projectRecordNames = results.matchResults.compactMap { (recordID, result) in
                    guard (try? result.get()) != nil else { return nil }
                    return recordID.recordName
                }
                print("   ✅ 실제 CloudKit에서 \(projectRecordNames.count)개 프로젝트 발견")
            } catch {
                print("   ⚠️ CKQuery 실패: \(error)")
                // 에러가 나도 계속 진행 (빈 배열로)
            }
        }

        let preview = CloudDataPreview(
            taskCount: taskRecordNames.count,
            projectCount: projectRecordNames.count,
            lastSyncDate: lastSync
        )

        print("📊 [TaskViewModel.getCloudDataPreview] 클라우드 데이터:")
        print("   태스크: \(preview.taskCount)개")
        print("   프로젝트: \(preview.projectCount)개")
        if let lastSync = preview.lastSyncDate {
            print("   마지막 동기화: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
        } else {
            print("   마지막 동기화: 없음")
        }

        return preview
    }

    /// 로컬과 클라우드 데이터 비교
    func compareLocalAndCloudData() async throws -> DataComparisonResult {
        guard let database = database else {
            throw NSError(domain: "CloudKit", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "CloudKit이 초기화되지 않았습니다. iCloud 설정을 확인하세요."
            ])
        }

        print("🔍 로컬과 클라우드 데이터 비교 시작...")

        // Get saved recordNames from UserDefaults
        let taskRecordNames = UserDefaults.standard.stringArray(forKey: "cloudTaskRecordNames") ?? []
        let projectRecordNames = UserDefaults.standard.stringArray(forKey: "cloudProjectRecordNames") ?? []

        let localTaskCount = tasks.count
        let localProjectCount = projects.count
        let cloudTaskCount = taskRecordNames.count
        let cloudProjectCount = projectRecordNames.count

        let result = DataComparisonResult(
            localTaskCount: localTaskCount,
            cloudTaskCount: cloudTaskCount,
            localProjectCount: localProjectCount,
            cloudProjectCount: cloudProjectCount
        )

        print("📊 비교 결과:")
        print("   로컬: 태스크 \(localTaskCount)개, 프로젝트 \(localProjectCount)개")
        print("   클라우드: 태스크 \(cloudTaskCount)개, 프로젝트 \(cloudProjectCount)개")
        print("   차이: 태스크 \(result.taskCountDifference)개 (\(String(format: "%.1f", result.taskDifferencePercentage))%)")
        print("   유의미한 차이: \(result.hasSignificantDifference ? "예" : "아니오")")

        return result
    }

    // MARK: - Auto Backup

    /// 자동 백업 트리거 (변경 감지 후 일정 시간 후 실행)
    private func triggerAutoBackup() {
        guard isAutoBackupEnabled else {
            print("ℹ️ [TaskViewModel] 자동 백업 비활성화됨")
            return
        }

        // 현재 동기화 중이면 스킵
        guard !isSyncing else {
            print("ℹ️ [TaskViewModel] 이미 동기화 중 - 자동 백업 스킵")
            return
        }

        // 마지막 변경 시간 기록
        lastChangeDate = Date()

        // 기존 타이머 취소
        autoBackupTimer?.invalidate()

        // 새 타이머 시작 (10초 후 실행)
        autoBackupTimer = Timer.scheduledTimer(withTimeInterval: autoBackupDelay, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            _Concurrency.Task { @MainActor in
                await self.performAutoBackup()
            }
        }

        print("⏱️ [TaskViewModel] 자동 백업 예약: \(Int(autoBackupDelay))초 후")
    }

    /// 자동 백업 실행
    private func performAutoBackup() async {
        // 마지막 변경 후 충분한 시간이 지났는지 확인
        guard let lastChange = lastChangeDate else {
            print("ℹ️ [TaskViewModel] 마지막 변경 없음 - 자동 백업 스킵")
            return
        }

        let timeSinceChange = Date().timeIntervalSince(lastChange)
        guard timeSinceChange >= autoBackupDelay else {
            print("ℹ️ [TaskViewModel] 변경 후 시간 부족 (\(Int(timeSinceChange))초) - 자동 백업 스킵")
            return
        }

        print("🔄 [TaskViewModel] 자동 백업 시작...")
        print("   마지막 변경: \(Int(timeSinceChange))초 전")
        print("   태스크: \(tasks.count)개")
        print("   프로젝트: \(projects.count)개")

        do {
            try await saveToCloud()
            lastAutoBackupDate = Date()
            print("✅ [TaskViewModel] 자동 백업 완료")
        } catch {
            print("❌ [TaskViewModel] 자동 백업 실패: \(error.localizedDescription)")
            // 자동 백업 실패는 사용자에게 알리지 않음 (조용히 실패)
        }
    }

    /// 클라우드에 저장
    func saveToCloud() async throws {
        guard let database = database else {
            throw NSError(domain: "CloudKit", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "CloudKit이 초기화되지 않았습니다. iCloud 설정을 확인하세요."
            ])
        }

        print("☁️ [macOS TaskViewModel.saveToCloud] Starting cloud save...")
        print("   Container ID: \(container?.containerIdentifier ?? "nil")")
        print("   Database: privateCloudDatabase")
        print("   저장할 태스크: \(tasks.count)개")
        print("   저장할 프로젝트: \(projects.count)개")

        isSyncing = true
        syncError = nil

        defer { isSyncing = false }

        // Delete existing records first
        try await deleteAllCloudRecords()

        // Convert tasks to CKRecords and save
        let taskRecords = tasks.map { taskToCKRecord($0) }
        for batch in taskRecords.chunked(into: 200) {
            try await saveBatch(batch)
        }

        // Convert projects to CKRecords and save
        let projectRecords = projects.map { projectToCKRecord($0) }
        for batch in projectRecords.chunked(into: 200) {
            try await saveBatch(batch)
        }

        // Save recordNames to UserDefaults (쿼리 없이 복원하기 위함)
        let taskRecordNames = tasks.map { $0.id.uuidString }
        let projectRecordNames = projects.map { $0.id.uuidString }
        UserDefaults.standard.set(taskRecordNames, forKey: "cloudTaskRecordNames")
        UserDefaults.standard.set(projectRecordNames, forKey: "cloudProjectRecordNames")

        // Update last sync date
        lastSyncDate = Date()
        UserDefaults.standard.set(lastSyncDate, forKey: syncDateKey)

        print("☁️ Successfully saved \(tasks.count) tasks and \(projects.count) projects to cloud")
    }

    /// 클라우드에서 복원
    func restoreFromCloud() async throws {
        print("☁️ [TaskViewModel.restoreFromCloud] 시작")
        print("   호출 스택:")
        Thread.callStackSymbols.prefix(5).forEach { print("   \($0)") }
        print("   현재 로컬 태스크: \(tasks.count)개")
        print("   현재 로컬 프로젝트: \(projects.count)개")

        guard let database = database else {
            throw NSError(domain: "CloudKit", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "CloudKit이 초기화되지 않았습니다. iCloud 설정을 확인하세요."
            ])
        }

        print("☁️ Starting cloud restore...")
        isSyncing = true
        syncError = nil

        defer { isSyncing = false }

        // Get saved recordNames from UserDefaults
        let taskRecordNames = UserDefaults.standard.stringArray(forKey: "cloudTaskRecordNames") ?? []
        let projectRecordNames = UserDefaults.standard.stringArray(forKey: "cloudProjectRecordNames") ?? []

        print("📋 [TaskViewModel.restoreFromCloud] Found \(taskRecordNames.count) task records and \(projectRecordNames.count) project records in UserDefaults")

        // Restore tasks
        var cloudTasks: [Task] = []

        if !taskRecordNames.isEmpty {
            print("   📥 recordNames로 태스크 복원 시도...")
            // recordNames가 있으면 직접 fetch
            let taskRecordIDs = taskRecordNames.map { CKRecord.ID(recordName: $0) }

            // Fetch in batches of 200
            for batch in taskRecordIDs.chunked(into: 200) {
                do {
                    let results = try await database.records(for: batch)
                    let batchTasks = results.values.compactMap { result in
                        try? result.get()
                    }.compactMap { ckRecordToTask($0) }
                    cloudTasks.append(contentsOf: batchTasks)
                    print("   ✅ 배치에서 \(batchTasks.count)개 태스크 복원")
                } catch let error as CKError {
                    // unknownItem 에러는 레코드가 삭제된 경우이므로 경고만 출력
                    if error.code == .unknownItem {
                        print("⚠️ Some task records not found (may have been deleted)")
                    } else {
                        throw error
                    }
                }
            }
        } else {
            print("   ⚠️ recordNames가 비어있음. CKQuery로 모든 태스크 검색...")
            // recordNames가 없으면 CKQuery로 모든 레코드 가져오기
            let query = CKQuery(recordType: "Task", predicate: NSPredicate(value: true))
            query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

            do {
                // 모든 필드를 가져오기 위해 desiredKeys를 지정하지 않음 (또는 nil)
                let results = try await database.records(matching: query)
                print("   📦 CKQuery 결과: \(results.matchResults.count)개 레코드")

                cloudTasks = results.matchResults.compactMap { (recordID, result) in
                    guard let record = try? result.get() else {
                        print("   ⚠️ 레코드 가져오기 실패: \(recordID.recordName)")
                        return nil
                    }
                    let task = ckRecordToTask(record)
                    if task == nil {
                        print("   ⚠️ Task 변환 실패: \(recordID.recordName)")
                        print("      title: \(record["title"] as? String ?? "없음")")
                    }
                    return task
                }
                print("   ✅ CKQuery로 \(cloudTasks.count)개 태스크 발견 (총 \(results.matchResults.count)개 레코드)")

                // 가져온 레코드 ID를 UserDefaults에 저장
                let fetchedRecordNames = cloudTasks.map { $0.id.uuidString }
                UserDefaults.standard.set(fetchedRecordNames, forKey: "cloudTaskRecordNames")
                print("   💾 recordNames를 UserDefaults에 저장: \(fetchedRecordNames.count)개")
            } catch {
                print("   ❌ CKQuery 실패: \(error)")
                throw error
            }
        }

        // Restore projects
        var cloudProjects: [Project] = []

        if !projectRecordNames.isEmpty {
            print("   📥 recordNames로 프로젝트 복원 시도...")
            // recordNames가 있으면 직접 fetch
            let projectRecordIDs = projectRecordNames.map { CKRecord.ID(recordName: $0) }

            // Fetch in batches of 200
            for batch in projectRecordIDs.chunked(into: 200) {
                do {
                    let results = try await database.records(for: batch)
                    let batchProjects = results.values.compactMap { result in
                        try? result.get()
                    }.compactMap { ckRecordToProject($0) }
                    cloudProjects.append(contentsOf: batchProjects)
                    print("   ✅ 배치에서 \(batchProjects.count)개 프로젝트 복원")
                } catch let error as CKError {
                    // unknownItem 에러는 레코드가 삭제된 경우이므로 경고만 출력
                    if error.code == .unknownItem {
                        print("⚠️ Some project records not found (may have been deleted)")
                    } else {
                        throw error
                    }
                }
            }
        } else {
            print("   ⚠️ recordNames가 비어있음. CKQuery로 모든 프로젝트 검색...")
            // recordNames가 없으면 CKQuery로 모든 레코드 가져오기
            let query = CKQuery(recordType: "Project", predicate: NSPredicate(value: true))

            do {
                // 모든 필드를 가져오기 위해 desiredKeys를 지정하지 않음
                let results = try await database.records(matching: query)
                print("   📦 CKQuery 결과: \(results.matchResults.count)개 레코드")

                cloudProjects = results.matchResults.compactMap { (recordID, result) in
                    guard let record = try? result.get() else {
                        print("   ⚠️ 레코드 가져오기 실패: \(recordID.recordName)")
                        return nil
                    }
                    let project = ckRecordToProject(record)
                    if project == nil {
                        print("   ⚠️ Project 변환 실패: \(recordID.recordName)")
                        print("      name: \(record["name"] as? String ?? "없음")")
                    }
                    return project
                }
                print("   ✅ CKQuery로 \(cloudProjects.count)개 프로젝트 발견 (총 \(results.matchResults.count)개 레코드)")

                // 가져온 레코드 ID를 UserDefaults에 저장
                let fetchedRecordNames = cloudProjects.map { $0.id.uuidString }
                UserDefaults.standard.set(fetchedRecordNames, forKey: "cloudProjectRecordNames")
                print("   💾 recordNames를 UserDefaults에 저장: \(fetchedRecordNames.count)개")
            } catch {
                print("   ❌ CKQuery 실패: \(error)")
                throw error
            }
        }

        print("   📝 tasks 배열에 클라우드 데이터 할당 중... (\(cloudTasks.count)개)")
        tasks = cloudTasks
        print("   ✅ tasks 배열 할당 완료 (현재: \(tasks.count)개)")

        print("   📝 projects 배열에 클라우드 데이터 할당 중... (\(cloudProjects.count)개)")
        projects = cloudProjects
        print("   ✅ projects 배열 할당 완료 (현재: \(projects.count)개)")

        lastSyncDate = Date()
        UserDefaults.standard.set(lastSyncDate, forKey: syncDateKey)

        print("✅ [TaskViewModel.restoreFromCloud] Restored \(cloudTasks.count) tasks and \(cloudProjects.count) projects from cloud")
        print("   최종 태스크 개수: \(tasks.count)")
        print("   최종 프로젝트 개수: \(projects.count)")
    }

    /// 데이터 초기화 (로컬 + 클라우드)
    func resetAllData() async throws {
        print("🗑️ [TaskViewModel.resetAllData] 시작")
        print("   현재 태스크: \(tasks.count)개")
        print("   호출 스택:")
        Thread.callStackSymbols.prefix(5).forEach { print("   \($0)") }

        // 1. tasks 배열 초기화 (이때 didSet이 호출되어 saveTasks() 실행됨)
        print("   1️⃣ tasks 배열 초기화 중...")
        tasks = []
        print("   ✅ tasks 배열 초기화 완료 (현재: \(tasks.count)개)")

        // 2. UserDefaults 삭제
        print("   2️⃣ UserDefaults 삭제 중...")
        UserDefaults.standard.removeObject(forKey: tasksKey)
        UserDefaults.standard.removeObject(forKey: "\(tasksKey)_backup")
        print("   ✅ UserDefaults 삭제 완료")

        // 3. 프로젝트 초기화
        print("   3️⃣ 프로젝트 초기화 중... (현재: \(projects.count)개)")
        projects = []
        UserDefaults.standard.removeObject(forKey: projectsKey)
        print("   ✅ 프로젝트 초기화 완료")

        // 4. 클라우드 레코드 삭제
        print("   4️⃣ 클라우드 레코드 삭제 중...")
        try await deleteAllCloudRecords()
        print("   ✅ 클라우드 레코드 삭제 완료")

        print("✅ [TaskViewModel.resetAllData] All data has been reset")
        print("   최종 태스크 개수: \(tasks.count)")
        print("   최종 프로젝트 개수: \(projects.count)")
    }

    /// 로컬 데이터만 초기화
    func resetLocalData() {
        print("🗑️ [TaskViewModel.resetLocalData] 시작")
        print("   현재 태스크: \(tasks.count)개")
        print("   호출 스택:")
        Thread.callStackSymbols.prefix(5).forEach { print("   \($0)") }

        // 1. tasks 배열 초기화
        print("   1️⃣ tasks 배열 초기화 중...")
        tasks = []
        print("   ✅ tasks 배열 초기화 완료 (현재: \(tasks.count)개)")

        // 2. UserDefaults 삭제
        print("   2️⃣ UserDefaults 삭제 중...")
        UserDefaults.standard.removeObject(forKey: tasksKey)
        UserDefaults.standard.removeObject(forKey: "\(tasksKey)_backup")
        print("   ✅ UserDefaults 삭제 완료")

        // 3. 프로젝트 초기화
        print("   3️⃣ 프로젝트 초기화 중... (현재: \(projects.count)개)")
        projects = []
        UserDefaults.standard.removeObject(forKey: projectsKey)
        print("   ✅ 프로젝트 초기화 완료")

        print("✅ [TaskViewModel.resetLocalData] Local data has been reset")
        print("   최종 태스크 개수: \(tasks.count)")
        print("   최종 프로젝트 개수: \(projects.count)")
    }

    // MARK: - CloudKit Helper Methods

    private func saveBatch(_ records: [CKRecord]) async throws {
        guard let database = database else {
            throw NSError(domain: "CloudKit", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "CloudKit database not available"
            ])
        }

        do {
            let (savedRecords, _) = try await database.modifyRecords(saving: records, deleting: [])
            print("✅ Saved batch of \(savedRecords.count) records")
        } catch let error as CKError {
            print("❌ CloudKit save error: \(error.localizedDescription)")
            print("   Error code: \(error.code.rawValue)")
            if let partialErrors = error.userInfo[CKPartialErrorsByItemIDKey] as? [CKRecord.ID: Error] {
                for (recordID, partialError) in partialErrors {
                    print("   Failed record: \(recordID.recordName) - \(partialError.localizedDescription)")
                }
            }
            throw error
        }
    }

    private func deleteAllCloudRecords() async throws {
        guard let database = database else { return }

        // Get saved recordNames from UserDefaults (쿼리 없이 삭제)
        let taskRecordNames = UserDefaults.standard.stringArray(forKey: "cloudTaskRecordNames") ?? []
        let projectRecordNames = UserDefaults.standard.stringArray(forKey: "cloudProjectRecordNames") ?? []

        do {
            // Delete all Task records
            if !taskRecordNames.isEmpty {
                let taskRecordIDs = taskRecordNames.map { CKRecord.ID(recordName: $0) }
                for batch in taskRecordIDs.chunked(into: 200) {
                    let (_, deletedRecordIDs) = try await database.modifyRecords(saving: [], deleting: batch)
                    print("🗑️ Deleted batch of \(deletedRecordIDs.count) task records")
                }
                print("🗑️ Deleted \(taskRecordIDs.count) task records in total")
            }

            // Delete all Project records
            if !projectRecordNames.isEmpty {
                let projectRecordIDs = projectRecordNames.map { CKRecord.ID(recordName: $0) }
                for batch in projectRecordIDs.chunked(into: 200) {
                    let (_, deletedRecordIDs) = try await database.modifyRecords(saving: [], deleting: batch)
                    print("🗑️ Deleted batch of \(deletedRecordIDs.count) project records")
                }
                print("🗑️ Deleted \(projectRecordIDs.count) project records in total")
            }
        } catch let error as CKError {
            // "Unknown Item" 에러는 레코드가 없다는 의미이므로 무시
            if error.code == .unknownItem {
                print("⚠️ No records found in CloudKit (this is normal if you haven't saved to cloud yet)")
                return
            }
            throw error
        }
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
        if let projectId = task.projectId {
            record["projectId"] = projectId.uuidString as CKRecordValue
        }
        if let manualPriority = task.manualPriority {
            record["manualPriority"] = manualPriority as CKRecordValue
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
            let statusRaw = record["status"] as? String,
            let status = TaskStatus(rawValue: statusRaw),
            let createdAt = record["createdAt"] as? Date
        else {
            return nil
        }

        // 마이그레이션: "메인" → "루틴"으로 변환
        let taskRole: TaskRole
        if taskRoleRaw == "메인" {
            taskRole = .none
        } else if let role = TaskRole(rawValue: taskRoleRaw) {
            taskRole = role
        } else {
            taskRole = .none  // 알 수 없는 값은 기본값
        }

        let taskDescription = record["taskDescription"] as? String ?? ""
        let parentTaskId = (record["parentTaskId"] as? String).flatMap { UUID(uuidString: $0) }
        let mainTaskId = (record["mainTaskId"] as? String).flatMap { UUID(uuidString: $0) }
        let targetDate = record["targetDate"] as? Date
        let projectId = (record["projectId"] as? String).flatMap { UUID(uuidString: $0) }
        let manualPriority = record["manualPriority"] as? Int

        // priority는 optional로 처리 (기존 레코드 호환성)
        let priorityRaw = record["priority"] as? String
        let priority = priorityRaw.flatMap { TaskPriority(rawValue: $0) } ?? .normal

        var task = Task(
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
            projectId: projectId,
            parentTaskId: parentTaskId,
            mainTaskId: mainTaskId,
            targetDate: targetDate
        )
        task.manualPriority = manualPriority
        return task
    }

    private func projectToCKRecord(_ project: Project) -> CKRecord {
        let recordID = CKRecord.ID(recordName: project.id.uuidString)
        let record = CKRecord(recordType: "Project", recordID: recordID)

        record["name"] = project.name as CKRecordValue
        record["color"] = project.color as CKRecordValue
        record["icon"] = project.icon as CKRecordValue

        return record
    }

    private func ckRecordToProject(_ record: CKRecord) -> Project? {
        guard
            let name = record["name"] as? String,
            let color = record["color"] as? String,
            let icon = record["icon"] as? String
        else {
            return nil
        }

        var project = Project(name: name, color: color, icon: icon)
        project.id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        return project
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

    // MARK: - Checkin Management

    /// 체크인 응답 처리
    func handleCheckinResponse(taskId: UUID, response: CheckinResponse) {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else {
            print("⚠️ [TaskViewModel] 체크인 대상 태스크를 찾을 수 없음: \(taskId)")
            return
        }

        // 체크인 시간 기록
        tasks[index].lastCheckinDate = Date()
        tasks[index].consecutiveMissedCheckins = 0

        switch response {
        case .onTrack:
            // 순조롭게 진행 중 - 상태 유지
            print("✅ [TaskViewModel] 체크인: \(tasks[index].title) - 순조로움")

        case .completed:
            // 완료 처리
            tasks[index].status = .completed
            print("✅ [TaskViewModel] 체크인: \(tasks[index].title) - 완료")

        case .needHelp:
            // 문제 있음 - 우선순위 상향
            if tasks[index].priority != .urgent {
                tasks[index].priority = .high
            }
            print("⚠️ [TaskViewModel] 체크인: \(tasks[index].title) - 문제 있음")

        case .postponed:
            // 연기 - 마감일 하루 연장
            if let newDueDate = Calendar.current.date(byAdding: .day, value: 1, to: tasks[index].dueDate) {
                tasks[index].dueDate = newDueDate
            }
            print("📅 [TaskViewModel] 체크인: \(tasks[index].title) - 연기됨")
        }
    }

    /// 미체크인 태스크 감지 (앱 시작 시 호출)
    func detectMissedCheckins() {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!

        for index in tasks.indices {
            guard tasks[index].isInProgress else { continue }

            // 어제 체크인하지 않은 경우
            if let lastCheckin = tasks[index].lastCheckinDate {
                if lastCheckin < calendar.startOfDay(for: yesterday) {
                    tasks[index].consecutiveMissedCheckins += 1
                    print("⚠️ [TaskViewModel] 미체크인 감지: \(tasks[index].title) - \(tasks[index].consecutiveMissedCheckins)일 연속")
                }
            } else if tasks[index].status == .inProgress {
                // 진행 중인데 한 번도 체크인한 적 없음
                tasks[index].consecutiveMissedCheckins += 1
                print("⚠️ [TaskViewModel] 미체크인 감지 (첫 체크인 없음): \(tasks[index].title)")
            }
        }
    }

    /// 연속 미체크인 태스크 목록
    var tasksWithMissedCheckins: [Task] {
        tasks.filter { $0.isInProgress && $0.consecutiveMissedCheckins > 0 }
            .sorted { $0.consecutiveMissedCheckins > $1.consecutiveMissedCheckins }
    }

    /// 체크인이 필요한 태스크 (진행 중인 태스크 중 오늘 체크인하지 않은 것)
    var tasksNeedingCheckin: [Task] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return tasks.filter { task in
            guard task.isInProgress else { return false }

            if let lastCheckin = task.lastCheckinDate {
                // 오늘 체크인하지 않은 경우
                return lastCheckin < today
            } else {
                // 한 번도 체크인하지 않은 경우
                return true
            }
        }
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
