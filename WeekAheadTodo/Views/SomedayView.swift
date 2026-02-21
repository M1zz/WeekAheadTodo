import WeekAheadShared
import SwiftUI

// MARK: - Someday View

struct SomedayView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @State private var showingAddTask = false
    @State private var isEditMode = false
    @State private var selectedTasks: Set<UUID> = []
    @State private var showingDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !viewModel.somedayTasks.isEmpty {
                        taskSection
                    } else {
                        emptyStateView
                    }
                }
                .padding(24)
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
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("언젠가")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                HStack(spacing: 12) {
                    Text("총 \(viewModel.somedayTasks.count)개")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if viewModel.somedayIncompleteTasks.count > 0 {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text("미완료 \(viewModel.somedayIncompleteTasks.count)개")
                            .font(.subheadline)
                            .foregroundColor(.purple)
                    }
                }
            }
            Spacer()

            if !viewModel.somedayTasks.isEmpty {
                HStack(spacing: 12) {
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

                    if isEditMode && !selectedTasks.isEmpty {
                        Button(action: {
                            moveSelectedTasksToToday()
                        }) {
                            Label("오늘하기 (\(selectedTasks.count))", systemImage: "calendar.badge.clock")
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)

                        Button(action: {
                            showingDeleteConfirmation = true
                        }) {
                            Label("삭제 (\(selectedTasks.count))", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .confirmationDialog(
                            "선택한 \(selectedTasks.count)개의 태스크를 삭제하시겠습니까?",
                            isPresented: $showingDeleteConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button("삭제", role: .destructive) {
                                deleteSelectedTasks()
                            }
                            Button("취소", role: .cancel) {}
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var taskSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("다음 주 이후 할 일")
                .font(.headline)
                .padding(.horizontal, 4)

            ForEach(viewModel.somedayTasks) { task in
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
                                .foregroundColor(selectedTasks.contains(task.id) ? .blue : .gray)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)

                        TaskRowView(task: task)
                    }
                } else {
                    TaskRowView(task: task)
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 52))
                .foregroundColor(.secondary)
            Text("언젠가 할 일이 없습니다")
                .font(.title3)
                .fontWeight(.medium)
            Text("다음 주 이후의 할 일을 추가해보세요")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private func deleteSelectedTasks() {
        for taskId in selectedTasks {
            if let task = viewModel.tasks.first(where: { $0.id == taskId }) {
                viewModel.deleteTask(task)
            }
        }
        selectedTasks.removeAll()
        isEditMode = false
    }

    private func moveSelectedTasksToToday() {
        let today = Calendar.current.startOfDay(for: Date())
        for taskId in selectedTasks {
            if var task = viewModel.tasks.first(where: { $0.id == taskId }) {
                task.dueDate = today
                task.leadTimeDays = 0  // 오늘로 옮기면 선행 일수 초기화
                viewModel.updateTask(task)
            }
        }
        selectedTasks.removeAll()
        isEditMode = false
    }
}
