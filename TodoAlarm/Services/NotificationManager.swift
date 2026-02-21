//
//  NotificationManager.swift
//  TodoAlarm (iOS)
//
//  로컬 푸시 알림 관리
//

import WeekAheadShared
import Foundation
import UserNotifications
import SwiftUI
import Combine

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private init() {
        _Concurrency.Task {
            await checkAuthorizationStatus()
        }
    }

    // MARK: - Authorization

    /// 알림 권한 요청
    func requestAuthorization() async throws {
        print("🔔 [NotificationManager] 알림 권한 요청")

        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options)

        await checkAuthorizationStatus()

        if granted {
            print("✅ [NotificationManager] 알림 권한 승인됨")
        } else {
            print("❌ [NotificationManager] 알림 권한 거부됨")
        }
    }

    /// 현재 권한 상태 확인
    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
        print("ℹ️ [NotificationManager] 권한 상태: \(authorizationStatus.rawValue)")
    }

    // MARK: - Today Tasks Notifications

    /// 오늘 할 일 알림 스케줄링
    func scheduleTodayTasksNotifications(tasks: [TaskModel]) async {
        print("📅 [NotificationManager] 오늘 할 일 알림 스케줄링: \(tasks.count)개")

        // 기존 알림 제거
        await removeAllNotifications()

        guard !tasks.isEmpty else {
            print("   ℹ️ 오늘 할 일이 없음 - 알림 스케줄 안 함")
            return
        }

        // 권한 확인
        guard authorizationStatus == .authorized else {
            print("   ⚠️ 알림 권한 없음 - 스케줄 불가")
            return
        }

        // 가장 긴급한 태스크 찾기
        let urgentTask = tasks
            .filter { !$0.isCompleted }
            .min(by: { $0.urgencyScore < $1.urgencyScore })

        // 즉시 알림 (오늘 할 일이 있다는 것을 알림)
        await scheduleImmediateNotification(taskCount: tasks.count, urgentTask: urgentTask)

        // 1시간마다 반복 알림 (오늘 할 일 리마인더)
        await scheduleRepeatingReminders(tasks: tasks)

        // 마감 시간 알림 (각 태스크의 마감 시간에)
        await scheduleDeadlineAlerts(tasks: tasks)
    }

    /// 즉시 알림 (오늘 할 일 있음)
    private func scheduleImmediateNotification(taskCount: Int, urgentTask: TaskModel? = nil) async {
        print("   📲 즉시 알림 생성: \(taskCount)개 할 일")

        let content = UNMutableNotificationContent()
        content.title = "오늘 할 일 \(taskCount)개"

        if let task = urgentTask {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d HH:mm"
            formatter.locale = Locale(identifier: "ko_KR")
            let dueDateStr = formatter.string(from: task.dueDate)

            if task.dueDate < Date() {
                content.body = "⚠️ 마감 지남: \(task.title) (마감: \(dueDateStr))"
            } else {
                content.body = "📌 긴급: \(task.title) (마감: \(dueDateStr))"
            }
        } else {
            content.body = "잊지 말고 확인하세요!"
        }

        content.sound = .default
        content.badge = taskCount as NSNumber

        // 5초 후 알림
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "today-tasks-immediate",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("   ✅ 즉시 알림 스케줄 완료")
        } catch {
            print("   ❌ 즉시 알림 스케줄 실패: \(error)")
        }
    }

    /// 반복 리마인더 (1시간마다)
    private func scheduleRepeatingReminders(tasks: [TaskModel]) async {
        print("   🔄 반복 리마인더 생성 (1시간마다)")

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "ko_KR")

        // 미완료 태스크 중 긴급한 것
        let urgentTasks = tasks
            .filter { !$0.isCompleted }
            .sorted { $0.urgencyScore < $1.urgencyScore }
            .prefix(3)

        let content = UNMutableNotificationContent()
        content.title = "⏰ 오늘 할 일 리마인더"

        if !urgentTasks.isEmpty {
            var taskLines: [String] = []
            for task in urgentTasks {
                let timeStr = formatter.string(from: task.dueDate)
                let prefix = task.dueDate < Date() ? "⚠️" : "•"
                taskLines.append("\(prefix) \(task.title) (마감: \(timeStr))")
            }
            content.body = taskLines.joined(separator: "\n")
        } else {
            content.body = "오늘 할 일 \(tasks.count)개가 있습니다"
        }

        content.sound = .default
        content.badge = tasks.filter { !$0.isCompleted }.count as NSNumber

        // 1시간마다 반복
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: true)
        let request = UNNotificationRequest(
            identifier: "today-tasks-hourly",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("   ✅ 반복 리마인더 스케줄 완료")
        } catch {
            print("   ❌ 반복 리마인더 스케줄 실패: \(error)")
        }
    }

    /// 마감 시간 알림 (각 태스크의 마감 시간에)
    private func scheduleDeadlineAlerts(tasks: [TaskModel]) async {
        print("   ⏰ 마감 시간 알림 생성")

        let now = Date()
        let incompleteTasks = tasks.filter { !$0.isCompleted && $0.dueDate > now }

        print("      미완료 태스크: \(incompleteTasks.count)개")

        for task in incompleteTasks {
            let timeInterval = task.dueDate.timeIntervalSince(now)

            // 미래의 태스크만 스케줄링
            guard timeInterval > 0 else { continue }

            // 마감 시간 알림
            await scheduleDeadlineAlert(
                task: task,
                timeInterval: timeInterval,
                suffix: "deadline"
            )

            // 마감 10분 후 알림 (완료 안 했을 경우)
            await scheduleDeadlineAlert(
                task: task,
                timeInterval: timeInterval + 600, // +10분
                suffix: "overdue-10m"
            )

            // 마감 30분 후 알림
            await scheduleDeadlineAlert(
                task: task,
                timeInterval: timeInterval + 1800, // +30분
                suffix: "overdue-30m"
            )

            // 마감 1시간 후 알림
            await scheduleDeadlineAlert(
                task: task,
                timeInterval: timeInterval + 3600, // +1시간
                suffix: "overdue-1h"
            )
        }
    }

    /// 개별 마감 알림 스케줄링
    private func scheduleDeadlineAlert(task: TaskModel, timeInterval: TimeInterval, suffix: String) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        formatter.locale = Locale(identifier: "ko_KR")
        let dueDateStr = formatter.string(from: task.dueDate)

        let content = UNMutableNotificationContent()

        if suffix == "deadline" {
            content.title = "⏰ 마감 시간입니다!"
            content.body = "\(task.title)\n마감: \(dueDateStr)"
            content.sound = .default
        } else if suffix.hasPrefix("overdue") {
            content.title = "⚠️ 마감 시간이 지났습니다!"
            content.body = "\(task.title)\n마감: \(dueDateStr)\n지금 바로 완료하세요!"
            content.sound = .defaultCritical // 중요 알림
        }

        content.badge = 1

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(
            identifier: "task-\(task.id.uuidString)-\(suffix)",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            let alertTime = Date().addingTimeInterval(timeInterval)
            let alertTimeStr = formatter.string(from: alertTime)
            print("      ✅ [\(task.title)] \(suffix) 알림 스케줄: \(alertTimeStr)")
        } catch {
            print("      ❌ [\(task.title)] \(suffix) 알림 스케줄 실패: \(error)")
        }
    }

    /// 특정 시간에 알림 (예: 오전 9시, 오후 3시, 오후 9시)
    func scheduleTimedReminders(tasks: [TaskModel]) async {
        print("   ⏰ 시간별 리마인더 생성")

        let reminderTimes = [9, 15, 21] // 오전 9시, 오후 3시, 오후 9시

        for hour in reminderTimes {
            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = 0

            let incompleteTasks = tasks.filter { !$0.isCompleted }
            let pastDueTasks = incompleteTasks.filter { $0.dueDate < Date() }

            let content = UNMutableNotificationContent()
            content.title = "⏰ 할 일 체크 시간"

            if pastDueTasks.isEmpty {
                content.body = "오늘 할 일 \(incompleteTasks.count)개 남았어요"
            } else {
                content.body = "⚠️ 마감 지난 태스크 \(pastDueTasks.count)개 포함, 총 \(incompleteTasks.count)개 남았어요"
            }

            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: "today-tasks-\(hour)h",
                content: content,
                trigger: trigger
            )

            do {
                try await UNUserNotificationCenter.current().add(request)
                print("   ✅ \(hour)시 리마인더 스케줄 완료")
            } catch {
                print("   ❌ \(hour)시 리마인더 스케줄 실패: \(error)")
            }
        }
    }

    // MARK: - Management

    /// 모든 알림 제거
    func removeAllNotifications() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        print("🗑️ [NotificationManager] 모든 알림 제거됨")
    }

    /// 특정 태스크의 알림 제거 (완료 시)
    func removeNotifications(for taskId: UUID) async {
        let identifierPrefixes = [
            "task-\(taskId.uuidString)-deadline",
            "task-\(taskId.uuidString)-overdue-10m",
            "task-\(taskId.uuidString)-overdue-30m",
            "task-\(taskId.uuidString)-overdue-1h"
        ]

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifierPrefixes)
        print("🗑️ [NotificationManager] 태스크 알림 제거: \(taskId)")
    }

    /// 예약된 알림 목록 확인
    func listPendingNotifications() async {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        print("📋 [NotificationManager] 예약된 알림: \(requests.count)개")
        for request in requests {
            print("   - \(request.identifier): \(request.content.title)")
        }
    }
}
