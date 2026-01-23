import XCTest
@testable import WeekAheadTodo

@MainActor
final class TaskViewModelTests: XCTestCase {

    var viewModel: TaskViewModel!

    override func setUp() {
        super.setUp()
        // Clear UserDefaults before each test to ensure clean state
        UserDefaults.standard.removeObject(forKey: "SavedTasks")
        UserDefaults.standard.removeObject(forKey: "projects")
        viewModel = TaskViewModel()
    }

    override func tearDown() {
        // Clean up after test
        UserDefaults.standard.removeObject(forKey: "SavedTasks")
        UserDefaults.standard.removeObject(forKey: "projects")
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Today Tasks Tests

    func test오늘할일_현재지평선으로필터링() {
        // Given
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let nextWeek = Calendar.current.date(byAdding: .day, value: 8, to: today)!

        viewModel.addTask(Task(title: "Today Task 1", dueDate: today, leadTimeDays: 0))
        viewModel.addTask(Task(title: "Today Task 2", dueDate: today, leadTimeDays: 0))
        viewModel.addTask(Task(title: "Tomorrow Task", dueDate: tomorrow, leadTimeDays: 0))
        viewModel.addTask(Task(title: "Next Week Task", dueDate: nextWeek, leadTimeDays: 0))

        // When
        let todayTasks = viewModel.todayTasks

        // Then
        XCTAssertEqual(todayTasks.count, 2)
        XCTAssertTrue(todayTasks.allSatisfy { $0.currentHorizon == .today })
    }

    func test오늘할일_긴급도점수로정렬() {
        // Given
        let today = Date()
        let urgentTask = Task(title: "Urgent", dueDate: today, estimatedMinutes: 180, leadTimeDays: 0)
        let normalTask = Task(title: "Normal", dueDate: today, estimatedMinutes: 60, leadTimeDays: 0)
        let quickTask = Task(title: "Quick", dueDate: today, estimatedMinutes: 15, leadTimeDays: 0)

        viewModel.addTask(normalTask)
        viewModel.addTask(quickTask)
        viewModel.addTask(urgentTask)

        // When
        let todayTasks = viewModel.todayTasks

        // Then - sortOrder 오름차순 정렬 (작은 값이 먼저)
        // urgencyScore: Quick(-99.75), Normal(-99), Urgent(-97)
        // sortOrder: Quick(-9975), Normal(-9900), Urgent(-9700)
        XCTAssertEqual(todayTasks.count, 3)
        XCTAssertEqual(todayTasks[0].title, "Quick") // sortOrder가 가장 작음
        XCTAssertEqual(todayTasks[2].title, "Urgent") // sortOrder가 가장 큼
    }

    func test오늘할일_완료된태스크포함() {
        // Given
        let today = Date()
        var completedTask = Task(title: "Completed", dueDate: today, leadTimeDays: 0)
        completedTask.status = .completed

        viewModel.addTask(Task(title: "Not Completed", dueDate: today, leadTimeDays: 0))
        viewModel.addTask(completedTask)

        // When
        let todayTasks = viewModel.todayTasks

        // Then
        XCTAssertEqual(todayTasks.count, 2)
        XCTAssertTrue(todayTasks.contains { $0.isCompleted })
    }

    func test오늘미완료할일_완료된것제외() {
        // Given
        let today = Date()
        var completedTask = Task(title: "Completed", dueDate: today, leadTimeDays: 0)
        completedTask.status = .completed

        viewModel.addTask(Task(title: "Not Completed", dueDate: today, leadTimeDays: 0))
        viewModel.addTask(completedTask)

        // When
        let incompleteTasks = viewModel.todayIncompleteTasks

        // Then
        XCTAssertEqual(incompleteTasks.count, 1)
        XCTAssertFalse(incompleteTasks[0].isCompleted)
    }

    // MARK: - Reorder Tasks Tests

    func test오늘할일재정렬_수동우선순위할당() {
        // Given
        let today = Date()
        viewModel.addTask(Task(title: "Task A", dueDate: today, leadTimeDays: 0))
        viewModel.addTask(Task(title: "Task B", dueDate: today, leadTimeDays: 0))
        viewModel.addTask(Task(title: "Task C", dueDate: today, leadTimeDays: 0))

        // When - Move first item to end (0 -> 2)
        viewModel.reorderTodayTasks(from: IndexSet(integer: 0), to: 3)

        // Then - 순서가 바뀌고 manualPriority가 할당됨
        let reorderedTasks = viewModel.todayTasks
        XCTAssertNotNil(reorderedTasks[0].manualPriority)
        XCTAssertNotNil(reorderedTasks[1].manualPriority)
        XCTAssertNotNil(reorderedTasks[2].manualPriority)

        // 순서 확인
        XCTAssertEqual(reorderedTasks[0].manualPriority, 0)
        XCTAssertEqual(reorderedTasks[1].manualPriority, 1)
        XCTAssertEqual(reorderedTasks[2].manualPriority, 2)
    }

    func test수동우선순위초기화_모든수동우선순위제거() {
        // Given
        let today = Date()
        viewModel.addTask(Task(title: "Task A", dueDate: today, leadTimeDays: 0))
        viewModel.addTask(Task(title: "Task B", dueDate: today, leadTimeDays: 0))

        viewModel.reorderTodayTasks(from: IndexSet(integer: 0), to: 2)

        // Verify manual priorities are set
        XCTAssertTrue(viewModel.tasks.contains { $0.manualPriority != nil })

        // When
        viewModel.resetManualPriorities()

        // Then
        XCTAssertTrue(viewModel.tasks.allSatisfy { $0.manualPriority == nil })
    }

    // MARK: - Add Task Tests

    func test태스크추가_개수증가() {
        // Given
        let initialCount = viewModel.tasks.count

        // When
        viewModel.addTask(Task(title: "New Task", dueDate: Date()))

        // Then
        XCTAssertEqual(viewModel.tasks.count, initialCount + 1)
    }

    func test태스크추가_배열에추가됨() {
        // Given
        let newTask = Task(title: "New Task", dueDate: Date())

        // When
        viewModel.addTask(newTask)

        // Then
        XCTAssertTrue(viewModel.tasks.contains { $0.id == newTask.id })
    }

    // MARK: - Delete Task Tests

    func test태스크삭제_배열에서제거() {
        // Given
        let task = Task(title: "Task to Delete", dueDate: Date())
        viewModel.addTask(task)
        let initialCount = viewModel.tasks.count

        // When
        viewModel.deleteTask(task)

        // Then
        XCTAssertEqual(viewModel.tasks.count, initialCount - 1)
        XCTAssertFalse(viewModel.tasks.contains { $0.id == task.id })
    }

    func test태스크삭제_준비태스크포함_준비태스크도삭제() {
        // Given
        let mainTask = Task(title: "Main Task", dueDate: Date(), taskRole: .none)
        var prepTask1 = Task(title: "Prep 1", dueDate: Date(), taskRole: .preparation)
        prepTask1.mainTaskId = mainTask.id
        var prepTask2 = Task(title: "Prep 2", dueDate: Date(), taskRole: .preparation)
        prepTask2.mainTaskId = mainTask.id

        viewModel.addTask(mainTask)
        viewModel.addTask(prepTask1)
        viewModel.addTask(prepTask2)

        let initialCount = viewModel.tasks.count
        XCTAssertEqual(initialCount, 3)

        // When
        viewModel.deleteTask(mainTask)

        // Then - 메인 태스크와 준비 태스크 모두 삭제됨
        XCTAssertEqual(viewModel.tasks.count, 0)
    }

    // MARK: - Update Task Tests

    func test태스크업데이트_기존태스크수정() {
        // Given
        var task = Task(title: "Original Title", dueDate: Date())
        viewModel.addTask(task)

        // When
        task.title = "Updated Title"
        viewModel.updateTask(task)

        // Then
        let updatedTask = viewModel.tasks.first { $0.id == task.id }
        XCTAssertEqual(updatedTask?.title, "Updated Title")
    }

    // MARK: - Tasks by Horizon Tests

    func test지평선별태스크_올바르게그룹화() {
        // Given
        let today = Date()
        let thisWeek = Calendar.current.date(byAdding: .day, value: 5, to: today)!
        let nextWeek = Calendar.current.date(byAdding: .day, value: 10, to: today)!
        let later = Calendar.current.date(byAdding: .day, value: 20, to: today)!

        viewModel.addTask(Task(title: "Today 1", dueDate: today, leadTimeDays: 0))
        viewModel.addTask(Task(title: "Today 2", dueDate: today, leadTimeDays: 0))
        viewModel.addTask(Task(title: "This Week", dueDate: thisWeek, leadTimeDays: 0))
        viewModel.addTask(Task(title: "Next Week", dueDate: nextWeek, leadTimeDays: 0))
        viewModel.addTask(Task(title: "Later", dueDate: later, leadTimeDays: 0))

        // When
        let grouped = viewModel.tasksByHorizon

        // Then
        XCTAssertEqual(grouped[.today]?.count, 2)
        XCTAssertEqual(grouped[.thisWeek]?.count, 1)
        XCTAssertEqual(grouped[.nextWeek]?.count, 1)
        XCTAssertEqual(grouped[.later]?.count, 1)
    }

    func test지평선별태스크_완료된태스크제외() {
        // Given
        let today = Date()
        var completedTask = Task(title: "Completed", dueDate: today, leadTimeDays: 0)
        completedTask.status = .completed

        viewModel.addTask(Task(title: "Active", dueDate: today, leadTimeDays: 0))
        viewModel.addTask(completedTask)

        // When
        let grouped = viewModel.tasksByHorizon

        // Then
        XCTAssertEqual(grouped[.today]?.count, 1)
        XCTAssertFalse(grouped[.today]?.contains { $0.isCompleted } ?? true)
    }

    // MARK: - Capacity Tests

    func test오늘용량초과_초과됨() {
        // Given
        let today = Date()
        // 기본 용량은 6시간 (360분)
        // 총 9시간 = 540분 > 360분
        viewModel.addTask(Task(title: "Task 1", dueDate: today, estimatedMinutes: 300, leadTimeDays: 0))
        viewModel.addTask(Task(title: "Task 2", dueDate: today, estimatedMinutes: 240, leadTimeDays: 0))

        // When
        let isOverCapacity = viewModel.isTodayOverCapacity

        // Then
        XCTAssertTrue(isOverCapacity)
    }

    func test오늘용량초과_초과안됨() {
        // Given
        let today = Date()
        // 기본 용량은 6시간 (360분)
        // 총 3시간 = 180분 < 360분
        viewModel.addTask(Task(title: "Task 1", dueDate: today, estimatedMinutes: 120, leadTimeDays: 0))
        viewModel.addTask(Task(title: "Task 2", dueDate: today, estimatedMinutes: 60, leadTimeDays: 0))

        // When
        let isOverCapacity = viewModel.isTodayOverCapacity

        // Then
        XCTAssertFalse(isOverCapacity)
    }
}
