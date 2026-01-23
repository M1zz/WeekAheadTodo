import XCTest
@testable import WeekAheadTodo

@MainActor
final class ProactiveAssistantServiceTests: XCTestCase {

    var service: ProactiveAssistantService!

    override func setUp() {
        super.setUp()
        service = ProactiveAssistantService.shared
        service.clearDismissedSuggestions()
    }

    override func tearDown() {
        service.clearDismissedSuggestions()
        service = nil
        super.tearDown()
    }

    // MARK: - Meeting Preparation Missing Tests

    func test회의준비누락감지_준비미완료() {
        // Given
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!

        let mainTask = Task(
            title: "Team Meeting",
            dueDate: tomorrow,
            taskRole: .none
        )

        var prepTask1 = Task(
            title: "Prepare Agenda",
            dueDate: tomorrow,
            taskRole: .preparation
        )
        prepTask1.mainTaskId = mainTask.id
        prepTask1.status = .completed

        var prepTask2 = Task(
            title: "Prepare Materials",
            dueDate: tomorrow,
            taskRole: .preparation
        )
        prepTask2.mainTaskId = mainTask.id
        prepTask2.status = .notStarted

        var prepTask3 = Task(
            title: "Review Data",
            dueDate: tomorrow,
            taskRole: .preparation
        )
        prepTask3.mainTaskId = mainTask.id
        prepTask3.status = .notStarted

        let tasks = [mainTask, prepTask1, prepTask2, prepTask3]

        // When
        service.analyzeTasks(tasks)

        // Then - 준비 완료도 33% < 50%
        XCTAssertTrue(service.activeSuggestions.contains { $0.type == .meetingPreparationMissing })
    }

    func test회의준비누락감지_준비충분() {
        // Given
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!

        let mainTask = Task(
            title: "Team Meeting",
            dueDate: tomorrow,
            taskRole: .none
        )

        var prepTask1 = Task(
            title: "Prepare Agenda",
            dueDate: tomorrow,
            taskRole: .preparation
        )
        prepTask1.mainTaskId = mainTask.id
        prepTask1.status = .completed

        var prepTask2 = Task(
            title: "Prepare Materials",
            dueDate: tomorrow,
            taskRole: .preparation
        )
        prepTask2.mainTaskId = mainTask.id
        prepTask2.status = .completed

        let tasks = [mainTask, prepTask1, prepTask2]

        // When
        service.analyzeTasks(tasks)

        // Then - 준비 완료도 100% >= 50%
        XCTAssertFalse(service.activeSuggestions.contains { $0.type == .meetingPreparationMissing })
    }

    // MARK: - Capacity Overload Tests

    func test용량초과감지_초과됨() {
        // Given
        let today = Date()
        let task1 = Task(
            title: "Task 1",
            dueDate: today,
            estimatedMinutes: 300, // 5시간
            leadTimeDays: 0
        )
        let task2 = Task(
            title: "Task 2",
            dueDate: today,
            estimatedMinutes: 240, // 4시간
            leadTimeDays: 0
        )
        // 총 9시간 > 8시간

        let tasks = [task1, task2]

        // When
        service.analyzeTasks(tasks)

        // Then
        XCTAssertTrue(service.activeSuggestions.contains { $0.type == .capacityOverload })
        let suggestion = service.activeSuggestions.first { $0.type == .capacityOverload }
        XCTAssertEqual(suggestion?.priority, .urgent)
    }

    func test용량초과감지_초과안됨() {
        // Given
        let today = Date()
        let task1 = Task(
            title: "Task 1",
            dueDate: today,
            estimatedMinutes: 120, // 2시간
            leadTimeDays: 0
        )
        let task2 = Task(
            title: "Task 2",
            dueDate: today,
            estimatedMinutes: 90, // 1.5시간
            leadTimeDays: 0
        )
        // 총 3.5시간 < 8시간

        let tasks = [task1, task2]

        // When
        service.analyzeTasks(tasks)

        // Then
        XCTAssertFalse(service.activeSuggestions.contains { $0.type == .capacityOverload })
    }

    // MARK: - Deadline Risk Tests

    func test마감위험감지_기한초과() {
        // Given
        let calendar = Calendar.current
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: Date())!
        let dueDate = calendar.date(byAdding: .day, value: 2, to: Date())!

        let task = Task(
            title: "Overdue Task",
            dueDate: dueDate,
            leadTimeDays: 5, // 시작일이 3일 전
            status: .notStarted
        )

        let tasks = [task]

        // When
        service.analyzeTasks(tasks)

        // Then
        XCTAssertTrue(service.activeSuggestions.contains { $0.type == .deadlineRisk })
        let suggestion = service.activeSuggestions.first { $0.type == .deadlineRisk }
        XCTAssertEqual(suggestion?.priority, .high)
    }

    func test마감위험감지_진행중() {
        // Given
        let calendar = Calendar.current
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: Date())!
        let dueDate = calendar.date(byAdding: .day, value: 2, to: Date())!

        var task = Task(
            title: "In Progress Task",
            dueDate: dueDate,
            leadTimeDays: 5,
            status: .inProgress
        )

        let tasks = [task]

        // When
        service.analyzeTasks(tasks)

        // Then - 진행 중이면 제안 안 함
        XCTAssertFalse(service.activeSuggestions.contains { $0.type == .deadlineRisk })
    }

    // MARK: - Idle Time Tests

    func test여유시간감지_여유있음() {
        // Given
        let calendar = Calendar.current
        let today = Date()
        let thisWeek = calendar.date(byAdding: .day, value: 5, to: today)!

        // 오늘: 총 2시간 (6시간 여유)
        let todayTask = Task(
            title: "Today Task",
            dueDate: today,
            estimatedMinutes: 120,
            leadTimeDays: 0
        )

        // 이번 주: 미리 할 수 있는 일
        let futureTask = Task(
            title: "Future Task",
            dueDate: thisWeek,
            estimatedMinutes: 60,
            leadTimeDays: 0,
            taskType: .preparable
        )

        let tasks = [todayTask, futureTask]

        // When
        service.analyzeTasks(tasks)

        // Then - 여유 시간 >= 60분
        XCTAssertTrue(service.activeSuggestions.contains { $0.type == .idleTime })
        let suggestion = service.activeSuggestions.first { $0.type == .idleTime }
        XCTAssertEqual(suggestion?.priority, .low)
    }

    func test여유시간감지_여유없음() {
        // Given
        let today = Date()
        // 오늘: 총 8시간 (여유 없음)
        let task1 = Task(
            title: "Task 1",
            dueDate: today,
            estimatedMinutes: 240,
            leadTimeDays: 0
        )
        let task2 = Task(
            title: "Task 2",
            dueDate: today,
            estimatedMinutes: 240,
            leadTimeDays: 0
        )

        let tasks = [task1, task2]

        // When
        service.analyzeTasks(tasks)

        // Then
        XCTAssertFalse(service.activeSuggestions.contains { $0.type == .idleTime })
    }

    // MARK: - Suggestion Priority Tests

    func test태스크분석_최대3개제안으로제한() {
        // Given - 여러 조건을 동시에 만족하도록 설정
        let calendar = Calendar.current
        let today = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        // 1. Capacity Overload
        let overloadTask1 = Task(title: "Heavy 1", dueDate: today, estimatedMinutes: 300, leadTimeDays: 0)
        let overloadTask2 = Task(title: "Heavy 2", dueDate: today, estimatedMinutes: 240, leadTimeDays: 0)

        // 2. Deadline Risk
        var riskTask = Task(title: "Risk", dueDate: tomorrow, leadTimeDays: 5, status: .notStarted)

        // 3. Meeting Preparation Missing
        let mainTask = Task(title: "Meeting", dueDate: tomorrow, taskRole: .none)
        var prepTask = Task(title: "Prep", dueDate: tomorrow, taskRole: .preparation)
        prepTask.mainTaskId = mainTask.id

        let tasks = [overloadTask1, overloadTask2, riskTask, mainTask, prepTask]

        // When
        service.analyzeTasks(tasks)

        // Then - 최대 3개만 표시
        XCTAssertLessThanOrEqual(service.activeSuggestions.count, 3)
    }

    func test태스크분석_우선순위순정렬() {
        // Given
        let calendar = Calendar.current
        let today = Date()
        let thisWeek = calendar.date(byAdding: .day, value: 5, to: today)!

        // Urgent: Capacity Overload
        let urgentTask1 = Task(title: "Urgent 1", dueDate: today, estimatedMinutes: 300, leadTimeDays: 0)
        let urgentTask2 = Task(title: "Urgent 2", dueDate: today, estimatedMinutes: 240, leadTimeDays: 0)

        // Low: Idle Time
        let todayLightTask = Task(title: "Light", dueDate: today, estimatedMinutes: 60, leadTimeDays: 0)
        let futureTask = Task(title: "Future", dueDate: thisWeek, estimatedMinutes: 30, leadTimeDays: 0, taskType: .preparable)

        let tasks = [urgentTask1, urgentTask2, todayLightTask, futureTask]

        // When
        service.analyzeTasks(tasks)

        // Then - 우선순위 순으로 정렬
        if service.activeSuggestions.count >= 2 {
            let firstPriority = service.activeSuggestions[0].priority.rawValue
            let secondPriority = service.activeSuggestions[1].priority.rawValue
            XCTAssertGreaterThanOrEqual(firstPriority, secondPriority)
        }
    }

    // MARK: - Dismiss Tests

    func test제안무시_활성제안에서제거() {
        // Given
        let today = Date()
        let task1 = Task(title: "Task 1", dueDate: today, estimatedMinutes: 300, leadTimeDays: 0)
        let task2 = Task(title: "Task 2", dueDate: today, estimatedMinutes: 240, leadTimeDays: 0)
        service.analyzeTasks([task1, task2])

        guard let suggestion = service.activeSuggestions.first else {
            XCTFail("No suggestions generated")
            return
        }

        let initialCount = service.activeSuggestions.count

        // When
        service.dismissSuggestion(suggestion)

        // Then
        XCTAssertEqual(service.activeSuggestions.count, initialCount - 1)
        XCTAssertFalse(service.activeSuggestions.contains { $0.id == suggestion.id })
    }

    func test제안무시_24시간내재표시방지() {
        // Given
        let today = Date()
        let task1 = Task(title: "Task 1", dueDate: today, estimatedMinutes: 300, leadTimeDays: 0)
        let task2 = Task(title: "Task 2", dueDate: today, estimatedMinutes: 240, leadTimeDays: 0)
        service.analyzeTasks([task1, task2])

        guard let suggestion = service.activeSuggestions.first else {
            XCTFail("No suggestions generated")
            return
        }

        // When
        service.dismissSuggestion(suggestion)
        service.analyzeTasks([task1, task2]) // 다시 분석

        // Then - 같은 제안이 다시 나타나지 않음
        XCTAssertFalse(service.activeSuggestions.contains { $0.uniqueKey == suggestion.uniqueKey })
    }
}
