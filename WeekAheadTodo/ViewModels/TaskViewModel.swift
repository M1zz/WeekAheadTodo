import Foundation
import SwiftUI

/// 앱의 핵심 비즈니스 로직을 담당하는 ViewModel
@MainActor
class TaskViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var tasks: [Task] = []
    @Published var timeBlockManager: WeeklyTimeBlockManager
    @Published var dailyAvailableHours: Double = 6.0
    @Published var selectedDate: Date = Date()
    @Published var showingAddTask = false
    @Published var selectedHorizon: TimeHorizon? = nil
    
    // MARK: - Initialization
    
    init() {
        self.timeBlockManager = WeeklyTimeBlockManager(defaultDailyMinutes: 360)
        loadSampleData()
    }
    
    // MARK: - Computed Properties
    
    /// 시간 지평선별로 그룹화된 태스크
    var tasksByHorizon: [TimeHorizon: [Task]] {
        Dictionary(grouping: tasks.filter { !$0.isCompleted }) { $0.currentHorizon }
    }
    
    /// 오늘 할 일 (역산 결과 기준)
    var todayTasks: [Task] {
        tasks
            .filter { !$0.isCompleted && $0.currentHorizon == .today }
            .sorted { $0.urgencyScore < $1.urgencyScore }
    }
    
    /// 이번 주 할 일
    var thisWeekTasks: [Task] {
        tasks
            .filter { !$0.isCompleted && $0.currentHorizon == .thisWeek }
            .sorted { $0.effectiveStartDate < $1.effectiveStartDate }
    }
    
    /// 다음 주 할 일
    var nextWeekTasks: [Task] {
        tasks
            .filter { !$0.isCompleted && $0.currentHorizon == .nextWeek }
            .sorted { $0.effectiveStartDate < $1.effectiveStartDate }
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
    
    /// 오늘 사용된 시간 (분)
    var todayUsedMinutes: Int {
        todayTasks.reduce(0) { $0 + $1.estimatedMinutes }
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
        // 메인 태스크 추가
        var main = mainTask
        tasks.append(main)
        
        // 템플릿 기반 서브태스크 생성
        for subtask in template.subtasks {
            let sub = Task(
                title: subtask.title,
                dueDate: mainTask.dueDate,
                estimatedMinutes: subtask.estimatedMinutes,
                leadTimeDays: subtask.leadTimeDays,
                taskType: .preparable,
                parentTaskId: main.id
            )
            tasks.append(sub)
            allocateTaskToTimeBlock(sub)
        }
    }
    
    func toggleTaskCompletion(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isCompleted.toggle()
        }
    }
    
    func deleteTask(_ task: Task) {
        // 서브태스크도 함께 삭제
        tasks.removeAll { $0.id == task.id || $0.parentTaskId == task.id }
        
        // 시간 블록에서도 제거
        for i in 0..<timeBlockManager.blocks.count {
            timeBlockManager.blocks[i].allocatedTasks.removeAll { $0 == task.id }
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
    
    // MARK: - Sample Data
    
    private func loadSampleData() {
        let calendar = Calendar.current
        let today = Date()
        
        // 오늘 해야 할 일
        tasks.append(Task(
            title: "이메일 회신 정리",
            dueDate: today,
            estimatedMinutes: 30,
            leadTimeDays: 0,
            taskType: .dateSpecific
        ))
        
        // 이번 주 회의 준비
        let meetingDate = calendar.date(byAdding: .day, value: 3, to: today)!
        tasks.append(Task(
            title: "팀 주간 회의 아젠다 준비",
            dueDate: meetingDate,
            estimatedMinutes: 45,
            leadTimeDays: 2,
            taskType: .preparable
        ))
        
        // 다음 주 발표 준비
        let presentationDate = calendar.date(byAdding: .day, value: 8, to: today)!
        tasks.append(Task(
            title: "분기 리뷰 발표 자료",
            description: "Q4 성과 정리 및 Q1 계획 발표",
            dueDate: presentationDate,
            estimatedMinutes: 120,
            leadTimeDays: 5,
            taskType: .preparable
        ))
        
        tasks.append(Task(
            title: "발표 슬라이드 디자인",
            dueDate: presentationDate,
            estimatedMinutes: 60,
            leadTimeDays: 3,
            taskType: .preparable
        ))
        
        // 더 먼 미래
        let reportDate = calendar.date(byAdding: .day, value: 12, to: today)!
        tasks.append(Task(
            title: "월간 보고서 작성",
            dueDate: reportDate,
            estimatedMinutes: 90,
            leadTimeDays: 4,
            taskType: .preparable
        ))
        
        // 당일만 가능한 일
        let interviewDate = calendar.date(byAdding: .day, value: 5, to: today)!
        tasks.append(Task(
            title: "채용 면접 진행",
            dueDate: interviewDate,
            estimatedMinutes: 60,
            leadTimeDays: 0,
            taskType: .dateSpecific
        ))
    }
    
    // MARK: - Calendar Pattern Integration

    /// 캘린더 패턴에서 Task 생성
    func createTaskFromPattern(_ pattern: RecurrencePattern) {
        let suggested = pattern.suggestedTask

        // 다음 발생 날짜 계산
        let nextOccurrence = suggested.recurrenceRule?.nextOccurrenceDate ?? Calendar.current.date(byAdding: .day, value: 7, to: Date())!

        // Task 생성
        let task = Task(
            title: suggested.title,
            description: "캘린더 패턴에서 자동 생성됨",
            dueDate: nextOccurrence,
            estimatedMinutes: suggested.estimatedMinutes,
            leadTimeDays: suggested.leadTimeDays,
            taskType: suggested.taskType,
            isCompleted: false
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
}
