import SwiftUI

// MARK: - Edit Task View

struct EditTaskView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @Environment(\.dismiss) var dismiss

    let task: Task

    @State private var title: String
    @State private var description: String
    @State private var dueDate: Date
    @State private var startTime: Date
    @State private var hasStartTime: Bool
    @State private var estimatedHours: Int
    @State private var estimatedMinutes: Int
    @State private var leadTimeDays: Int
    @State private var priority: TaskPriority
    @State private var taskType: TaskType
    @State private var selectedProjectId: UUID?
    @State private var subtasks: [Subtask]
    @State private var newSubtaskTitle: String = ""

    init(task: Task) {
        self.task = task
        _title = State(initialValue: task.title)
        _description = State(initialValue: task.description)
        _dueDate = State(initialValue: task.dueDate)
        _startTime = State(initialValue: task.targetDate ?? Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: task.dueDate) ?? task.dueDate)
        _hasStartTime = State(initialValue: task.targetDate != nil)
        _estimatedHours = State(initialValue: task.estimatedMinutes / 60)
        _estimatedMinutes = State(initialValue: task.estimatedMinutes % 60)
        _leadTimeDays = State(initialValue: task.leadTimeDays)
        _priority = State(initialValue: task.priority)
        _taskType = State(initialValue: task.taskType)
        _selectedProjectId = State(initialValue: task.projectId)
        _subtasks = State(initialValue: task.subtasks)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("취소") { dismiss() }
                Spacer()
                Text("할 일 수정")
                    .font(.headline)
                Spacer()
                Button("저장") { saveTask() }
                    .disabled(title.isEmpty)
                    .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            Form {
                Section("기본 정보") {
                    TextField("제목", text: $title)
                    TextField("설명 (선택)", text: $description)
                    DatePicker("마감일", selection: $dueDate, displayedComponents: .date)

                    Picker("우선순위", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            HStack {
                                Image(systemName: priority.icon)
                                Text(priority.rawValue)
                            }
                            .tag(priority)
                        }
                    }

                    Picker("프로젝트", selection: $selectedProjectId) {
                        Text("프로젝트 없음").tag(nil as UUID?)
                        ForEach(viewModel.projects) { project in
                            HStack {
                                Image(systemName: project.icon)
                                    .foregroundColor(Color(hex: project.color))
                                Text(project.name)
                            }
                            .tag(project.id as UUID?)
                        }
                    }
                }

                Section("시간 설정") {
                    Toggle("시작 시간 지정", isOn: $hasStartTime)

                    if hasStartTime {
                        DatePicker("시작 시간", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                    }

                    HStack {
                        Text("예상 소요 시간")
                        Spacer()
                        Picker("시간", selection: $estimatedHours) {
                            ForEach(0..<13) { Text("\($0)시간").tag($0) }
                        }
                        .frame(width: 100)
                        Picker("분", selection: $estimatedMinutes) {
                            ForEach([0, 15, 30, 45], id: \.self) { Text("\($0)분").tag($0) }
                        }
                        .frame(width: 90)
                    }

                    Stepper("선행 소요 일수: \(leadTimeDays)일", value: $leadTimeDays, in: 0...14)

                    if leadTimeDays > 0 {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("마감 \(leadTimeDays)일 전부터 '오늘 할 일'에 표시됩니다")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("태스크 유형") {
                    Picker("유형", selection: $taskType) {
                        ForEach(TaskType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    if taskType == .preparable {
                        Text("미리 시간이 있을 때 해둘 수 있는 일입니다")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    } else {
                        Text("해당 날짜에만 할 수 있는 일입니다 (회의, 미팅 등)")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                }

                Section("하위 할 일") {
                    ForEach($subtasks) { $subtask in
                        HStack(spacing: 8) {
                            Button(action: { subtask.isCompleted.toggle() }) {
                                Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(subtask.isCompleted ? .green : .gray)
                            }
                            .buttonStyle(.plain)

                            TextField("하위 할 일", text: $subtask.title)
                                .font(.callout)

                            Button(action: {
                                subtasks.removeAll { $0.id == subtask.id }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.blue)
                        TextField("새 하위 할 일 추가...", text: $newSubtaskTitle)
                            .font(.callout)
                            .onSubmit { addSubtask() }

                        if !newSubtaskTitle.isEmpty {
                            Button("추가") { addSubtask() }
                                .buttonStyle(.plain)
                                .foregroundColor(.blue)
                                .font(.callout)
                        }
                    }

                    if !subtasks.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.secondary)
                            Text("완료 \(subtasks.filter { $0.isCompleted }.count) / 전체 \(subtasks.count)")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("정보") {
                    if task.taskRole != .none {
                        LabeledContent("역할", value: task.taskRole.rawValue)
                    }
                    LabeledContent("상태", value: task.status.rawValue)
                    if task.isPreparation, let mainTask = viewModel.mainTask(for: task) {
                        LabeledContent("메인 태스크", value: mainTask.title)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 500, height: 600)
    }

    private func saveTask() {
        var updatedTask = task
        updatedTask.title = title
        updatedTask.description = description
        updatedTask.dueDate = dueDate
        updatedTask.estimatedMinutes = estimatedHours * 60 + estimatedMinutes
        updatedTask.leadTimeDays = leadTimeDays
        updatedTask.priority = priority
        updatedTask.taskType = taskType
        updatedTask.projectId = selectedProjectId

        if hasStartTime {
            updatedTask.targetDate = startTime
        } else {
            updatedTask.targetDate = nil
        }

        updatedTask.subtasks = subtasks
        viewModel.updateTask(updatedTask)
        dismiss()
    }

    private func addSubtask() {
        let trimmed = newSubtaskTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        subtasks.append(Subtask(title: trimmed))
        newSubtaskTitle = ""
        print("✅ [EditTaskView] 하위 할 일 추가: \(trimmed)")
    }
}
