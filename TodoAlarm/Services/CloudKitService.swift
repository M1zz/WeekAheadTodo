//
//  CloudKitService.swift
//  TodoAlarm (iOS)
//
//  CloudKit 읽기 전용 서비스
//

import CloudKit
import Foundation


@MainActor
class CloudKitService {
    private let container: CKContainer
    private let database: CKDatabase

    init() {
        // macOS와 같은 Container 사용
        self.container = CKContainer(identifier: "iCloud.com.weekahead.todo")
        self.database = container.privateCloudDatabase
    }

    /// CloudKit에서 모든 Task 가져오기 (CKQuery 방식)
    func fetchAllTasks() async throws -> [TaskModel] {
        let query = CKQuery(recordType: "Task", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        // 중요: desiredKeys에 최소 하나 이상 필드 지정 (쿼리 제약 우회)
        let results = try await database.records(
            matching: query,
            desiredKeys: ["title"] // 빈 배열 사용 시 에러
        )

        return results.matchResults.compactMap { (_, result) in
            guard let record = try? result.get() else { return nil }
            return ckRecordToTask(record)
        }
    }

    /// CloudKit에서 모든 Project 가져오기
    func fetchAllProjects() async throws -> [Project] {
        let query = CKQuery(recordType: "Project", predicate: NSPredicate(value: true))

        let results = try await database.records(
            matching: query,
            desiredKeys: ["name"]
        )

        return results.matchResults.compactMap { (_, result) in
            guard let record = try? result.get() else { return nil }
            return ckRecordToProject(record)
        }
    }

    // MARK: - CKRecord 변환

    /// CKRecord → Task 변환 (macOS TaskViewModel 라인 1018-1098 참고)
    private func ckRecordToTask(_ record: CKRecord) -> TaskModel? {
        guard let title = record["title"] as? String,
              let taskDescription = record["taskDescription"] as? String,
              let dueDate = record["dueDate"] as? Date,
              let estimatedMinutes = record["estimatedMinutes"] as? Int,
              let leadTimeDays = record["leadTimeDays"] as? Int,
              let taskTypeRaw = record["taskType"] as? String,
              let taskRoleRaw = record["taskRole"] as? String,
              let statusRaw = record["status"] as? String,
              let priorityRaw = record["priority"] as? String,
              let createdAt = record["createdAt"] as? Date,
              let taskType = TaskType(rawValue: taskTypeRaw),
              let status = TaskStatus(rawValue: statusRaw),
              let priority = TaskPriority(rawValue: priorityRaw)
        else {
            print("❌ Failed to parse required fields from CKRecord")
            return nil
        }

        // TaskRole 마이그레이션 (macOS 라인 1034-1042)
        let taskRole: TaskRole
        if taskRoleRaw == "메인" {
            taskRole = .none
        } else if let role = TaskRole(rawValue: taskRoleRaw) {
            taskRole = role
        } else {
            taskRole = .none
        }

        // 선택적 필드
        let parentTaskId = (record["parentTaskId"] as? String).flatMap { UUID(uuidString: $0) }
        let mainTaskId = (record["mainTaskId"] as? String).flatMap { UUID(uuidString: $0) }
        let targetDate = record["targetDate"] as? Date
        let projectId = (record["projectId"] as? String).flatMap { UUID(uuidString: $0) }
        let manualPriority = record["manualPriority"] as? Int

        // RecordName = UUID
        guard let taskId = UUID(uuidString: record.recordID.recordName) else {
            print("❌ Invalid UUID in recordName")
            return nil
        }

        return Task(
            id: taskId,
            title: title,
            description: taskDescription,
            dueDate: dueDate,
            estimatedMinutes: estimatedMinutes,
            leadTimeDays: leadTimeDays,
            taskType: taskType,
            taskRole: taskRole,
            status: status,
            priority: priority,
            projectId: projectId,
            parentTaskId: parentTaskId,
            mainTaskId: mainTaskId,
            targetDate: targetDate,
            createdAt: createdAt,
            manualPriority: manualPriority,
            // 기타 필드는 기본값 사용
            calendarEventId: nil,
            isFromCalendarPattern: false,
            patternId: nil,
            autoRecurring: false,
            lastCheckinDate: nil,
            consecutiveMissedCheckins: 0,
            completedAt: nil
        )
    }

    /// CKRecord → Project 변환
    private func ckRecordToProject(_ record: CKRecord) -> Project? {
        guard let name = record["name"] as? String,
              let color = record["color"] as? String,
              let icon = record["icon"] as? String,
              let projectId = UUID(uuidString: record.recordID.recordName)
        else {
            return nil
        }

        return Project(id: projectId, name: name, color: color, icon: icon)
    }
}
