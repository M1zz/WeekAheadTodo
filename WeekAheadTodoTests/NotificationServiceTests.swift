import XCTest
@testable import WeekAheadTodo

@MainActor
final class NotificationServiceTests: XCTestCase {

    var service: NotificationService!

    override func setUp() {
        super.setUp()
        // Clear UserDefaults before each test to ensure clean state
        UserDefaults.standard.removeObject(forKey: "NotificationEnabled")
        UserDefaults.standard.removeObject(forKey: "customNotificationTimes")
        UserDefaults.standard.removeObject(forKey: "nudgeNotificationEnabled")
        service = NotificationService.shared
        // Reset to default notification times after clearing UserDefaults
        service.notificationTimes = [
            NotificationTime(hour: 9, minute: 0, label: "아침 체크"),
            NotificationTime(hour: 15, minute: 0, label: "오후 체크"),
            NotificationTime(hour: 21, minute: 0, label: "저녁 체크")
        ]
    }

    override func tearDown() {
        // Clean up after test
        UserDefaults.standard.removeObject(forKey: "NotificationEnabled")
        UserDefaults.standard.removeObject(forKey: "customNotificationTimes")
        UserDefaults.standard.removeObject(forKey: "nudgeNotificationEnabled")
        service = nil
        super.tearDown()
    }

    // MARK: - Notification Time Management Tests

    func test알림시간추가_개수증가() {
        // Given
        let initialCount = service.notificationTimes.count

        // When
        service.addNotificationTime(hour: 14, minute: 30, label: "Afternoon Check")

        // Then
        XCTAssertEqual(service.notificationTimes.count, initialCount + 1)
    }

    func test알림시간추가_올바른시간추가() {
        // Given
        let hour = 14
        let minute = 30
        let label = "Afternoon Check"

        // When
        service.addNotificationTime(hour: hour, minute: minute, label: label)

        // Then
        let addedTime = service.notificationTimes.last
        XCTAssertEqual(addedTime?.hour, hour)
        XCTAssertEqual(addedTime?.minute, minute)
        XCTAssertEqual(addedTime?.label, label)
        XCTAssertTrue(addedTime?.isEnabled ?? false)
    }

    func test알림시간삭제_개수감소() {
        // Given
        service.addNotificationTime(hour: 10, minute: 0, label: "Test")
        guard let timeToRemove = service.notificationTimes.last else {
            XCTFail("Failed to add notification time")
            return
        }
        let initialCount = service.notificationTimes.count

        // When
        service.removeNotificationTime(id: timeToRemove.id)

        // Then
        XCTAssertEqual(service.notificationTimes.count, initialCount - 1)
    }

    func test알림시간삭제_올바른시간삭제() {
        // Given
        service.addNotificationTime(hour: 10, minute: 0, label: "Test")
        guard let timeToRemove = service.notificationTimes.last else {
            XCTFail("Failed to add notification time")
            return
        }

        // When
        service.removeNotificationTime(id: timeToRemove.id)

        // Then
        XCTAssertFalse(service.notificationTimes.contains { $0.id == timeToRemove.id })
    }

    func test알림시간수정_기존시간변경() {
        // Given
        service.addNotificationTime(hour: 10, minute: 0, label: "Original")
        guard let timeToUpdate = service.notificationTimes.last else {
            XCTFail("Failed to add notification time")
            return
        }

        // When
        service.updateNotificationTime(
            id: timeToUpdate.id,
            hour: 11,
            minute: 30,
            label: "Updated",
            isEnabled: false
        )

        // Then
        let updatedTime = service.notificationTimes.first { $0.id == timeToUpdate.id }
        XCTAssertEqual(updatedTime?.hour, 11)
        XCTAssertEqual(updatedTime?.minute, 30)
        XCTAssertEqual(updatedTime?.label, "Updated")
        XCTAssertFalse(updatedTime?.isEnabled ?? true)
    }

    // MARK: - Nudge Notification Tests

    func test재촉알림설정_상태업데이트() {
        // Given
        let initialState = service.nudgeNotificationEnabled

        // When
        service.setNudgeNotificationEnabled(!initialState)

        // Then
        XCTAssertEqual(service.nudgeNotificationEnabled, !initialState)
    }

    func test재촉알림설정_UserDefaults저장() {
        // Given
        service.setNudgeNotificationEnabled(true)

        // When
        let saved = UserDefaults.standard.bool(forKey: "nudgeNotificationEnabled")

        // Then
        XCTAssertTrue(saved)
    }

    // MARK: - Notification Time Model Tests

    func test알림시간모델_올바르게초기화() {
        // Given
        let id = UUID()
        let hour = 9
        let minute = 30
        let label = "Morning Check"

        // When
        let time = NotificationTime(
            id: id,
            hour: hour,
            minute: minute,
            isEnabled: true,
            label: label
        )

        // Then
        XCTAssertEqual(time.id, id)
        XCTAssertEqual(time.hour, hour)
        XCTAssertEqual(time.minute, minute)
        XCTAssertTrue(time.isEnabled)
        XCTAssertEqual(time.label, label)
    }

    func test알림시간모델_기본활성화상태() {
        // When
        let time = NotificationTime(
            hour: 9,
            minute: 0,
            label: "Test"
        )

        // Then
        XCTAssertTrue(time.isEnabled)
    }

    func test알림시간모델_Equatable준수() {
        // Given
        let id = UUID()
        let time1 = NotificationTime(id: id, hour: 9, minute: 0, isEnabled: true, label: "Test")
        let time2 = NotificationTime(id: id, hour: 9, minute: 0, isEnabled: true, label: "Test")
        let time3 = NotificationTime(id: UUID(), hour: 9, minute: 0, isEnabled: true, label: "Test")

        // Then
        XCTAssertEqual(time1, time2)
        XCTAssertNotEqual(time1, time3)
    }

    func test알림시간모델_Codable준수() throws {
        // Given
        let time = NotificationTime(hour: 14, minute: 30, isEnabled: true, label: "Test")

        // When
        let encoded = try JSONEncoder().encode(time)
        let decoded = try JSONDecoder().decode(NotificationTime.self, from: encoded)

        // Then
        XCTAssertEqual(time.hour, decoded.hour)
        XCTAssertEqual(time.minute, decoded.minute)
        XCTAssertEqual(time.isEnabled, decoded.isEnabled)
        XCTAssertEqual(time.label, decoded.label)
    }

    // MARK: - Persistence Tests

    func test알림시간_UserDefaults영속성() {
        // Given
        service.addNotificationTime(hour: 10, minute: 0, label: "Test")
        let timesBeforeSave = service.notificationTimes

        // When
        service.saveNotificationTimes()

        // Verify saved to UserDefaults
        let data = UserDefaults.standard.data(forKey: "customNotificationTimes")
        XCTAssertNotNil(data)

        // Then - Decode and compare
        if let data = data,
           let decoded = try? JSONDecoder().decode([NotificationTime].self, from: data) {
            XCTAssertEqual(decoded.count, timesBeforeSave.count)
        } else {
            XCTFail("Failed to decode saved notification times")
        }
    }

    // MARK: - Notification Filtering Logic Tests (간접 테스트)

    func test알림활성화_기본값False() {
        // Given - 새로운 NotificationService 인스턴스 시뮬레이션
        // UserDefaults에 값이 없으면 false가 기본값

        // When
        let isEnabled = UserDefaults.standard.bool(forKey: "NotificationEnabled")

        // Then
        XCTAssertFalse(isEnabled) // UserDefaults.bool는 값이 없으면 false 반환
    }

    func test알림활성화설정_UserDefaults저장() {
        // Given
        service.setNotificationEnabled(true)

        // When
        let saved = UserDefaults.standard.bool(forKey: "NotificationEnabled")

        // Then
        XCTAssertTrue(saved)
    }

    func test알림활성화설정_Published속성업데이트() {
        // Given
        let initialState = service.isNotificationEnabled

        // When
        service.setNotificationEnabled(!initialState)

        // Then
        XCTAssertEqual(service.isNotificationEnabled, !initialState)
    }
}
