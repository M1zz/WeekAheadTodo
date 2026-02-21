import WeekAheadShared
import SwiftUI

// MARK: - Next Week View

struct NextWeekView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @State private var showingAddTask = false
    @State private var viewMode: WeekViewMode = .calendar
    @State private var taskFilterMode: TaskFilterMode = .byStartDate
    @State private var isEditMode = false
    @State private var selectedTasks: Set<UUID> = []
    @State private var showingDeleteConfirmation = false

    private var weekDates: [Date] {
        let calendar = Calendar.current
        let thisWeekRange = ContentView.weekDateRange(for: Date(), weekStartDay: viewModel.weekStartDay)
        guard let nextWeekStart = calendar.date(byAdding: .day, value: 7, to: thisWeekRange.start) else {
            return []
        }
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: nextWeekStart)
        }
    }

    private func tasks(for date: Date) -> [Task] {
        let calendar = Calendar.current
        return viewModel.tasks.filter { task in
            switch taskFilterMode {
            case .byStartDate:
                return calendar.isDate(task.effectiveStartDate, inSameDayAs: date)
            case .byDueDate:
                return calendar.isDate(task.dueDate, inSameDayAs: date)
            }
        }
    }

    private var allNextWeekTasks: [Task] {
        weekDates.flatMap { tasks(for: $0) }
    }

    private var totalTasksNextWeek: Int {
        weekDates.reduce(0) { $0 + tasks(for: $1).count }
    }

    private var completedNextWeekCount: Int {
        weekDates.flatMap { tasks(for: $0) }.filter { $0.isCompleted }.count
    }

    private var nextWeekCompletionPercentage: Int {
        guard totalTasksNextWeek > 0 else { return 0 }
        return Int(Double(completedNextWeekCount) / Double(totalTasksNextWeek) * 100)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    let thisWeekRange = ContentView.weekDateRange(for: Date(), weekStartDay: viewModel.weekStartDay)
                    let calendar = Calendar.current
                    let nextWeekStart = calendar.date(byAdding: .day, value: 7, to: thisWeekRange.start) ?? Date()
                    let nextWeekEnd = calendar.date(byAdding: .day, value: 6, to: nextWeekStart) ?? Date()
                    Text("다음 주 (\(ContentView.formatDateRange(start: nextWeekStart, end: nextWeekEnd)))")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("\(totalTasksNextWeek)개의 할 일")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()

                if totalTasksNextWeek > 0 {
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

                if totalTasksNextWeek > 0 {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("달성도")
                            .font(.callout)
                            .foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            Text("\(completedNextWeekCount)/\(totalTasksNextWeek)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(completedNextWeekCount == totalTasksNextWeek ? .green : .primary)
                            Text("(\(nextWeekCompletionPercentage)%)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(24)
            .background(Color(NSColor.windowBackgroundColor))
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

            HStack(spacing: 12) {
                Picker("보기 모드", selection: $viewMode) {
                    ForEach(WeekViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                Picker("정렬 기준", selection: $taskFilterMode) {
                    ForEach(TaskFilterMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 250)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if totalTasksNextWeek == 0 {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 52))
                        .foregroundColor(.blue)
                    Text("다음 주 예정된 할 일이 없습니다")
                        .font(.headline)
                    Text("미리 계획을 세워보세요")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Group {
                    switch viewMode {
                    case .calendar:
                        TimeBasedWeekCalendar(
                            weekDates: weekDates,
                            tasksForDate: { tasks(for: $0) }
                        )
                    case .list:
                        WeekListView(
                            weekDates: weekDates,
                            tasks: allNextWeekTasks,
                            filterMode: taskFilterMode,
                            isEditMode: $isEditMode,
                            selectedTasks: $selectedTasks
                        )
                    }
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
            let thisWeekRange = ContentView.weekDateRange(for: Date(), weekStartDay: viewModel.weekStartDay)
            let calendar = Calendar.current
            let nextWeekStart = calendar.date(byAdding: .day, value: 7, to: thisWeekRange.start) ?? Date()
            AddTaskView(defaultDueDate: nextWeekStart)
        }
    }
}

// MARK: - Week List View Component

struct WeekListView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    let weekDates: [Date]
    let tasks: [Task]
    let filterMode: TaskFilterMode
    @Binding var isEditMode: Bool
    @Binding var selectedTasks: Set<UUID>

    private var groupedTasks: [(date: Date, tasks: [Task])] {
        weekDates.map { date in
            let calendar = Calendar.current
            let tasksForDate = viewModel.tasks.filter { task in
                switch filterMode {
                case .byStartDate:
                    return calendar.isDate(task.effectiveStartDate, inSameDayAs: date)
                case .byDueDate:
                    return calendar.isDate(task.dueDate, inSameDayAs: date)
                }
            }
            return (date, tasksForDate)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(groupedTasks, id: \.date) { group in
                    if !group.tasks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dayOfWeek(group.date))
                                        .font(.callout)
                                        .foregroundColor(.secondary)
                                    Text(dayAndMonth(group.date))
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }

                                Spacer()

                                let completed = group.tasks.filter { $0.isCompleted }.count
                                Text("\(completed)/\(group.tasks.count) 완료")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)

                            VStack(spacing: 8) {
                                ForEach(group.tasks) { task in
                                    if isEditMode {
                                        HStack(spacing: 8) {
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
                            .padding(.horizontal, 16)
                        }
                        .padding(.vertical, 12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(24)
        }
    }

    private func dayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    private func dayAndMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일"
        return formatter.string(from: date)
    }
}
