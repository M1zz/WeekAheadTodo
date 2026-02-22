//
//  CloudKitService.swift
//  TodoAlarm (iOS)
//
//  CloudKit 읽기 전용 서비스
//

import WeekAheadShared
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
        print("📥 [iOS CloudKitService.fetchAllTasks] 시작")
        print("   Container ID: \(container.containerIdentifier ?? "nil")")

        let query = CKQuery(recordType: "Task", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        print("   🔍 CKQuery 실행 중... (recordType: Task)")

        // 모든 필드를 가져오기 위해 desiredKeys 제거 (macOS와 동일)
        let results = try await database.records(matching: query)

        print("   📦 CKQuery 결과: \(results.matchResults.count)개 레코드")

        let tasks = results.matchResults.compactMap { (recordID, result) -> TaskModel? in
            guard let record = try? result.get() else {
                print("   ⚠️ 레코드 가져오기 실패: \(recordID.recordName)")
                return nil
            }
            let task = ckRecordToTask(record)
            if task == nil {
                print("   ⚠️ Task 변환 실패: \(recordID.recordName)")
                print("      title: \(record["title"] as? String ?? "없음")")
                print("      dueDate: \(record["dueDate"] as? Date ?? Date())")
            }
            return task
        }

        print("✅ [iOS CloudKitService.fetchAllTasks] \(tasks.count)개 태스크 변환 성공 (총 \(results.matchResults.count)개 레코드)")

        return tasks
    }

    /// CloudKit에서 모든 Project 가져오기
    func fetchAllProjects() async throws -> [Project] {
        print("📥 [iOS CloudKitService.fetchAllProjects] 시작")

        let query = CKQuery(recordType: "Project", predicate: NSPredicate(value: true))

        print("   🔍 CKQuery 실행 중... (recordType: Project)")

        // 모든 필드를 가져오기 위해 desiredKeys 제거 (macOS와 동일)
        let results = try await database.records(matching: query)

        print("   📦 CKQuery 결과: \(results.matchResults.count)개 레코드")

        let projects = results.matchResults.compactMap { (recordID, result) -> Project? in
            guard let record = try? result.get() else {
                print("   ⚠️ 레코드 가져오기 실패: \(recordID.recordName)")
                return nil
            }
            let project = ckRecordToProject(record)
            if project == nil {
                print("   ⚠️ Project 변환 실패: \(recordID.recordName)")
                print("      name: \(record["name"] as? String ?? "없음")")
            }
            return project
        }

        print("✅ [iOS CloudKitService.fetchAllProjects] \(projects.count)개 프로젝트 변환 성공 (총 \(results.matchResults.count)개 레코드)")

        return projects
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
              let _ = record["createdAt"] as? Date,
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

        var task = Task(
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
            targetDate: targetDate
        )

        // 생성자에 없는 필드들은 직접 할당
        task.manualPriority = manualPriority
        task.completedAt = record["completedAt"] as? Date

        return task
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

        var project = Project(name: name, color: color, icon: icon)
        project.id = projectId
        return project
    }
}
