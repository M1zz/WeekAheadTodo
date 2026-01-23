import XCTest
@testable import WeekAheadTodo

final class AssistantSuggestionTests: XCTestCase {

    // MARK: - Unique Key Tests

    func test고유키_같은타입과태스크_같은키생성() {
        // Given
        let taskId1 = UUID()
        let taskId2 = UUID()

        let suggestion1 = AssistantSuggestion(
            type: .capacityOverload,
            title: "Test 1",
            message: "Message 1",
            priority: .urgent,
            relatedTaskIds: [taskId1, taskId2]
        )

        let suggestion2 = AssistantSuggestion(
            type: .capacityOverload,
            title: "Test 2",
            message: "Message 2",
            priority: .high,
            relatedTaskIds: [taskId1, taskId2]
        )

        // When
        let key1 = suggestion1.uniqueKey
        let key2 = suggestion2.uniqueKey

        // Then
        XCTAssertEqual(key1, key2)
    }

    func test고유키_다른타입_다른키생성() {
        // Given
        let taskId = UUID()

        let suggestion1 = AssistantSuggestion(
            type: .capacityOverload,
            title: "Test",
            message: "Message",
            priority: .urgent,
            relatedTaskIds: [taskId]
        )

        let suggestion2 = AssistantSuggestion(
            type: .deadlineRisk,
            title: "Test",
            message: "Message",
            priority: .urgent,
            relatedTaskIds: [taskId]
        )

        // When
        let key1 = suggestion1.uniqueKey
        let key2 = suggestion2.uniqueKey

        // Then
        XCTAssertNotEqual(key1, key2)
    }

    func test고유키_다른태스크_다른키생성() {
        // Given
        let taskId1 = UUID()
        let taskId2 = UUID()

        let suggestion1 = AssistantSuggestion(
            type: .capacityOverload,
            title: "Test",
            message: "Message",
            priority: .urgent,
            relatedTaskIds: [taskId1]
        )

        let suggestion2 = AssistantSuggestion(
            type: .capacityOverload,
            title: "Test",
            message: "Message",
            priority: .urgent,
            relatedTaskIds: [taskId2]
        )

        // When
        let key1 = suggestion1.uniqueKey
        let key2 = suggestion2.uniqueKey

        // Then
        XCTAssertNotEqual(key1, key2)
    }

    func test고유키_태스크순서무관() {
        // Given
        let taskId1 = UUID()
        let taskId2 = UUID()
        let taskId3 = UUID()

        let suggestion1 = AssistantSuggestion(
            type: .meetingPreparationMissing,
            title: "Test",
            message: "Message",
            priority: .high,
            relatedTaskIds: [taskId1, taskId2, taskId3]
        )

        let suggestion2 = AssistantSuggestion(
            type: .meetingPreparationMissing,
            title: "Test",
            message: "Message",
            priority: .high,
            relatedTaskIds: [taskId3, taskId1, taskId2]
        )

        // When
        let key1 = suggestion1.uniqueKey
        let key2 = suggestion2.uniqueKey

        // Then - sorted()를 사용하므로 순서와 무관하게 같은 키
        XCTAssertEqual(key1, key2)
    }

    // MARK: - Initialization Tests

    func test초기화_모든매개변수() {
        // Given
        let id = UUID()
        let type = SuggestionType.capacityOverload
        let title = "Test Title"
        let message = "Test Message"
        let priority = SuggestionPriority.urgent
        let taskIds = [UUID(), UUID()]
        let actions = [
            SuggestionAction(title: "Action 1", actionType: .reschedule),
            SuggestionAction(title: "Action 2", actionType: .dismiss)
        ]

        // When
        let suggestion = AssistantSuggestion(
            id: id,
            type: type,
            title: title,
            message: message,
            priority: priority,
            relatedTaskIds: taskIds,
            actionButtons: actions,
            dismissible: false
        )

        // Then
        XCTAssertEqual(suggestion.id, id)
        XCTAssertEqual(suggestion.type, type)
        XCTAssertEqual(suggestion.title, title)
        XCTAssertEqual(suggestion.message, message)
        XCTAssertEqual(suggestion.priority, priority)
        XCTAssertEqual(suggestion.relatedTaskIds, taskIds)
        XCTAssertEqual(suggestion.actionButtons.count, 2)
        XCTAssertFalse(suggestion.dismissible)
    }

    func test초기화_기본값() {
        // When
        let suggestion = AssistantSuggestion(
            type: .idleTime,
            title: "Test",
            message: "Message",
            priority: .low
        )

        // Then
        XCTAssertTrue(suggestion.relatedTaskIds.isEmpty)
        XCTAssertTrue(suggestion.actionButtons.isEmpty)
        XCTAssertTrue(suggestion.dismissible)
    }

    // MARK: - SuggestionPriority Tests

    func test제안우선순위_색상() {
        // When/Then
        XCTAssertEqual(SuggestionPriority.urgent.color, "red")
        XCTAssertEqual(SuggestionPriority.high.color, "orange")
        XCTAssertEqual(SuggestionPriority.medium.color, "blue")
        XCTAssertEqual(SuggestionPriority.low.color, "gray")
    }

    func test제안우선순위_아이콘() {
        // When/Then
        XCTAssertEqual(SuggestionPriority.urgent.icon, "exclamationmark.octagon")
        XCTAssertEqual(SuggestionPriority.high.icon, "exclamationmark.triangle")
        XCTAssertEqual(SuggestionPriority.medium.icon, "exclamationmark.circle")
        XCTAssertEqual(SuggestionPriority.low.icon, "info.circle")
    }

    func test제안우선순위_원시값() {
        // When/Then
        XCTAssertEqual(SuggestionPriority.low.rawValue, 0)
        XCTAssertEqual(SuggestionPriority.medium.rawValue, 1)
        XCTAssertEqual(SuggestionPriority.high.rawValue, 2)
        XCTAssertEqual(SuggestionPriority.urgent.rawValue, 3)
    }

    // MARK: - SuggestionAction Tests

    func test제안액션_초기화() {
        // Given
        let id = UUID()
        let title = "Add Task"
        let actionType = SuggestionAction.ActionType.addTask

        // When
        let action = SuggestionAction(id: id, title: title, actionType: actionType)

        // Then
        XCTAssertEqual(action.id, id)
        XCTAssertEqual(action.title, title)
        XCTAssertEqual(action.actionType, actionType)
    }

    func test제안액션_기본ID() {
        // When
        let action1 = SuggestionAction(title: "Action 1", actionType: .addTask)
        let action2 = SuggestionAction(title: "Action 2", actionType: .addTask)

        // Then - 각각 다른 UUID가 생성됨
        XCTAssertNotEqual(action1.id, action2.id)
    }

    func test제안액션_모든액션타입() {
        // Given
        let types: [SuggestionAction.ActionType] = [.addTask, .viewTasks, .reschedule, .dismiss]

        // When/Then
        for type in types {
            let action = SuggestionAction(title: "Test", actionType: type)
            XCTAssertEqual(action.actionType, type)
        }
    }

    // MARK: - Codable Tests

    func test비서제안_Codable준수() throws {
        // Given
        let suggestion = AssistantSuggestion(
            type: .capacityOverload,
            title: "Test",
            message: "Message",
            priority: .urgent,
            relatedTaskIds: [UUID()],
            actionButtons: [
                SuggestionAction(title: "Action", actionType: .reschedule)
            ]
        )

        // When
        let encoded = try JSONEncoder().encode(suggestion)
        let decoded = try JSONDecoder().decode(AssistantSuggestion.self, from: encoded)

        // Then
        XCTAssertEqual(suggestion.type, decoded.type)
        XCTAssertEqual(suggestion.title, decoded.title)
        XCTAssertEqual(suggestion.message, decoded.message)
        XCTAssertEqual(suggestion.priority, decoded.priority)
        XCTAssertEqual(suggestion.relatedTaskIds, decoded.relatedTaskIds)
        XCTAssertEqual(suggestion.actionButtons.count, decoded.actionButtons.count)
        XCTAssertEqual(suggestion.dismissible, decoded.dismissible)
    }

    func test제안액션_Codable준수() throws {
        // Given
        let action = SuggestionAction(title: "Test Action", actionType: .viewTasks)

        // When
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(SuggestionAction.self, from: encoded)

        // Then
        XCTAssertEqual(action.title, decoded.title)
        XCTAssertEqual(action.actionType, decoded.actionType)
    }

    // MARK: - SuggestionType Tests

    func test제안타입_모든타입() {
        // Given
        let allTypes: [SuggestionType] = [
            .meetingPreparationMissing,
            .capacityOverload,
            .followUpNeeded,
            .deadlineRisk,
            .idleTime
        ]

        // When/Then
        for type in allTypes {
            XCTAssertNotNil(type.rawValue)
        }
    }

    func test제안타입_원시값() {
        // When/Then
        XCTAssertEqual(SuggestionType.meetingPreparationMissing.rawValue, "회의 준비 누락")
        XCTAssertEqual(SuggestionType.capacityOverload.rawValue, "용량 초과")
        XCTAssertEqual(SuggestionType.followUpNeeded.rawValue, "후속 조치 필요")
        XCTAssertEqual(SuggestionType.deadlineRisk.rawValue, "마감 위험")
        XCTAssertEqual(SuggestionType.idleTime.rawValue, "여유 시간")
    }
}
