//
//  TaskViewModel.swift
//  TodoAlarm (iOS)
//
//  iOS 전용 간소화 ViewModel
//

import SwiftUI
import CloudKit
import Foundation
import Combine

// Swift Concurrency Task와 구분하기 위한 typealias
typealias TaskModel = Task

@MainActor
class TaskViewModel: ObservableObject {
    @Published var tasks: [TaskModel] = [] {
        didSet {
            // 태스크가 변경되면 알림과 Live Activity 업데이트
            _Concurrency.Task {
                await updateNotificationsAndActivity()
            }
        }
    }
    @Published var projects: [Project] = []
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?

    // 자동 동기화 설정
    @Published var isAutoSyncEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isAutoSyncEnabled, forKey: "isAutoSyncEnabled")
            if isAutoSyncEnabled {
                startPeriodicSync()
            } else {
                stopPeriodicSync()
            }
        }
    }

    private let cloudService = CloudKitService()
    private let notificationManager = NotificationManager.shared
    private var periodicSyncTimer: Timer?

    #if os(iOS)
    @available(iOS 16.1, *)
    private lazy var liveActivityManager = LiveActivityManager.shared
    #endif

    // MARK: - Initialization

    init() {
        // UserDefaults에서 자동 동기화 설정 로드
        self.isAutoSyncEnabled = UserDefaults.standard.object(forKey: "isAutoSyncEnabled") as? Bool ?? true

        // 자동 동기화가 켜져 있으면 타이머 시작
        if isAutoSyncEnabled {
            startPeriodicSync()
        }
    }

    // MARK: - Cloud Sync

    func syncFromCloud() async {
        print("☁️ [iOS TaskViewModel.syncFromCloud] 시작")
        print("   현재 태스크: \(tasks.count)개")
        print("   현재 프로젝트: \(projects.count)개")

        guard !isSyncing else {
            print("⚠️ [iOS TaskViewModel.syncFromCloud] 이미 동기화 중")
            return
        }

        isSyncing = true
        syncError = nil
        defer {
            print("   [iOS TaskViewModel.syncFromCloud] defer - isSyncing = false")
            isSyncing = false
        }

        do {
            print("   📥 CloudKitService.fetchAllTasks() 호출...")
            // Task와 Project 동시 가져오기
            async let taskResults = cloudService.fetchAllTasks()
            print("   📥 CloudKitService.fetchAllProjects() 호출...")
            async let projectResults = cloudService.fetchAllProjects()

            print("   ⏳ 결과 대기 중...")
            let fetchedTasks = try await taskResults
            print("   ✅ fetchAllTasks() 완료: \(fetchedTasks.count)개")

            let fetchedProjects = try await projectResults
            print("   ✅ fetchAllProjects() 완료: \(fetchedProjects.count)개")

            print("   📝 tasks 배열에 할당 중...")
            self.tasks = fetchedTasks
            print("   ✅ tasks 배열 할당 완료: \(self.tasks.count)개")

            print("   📝 projects 배열에 할당 중...")
            self.projects = fetchedProjects
            print("   ✅ projects 배열 할당 완료: \(self.projects.count)개")

            self.lastSyncDate = Date()

            print("✅ [iOS TaskViewModel.syncFromCloud] Synced: \(tasks.count) tasks, \(projects.count) projects")
        } catch let error as CKError {
            print("❌ [iOS TaskViewModel.syncFromCloud] CKError 발생")
            print("   Error code: \(error.code.rawValue)")
            print("   Error: \(error)")
            print("   LocalizedDescription: \(error.localizedDescription)")

            // CloudKit 에러 상세 처리
            switch error.code {
            case .networkUnavailable:
                syncError = "네트워크 연결을 확인하세요"
                print("   → 네트워크 없음")
            case .notAuthenticated:
                syncError = "iCloud에 로그인하세요"
                print("   → iCloud 미인증")
            case .unknownItem:
                syncError = "macOS 앱에서 먼저 데이터를 저장하세요"
                print("   → 레코드 없음")
            default:
                syncError = error.localizedDescription
                print("   → 기타 에러: \(error.code.rawValue)")
            }
        } catch {
            print("❌ [iOS TaskViewModel.syncFromCloud] 일반 에러 발생")
            print("   Error: \(error)")
            print("   LocalizedDescription: \(error.localizedDescription)")
            syncError = error.localizedDescription
        }
    }

    // MARK: - Periodic Sync

    /// 주기적 동기화 시작 (1시간마다)
    private func startPeriodicSync() {
        print("🔄 [TaskViewModel] 주기적 동기화 시작 (1시간마다)")

        // 기존 타이머 정지
        stopPeriodicSync()

        // 1시간 = 3600초
        periodicSyncTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            print("⏰ [TaskViewModel] 주기적 동기화 실행")
            _Concurrency.Task { @MainActor in
                await self?.syncFromCloud()
            }
        }

        print("✅ [TaskViewModel] 주기적 동기화 타이머 설정 완료")
    }

    /// 주기적 동기화 중지
    private func stopPeriodicSync() {
        if periodicSyncTimer != nil {
            print("⏹️ [TaskViewModel] 주기적 동기화 중지")
            periodicSyncTimer?.invalidate()
            periodicSyncTimer = nil
        }
    }

    // MARK: - Computed Properties (macOS TaskViewModel 참고)

    /// 오늘 할 일 (effectiveStartDate 기준)
    var todayTasks: [TaskModel] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return tasks.filter { task in
            let startDate = calendar.startOfDay(for: task.effectiveStartDate)
            return startDate <= today && task.status != .completed
        }.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// 이번 주 할 일
    var thisWeekTasks: [TaskModel] {
        let calendar = Calendar.current
        let today = Date()
        let weekStart = calendar.startOfDay(for: today)
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
            return []
        }

        return tasks.filter { task in
            let startDate = task.effectiveStartDate
            return startDate >= weekStart && startDate < weekEnd && task.status != .completed
        }.sorted { $0.effectiveStartDate < $1.effectiveStartDate }
    }

    /// 다음 주 할 일
    var nextWeekTasks: [TaskModel] {
        let calendar = Calendar.current
        let today = Date()
        guard let nextWeekStart = calendar.date(byAdding: .day, value: 7, to: today),
              let nextWeekEnd = calendar.date(byAdding: .day, value: 14, to: today) else {
            return []
        }

        return tasks.filter { task in
            let startDate = task.effectiveStartDate
            return startDate >= nextWeekStart && startDate < nextWeekEnd && task.status != .completed
        }.sorted { $0.effectiveStartDate < $1.effectiveStartDate }
    }

    /// Project 이름 가져오기
    func projectName(for projectId: UUID?) -> String? {
        guard let id = projectId else { return nil }
        return projects.first { $0.id == id }?.name
    }

    // MARK: - Notifications & Live Activity

    /// 알림 권한 요청
    func requestNotificationPermission() async {
        print("🔔 [TaskViewModel] 알림 권한 요청")
        do {
            try await notificationManager.requestAuthorization()
        } catch {
            print("❌ [TaskViewModel] 알림 권한 요청 실패: \(error)")
        }
    }

    /// 알림 및 Live Activity 업데이트
    private func updateNotificationsAndActivity() async {
        print("🔄 [TaskViewModel] 알림 및 Live Activity 업데이트")

        let today = todayTasks
        print("   오늘 할 일: \(today.count)개")

        // 로컬 푸시 알림 스케줄링
        await notificationManager.scheduleTodayTasksNotifications(tasks: today)

        // Live Activity 관리 (다이나믹 아일랜드) - iOS 16.1+ only
        #if os(iOS)
        if #available(iOS 16.1, *) {
            liveActivityManager.manageTodayTasksActivity(tasks: today)
        }
        #endif
    }

    /// 수동으로 알림 및 Live Activity 업데이트
    func refreshNotificationsAndActivity() async {
        await updateNotificationsAndActivity()
    }

    /// 태스크 완료 토글 (알림 업데이트 포함)
    func toggleTaskCompletion(_ task: TaskModel) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].status = tasks[index].status == .completed ? .notStarted : .completed
            print("✅ [TaskViewModel] 태스크 상태 변경: \(tasks[index].title) - \(tasks[index].status.rawValue)")
        }
    }
}
