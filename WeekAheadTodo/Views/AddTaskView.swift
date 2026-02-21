import WeekAheadShared
import SwiftUI

// MARK: - Add Task View

struct AddTaskView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @Environment(\.dismiss) var dismiss

    var preselectedProjectId: UUID? = nil
    var defaultDueDate: Date? = nil
    var initialTime: Date? = nil

    @State private var quickInput = ""
    @State private var title = ""
    @State private var description = ""
    @State private var dueDate: Date
    @State private var startTime: Date
    @State private var hasStartTime: Bool
    @State private var estimatedHours = 1
    @State private var estimatedMinutes = 0
    @State private var leadTimeDays = 0
    @State private var priority: TaskPriority = .normal
    @State private var taskType: TaskType = .preparable
    @State private var useTemplate = false
    @State private var selectedTemplate: TaskTemplate?
    @State private var showDetailedForm = false
    @State private var selectedProjectId: UUID? = nil

    init(preselectedProjectId: UUID? = nil, defaultDueDate: Date? = nil, initialDate: Date? = nil, initialTime: Date? = nil) {
        self.preselectedProjectId = preselectedProjectId
        self.defaultDueDate = defaultDueDate
        self.initialTime = initialTime

        let date = initialDate ?? defaultDueDate ?? Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        _dueDate = State(initialValue: date)
        _selectedProjectId = State(initialValue: preselectedProjectId)

        // 시간이 지정된 경우 해당 시간 사용
        if let time = initialTime {
            _startTime = State(initialValue: time)
            _hasStartTime = State(initialValue: true)
        } else {
            _startTime = State(initialValue: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date())
            _hasStartTime = State(initialValue: false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("취소") { dismiss() }
                Spacer()
                Text("새 할 일")
                    .font(.headline)
                Spacer()
                Button("추가") { addTask() }
                    .disabled(title.isEmpty && quickInput.isEmpty)
                    .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("예: 내일까지 회의 자료 준비 2시간 중요", text: $quickInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                            .onSubmit { parseQuickInput() }

                        HStack(spacing: 4) {
                            Image(systemName: "lightbulb.fill")
                                .font(.callout)
                                .foregroundColor(.orange)
                            Text("자연어로 입력하면 자동으로 파싱됩니다")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }

                        if !quickInput.isEmpty {
                            Button(action: parseQuickInput) {
                                Label("입력 분석", systemImage: "wand.and.stars")
                                    .font(.callout)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                } header: {
                    HStack {
                        Text("빠른 입력")
                        Spacer()
                        Button(action: { showDetailedForm.toggle() }) {
                            Text(showDetailedForm ? "간단히 보기" : "상세 설정")
                                .font(.callout)
                        }
                    }
                }

                if showDetailedForm {
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

                    Section("템플릿 (선택)") {
                        Toggle("템플릿 사용", isOn: $useTemplate)

                        if useTemplate {
                            ForEach(TaskTemplate.allTemplates, id: \.name) { template in
                                Button(action: { selectedTemplate = template }) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(template.name)
                                            Text("\(template.subtasks.count)개의 서브태스크")
                                                .font(.callout)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if selectedTemplate?.name == template.name {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    if !title.isEmpty {
                        Section("파싱 결과") {
                            LabeledContent("제목", value: title)
                            LabeledContent("마감일", value: dueDate.formatted(date: .abbreviated, time: .omitted))
                            LabeledContent("예상 시간", value: "\(estimatedHours)시간 \(estimatedMinutes)분")
                            if priority != .normal {
                                LabeledContent("우선순위", value: priority.rawValue)
                            }
                            if leadTimeDays > 0 {
                                LabeledContent("선행 일수", value: "\(leadTimeDays)일 전")
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 500, height: showDetailedForm ? 700 : 400)
        .onAppear { selectedProjectId = preselectedProjectId }
    }

    private func parseQuickInput() {
        let parsed = TaskInputParser.parse(quickInput)


        title = parsed.title
        if let date = parsed.dueDate { dueDate = date }
        if let minutes = parsed.estimatedMinutes {
            estimatedHours = minutes / 60
            estimatedMinutes = minutes % 60
        }
        if let parsedPriority = parsed.priority { priority = parsedPriority }
        if let days = parsed.leadTimeDays { leadTimeDays = days }

        showDetailedForm = true
    }

    private func addTask() {
        if !quickInput.isEmpty && title.isEmpty {
            parseQuickInput()
        }

        guard !title.isEmpty else { return }

        var task = Task(
            title: title,
            description: description,
            dueDate: dueDate,
            estimatedMinutes: estimatedHours * 60 + estimatedMinutes,
            leadTimeDays: leadTimeDays,
            taskType: taskType,
            taskRole: .none,
            priority: priority,
            projectId: selectedProjectId
        )

        if hasStartTime {
            task.targetDate = startTime
        }

        if useTemplate, let template = selectedTemplate {
            viewModel.addTaskWithSubtasks(mainTask: task, template: template)
        } else {
            viewModel.addTask(task)
        }

        dismiss()
    }
}
