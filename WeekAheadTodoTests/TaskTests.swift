import XCTest
@testable import WeekAheadTodo

final class TaskTests: XCTestCase {

    // MARK: - Effective Start Date Tests

    func test효과적시작날짜_선행작업없음() {
        // Given
        let dueDate = Date()
        let task = Task(
            title: "Test Task",
            dueDate: dueDate,
            leadTimeDays: 0
        )

        // Then - effectiveStartDate는 startOfDay를 사용하지 않음
        XCTAssertEqual(task.effectiveStartDate, dueDate)
    }

    func test효과적시작날짜_선행작업있음() {
        // Given
        let calendar = Calendar.current
        let dueDate = calendar.date(byAdding: .day, value: 5, to: Date())!
        let leadTimeDays = 3
        let task = Task(
            title: "Test Task",
            dueDate: dueDate,
            leadTimeDays: leadTimeDays
        )

        // When - effectiveStartDate는 startOfDay를 사용하지 않음
        let expectedStartDate = calendar.date(byAdding: .day, value: -leadTimeDays, to: dueDate)!

        // Then
        XCTAssertEqual(task.effectiveStartDate, expectedStartDate)
    }

    // MARK: - Days Until Due Tests

    func test마감까지남은일수_오늘() {
        // Given
        let today = Calendar.current.startOfDay(for: Date())
        let task = Task(
            title: "Test Task",
            dueDate: today
        )

        // Then
        XCTAssertEqual(task.daysUntilDue, 0)
    }

    func test마감까지남은일수_내일() {
        // Given
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let task = Task(
            title: "Test Task",
            dueDate: tomorrow
        )

        // Then
        XCTAssertEqual(task.daysUntilDue, 1)
    }

    func test마감까지남은일수_과거() {
        // Given
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let task = Task(
            title: "Test Task",
            dueDate: yesterday
        )

        // Then
        XCTAssertEqual(task.daysUntilDue, -1)
    }

    // MARK: - Days Until Start Tests

    func test시작까지남은일수_선행작업있음() {
        // Given
        let dueDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let task = Task(
            title: "Test Task",
            dueDate: dueDate,
            leadTimeDays: 3
        )

        // Then - 5일 뒤 마감, 3일 선행 = 2일 뒤 시작
        XCTAssertEqual(task.daysUntilStart, 2)
    }

    // MARK: - Urgency Score Tests

    func test긴급도점수_지난태스크() {
        // Given
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let task = Task(
            title: "Overdue Task",
            dueDate: yesterday,
            estimatedMinutes: 60
        )

        // Then - 지난 태스크는 매우 낮은 긴급도 점수
        XCTAssertLessThan(task.urgencyScore, -90)
    }

    func test긴급도점수_긴급태스크() {
        // Given
        let today = Date()
        let task = Task(
            title: "Urgent Task",
            dueDate: today,
            estimatedMinutes: 120,
            leadTimeDays: 0
        )

        // Then - 오늘 시작해야 하는 2시간 태스크
        XCTAssertLessThan(task.urgencyScore, 0)
    }

    func test긴급도점수_여유태스크() {
        // Given
        let futureDate = Calendar.current.date(byAdding: .day, value: 10, to: Date())!
        let task = Task(
            title: "Relaxed Task",
            dueDate: futureDate,
            estimatedMinutes: 30,
            leadTimeDays: 0
        )

        // Then - 10일 뒤 시작, 30분 = 높은 긴급도 점수
        XCTAssertGreaterThan(task.urgencyScore, 9)
    }

    // MARK: - Sort Order Tests

    func test정렬순서_자동우선순위() {
        // Given
        let task = Task(
            title: "Auto Priority Task",
            dueDate: Date(),
            estimatedMinutes: 60
        )

        // Then - manualPriority가 nil이면 urgencyScore 기반
        XCTAssertNil(task.manualPriority)
        XCTAssertEqual(task.sortOrder, Int(task.urgencyScore * 100))
    }

    func test정렬순서_수동우선순위() {
        // Given
        var task = Task(
            title: "Manual Priority Task",
            dueDate: Date(),
            estimatedMinutes: 60
        )
        task.manualPriority = 5

        // Then - manualPriority가 있으면 그것을 사용
        XCTAssertEqual(task.sortOrder, 5)
    }

    // MARK: - Current Horizon Tests

    func test현재지평선_오늘() {
        // Given
        let today = Date()
        let task = Task(
            title: "Today Task",
            dueDate: today,
            leadTimeDays: 0
        )

        // Then
        XCTAssertEqual(task.currentHorizon, .today)
    }

    func test현재지평선_이번주() {
        // Given
        let futureDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let task = Task(
            title: "This Week Task",
            dueDate: futureDate,
            leadTimeDays: 0
        )

        // Then
        XCTAssertEqual(task.currentHorizon, .thisWeek)
    }

    func test현재지평선_다음주() {
        // Given
        let futureDate = Calendar.current.date(byAdding: .day, value: 10, to: Date())!
        let task = Task(
            title: "Next Week Task",
            dueDate: futureDate,
            leadTimeDays: 0
        )

        // Then
        XCTAssertEqual(task.currentHorizon, .nextWeek)
    }

    func test현재지평선_나중에() {
        // Given
        let futureDate = Calendar.current.date(byAdding: .day, value: 20, to: Date())!
        let task = Task(
            title: "Later Task",
            dueDate: futureDate,
            leadTimeDays: 0
        )

        // Then
        XCTAssertEqual(task.currentHorizon, .later)
    }

    // MARK: - Status Check Tests

    func test완료상태() {
        // Given
        var task = Task(title: "Task", dueDate: Date())

        // When
        task.status = .completed

        // Then
        XCTAssertTrue(task.isCompleted)
        XCTAssertFalse(task.isInProgress)
        XCTAssertFalse(task.isNotStarted)
    }

    func test진행중상태() {
        // Given
        var task = Task(title: "Task", dueDate: Date())

        // When
        task.status = .inProgress

        // Then
        XCTAssertFalse(task.isCompleted)
        XCTAssertTrue(task.isInProgress)
        XCTAssertFalse(task.isNotStarted)
    }

    func test시작안함상태() {
        // Given
        let task = Task(title: "Task", dueDate: Date())

        // Then
        XCTAssertFalse(task.isCompleted)
        XCTAssertFalse(task.isInProgress)
        XCTAssertTrue(task.isNotStarted)
    }

    // MARK: - Role Check Tests

    func test준비작업역할() {
        // Given
        var task = Task(title: "Prep Task", dueDate: Date())
        task.taskRole = .preparation

        // Then
        XCTAssertTrue(task.isPreparation)
        XCTAssertFalse(!task.isPreparation)
    }

    func test메인작업역할() {
        // Given
        let task = Task(title: "Main Task", dueDate: Date(), taskRole: .none)

        // Then
        XCTAssertTrue(!task.isPreparation)
        XCTAssertFalse(task.isPreparation)
    }

    // MARK: - D-Day Text Tests

    func testD데이텍스트_오늘() {
        // Given
        let task = Task(title: "Task", dueDate: Date())

        // Then
        XCTAssertEqual(task.dDayText, "D-day")
    }

    func testD데이텍스트_미래() {
        // Given
        let futureDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        let task = Task(title: "Task", dueDate: futureDate)

        // Then
        XCTAssertEqual(task.dDayText, "D-3")
    }

    func testD데이텍스트_과거() {
        // Given
        let pastDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let task = Task(title: "Task", dueDate: pastDate)

        // Then
        XCTAssertEqual(task.dDayText, "D+2")
    }

    // MARK: - Estimated Time Format Tests

    func test예상시간포맷_분만() {
        // Given
        let task = Task(title: "Task", dueDate: Date(), estimatedMinutes: 45)

        // Then
        XCTAssertEqual(task.estimatedTimeFormatted, "45분")
    }

    func test예상시간포맷_시간만() {
        // Given
        let task = Task(title: "Task", dueDate: Date(), estimatedMinutes: 120)

        // Then
        XCTAssertEqual(task.estimatedTimeFormatted, "2시간")
    }

    func test예상시간포맷_시간과분() {
        // Given
        let task = Task(title: "Task", dueDate: Date(), estimatedMinutes: 150)

        // Then
        XCTAssertEqual(task.estimatedTimeFormatted, "2시간 30분")
    }

    // MARK: - Migration Tests

    func test마이그레이션_메인역할_없음으로변환() throws {
        // Given - "메인" 역할을 가진 Task를 JSON으로 변환
        let mainTask = Task(
            title: "Test Task",
            dueDate: Date(),
            taskRole: .none
        )

        // Task를 JSON으로 인코딩
        let encoder = JSONEncoder()
        var jsonData = try encoder.encode(mainTask)

        // JSON 문자열로 변환하여 taskRole을 "메인"으로 교체
        var jsonString = String(data: jsonData, encoding: .utf8)!
        jsonString = jsonString.replacingOccurrences(of: "\"taskRole\":\"\"", with: "\"taskRole\":\"메인\"")
        jsonData = jsonString.data(using: .utf8)!

        // When - JSON 디코딩 (마이그레이션 발생)
        let decoder = JSONDecoder()
        let decodedTask = try decoder.decode(Task.self, from: jsonData)

        // Then - "메인"이 ""(없음)으로 변환됨
        XCTAssertEqual(decodedTask.taskRole, .none)
        XCTAssertEqual(decodedTask.title, "Test Task")
    }

    func test마이그레이션_기존역할_유지() throws {
        // Given - "준비" 역할을 가진 Task
        let prepTask = Task(
            title: "Test Task",
            dueDate: Date(),
            taskRole: .preparation
        )

        // When - JSON으로 인코딩 후 다시 디코딩
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(prepTask)
        let decoder = JSONDecoder()
        let decodedTask = try decoder.decode(Task.self, from: jsonData)

        // Then - "준비" 역할이 그대로 유지됨
        XCTAssertEqual(decodedTask.taskRole, .preparation)
    }

    func test마이그레이션_루틴역할_없음으로변환() throws {
        // Given - "루틴" 역할을 가진 Task를 JSON으로 변환
        let task = Task(
            title: "Test Task",
            dueDate: Date(),
            taskRole: .none
        )

        let encoder = JSONEncoder()
        var jsonData = try encoder.encode(task)

        // JSON 문자열로 변환하여 taskRole을 "루틴"으로 교체
        var jsonString = String(data: jsonData, encoding: .utf8)!
        jsonString = jsonString.replacingOccurrences(of: "\"taskRole\":\"\"", with: "\"taskRole\":\"루틴\"")
        jsonData = jsonString.data(using: .utf8)!

        // When - JSON 디코딩 (마이그레이션 발생)
        let decoder = JSONDecoder()
        let decodedTask = try decoder.decode(Task.self, from: jsonData)

        // Then - "루틴"이 ""(없음)으로 변환됨
        XCTAssertEqual(decodedTask.taskRole, .none)
    }

    func test마이그레이션_알수없는역할_기본값으로변환() throws {
        // Given - Task를 JSON으로 변환 후 알 수 없는 역할로 교체
        let task = Task(
            title: "Test Task",
            dueDate: Date(),
            taskRole: .none
        )

        let encoder = JSONEncoder()
        var jsonData = try encoder.encode(task)

        // JSON 문자열로 변환하여 taskRole을 "알수없음"으로 교체
        var jsonString = String(data: jsonData, encoding: .utf8)!
        jsonString = jsonString.replacingOccurrences(of: "\"taskRole\":\"\"", with: "\"taskRole\":\"알수없음\"")
        jsonData = jsonString.data(using: .utf8)!

        // When - JSON 디코딩 (마이그레이션 발생)
        let decoder = JSONDecoder()
        let decodedTask = try decoder.decode(Task.self, from: jsonData)

        // Then - 알 수 없는 역할이 기본값(없음)으로 변환됨
        XCTAssertEqual(decodedTask.taskRole, .none)
    }

    // MARK: - New Fields Migration Tests

    func test마이그레이션_targetDate없는데이터_정상로딩() throws {
        // Given - targetDate 필드가 없는 구버전 JSON 생성
        let jsonString = """
        {
            "id": "\(UUID().uuidString)",
            "title": "Old Task",
            "description": "",
            "dueDate": \(Date().timeIntervalSinceReferenceDate),
            "estimatedMinutes": 30,
            "leadTimeDays": 0,
            "taskType": "미리 가능",
            "taskRole": "",
            "status": "시작 안함",
            "priority": "보통",
            "createdAt": \(Date().timeIntervalSinceReferenceDate),
            "isFromCalendarPattern": false,
            "autoRecurring": false
        }
        """

        // When - JSON 디코딩
        let decoder = JSONDecoder()
        let jsonData = jsonString.data(using: .utf8)!
        let decodedTask = try decoder.decode(Task.self, from: jsonData)

        // Then - targetDate는 nil이어야 함
        XCTAssertEqual(decodedTask.title, "Old Task")
        XCTAssertNil(decodedTask.targetDate)
        XCTAssertNil(decodedTask.manualPriority)
    }

    func test마이그레이션_manualPriority없는데이터_정상로딩() throws {
        // Given - manualPriority 필드가 없는 구버전 JSON 생성
        let jsonString = """
        {
            "id": "\(UUID().uuidString)",
            "title": "Old Task Without Manual Priority",
            "description": "",
            "dueDate": \(Date().timeIntervalSinceReferenceDate),
            "estimatedMinutes": 60,
            "leadTimeDays": 1,
            "taskType": "당일만 가능",
            "taskRole": "준비",
            "status": "진행 중",
            "priority": "높음",
            "createdAt": \(Date().timeIntervalSinceReferenceDate),
            "isFromCalendarPattern": false,
            "autoRecurring": false
        }
        """

        // When - JSON 디코딩
        let decoder = JSONDecoder()
        let jsonData = jsonString.data(using: .utf8)!
        let decodedTask = try decoder.decode(Task.self, from: jsonData)

        // Then - manualPriority는 nil, 다른 필드는 정상
        XCTAssertEqual(decodedTask.title, "Old Task Without Manual Priority")
        XCTAssertEqual(decodedTask.taskRole, .preparation)
        XCTAssertNil(decodedTask.manualPriority)
    }

    func test마이그레이션_새필드포함데이터_정상저장로딩() throws {
        // Given - 새 필드를 포함한 Task
        let targetDate = Calendar.current.date(byAdding: .day, value: 2, to: Date())!
        var task = Task(
            title: "New Task With All Fields",
            dueDate: Date(),
            targetDate: targetDate
        )
        task.manualPriority = 5

        // When - JSON 인코딩 후 디코딩
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(task)
        let decoder = JSONDecoder()
        let decodedTask = try decoder.decode(Task.self, from: jsonData)

        // Then - 모든 필드가 정상적으로 유지됨
        XCTAssertEqual(decodedTask.title, "New Task With All Fields")
        XCTAssertNotNil(decodedTask.targetDate)
        XCTAssertEqual(decodedTask.manualPriority, 5)
    }
}
