import Foundation
import SwiftData
import WeekAheadShared

/// SwiftData 기반 태스크 모델 (CloudKit 자동 동기화 지원)
/// WeekAheadShared.Task struct와 1:1 매핑되며, @Model 클래스로 SwiftData/CloudKit 연동
@Model
final class TaskItem {
    // MARK: - 기본 필드

    var id: UUID = UUID()
    var title: String = ""
    var taskDescription: String = ""
    var dueDate: Date = Date()
    var scheduledStartTime: Date?
    var estimatedMinutes: Int = 30
    var leadTimeDays: Int = 0

    // MARK: - Enum Raw Values (CloudKit 호환을 위해 String 저장)

    var taskTypeRaw: String = "미리 가능"
    var taskRoleRaw: String = "없음"
    var statusRaw: String = "시작 전"
    var priorityRaw: String = "보통"

    // MARK: - 관계 ID

    var projectId: UUID?
    var parentTaskId: UUID?
    var mainTaskId: UUID?
    var targetDate: Date?

    // MARK: - 메타데이터

    var createdAt: Date = Date()
    var manualPriority: Int?

    // MARK: - 캘린더 연동

    var calendarEventId: String?
    var isFromCalendarPattern: Bool = false
    var patternId: UUID?
    var autoRecurring: Bool = false

    // MARK: - 체크인

    var lastCheckinDate: Date?
    var consecutiveMissedCheckins: Int = 0

    // MARK: - 완료

    var completedAt: Date?

    // MARK: - 복합 데이터 (JSON Data로 저장)

    var subtasksData: Data?
    var linkedWikiPageIdsData: Data?

    // MARK: - MIT

    var isMIT: Bool = false

    // MARK: - Computed Properties (Type-Safe Enum Access)

    var taskType: TaskType {
        get { TaskType(rawValue: taskTypeRaw) ?? .preparable }
        set { taskTypeRaw = newValue.rawValue }
    }

    var taskRole: TaskRole {
        get {
            if taskRoleRaw == "메인" || taskRoleRaw == "루틴" {
                return .none
            }
            return TaskRole(rawValue: taskRoleRaw) ?? .none
        }
        set { taskRoleRaw = newValue.rawValue }
    }

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .notStarted }
        set { statusRaw = newValue.rawValue }
    }

    var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRaw) ?? .normal }
        set { priorityRaw = newValue.rawValue }
    }

    // MARK: - Computed Properties (복합 데이터)

    var subtasks: [Subtask] {
        get {
            guard let data = subtasksData else { return [] }
            return (try? JSONDecoder().decode([Subtask].self, from: data)) ?? []
        }
        set {
            subtasksData = try? JSONEncoder().encode(newValue)
        }
    }

    var linkedWikiPageIds: [UUID] {
        get {
            guard let data = linkedWikiPageIdsData else { return [] }
            return (try? JSONDecoder().decode([UUID].self, from: data)) ?? []
        }
        set {
            linkedWikiPageIdsData = try? JSONEncoder().encode(newValue)
        }
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        title: String,
        taskDescription: String = "",
        dueDate: Date,
        scheduledStartTime: Date? = nil,
        estimatedMinutes: Int = 30,
        leadTimeDays: Int = 0,
        taskType: TaskType = .preparable,
        taskRole: TaskRole = .none,
        status: TaskStatus = .notStarted,
        priority: TaskPriority = .normal,
        projectId: UUID? = nil,
        parentTaskId: UUID? = nil,
        mainTaskId: UUID? = nil,
        targetDate: Date? = nil,
        createdAt: Date = Date(),
        manualPriority: Int? = nil,
        calendarEventId: String? = nil,
        isFromCalendarPattern: Bool = false,
        patternId: UUID? = nil,
        autoRecurring: Bool = false,
        lastCheckinDate: Date? = nil,
        consecutiveMissedCheckins: Int = 0,
        completedAt: Date? = nil,
        isMIT: Bool = false
    ) {
        self.id = id
        self.title = title
        self.taskDescription = taskDescription
        self.dueDate = dueDate
        self.scheduledStartTime = scheduledStartTime
        self.estimatedMinutes = estimatedMinutes
        self.leadTimeDays = leadTimeDays
        self.taskTypeRaw = taskType.rawValue
        self.taskRoleRaw = taskRole.rawValue
        self.statusRaw = status.rawValue
        self.priorityRaw = priority.rawValue
        self.projectId = projectId
        self.parentTaskId = parentTaskId
        self.mainTaskId = mainTaskId
        self.targetDate = targetDate
        self.createdAt = createdAt
        self.manualPriority = manualPriority
        self.calendarEventId = calendarEventId
        self.isFromCalendarPattern = isFromCalendarPattern
        self.patternId = patternId
        self.autoRecurring = autoRecurring
        self.lastCheckinDate = lastCheckinDate
        self.consecutiveMissedCheckins = consecutiveMissedCheckins
        self.completedAt = completedAt
        self.isMIT = isMIT
    }
}

// MARK: - Task ↔ TaskItem 변환

extension TaskItem {
    /// WeekAheadShared.Task struct로부터 TaskItem 생성
    convenience init(from task: Task) {
        self.init(
            id: task.id,
            title: task.title,
            taskDescription: task.description,
            dueDate: task.dueDate,
            scheduledStartTime: task.scheduledStartTime,
            estimatedMinutes: task.estimatedMinutes,
            leadTimeDays: task.leadTimeDays,
            taskType: task.taskType,
            taskRole: task.taskRole,
            status: task.status,
            priority: task.priority,
            projectId: task.projectId,
            parentTaskId: task.parentTaskId,
            mainTaskId: task.mainTaskId,
            targetDate: task.targetDate,
            createdAt: task.createdAt,
            manualPriority: task.manualPriority,
            calendarEventId: task.calendarEventId,
            isFromCalendarPattern: task.isFromCalendarPattern,
            patternId: task.patternId,
            autoRecurring: task.autoRecurring,
            lastCheckinDate: task.lastCheckinDate,
            consecutiveMissedCheckins: task.consecutiveMissedCheckins,
            completedAt: task.completedAt,
            isMIT: task.isMIT
        )
        self.subtasks = task.subtasks
        self.linkedWikiPageIds = task.linkedWikiPageIds
    }

    /// TaskItem을 WeekAheadShared.Task struct로 변환
    func toTask() -> Task {
        var task = Task(
            id: id,
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
        task.scheduledStartTime = scheduledStartTime
        task.manualPriority = manualPriority
        task.calendarEventId = calendarEventId
        task.isFromCalendarPattern = isFromCalendarPattern
        task.patternId = patternId
        task.autoRecurring = autoRecurring
        task.lastCheckinDate = lastCheckinDate
        task.consecutiveMissedCheckins = consecutiveMissedCheckins
        task.completedAt = completedAt
        task.subtasks = subtasks
        task.isMIT = isMIT
        task.linkedWikiPageIds = linkedWikiPageIds
        return task
    }

    /// 기존 Task struct의 변경사항을 TaskItem에 반영
    func update(from task: Task) {
        title = task.title
        taskDescription = task.description
        dueDate = task.dueDate
        scheduledStartTime = task.scheduledStartTime
        estimatedMinutes = task.estimatedMinutes
        leadTimeDays = task.leadTimeDays
        taskType = task.taskType
        taskRole = task.taskRole
        status = task.status
        priority = task.priority
        projectId = task.projectId
        parentTaskId = task.parentTaskId
        mainTaskId = task.mainTaskId
        targetDate = task.targetDate
        manualPriority = task.manualPriority
        calendarEventId = task.calendarEventId
        isFromCalendarPattern = task.isFromCalendarPattern
        patternId = task.patternId
        autoRecurring = task.autoRecurring
        lastCheckinDate = task.lastCheckinDate
        consecutiveMissedCheckins = task.consecutiveMissedCheckins
        completedAt = task.completedAt
        subtasks = task.subtasks
        isMIT = task.isMIT
        linkedWikiPageIds = task.linkedWikiPageIds
    }
}

// MARK: - ProjectItem SwiftData Model

/// SwiftData 기반 프로젝트 모델 (CloudKit 자동 동기화 지원)
@Model
final class ProjectItem {
    var id: UUID = UUID()
    var name: String = ""
    var color: String = "#007AFF"
    var icon: String = "folder.fill"
    var createdAt: Date = Date()

    init(id: UUID = UUID(), name: String, color: String = "#007AFF", icon: String = "folder.fill") {
        self.id = id
        self.name = name
        self.color = color
        self.icon = icon
        self.createdAt = Date()
    }
}

// MARK: - Project ↔ ProjectItem 변환

extension ProjectItem {
    convenience init(from project: Project) {
        self.init(id: project.id, name: project.name, color: project.color, icon: project.icon)
        self.createdAt = project.createdAt
    }

    func toProject() -> Project {
        var project = Project(name: name, color: color, icon: icon)
        project.id = id
        project.createdAt = createdAt
        return project
    }

    func update(from project: Project) {
        name = project.name
        color = project.color
        icon = project.icon
    }
}
