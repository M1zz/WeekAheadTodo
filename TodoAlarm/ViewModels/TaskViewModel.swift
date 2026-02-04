//
//  TaskViewModel.swift
//  TodoAlarm (iOS)
//
//  iOS 전용 간소화 ViewModel
//

import SwiftUI
import CloudKit
import Foundation

// Swift Concurrency Task와 구분하기 위한 typealias
typealias TaskModel = Task

@MainActor
class TaskViewModel: ObservableObject {
    @Published var tasks: [TaskModel] = []
    @Published var projects: [Project] = []
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?

    private let cloudService = CloudKitService()

    // MARK: - Cloud Sync

    func syncFromCloud() async {
        guard !isSyncing else { return }

        isSyncing = true
        syncError = nil
        defer { isSyncing = false }

        do {
            // Task와 Project 동시 가져오기
            async let taskResults = cloudService.fetchAllTasks()
            async let projectResults = cloudService.fetchAllProjects()

            self.tasks = try await taskResults
            self.projects = try await projectResults
            self.lastSyncDate = Date()

            print("✅ Synced: \(tasks.count) tasks, \(projects.count) projects")
        } catch let error as CKError {
            // CloudKit 에러 상세 처리
            switch error.code {
            case .networkUnavailable:
                syncError = "네트워크 연결을 확인하세요"
            case .notAuthenticated:
                syncError = "iCloud에 로그인하세요"
            case .unknownItem:
                syncError = "macOS 앱에서 먼저 데이터를 저장하세요"
            default:
                syncError = error.localizedDescription
            }
            print("❌ Sync failed: \(error)")
        } catch {
            syncError = error.localizedDescription
            print("❌ Sync failed: \(error)")
        }
    }

    // MARK: - Computed Properties (macOS TaskViewModel 참고)

    /// 오늘 할 일 (effectiveStartDate 기준)
    var todayTasks: [Task] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return tasks.filter { task in
            let startDate = calendar.startOfDay(for: task.effectiveStartDate)
            return startDate <= today && task.status != .completed
        }.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// 이번 주 할 일
    var thisWeekTasks: [Task] {
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
    var nextWeekTasks: [Task] {
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
}
