import WeekAheadShared
import SwiftUI

// MARK: - Completed Tasks View

struct CompletedTasksView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @State private var showingAddTask = false
    @State private var isEditMode = false
    @State private var selectedTasks: Set<UUID> = []
    @State private var showingDeleteConfirmation = false

    private var completedTasks: [Task] {
        viewModel.tasks.filter { $0.isCompleted }
            .sorted { $0.dueDate > $1.dueDate } // 최신순
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("완료된 일")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("\(completedTasks.count)개의 완료된 할 일")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()

                // 편집 모드 버튼
                if !completedTasks.isEmpty {
                    Button(action: {
                        isEditMode.toggle()
                        if !isEditMode {
                            selectedTasks.removeAll()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isEditMode ? "checkmark.circle.fill" : "checkmark.circle")
                            Text(isEditMode ? "완료" : "선택")
                        }
                    }
                    .buttonStyle(.bordered)

                    // 삭제 버튼 (편집 모드이고 선택된 항목이 있을 때만)
                    if isEditMode && !selectedTasks.isEmpty {
                        Button(action: {
                            showingDeleteConfirmation = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                Text("\(selectedTasks.count)개 삭제")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
            }
            .padding(24)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            if completedTasks.isEmpty {
                // 빈 상태
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 52))
                        .foregroundColor(.green)
                    Text("완료된 일이 없습니다")
                        .font(.headline)
                    Text("할 일을 완료하면 여기에 표시됩니다")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(completedTasks) { task in
                            if isEditMode {
                                HStack(spacing: 12) {
                                    Button(action: {
                                        if selectedTasks.contains(task.id) {
                                            selectedTasks.remove(task.id)
                                        } else {
                                            selectedTasks.insert(task.id)
                                        }
                                    }) {
                                        Image(systemName: selectedTasks.contains(task.id) ? "checkmark.circle.fill" : "circle")
                                            .font(.title2)
                                            .foregroundColor(selectedTasks.contains(task.id) ? .blue : .gray)
                                    }
                                    .buttonStyle(.plain)

                                    CompletedTaskRow(task: task)
                                }
                            } else {
                                CompletedTaskRow(task: task)
                            }
                        }
                    }
                    .padding(24)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddTask = true }) {
                    Label("새 할 일", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView()
        }
        .alert("선택한 \(selectedTasks.count)개의 할 일을 삭제하시겠습니까?", isPresented: $showingDeleteConfirmation) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) {
                let tasksToDelete = viewModel.tasks.filter { selectedTasks.contains($0.id) }
                viewModel.deleteTasks(tasksToDelete)
                selectedTasks.removeAll()
                isEditMode = false
            }
        } message: {
            Text("이 작업은 되돌릴 수 없습니다.")
        }
    }
}

// MARK: - Completed Task Row

struct CompletedTaskRow: View {
    @EnvironmentObject var viewModel: TaskViewModel
    let task: Task

    var body: some View {
        HStack(spacing: 12) {
            // 완료 체크마크
            Button(action: {
                viewModel.toggleTaskCompletion(task)
            }) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(task.title)
                        .strikethrough()
                        .foregroundColor(.secondary)

                    if task.taskRole != .none {
                        HStack(spacing: 4) {
                            Image(systemName: task.taskRole.icon)
                                .font(.callout)
                            Text(task.taskRole.rawValue)
                                .font(.callout)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.secondary)
                        .cornerRadius(4)
                    }
                }

                HStack(spacing: 8) {
                    Label(task.estimatedTimeFormatted, systemImage: "clock")
                    Label(task.dueDateFormatted, systemImage: "calendar")
                }
                .font(.callout)
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}
