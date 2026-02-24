import WeekAheadShared
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
    private var initialSyncCompleted: Bool = false   // 초기 동기화 완료 플래그

    // 삭제된 태스크 tombstone: [taskId → deletedAt]
    // 클라우드에 삭제를 전파하고, 다른 기기의 삭제를 받아 로컬에 적용하는 데 사용
    private var taskTombstones: [UUID: Date] = [:]
    private let tombstonesKey = "TaskTombstones_v2"

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

    // Time Migration 버전 관리 (일회성 마이그레이션 가드)
    private let timeMigrationVersionKey = "TaskTimeMigrationVersion"
    private let currentMigrationVersion = 1

    // MARK: - Initialization

    init() {

        // Initialize CloudKit (optional, may fail if not configured)
        // iOS와 같은 Container 사용 (명시적 지정)
        self.container = CKContainer(identifier: "iCloud.com.weekahead.todo")
        self.database = container?.privateCloudDatabase

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

        loadTasks()
        loadProjects()
        loadTombstones()

        // 체크인 관련 옵저버 등록
        setupCheckinObservers()


        // 태스크 시간 데이터 마이그레이션 (scheduledStartTime 기반으로 dueDate 동기화)
        migrateTaskTimes()
    }

    // MARK: - Task Time Migration

    /// 시간 데이터 수동 수정 (설정 뷰에서 호출)
    func fixTaskTimeMigration() async {
        migrateTaskTimes()
    }

    /// 특정 태스크의 모든 데이터 출력 (디버깅용)
    func debugTask(title: String) {
        guard let task = tasks.first(where: { $0.title.contains(title) }) else {
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "ko_KR")

    }

    /// 캘린더 배치 정보를 기반으로 dueDate를 동기화
    /// scheduledStartTime이 설정된 경우, dueDate = scheduledStartTime + estimatedMinutes로 자동 계산
    private func migrateTaskTimes() {
        // 이미 완료된 버전이면 건너뜀 (매 앱 시작마다 덮어쓰는 버그 방지)
        let completedVersion = UserDefaults.standard.integer(forKey: timeMigrationVersionKey)
        guard completedVersion < currentMigrationVersion else {
            print("ℹ️ [migrateTaskTimes] 이미 완료 (v\(completedVersion)), 건너뜀")
            return
        }

        var migrationCount = 0
        let calendar = Calendar.current

        for index in tasks.indices {
            let task = tasks[index]

            // 1. targetDate가 있으면 dueDate = targetDate + estimatedMinutes
            if let targetDate = task.targetDate {
                let calculatedDueDate = calendar.date(byAdding: .minute, value: task.estimatedMinutes, to: targetDate) ?? targetDate

                if !calendar.isDate(task.dueDate, equalTo: calculatedDueDate, toGranularity: .minute) {

                    tasks[index].dueDate = calculatedDueDate
                    tasks[index].scheduledStartTime = targetDate
                    migrationCount += 1
                }
            }
            // 2. scheduledStartTime이 있으면 dueDate를 재계산
            else if let startTime = task.scheduledStartTime {
                let calculatedDueDate = calendar.date(byAdding: .minute, value: task.estimatedMinutes, to: startTime) ?? startTime

                // dueDate가 계산된 값과 다르면 동기화
                if !calendar.isDate(task.dueDate, equalTo: calculatedDueDate, toGranularity: .minute) {

                    tasks[index].dueDate = calculatedDueDate
                    migrationCount += 1
                }
            }
            // 3. scheduledStartTime이 없고 dueDate가 자정(00:00)인 경우
            else if isDueDateMidnight(task.dueDate) {
                // dueDate를 해당 날짜 23:59로 변경 (자정보다 현실적)
                var components = calendar.dateComponents([.year, .month, .day], from: task.dueDate)
                components.hour = 23
                components.minute = 59
                components.second = 0
                let newDueDate = calendar.date(from: components) ?? task.dueDate

                // scheduledStartTime = dueDate - estimatedMinutes
                let calculatedStartTime = calendar.date(byAdding: .minute, value: -task.estimatedMinutes, to: newDueDate) ?? newDueDate


                tasks[index].dueDate = newDueDate
                tasks[index].scheduledStartTime = calculatedStartTime
                migrationCount += 1
            }
        }

        if migrationCount > 0 {
            saveTasks()
        } else {
        }

        // 마이그레이션 완료 버전 기록 (이후 앱 시작 시 건너뜀)
        UserDefaults.standard.set(currentMigrationVersion, forKey: timeMigrationVersionKey)
        print("✅ [migrateTaskTimes] v\(currentMigrationVersion) 완료, \(migrationCount)개 수정")
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

            // 기존 데이터를 백업으로 저장 (마이그레이션 실패 시 복구용)
            if let existingData = UserDefaults.standard.data(forKey: tasksKey) {
                UserDefaults.standard.set(existingData, forKey: "\(tasksKey)_backup")
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted  // 디버깅 용이성
            let data = try encoder.encode(tasks)
            UserDefaults.standard.set(data, forKey: tasksKey)

            // 태스크가 변경되면 알림 스케줄 갱신
            _Concurrency.Task {
                await updateNotificationSchedule()
            }
        } catch {
        }
    }

    private func loadTasks() {

        guard let data = UserDefaults.standard.data(forKey: tasksKey) else {
            return
        }


        do {
            let decoder = JSONDecoder()
            tasks = try decoder.decode([Task].self, from: data)
            if tasks.count > 0 {
            }
        } catch {

            // 백업에서 복구 시도
            if let backupData = UserDefaults.standard.data(forKey: "\(tasksKey)_backup") {
                do {
                    let decoder = JSONDecoder()
                    tasks = try decoder.decode([Task].self, from: backupData)

                    // 복구 성공 시 백업을 현재 데이터로 저장
                    saveTasks()
                } catch {
                    tasks = []
                }
            } else {
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
        } catch {
        }
    }

    private func loadProjects() {
        guard let data = UserDefaults.standard.data(forKey: projectsKey) else {
            return
        }

        do {
            let decoder = JSONDecoder()
            projects = try decoder.decode([Project].self, from: data)
        } catch {
            projects = []
        }
    }

    // MARK: - Tombstone Persistence

    private func loadTombstones() {
        guard let data = UserDefaults.standard.data(forKey: tombstonesKey),
              let dict = try? JSONDecoder().decode([String: Double].self, from: data) else { return }
        taskTombstones = Dictionary(uniqueKeysWithValues: dict.compactMap { (key, value) -> (UUID, Date)? in
            guard let id = UUID(uuidString: key) else { return nil }
            return (id, Date(timeIntervalSince1970: value))
        })
        print("ℹ️ [loadTombstones] \(taskTombstones.count)개 로드")
    }

    private func saveTombstones() {
        // 60일 이상 된 tombstone 정리
        let cutoff = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        taskTombstones = taskTombstones.filter { $0.value > cutoff }
        let dict = Dictionary(uniqueKeysWithValues: taskTombstones.map { ($0.key.uuidString, $0.value.timeIntervalSince1970) })
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: tombstonesKey)
        }
    }

    // MARK: - Computed Properties
    
    /// 시간 지평선별로 그룹화된 태스크
    var tasksByHorizon: [TimeHorizon: [Task]] {
        Dictionary(grouping: tasks.filter { !$0.isCompleted }) { $0.currentHorizon }
    }
    
    /// 오늘 할 일 (역산 결과 기준) - 완료된 것 포함
    var todayTasks: [Task] {

        let result = tasks
            .filter { task in
                let horizon = task.currentHorizon
                let isToday = horizon == .today
                if !isToday {
                }
                return isToday
            }
            .sorted { $0.sortOrder < $1.sortOrder }

        for (index, task) in result.enumerated() {
            let statusIcon = task.isCompleted ? "✅" : "⏳"
        }

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
        var t = task
        t.modifiedAt = Date()
        tasks.append(t)
        allocateTaskToTimeBlock(t)
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
            tasks[index].modifiedAt = Date()
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

        // Tombstone 기록 (클라우드 삭제 전파용)
        let deletedAt = Date()
        for id in allTaskIdsToDelete {
            taskTombstones[id] = deletedAt
        }
        saveTombstones()

        // 태스크 삭제
        tasks.removeAll { allTaskIdsToDelete.contains($0.id) }

        // 시간 블록에서도 제거
        for i in 0..<timeBlockManager.blocks.count {
            timeBlockManager.blocks[i].allocatedTasks.removeAll { allTaskIdsToDelete.contains($0) }
        }
    }
    
    // MARK: - MIT (Most Important Task)

    /// 오늘의 핵심 태스크 (MIT, 미완료)
    var mitTasks: [Task] {
        todayTasks.filter { $0.isMIT && !$0.isCompleted }
    }

    /// MIT 토글 (최대 3개 제한)
    func toggleMIT(_ task: Task) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let currentCount = tasks.filter { $0.isMIT && !$0.isCompleted }.count
        if !tasks[index].isMIT && currentCount >= 3 { return }
        tasks[index].isMIT.toggle()
        tasks[index].modifiedAt = Date()
        print("⭐ [toggleMIT] \(tasks[index].title) isMIT=\(tasks[index].isMIT)")
    }

    func updateTask(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            var updatedTask = task
            updatedTask.modifiedAt = Date()
            // 오늘 이외의 horizon으로 이동하면 수동 순서 초기화
            if updatedTask.currentHorizon != .today {
                updatedTask.manualPriority = nil
            }
            tasks[index] = updatedTask
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
                tasks[taskIndex].modifiedAt = Date()
            }
        }
    }

    // MARK: - 하위 할 일 관련

    /// 특정 태스크의 하위 할 일 완료 상태 토글
    func toggleSubtaskCompletion(taskId: UUID, subtaskId: UUID) {
        guard let taskIndex = tasks.firstIndex(where: { $0.id == taskId }),
              let subtaskIndex = tasks[taskIndex].subtasks.firstIndex(where: { $0.id == subtaskId }) else {
            print("⚠️ [TaskViewModel] 하위 할 일 찾기 실패: taskId=\(taskId), subtaskId=\(subtaskId)")
            return
        }
        tasks[taskIndex].subtasks[subtaskIndex].isCompleted.toggle()
        tasks[taskIndex].modifiedAt = Date()
        print("✅ [TaskViewModel] 하위 할 일 완료 토글: \(tasks[taskIndex].subtasks[subtaskIndex].title)")
    }

    /// 드래그 앤 드롭으로 오늘 태스크 순서 재조정 (표시된 목록 기준, UUID 배열 사용)
    func moveTodayTask(draggedId: UUID, targetId: UUID, orderedIds: [UUID]) {
        guard draggedId != targetId else { return }
        var ordered = orderedIds
        guard let fromIndex = ordered.firstIndex(of: draggedId),
              let toIndex = ordered.firstIndex(of: targetId) else { return }

        ordered.move(fromOffsets: IndexSet(integer: fromIndex),
                     toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)

        // 새 순서에 따라 manualPriority 재할당
        for (index, taskId) in ordered.enumerated() {
            if let taskIndex = tasks.firstIndex(where: { $0.id == taskId }) {
                tasks[taskIndex].manualPriority = index
                tasks[taskIndex].modifiedAt = Date()
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
        do {
            let patternsNeedingTasks = try patternService.getPatternsNeedingTaskGeneration()


            for pattern in patternsNeedingTasks {

                // 앞으로 5주간의 발생일을 계산
                let calendar = Calendar.current
                var currentOccurrence = pattern.nextOccurrenceDate
                let fiveWeeksFromNow = calendar.date(byAdding: .day, value: 35, to: Date())!

                var occurrenceCount = 0
                while currentOccurrence <= fiveWeeksFromNow && occurrenceCount < 10 {

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
                    } else {
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

        } catch {
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

    // MARK: - Merge Sync (태스크 ID 기준 양방향 병합)

    /// 앱 시작 및 포그라운드 복귀 시 호출하는 완전한 양방향 병합 동기화.
    /// "마지막 타임스탬프 승" 방식 대신 태스크 ID별 modifiedAt 비교로 충돌 해결.
    /// - 클라우드에만 있는 태스크 → 로컬에 추가
    /// - 로컬에만 있는 태스크 → 클라우드에 업로드
    /// - 양쪽에 있을 때 → modifiedAt 최신 버전 사용
    /// - 삭제된 태스크 → tombstone으로 양방향 전파
    func performMergeSync() async {
        guard let _ = database else { return }
        guard !isSyncing else { return }

        isSyncing = true
        syncError = nil

        defer {
            isSyncing = false
            initialSyncCompleted = true
        }

        do {
            print("🔄 [performMergeSync] 시작 - 로컬: \(tasks.count)개 태스크")

            // 1. 클라우드에서 모든 태스크와 tombstone 가져오기
            let cloudTasks = try await fetchAllCloudTasksForMerge()
            let cloudTombstones = try await fetchCloudTombstones()

            let cloudDict = Dictionary(uniqueKeysWithValues: cloudTasks.map { ($0.id, $0) })
            print("☁️ [performMergeSync] 클라우드: \(cloudTasks.count)개, tombstone: \(cloudTombstones.count)개")

            var mergedTasks = tasks
            var tasksToUpsert: [Task] = []
            var idsToDeleteFromCloud: [UUID] = []

            // 2. 클라우드 tombstone을 로컬에 적용
            for (deletedId, cloudDeletedAt) in cloudTombstones {
                if let localTask = mergedTasks.first(where: { $0.id == deletedId }) {
                    if localTask.modifiedAt <= cloudDeletedAt {
                        // 클라우드에서 삭제됐고 로컬이 더 최신이 아님 → 로컬에서도 삭제
                        mergedTasks.removeAll { $0.id == deletedId }
                        print("🗑️ [merge] 클라우드 삭제 적용: \(localTask.title)")
                    }
                    // 로컬이 더 최신이면: 로컬 유지 (step 4에서 클라우드에 복원됨)
                }
                // 우리 로컬 tombstone에서 제거 (클라우드가 이미 알고 있음)
                taskTombstones.removeValue(forKey: deletedId)
            }

            // 3. 클라우드 태스크를 로컬에 병합
            for cloudTask in cloudTasks {
                let localIndex = mergedTasks.firstIndex(where: { $0.id == cloudTask.id })

                if let idx = localIndex {
                    // 양쪽에 있음 → modifiedAt 비교
                    let localTask = mergedTasks[idx]
                    if cloudTask.modifiedAt > localTask.modifiedAt {
                        mergedTasks[idx] = cloudTask
                        print("⬇️ [merge] 클라우드→로컬 업데이트: \(cloudTask.title)")
                    } else if localTask.modifiedAt > cloudTask.modifiedAt {
                        tasksToUpsert.append(localTask)
                        print("⬆️ [merge] 로컬→클라우드 업데이트: \(localTask.title)")
                    }
                    // 동일하면 무시
                } else if let tombstoneDate = taskTombstones[cloudTask.id] {
                    // 우리가 삭제한 태스크가 클라우드에 있음
                    if cloudTask.modifiedAt > tombstoneDate {
                        // 삭제 후 클라우드에서 수정됨 → 클라우드 버전 복원
                        mergedTasks.append(cloudTask)
                        taskTombstones.removeValue(forKey: cloudTask.id)
                        print("↩️ [merge] 삭제 후 재수정됨, 복원: \(cloudTask.title)")
                    } else {
                        // 우리 삭제가 유효 → 클라우드에서도 삭제 필요
                        idsToDeleteFromCloud.append(cloudTask.id)
                        taskTombstones.removeValue(forKey: cloudTask.id)
                    }
                } else {
                    // 클라우드에만 있고 우리가 삭제하지 않음 → 로컬에 추가 (다른 기기에서 추가됨)
                    mergedTasks.append(cloudTask)
                    print("➕ [merge] 클라우드→로컬 추가: \(cloudTask.title)")
                }
            }

            // 4. 로컬에만 있는 태스크 → 클라우드에 업로드
            for localTask in tasks {
                if cloudDict[localTask.id] == nil && taskTombstones[localTask.id] == nil {
                    tasksToUpsert.append(localTask)
                    print("⬆️ [merge] 로컬→클라우드 신규: \(localTask.title)")
                }
            }

            // 중복 제거 (같은 태스크가 upsert 목록에 두 번 들어갈 수 있음)
            let uniqueUpsert = Array(Dictionary(uniqueKeysWithValues: tasksToUpsert.map { ($0.id, $0) }).values)

            // 5. 병합 결과 적용
            let prevCount = tasks.count
            tasks = mergedTasks
            saveTombstones()
            print("✅ [performMergeSync] 병합: \(prevCount)개 → \(mergedTasks.count)개, 업로드: \(uniqueUpsert.count)개, 클라우드삭제: \(idsToDeleteFromCloud.count)개")

            // 6. 클라우드 upsert (변경된/새로운 태스크)
            for task in uniqueUpsert {
                try await upsertTaskToCloud(task)
            }

            // 7. 클라우드에서 삭제 (우리가 삭제한 태스크)
            for id in idsToDeleteFromCloud {
                try await deleteTaskRecordFromCloud(id)
            }

            // 8. 로컬 tombstone을 클라우드에 저장
            if !taskTombstones.isEmpty {
                try await saveCloudTombstones()
            }

            // 9. SyncMetadata 업데이트
            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: syncDateKey)
            try await updateSyncMetadata()

        } catch {
            syncError = "동기화 실패: \(error.localizedDescription)"
            print("❌ [performMergeSync] 실패: \(error)")
        }
    }

    // MARK: - CloudKit Per-Record Operations

    /// 단일 태스크를 CloudKit에 upsert (저장/갱신)
    private func upsertTaskToCloud(_ task: Task) async throws {
        guard let database = database else { return }
        let record = taskToCKRecord(task)
        do {
            try await database.modifyRecords(saving: [record], deleting: [])
        } catch let error as CKError where error.code == .serverRecordChanged {
            // 서버 버전과 충돌 → 우리 버전을 강제 저장
            let serverRecord = error.serverRecord ?? record
            let fields: [String] = ["title", "taskDescription", "dueDate", "scheduledStartTime",
                                     "estimatedMinutes", "leadTimeDays", "taskType", "taskRole",
                                     "status", "priority", "manualPriority", "projectId",
                                     "parentTaskId", "mainTaskId", "targetDate",
                                     "calendarEventId", "isFromCalendarPattern", "patternId", "autoRecurring",
                                     "lastCheckinDate", "consecutiveMissedCheckins", "completedAt",
                                     "isMIT", "subtasks", "linkedWikiPageIds", "modifiedAt"]
            for field in fields {
                serverRecord[field] = record[field]
            }
            try await database.modifyRecords(saving: [serverRecord], deleting: [])
        }
    }

    /// CloudKit에서 단일 태스크 레코드 삭제
    private func deleteTaskRecordFromCloud(_ id: UUID) async throws {
        guard let database = database else { return }
        let recordID = CKRecord.ID(recordName: id.uuidString)
        do {
            try await database.modifyRecords(saving: [], deleting: [recordID])
        } catch let error as CKError where error.code == .unknownItem {
            // 이미 없으면 무시
        }
    }

    /// 클라우드에서 모든 태스크 가져오기 (병합용)
    private func fetchAllCloudTasksForMerge() async throws -> [Task] {
        guard let database = database else { return [] }

        var allTasks: [Task] = []

        // 저장된 recordNames로 직접 fetch (빠름)
        let savedNames = UserDefaults.standard.stringArray(forKey: "cloudTaskRecordNames") ?? []
        if !savedNames.isEmpty {
            let recordIDs = savedNames.map { CKRecord.ID(recordName: $0) }
            for batch in recordIDs.chunked(into: 200) {
                let results = try await database.records(for: batch)
                let batchTasks = results.values.compactMap { result -> Task? in
                    guard let record = try? result.get() else { return nil }
                    return ckRecordToTask(record)
                }
                allTasks.append(contentsOf: batchTasks)
            }
        }

        // CKQuery fallback (recordNames가 없거나 새 기기)
        let query = CKQuery(recordType: "Task", predicate: NSPredicate(value: true))
        do {
            let results = try await database.records(matching: query, desiredKeys: [
                "title", "taskDescription", "dueDate", "scheduledStartTime", "estimatedMinutes", "leadTimeDays",
                "taskType", "taskRole", "status", "priority", "createdAt",
                "parentTaskId", "mainTaskId", "targetDate", "projectId", "manualPriority",
                "calendarEventId", "isFromCalendarPattern", "patternId", "autoRecurring",
                "lastCheckinDate", "consecutiveMissedCheckins", "completedAt",
                "isMIT", "subtasks", "linkedWikiPageIds", "modifiedAt"
            ])
            let queryTasks = results.matchResults.compactMap { (_, result) -> Task? in
                guard let record = try? result.get() else { return nil }
                return ckRecordToTask(record)
            }
            // savedNames로 가져온 것과 중복 제거 (ID 기준)
            let existingIds = Set(allTasks.map { $0.id })
            let newTasks = queryTasks.filter { !existingIds.contains($0.id) }
            allTasks.append(contentsOf: newTasks)

            // recordNames 갱신
            let allNames = allTasks.map { $0.id.uuidString }
            UserDefaults.standard.set(allNames, forKey: "cloudTaskRecordNames")
        } catch {
            // Query 실패 시 savedNames fetch 결과만 사용
            print("⚠️ [fetchAllCloudTasksForMerge] CKQuery 실패 (savedNames 결과 사용): \(error)")
        }

        return allTasks
    }

    /// CloudKit SyncMetadata에서 tombstone 가져오기
    private func fetchCloudTombstones() async throws -> [UUID: Date] {
        guard let database = database else { return [:] }
        let metadataRecordID = CKRecord.ID(recordName: "SyncMetadata")
        do {
            let record = try await database.record(for: metadataRecordID)
            guard let json = record["tombstones"] as? String,
                  let data = json.data(using: .utf8),
                  let array = try? JSONDecoder().decode([[String: Double]].self, from: data) else {
                return [:]
            }
            var result: [UUID: Date] = [:]
            for item in array {
                guard let idStr = item.keys.first,
                      let timestamp = item.values.first,
                      let id = UUID(uuidString: idStr) else { continue }
                result[id] = Date(timeIntervalSince1970: timestamp)
            }
            return result
        } catch let error as CKError where error.code == .unknownItem {
            return [:]
        }
    }

    /// 로컬 tombstone을 CloudKit SyncMetadata에 저장
    private func saveCloudTombstones() async throws {
        guard let database = database else { return }
        let array = taskTombstones.map { (id, date) -> [String: Double] in
            [id.uuidString: date.timeIntervalSince1970]
        }
        guard let data = try? JSONEncoder().encode(array),
              let json = String(data: data, encoding: .utf8) else { return }

        let metadataRecordID = CKRecord.ID(recordName: "SyncMetadata")
        let record: CKRecord
        do {
            record = try await database.record(for: metadataRecordID)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: "SyncMetadata", recordID: metadataRecordID)
        }
        record["tombstones"] = json as CKRecordValue
        try await database.modifyRecords(saving: [record], deleting: [])
    }

    /// SyncMetadata 업데이트
    private func updateSyncMetadata() async throws {
        guard let database = database else { return }
        let metadataRecordID = CKRecord.ID(recordName: "SyncMetadata")
        let record: CKRecord
        do {
            record = try await database.record(for: metadataRecordID)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: "SyncMetadata", recordID: metadataRecordID)
        }
        record["lastSyncDate"] = lastSyncDate! as CKRecordValue
        record["taskCount"] = tasks.count as CKRecordValue
        record["projectCount"] = projects.count as CKRecordValue

        // tombstones도 함께 저장
        let array = taskTombstones.map { (id, date) -> [String: Double] in
            [id.uuidString: date.timeIntervalSince1970]
        }
        if let data = try? JSONEncoder().encode(array),
           let json = String(data: data, encoding: .utf8) {
            record["tombstones"] = json as CKRecordValue
        }

        do {
            try await database.modifyRecords(saving: [record], deleting: [])
            print("✅ [updateSyncMetadata] lastSyncDate: \(lastSyncDate!), tasks: \(tasks.count)")
        } catch {
            print("⚠️ [updateSyncMetadata] 실패: \(error)")
        }
    }

    // MARK: - Initial Sync

    /// 앱 시작 시 자동 동기화 → 태스크 ID 기준 양방향 병합으로 위임
    func performInitialSync() async {
        await performMergeSync()
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
    /// CloudKit에서 SyncMetadata 레코드를 직접 fetch하여 실제 클라우드의 lastSyncDate를 반환
    func getCloudDataPreview() async throws -> CloudDataPreview {
        guard let database = database else {
            throw NSError(domain: "CloudKit", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "CloudKit이 초기화되지 않았습니다. iCloud 설정을 확인하세요."
            ])
        }

        print("🔍 [getCloudDataPreview] CloudKit에서 SyncMetadata 조회 시작")

        // 1. CloudKit에서 SyncMetadata 레코드 직접 fetch
        let metadataRecordID = CKRecord.ID(recordName: "SyncMetadata")
        do {
            let metadataRecord = try await database.record(for: metadataRecordID)
            let cloudLastSync = metadataRecord["lastSyncDate"] as? Date
            let cloudTaskCount = metadataRecord["taskCount"] as? Int ?? 0
            let cloudProjectCount = metadataRecord["projectCount"] as? Int ?? 0

            print("✅ [getCloudDataPreview] SyncMetadata 조회 성공 - lastSyncDate: \(String(describing: cloudLastSync)), tasks: \(cloudTaskCount), projects: \(cloudProjectCount)")

            return CloudDataPreview(
                taskCount: cloudTaskCount,
                projectCount: cloudProjectCount,
                lastSyncDate: cloudLastSync
            )
        } catch let error as CKError where error.code == .unknownItem {
            // SyncMetadata 레코드가 없는 경우 (아직 한 번도 새 방식으로 저장하지 않은 경우)
            print("ℹ️ [getCloudDataPreview] SyncMetadata 레코드 없음, CKQuery fallback 사용")
        } catch {
            print("⚠️ [getCloudDataPreview] SyncMetadata 조회 실패, CKQuery fallback 사용: \(error)")
        }

        // 2. SyncMetadata가 없으면 기존 fallback: CKQuery로 태스크/프로젝트 개수 확인
        var taskCount = 0
        var projectCount = 0

        do {
            let taskQuery = CKQuery(recordType: "Task", predicate: NSPredicate(value: true))
            let taskResults = try await database.records(matching: taskQuery, desiredKeys: ["title"])
            taskCount = taskResults.matchResults.compactMap { (recordID, result) -> CKRecord.ID? in
                guard (try? result.get()) != nil else { return nil }
                return recordID
            }.count
        } catch {
            print("⚠️ [getCloudDataPreview] Task 쿼리 실패: \(error)")
        }

        do {
            let projectQuery = CKQuery(recordType: "Project", predicate: NSPredicate(value: true))
            let projectResults = try await database.records(matching: projectQuery, desiredKeys: ["name"])
            projectCount = projectResults.matchResults.compactMap { (recordID, result) -> CKRecord.ID? in
                guard (try? result.get()) != nil else { return nil }
                return recordID
            }.count
        } catch {
            print("⚠️ [getCloudDataPreview] Project 쿼리 실패: \(error)")
        }

        let preview = CloudDataPreview(
            taskCount: taskCount,
            projectCount: projectCount,
            lastSyncDate: nil  // SyncMetadata가 없으면 클라우드 동기화 날짜 알 수 없음
        )

        print("📊 [getCloudDataPreview] fallback 결과 - tasks: \(taskCount), projects: \(projectCount)")

        return preview
    }

    /// 로컬과 클라우드 데이터 비교
    func compareLocalAndCloudData() async throws -> DataComparisonResult {
        guard let database = database else {
            throw NSError(domain: "CloudKit", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "CloudKit이 초기화되지 않았습니다. iCloud 설정을 확인하세요."
            ])
        }


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


        return result
    }

    // MARK: - Foreground Sync

    /// 앱이 포그라운드로 복귀할 때 클라우드와 동기화 → 태스크 ID 기준 양방향 병합으로 위임
    func syncOnForeground() async {
        guard initialSyncCompleted else { return }
        await performMergeSync()
    }

    // MARK: - Auto Backup

    /// 자동 백업 트리거 (변경 감지 후 일정 시간 후 실행)
    private func triggerAutoBackup() {
        // 초기 동기화가 완료되지 않았으면 스킵 (앱 시작 시 로컬 데이터로 클라우드를 덮어쓰는 것을 방지)
        guard initialSyncCompleted else {
            return
        }

        guard isAutoBackupEnabled else {
            return
        }

        // 현재 동기화 중이면 스킵
        guard !isSyncing else {
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

    }

    /// 자동 백업 실행 → 병합 동기화로 위임
    private func performAutoBackup() async {
        guard let lastChange = lastChangeDate else { return }
        let timeSinceChange = Date().timeIntervalSince(lastChange)
        guard timeSinceChange >= autoBackupDelay else { return }

        await performMergeSync()
        lastAutoBackupDate = Date()
    }

    /// 클라우드에 저장
    func saveToCloud() async throws {
        guard let database = database else {
            throw NSError(domain: "CloudKit", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "CloudKit이 초기화되지 않았습니다. iCloud 설정을 확인하세요."
            ])
        }


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

        // SyncMetadata 레코드를 CloudKit에 저장 (다른 기기에서 클라우드 최신 여부 판단용)
        let metadataRecordID = CKRecord.ID(recordName: "SyncMetadata")
        let metadataRecord = CKRecord(recordType: "SyncMetadata", recordID: metadataRecordID)
        metadataRecord["lastSyncDate"] = lastSyncDate! as CKRecordValue
        metadataRecord["taskCount"] = tasks.count as CKRecordValue
        metadataRecord["projectCount"] = projects.count as CKRecordValue
        do {
            try await database.save(metadataRecord)
            print("✅ [saveToCloud] SyncMetadata 저장 완료 - lastSyncDate: \(lastSyncDate!), tasks: \(tasks.count), projects: \(projects.count)")
        } catch {
            print("⚠️ [saveToCloud] SyncMetadata 저장 실패 (동기화 자체에는 영향 없음): \(error)")
        }

    }

    /// 클라우드에서 복원
    /// - Parameter syncDate: 복원 후 설정할 lastSyncDate (nil이면 현재 시각 사용)
    ///   자동 동기화 시에는 클라우드 SyncMetadata 타임스탬프를 전달해야 함.
    ///   그렇지 않으면 복원 직후 로컬이 클라우드보다 "더 최신"으로 보여
    ///   syncOnForeground()가 복원 데이터를 다시 덮어쓰는 버그가 발생함.
    func restoreFromCloud(syncDate: Date? = nil) async throws {

        guard let database = database else {
            throw NSError(domain: "CloudKit", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "CloudKit이 초기화되지 않았습니다. iCloud 설정을 확인하세요."
            ])
        }

        isSyncing = true
        syncError = nil

        defer { isSyncing = false }

        // Get saved recordNames from UserDefaults
        let taskRecordNames = UserDefaults.standard.stringArray(forKey: "cloudTaskRecordNames") ?? []
        let projectRecordNames = UserDefaults.standard.stringArray(forKey: "cloudProjectRecordNames") ?? []


        // Restore tasks
        var cloudTasks: [Task] = []

        if !taskRecordNames.isEmpty {
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
                } catch let error as CKError {
                    // unknownItem 에러는 레코드가 삭제된 경우이므로 경고만 출력
                    if error.code == .unknownItem {
                    } else {
                        throw error
                    }
                }
            }
        } else {
            // recordNames가 없으면 CKQuery로 모든 레코드 가져오기
            let query = CKQuery(recordType: "Task", predicate: NSPredicate(value: true))
            query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

            do {
                // 모든 필수 필드를 명시적으로 지정 (CloudKit은 desiredKeys 생략 시 일부 필드만 가져올 수 있음)
                let results = try await database.records(matching: query, desiredKeys: [
                    "title", "taskDescription", "dueDate", "scheduledStartTime", "estimatedMinutes", "leadTimeDays",
                    "taskType", "taskRole", "status", "priority", "createdAt",
                    "parentTaskId", "mainTaskId", "targetDate", "projectId", "manualPriority",
                    "calendarEventId", "isFromCalendarPattern", "patternId", "autoRecurring",
                    "lastCheckinDate", "consecutiveMissedCheckins", "completedAt",
                    "isMIT", "subtasks", "linkedWikiPageIds"
                ])

                cloudTasks = results.matchResults.compactMap { (recordID, result) in
                    guard let record = try? result.get() else {
                        return nil
                    }
                    let task = ckRecordToTask(record)
                    if task == nil {
                    }
                    return task
                }

                // 가져온 레코드 ID를 UserDefaults에 저장
                let fetchedRecordNames = cloudTasks.map { $0.id.uuidString }
                UserDefaults.standard.set(fetchedRecordNames, forKey: "cloudTaskRecordNames")
            } catch {
                throw error
            }
        }

        // Restore projects
        var cloudProjects: [Project] = []

        if !projectRecordNames.isEmpty {
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
                } catch let error as CKError {
                    // unknownItem 에러는 레코드가 삭제된 경우이므로 경고만 출력
                    if error.code == .unknownItem {
                    } else {
                        throw error
                    }
                }
            }
        } else {
            // recordNames가 없으면 CKQuery로 모든 레코드 가져오기
            let query = CKQuery(recordType: "Project", predicate: NSPredicate(value: true))

            do {
                // 모든 필수 필드를 명시적으로 지정
                let results = try await database.records(matching: query, desiredKeys: ["name", "color", "icon"])

                cloudProjects = results.matchResults.compactMap { (recordID, result) in
                    guard let record = try? result.get() else {
                        return nil
                    }
                    let project = ckRecordToProject(record)
                    if project == nil {
                    }
                    return project
                }

                // 가져온 레코드 ID를 UserDefaults에 저장
                let fetchedRecordNames = cloudProjects.map { $0.id.uuidString }
                UserDefaults.standard.set(fetchedRecordNames, forKey: "cloudProjectRecordNames")
            } catch {
                throw error
            }
        }

        tasks = cloudTasks

        projects = cloudProjects

        // 동기화 날짜 설정:
        // - 수동 복원(syncDate == nil): 현재 시각 사용
        // - 자동 복원(syncDate 전달됨): 클라우드 타임스탬프 사용
        //   → 이렇게 해야 복원 후 syncOnForeground()가 "로컬이 더 최신"으로
        //     오판하여 불완전한 데이터를 다시 클라우드에 덮어쓰는 버그를 방지함
        lastSyncDate = syncDate ?? Date()
        UserDefaults.standard.set(lastSyncDate, forKey: syncDateKey)

    }

    /// 데이터 초기화 (로컬 + 클라우드)
    func resetAllData() async throws {

        // 1. tasks 배열 초기화 (이때 didSet이 호출되어 saveTasks() 실행됨)
        tasks = []

        // 2. UserDefaults 삭제
        UserDefaults.standard.removeObject(forKey: tasksKey)
        UserDefaults.standard.removeObject(forKey: "\(tasksKey)_backup")

        // 3. 프로젝트 초기화
        projects = []
        UserDefaults.standard.removeObject(forKey: projectsKey)

        // 4. 클라우드 레코드 삭제
        try await deleteAllCloudRecords()

    }

    /// 로컬 데이터만 초기화
    func resetLocalData() {

        // 1. tasks 배열 초기화
        tasks = []

        // 2. UserDefaults 삭제
        UserDefaults.standard.removeObject(forKey: tasksKey)
        UserDefaults.standard.removeObject(forKey: "\(tasksKey)_backup")

        // 3. 프로젝트 초기화
        projects = []
        UserDefaults.standard.removeObject(forKey: projectsKey)

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
        } catch let error as CKError {
            if let partialErrors = error.userInfo[CKPartialErrorsByItemIDKey] as? [CKRecord.ID: Error] {
                for (recordID, partialError) in partialErrors {
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
                }
            }

            // Delete all Project records
            if !projectRecordNames.isEmpty {
                let projectRecordIDs = projectRecordNames.map { CKRecord.ID(recordName: $0) }
                for batch in projectRecordIDs.chunked(into: 200) {
                    let (_, deletedRecordIDs) = try await database.modifyRecords(saving: [], deleting: batch)
                }
            }

            // Delete SyncMetadata record
            let metadataRecordID = CKRecord.ID(recordName: "SyncMetadata")
            do {
                let (_, _) = try await database.modifyRecords(saving: [], deleting: [metadataRecordID])
                print("✅ [deleteAllCloudRecords] SyncMetadata 레코드 삭제 완료")
            } catch let metaError as CKError where metaError.code == .unknownItem {
                // SyncMetadata 레코드가 없으면 무시
                print("ℹ️ [deleteAllCloudRecords] SyncMetadata 레코드 없음 (이미 삭제됨)")
            }
        } catch let error as CKError {
            // "Unknown Item" 에러는 레코드가 없다는 의미이므로 무시
            if error.code == .unknownItem {
                return
            }
            throw error
        }
    }


    private func taskToCKRecord(_ task: Task) -> CKRecord {
        let recordID = CKRecord.ID(recordName: task.id.uuidString)
        let record = CKRecord(recordType: "Task", recordID: recordID)

        // 기본 정보
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

        // Optional 필드들
        if let scheduledStartTime = task.scheduledStartTime {
            record["scheduledStartTime"] = scheduledStartTime as CKRecordValue
        }
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

        // 캘린더 연동 정보
        if let calendarEventId = task.calendarEventId {
            record["calendarEventId"] = calendarEventId as CKRecordValue
        }
        record["isFromCalendarPattern"] = task.isFromCalendarPattern as CKRecordValue
        if let patternId = task.patternId {
            record["patternId"] = patternId.uuidString as CKRecordValue
        }
        record["autoRecurring"] = task.autoRecurring as CKRecordValue

        // 체크인 정보
        if let lastCheckinDate = task.lastCheckinDate {
            record["lastCheckinDate"] = lastCheckinDate as CKRecordValue
        }
        record["consecutiveMissedCheckins"] = task.consecutiveMissedCheckins as CKRecordValue

        // 완료 정보
        if let completedAt = task.completedAt {
            record["completedAt"] = completedAt as CKRecordValue
        }

        // MIT
        record["isMIT"] = task.isMIT as CKRecordValue

        // 수정 시각 (per-task 병합 기준)
        record["modifiedAt"] = task.modifiedAt as CKRecordValue

        // 하위 할 일 (JSON 직렬화)
        if !task.subtasks.isEmpty,
           let subtasksData = try? JSONEncoder().encode(task.subtasks),
           let subtasksString = String(data: subtasksData, encoding: .utf8) {
            record["subtasks"] = subtasksString as CKRecordValue
        }

        // 위키 연결 (UUID 배열을 JSON 직렬화)
        if !task.linkedWikiPageIds.isEmpty,
           let idsData = try? JSONEncoder().encode(task.linkedWikiPageIds.map { $0.uuidString }),
           let idsString = String(data: idsData, encoding: .utf8) {
            record["linkedWikiPageIds"] = idsString as CKRecordValue
        }

        return record
    }

    private func ckRecordToTask(_ record: CKRecord) -> Task? {
        // 필수 필드 체크 및 상세 로깅
        guard let title = record["title"] as? String else {
            return nil
        }
        guard let dueDate = record["dueDate"] as? Date else {
            return nil
        }
        guard let estimatedMinutes = record["estimatedMinutes"] as? Int else {
            return nil
        }
        guard let leadTimeDays = record["leadTimeDays"] as? Int else {
            return nil
        }
        guard let taskTypeRaw = record["taskType"] as? String,
              let taskType = TaskType(rawValue: taskTypeRaw) else {
            return nil
        }
        guard let taskRoleRaw = record["taskRole"] as? String else {
            return nil
        }
        guard let statusRaw = record["status"] as? String,
              let status = TaskStatus(rawValue: statusRaw) else {
            return nil
        }
        guard let createdAt = record["createdAt"] as? Date else {
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
        let scheduledStartTime = record["scheduledStartTime"] as? Date
        let parentTaskId = (record["parentTaskId"] as? String).flatMap { UUID(uuidString: $0) }
        let mainTaskId = (record["mainTaskId"] as? String).flatMap { UUID(uuidString: $0) }
        let targetDate = record["targetDate"] as? Date
        let projectId = (record["projectId"] as? String).flatMap { UUID(uuidString: $0) }
        let manualPriority = record["manualPriority"] as? Int

        // priority는 optional로 처리 (기존 레코드 호환성)
        let priorityRaw = record["priority"] as? String
        let priority = priorityRaw.flatMap { TaskPriority(rawValue: $0) } ?? .normal

        // 캘린더 연동 정보
        let calendarEventId = record["calendarEventId"] as? String
        let isFromCalendarPattern = record["isFromCalendarPattern"] as? Bool ?? false
        let patternId = (record["patternId"] as? String).flatMap { UUID(uuidString: $0) }
        let autoRecurring = record["autoRecurring"] as? Bool ?? false

        // 체크인 정보
        let lastCheckinDate = record["lastCheckinDate"] as? Date
        let consecutiveMissedCheckins = record["consecutiveMissedCheckins"] as? Int ?? 0

        // 완료 정보
        let completedAt = record["completedAt"] as? Date

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
        task.scheduledStartTime = scheduledStartTime
        task.manualPriority = manualPriority
        task.calendarEventId = calendarEventId
        task.isFromCalendarPattern = isFromCalendarPattern
        task.patternId = patternId
        task.autoRecurring = autoRecurring
        task.lastCheckinDate = lastCheckinDate
        task.consecutiveMissedCheckins = consecutiveMissedCheckins
        task.completedAt = completedAt

        // MIT
        task.isMIT = record["isMIT"] as? Bool ?? false

        // 수정 시각 (없으면 createdAt fallback)
        task.modifiedAt = record["modifiedAt"] as? Date ?? task.createdAt

        // 하위 할 일 (JSON 역직렬화)
        if let subtasksString = record["subtasks"] as? String,
           let subtasksData = subtasksString.data(using: .utf8),
           let subtasks = try? JSONDecoder().decode([Subtask].self, from: subtasksData) {
            task.subtasks = subtasks
        }

        // 위키 연결 (JSON 역직렬화)
        if let idsString = record["linkedWikiPageIds"] as? String,
           let idsData = idsString.data(using: .utf8),
           let idStrings = try? JSONDecoder().decode([String].self, from: idsData) {
            task.linkedWikiPageIds = idStrings.compactMap { UUID(uuidString: $0) }
        }

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
            // 캘린더를 사용하지 않으면 기본 설정 사용
            updateTimeBlocksWithFixedHours()
            return
        }

        guard !timeBlockCalendarIds.isEmpty else {
            updateTimeBlocksWithFixedHours()
            return
        }

        guard let calendarVM = calendarViewModel else {
            updateTimeBlocksWithFixedHours()
            return
        }


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

        }

    }

    /// 고정된 시간으로 타임 블록 업데이트 (캘린더 미사용)
    private func updateTimeBlocksWithFixedHours() {
        let fixedMinutes = Int(dailyAvailableHours * 60)

        for i in 0..<timeBlockManager.blocks.count {
            timeBlockManager.blocks[i].availableMinutes = fixedMinutes
        }

    }

    /// 캘린더 ViewModel 연결
    func setCalendarViewModel(_ calendarVM: CalendarViewModel) {
        self.calendarViewModel = calendarVM

        // 연결 후 즉시 타임 블록 업데이트
        if useCalendarForTimeBlocks {
            updateTimeBlocksWithCalendar()
        }
    }

    // MARK: - Notification Management

    /// NotificationService 연결
    func setNotificationService(_ service: NotificationService) {
        self.notificationService = service

        // 연결 후 즉시 알림 스케줄 업데이트
        _Concurrency.Task {
            await updateNotificationSchedule()
        }
    }

    /// 알림 스케줄 갱신
    func updateNotificationSchedule() async {
        guard let service = notificationService else {
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
            return
        }

        // 체크인 시간 기록
        tasks[index].lastCheckinDate = Date()
        tasks[index].consecutiveMissedCheckins = 0
        tasks[index].modifiedAt = Date()

        switch response {
        case .onTrack:
            // 순조롭게 진행 중 - 상태 유지
            break

        case .completed:
            // 완료 처리
            tasks[index].status = .completed

        case .needHelp:
            // 문제 있음 - 우선순위 상향
            if tasks[index].priority != .urgent {
                tasks[index].priority = .high
            }

        case .postponed:
            // 연기 - 마감일 하루 연장
            if let newDueDate = Calendar.current.date(byAdding: .day, value: 1, to: tasks[index].dueDate) {
                tasks[index].dueDate = newDueDate
            }
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
                }
            } else if tasks[index].status == .inProgress {
                // 진행 중인데 한 번도 체크인한 적 없음
                tasks[index].consecutiveMissedCheckins += 1
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
