import SwiftUI

// MARK: - Project View

struct ProjectView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    let project: Project
    @State private var showingAddTask = false
    @State private var showingEditProject = false
    @State private var isEditMode = false
    @State private var selectedTasks: Set<UUID> = []
    @State private var editingTask: Task? = nil

    private var projectTasks: [Task] {
        viewModel.tasks(for: project.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: project.icon)
                    .foregroundColor(Color(hex: project.color))
                    .font(.title)
                Text(project.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()

                Button { showingEditProject = true } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)

                Button { showingAddTask = true } label: {
                    Label("새 할 일", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)

                if !projectTasks.isEmpty {
                    Button(isEditMode ? "완료" : "편집") {
                        isEditMode.toggle()
                        if !isEditMode { selectedTasks.removeAll() }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()

            Divider()

            if projectTasks.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 64))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("할 일이 없습니다")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Button { showingAddTask = true } label: {
                        Label("첫 할 일 추가", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(projectTasks) { task in
                            HStack(spacing: 12) {
                                if isEditMode {
                                    Button {
                                        if selectedTasks.contains(task.id) {
                                            selectedTasks.remove(task.id)
                                        } else {
                                            selectedTasks.insert(task.id)
                                        }
                                    } label: {
                                        Image(systemName: selectedTasks.contains(task.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedTasks.contains(task.id) ? .blue : .gray)
                                    }
                                    .buttonStyle(.plain)
                                }

                                Button { viewModel.toggleTaskCompletion(task) } label: {
                                    Image(systemName: task.status.icon)
                                        .foregroundColor(Color(task.status.color))
                                }
                                .buttonStyle(.plain)

                                Button { editingTask = task } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(task.title)
                                            .font(.body)
                                            .strikethrough(task.isCompleted)
                                        HStack(spacing: 8) {
                                            Text(task.dueDateWithWeekday)
                                                .font(.callout)
                                                .foregroundColor(.secondary)
                                            Text(task.estimatedTimeFormatted)
                                                .font(.callout)
                                                .foregroundColor(.secondary)
                                            if task.priority != .normal {
                                                Image(systemName: task.priority.icon)
                                                    .foregroundColor(Color(task.priority.color))
                                                    .font(.callout)
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(.plain)

                                Spacer()

                                Text(task.dDayText)
                                    .font(.callout)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(task.daysUntilDue <= 0 ? Color.red.opacity(0.2) : Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                            }
                            .padding(12)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }

                if isEditMode && !selectedTasks.isEmpty {
                    HStack {
                        Text("\(selectedTasks.count)개 선택됨")
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(role: .destructive) {
                            let tasksToDelete = projectTasks.filter { selectedTasks.contains($0.id) }
                            viewModel.deleteTasks(tasksToDelete)
                            selectedTasks.removeAll()
                            isEditMode = false
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                }
            }
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(preselectedProjectId: project.id)
        }
        .sheet(isPresented: $showingEditProject) {
            EditProjectView(project: project)
        }
        .sheet(item: $editingTask) { task in
            EditTaskView(task: task)
        }
    }
}

// MARK: - Add Project View

struct AddProjectView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @Environment(\.dismiss) private var dismiss
    var onProjectAdded: ((UUID) -> Void)? = nil
    @State private var name = ""
    @State private var selectedColor = "#007AFF"
    @State private var selectedIcon = "folder.fill"

    private let availableColors = [
        "#007AFF", "#FF3B30", "#34C759", "#FF9500", "#5856D6",
        "#FF2D55", "#5AC8FA", "#FFCC00", "#AF52DE", "#32ADE6"
    ]

    private let availableIcons = [
        "folder.fill", "star.fill", "heart.fill", "bookmark.fill",
        "flag.fill", "tag.fill", "briefcase.fill", "house.fill",
        "cart.fill", "book.fill", "graduationcap.fill", "gamecontroller.fill"
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("새 프로젝트")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)

            VStack(alignment: .leading, spacing: 12) {
                Text("프로젝트 이름")
                    .font(.headline)
                TextField("프로젝트 이름", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("색상")
                    .font(.headline)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                    ForEach(availableColors, id: \.self) { color in
                        Circle()
                            .fill(Color(hex: color))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: selectedColor == color ? 3 : 0)
                            )
                            .onTapGesture { selectedColor = color }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("아이콘")
                    .font(.headline)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                    ForEach(availableIcons, id: \.self) { icon in
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundColor(Color(hex: selectedColor))
                            .frame(width: 40, height: 40)
                            .background(selectedIcon == icon ? Color.gray.opacity(0.2) : Color.clear)
                            .cornerRadius(8)
                            .onTapGesture { selectedIcon = icon }
                    }
                }
            }

            Spacer()

            HStack {
                Button("취소") { dismiss() }
                .buttonStyle(.bordered)

                Button("추가") {
                    let project = Project(
                        name: name,
                        color: selectedColor,
                        icon: selectedIcon
                    )
                    print("📝 [AddProjectView] 프로젝트 추가 중: \(project.name)")
                    viewModel.addProject(project)
                    print("✅ [AddProjectView] 프로젝트 추가 완료. 총 프로젝트 수: \(viewModel.projects.count)")
                    onProjectAdded?(project.id)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 500)
    }
}

// MARK: - Edit Project View

struct EditProjectView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @Environment(\.dismiss) private var dismiss
    let project: Project
    @State private var name = ""
    @State private var selectedColor = ""
    @State private var selectedIcon = ""
    @State private var showingDeleteConfirmation = false

    private let availableColors = [
        "#007AFF", "#FF3B30", "#34C759", "#FF9500", "#5856D6",
        "#FF2D55", "#5AC8FA", "#FFCC00", "#AF52DE", "#32ADE6"
    ]

    private let availableIcons = [
        "folder.fill", "star.fill", "heart.fill", "bookmark.fill",
        "flag.fill", "tag.fill", "briefcase.fill", "house.fill",
        "cart.fill", "book.fill", "graduationcap.fill", "gamecontroller.fill"
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("프로젝트 편집")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)

            VStack(alignment: .leading, spacing: 12) {
                Text("프로젝트 이름")
                    .font(.headline)
                TextField("프로젝트 이름", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("색상")
                    .font(.headline)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                    ForEach(availableColors, id: \.self) { color in
                        Circle()
                            .fill(Color(hex: color))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: selectedColor == color ? 3 : 0)
                            )
                            .onTapGesture { selectedColor = color }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("아이콘")
                    .font(.headline)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                    ForEach(availableIcons, id: \.self) { icon in
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundColor(Color(hex: selectedColor))
                            .frame(width: 40, height: 40)
                            .background(selectedIcon == icon ? Color.gray.opacity(0.2) : Color.clear)
                            .cornerRadius(8)
                            .onTapGesture { selectedIcon = icon }
                    }
                }
            }

            Spacer()

            HStack {
                Button(role: .destructive) { showingDeleteConfirmation = true } label: {
                    Label("삭제", systemImage: "trash")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("취소") { dismiss() }
                .buttonStyle(.bordered)

                Button("저장") {
                    var updatedProject = project
                    updatedProject.name = name
                    updatedProject.color = selectedColor
                    updatedProject.icon = selectedIcon
                    viewModel.updateProject(updatedProject)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 500)
        .onAppear {
            name = project.name
            selectedColor = project.color
            selectedIcon = project.icon
        }
        .alert("프로젝트 삭제", isPresented: $showingDeleteConfirmation) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) {
                viewModel.deleteProject(project)
                dismiss()
            }
        } message: {
            Text("프로젝트를 삭제하시겠습니까? 프로젝트에 속한 태스크는 프로젝트 없음으로 변경됩니다.")
        }
    }
}
