import Foundation
import UserNotifications

// MARK: - Notification Time Model

/// 알림 시간 모델
struct NotificationTime: Codable, Identifiable, Equatable {
    let id: UUID
    var hour: Int           // 0-23
    var minute: Int         // 0-59
    var isEnabled: Bool
    var label: String       // "아침 체크", "점심 후 체크" 등

    init(id: UUID = UUID(), hour: Int, minute: Int, isEnabled: Bool = true, label: String) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.isEnabled = isEnabled
        self.label = label
    }
}

/// 리마인더 알림을 관리하는 서비스
@MainActor
class NotificationService: NSObject, ObservableObject {

    static let shared = NotificationService()

    @Published var isNotificationEnabled: Bool = false
    @Published var notificationPermissionStatus: UNAuthorizationStatus = .notDetermined
    @Published var notificationTimes: [NotificationTime] = []
    @Published var nudgeNotificationEnabled: Bool = true

    private let center = UNUserNotificationCenter.current()

    // UserDefaults 키
    private let notificationEnabledKey = "NotificationEnabled"
    private let notificationTimesKey = "customNotificationTimes"
    private let nudgeNotificationEnabledKey = "nudgeNotificationEnabled"

    private override init() {
        super.init()
        self.isNotificationEnabled = UserDefaults.standard.bool(forKey: notificationEnabledKey)
        self.nudgeNotificationEnabled = UserDefaults.standard.object(forKey: nudgeNotificationEnabledKey) as? Bool ?? true

        // 알림 시간 로드 (없으면 기본값)
        loadNotificationTimes()

        // Delegate 설정
        center.delegate = self
    }

    // MARK: - Notification Times Management

    /// UserDefaults에서 알림 시간 로드
    private func loadNotificationTimes() {
        if let data = UserDefaults.standard.data(forKey: notificationTimesKey),
           let times = try? JSONDecoder().decode([NotificationTime].self, from: data) {
            notificationTimes = times
            print("✅ [NotificationService] 알림 시간 로드: \(times.count)개")
        } else {
            // 기본 알림 시간 (오전 9시, 오후 3시, 저녁 9시)
            notificationTimes = [
                NotificationTime(hour: 9, minute: 0, label: "아침 체크"),
                NotificationTime(hour: 15, minute: 0, label: "오후 체크"),
                NotificationTime(hour: 21, minute: 0, label: "저녁 체크")
            ]
            saveNotificationTimes()
            print("✅ [NotificationService] 기본 알림 시간 설정")
        }
    }

    /// UserDefaults에 알림 시간 저장
    func saveNotificationTimes() {
        if let data = try? JSONEncoder().encode(notificationTimes) {
            UserDefaults.standard.set(data, forKey: notificationTimesKey)
            print("✅ [NotificationService] 알림 시간 저장: \(notificationTimes.count)개")
        }
    }

    /// 새 알림 시간 추가
    func addNotificationTime(hour: Int, minute: Int, label: String) {
        let newTime = NotificationTime(hour: hour, minute: minute, label: label)
        notificationTimes.append(newTime)
        saveNotificationTimes()
        print("✅ [NotificationService] 알림 시간 추가: \(hour):\(minute) - \(label)")
    }

    /// 알림 시간 삭제
    func removeNotificationTime(id: UUID) {
        notificationTimes.removeAll { $0.id == id }
        saveNotificationTimes()
        print("✅ [NotificationService] 알림 시간 삭제: \(id)")
    }

    /// 알림 시간 업데이트
    func updateNotificationTime(id: UUID, hour: Int, minute: Int, label: String, isEnabled: Bool) {
        if let index = notificationTimes.firstIndex(where: { $0.id == id }) {
            notificationTimes[index] = NotificationTime(id: id, hour: hour, minute: minute, isEnabled: isEnabled, label: label)
            saveNotificationTimes()
            print("✅ [NotificationService] 알림 시간 업데이트: \(hour):\(minute)")
        }
    }

    /// 재촉 알림 활성화/비활성화
    func setNudgeNotificationEnabled(_ enabled: Bool) {
        nudgeNotificationEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: nudgeNotificationEnabledKey)
        print("✅ [NotificationService] 재촉 알림: \(enabled ? "활성화" : "비활성화")")
    }

    // MARK: - 권한 관리

    /// 알림 권한 요청
    func requestAuthorization() async throws {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        let granted = try await center.requestAuthorization(options: options)

        // 권한 상태 업데이트
        await checkAuthorizationStatus()

        if granted {
            print("✅ [NotificationService] 알림 권한 승인됨")
        } else {
            print("⚠️ [NotificationService] 알림 권한 거부됨")
        }
    }

    /// 현재 권한 상태 확인
    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        notificationPermissionStatus = settings.authorizationStatus

        if settings.authorizationStatus == .authorized {
            isNotificationEnabled = UserDefaults.standard.bool(forKey: notificationEnabledKey)
        } else {
            isNotificationEnabled = false
        }

        print("ℹ️ [NotificationService] 권한 상태: \(settings.authorizationStatus.rawValue)")
    }

    /// 알림 기능 활성화/비활성화
    func setNotificationEnabled(_ enabled: Bool) {
        isNotificationEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: notificationEnabledKey)

        if enabled {
            print("✅ [NotificationService] 알림 기능 활성화")
        } else {
            print("⚠️ [NotificationService] 알림 기능 비활성화")
            // 모든 예약된 알림 취소
            _Concurrency.Task {
                await cancelAllScheduledNotifications()
            }
        }
    }

    // MARK: - 태스크 알림 스케줄링

    /// 모든 태스크에 대해 알림 스케줄 갱신
    func scheduleNotifications(for tasks: [Task]) async {
        guard isNotificationEnabled else {
            print("ℹ️ [NotificationService] 알림이 비활성화되어 있음")
            return
        }

        // 기존 알림 모두 취소
        await cancelAllScheduledNotifications()

        print("🔔 [NotificationService] 알림 스케줄링 시작...")

        // 활성화된 알림 시간에 대해 알림 설정
        let enabledTimes = notificationTimes.filter { $0.isEnabled }
        for checkTime in enabledTimes {
            await scheduleDailyCheckNotification(hour: checkTime.hour, minute: checkTime.minute, tasks: tasks)
        }

        print("✅ [NotificationService] 알림 스케줄링 완료 (\(enabledTimes.count)개 시간)")
    }

    /// 특정 시간에 태스크 체크 알림 스케줄
    private func scheduleDailyCheckNotification(hour: Int, minute: Int, tasks: [Task]) async {
        let notificationId = "daily-check-\(hour)-\(minute)"

        // 알림이 필요한 태스크들 필터링
        let tasksNeedingAttention = filterTasksNeedingAttention(tasks)

        guard !tasksNeedingAttention.isEmpty else {
            print("  ⏭️ [\(hour):\(minute)] 알림 필요 없음")
            return
        }

        // 알림 내용 생성
        let content = UNMutableNotificationContent()
        content.title = "할 일 체크 시간이에요!"
        content.body = generateNotificationBody(for: tasksNeedingAttention)
        content.sound = .default
        content.categoryIdentifier = "TASK_REMINDER"

        // 매일 반복되는 트리거 설정
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger)

        do {
            try await center.add(request)
            print("  ✅ [\(hour):\(minute)] 알림 스케줄 등록: \(tasksNeedingAttention.count)개 태스크")
        } catch {
            print("  ❌ [\(hour):\(minute)] 알림 스케줄 실패: \(error)")
        }
    }

    // MARK: - 태스크 필터링 로직

    /// 알림이 필요한 태스크들 필터링
    private func filterTasksNeedingAttention(_ tasks: [Task]) -> [Task] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        var tasksNeedingAttention: [Task] = []

        for task in tasks where !task.isCompleted {
            // 1. 시작일이 지났는데 아직 시작 안한 일
            if task.effectiveStartDate < today && task.isNotStarted {
                tasksNeedingAttention.append(task)
                continue
            }

            // 2. 오늘 해야 할 일이 아직 완료되지 않은 경우
            if calendar.isDate(task.effectiveStartDate, inSameDayAs: today) && !task.isCompleted {
                tasksNeedingAttention.append(task)
                continue
            }

            // 3. 마감 1일 전 알림 (내일이 마감일)
            if calendar.isDate(task.dueDate, inSameDayAs: tomorrow) && !task.isCompleted {
                tasksNeedingAttention.append(task)
                continue
            }

            // 4. 준비 태스크를 시작할 시간
            if task.isPreparation && calendar.isDate(task.effectiveStartDate, inSameDayAs: today) && !task.isCompleted {
                tasksNeedingAttention.append(task)
                continue
            }

            // 재촉 알림이 활성화된 경우 추가 조건
            if nudgeNotificationEnabled {
                // 5. 마감 2일 이내 + 시작 안함 (재촉)
                if task.daysUntilDue <= 2 && task.daysUntilDue > 0 && task.isNotStarted {
                    tasksNeedingAttention.append(task)
                    continue
                }

                // 6. 마감 당일 + 진행 중
                if task.daysUntilDue == 0 && task.isInProgress {
                    tasksNeedingAttention.append(task)
                    continue
                }
            }
        }

        return tasksNeedingAttention
    }

    /// 알림 본문 생성
    private func generateNotificationBody(for tasks: [Task]) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var messages: [String] = []

        // 시작일이 지났는데 시작 안한 일
        let overdueNotStarted = tasks.filter {
            $0.effectiveStartDate < today && $0.isNotStarted
        }
        if !overdueNotStarted.isEmpty {
            messages.append("시작해야 할 일 \(overdueNotStarted.count)개가 아직 시작 안됨")
        }

        // 오늘 해야 할 일
        let todayTasks = tasks.filter {
            calendar.isDate($0.effectiveStartDate, inSameDayAs: today) && !$0.isCompleted
        }
        if !todayTasks.isEmpty {
            messages.append("오늘 할 일 \(todayTasks.count)개")
        }

        // 내일 마감
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let dueTomorrow = tasks.filter {
            calendar.isDate($0.dueDate, inSameDayAs: tomorrow) && !$0.isCompleted
        }
        if !dueTomorrow.isEmpty {
            messages.append("내일 마감 \(dueTomorrow.count)개")
        }

        // 기본 메시지
        if messages.isEmpty {
            return "확인이 필요한 할 일이 있어요"
        }

        return messages.joined(separator: " • ")
    }

    // MARK: - 알림 관리

    /// 모든 예약된 알림 취소
    func cancelAllScheduledNotifications() async {
        center.removeAllPendingNotificationRequests()
        print("🗑️ [NotificationService] 모든 알림 취소됨")
    }

    /// 예약된 알림 목록 확인 (디버깅용)
    func listScheduledNotifications() async {
        let requests = await center.pendingNotificationRequests()
        print("📋 [NotificationService] 예약된 알림 \(requests.count)개:")
        for request in requests {
            print("  - \(request.identifier): \(request.content.title)")
        }
    }

    // MARK: - 즉시 테스트 알림

    /// 테스트용 즉시 알림 발송
    func sendTestNotification() async {
        guard isNotificationEnabled else {
            print("⚠️ [NotificationService] 알림이 비활성화되어 있음")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "테스트 알림"
        content.body = "알림이 정상적으로 작동하고 있습니다!"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "test-notification-\(UUID().uuidString)",
            content: content,
            trigger: nil // 즉시 발송
        )

        do {
            try await center.add(request)
            print("✅ [NotificationService] 테스트 알림 발송됨")
        } catch {
            print("❌ [NotificationService] 테스트 알림 실패: \(error)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {

    /// 앱이 포그라운드에 있을 때도 알림 표시
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }

    /// 사용자가 알림을 탭했을 때 처리
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        print("🔔 [NotificationService] 사용자가 알림을 탭함: \(response.notification.request.identifier)")
        // TODO: 앱 내에서 해당 태스크로 네비게이션
    }
}
