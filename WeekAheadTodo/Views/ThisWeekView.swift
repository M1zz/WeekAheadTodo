import WeekAheadShared
import SwiftUI

// MARK: - This Week View

struct ThisWeekView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @State private var showingAddTask = false
    @State private var viewMode: WeekViewMode = .calendar
    @State private var taskFilterMode: TaskFilterMode = .byStartDate
    @State private var isEditMode = false
    @State private var selectedTasks: Set<UUID> = []
    @State private var showingDeleteConfirmation = false

    private var weekDates: [Date] {
        let calendar = Calendar.current
        let weekRange = ContentView.weekDateRange(for: Date(), weekStartDay: viewModel.weekStartDay)
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekRange.start)
        }
    }

    private func tasks(for date: Date) -> [Task] {
        let calendar = Calendar.current
        var result: [Task] = []
        for task in viewModel.tasks {
            // 메인 태스크 필터링
            let matches: Bool
            switch taskFilterMode {
            case .byStartDate:
                matches = calendar.isDate(task.effectiveStartDate, inSameDayAs: date)
            case .byDueDate:
                matches = calendar.isDate(task.dueDate, inSameDayAs: date)
            }
            if matches {
                result.append(task)
            }
            // 하위 할 일: scheduledDate가 있으면 그 날짜 기준, 없으면 parent와 같은 날
            for subtask in task.subtasks {
                let subtaskDate = subtask.scheduledDate ?? task.dueDate
                guard calendar.isDate(subtaskDate, inSameDayAs: date) else { continue }
                var subtaskTask = Task(
                    id: subtask.id,
                    title: subtask.title,
                    dueDate: subtaskDate,
                    estimatedMinutes: 30,
                    taskRole: .preparation,
                    parentTaskId: task.id
                )
                subtaskTask.targetDate = subtask.scheduledDate ?? task.targetDate
                subtaskTask.status = subtask.isCompleted ? .completed : .notStarted
                result.append(subtaskTask)
            }
        }
        return result
    }

    private var allThisWeekTasks: [Task] {
        weekDates.flatMap { tasks(for: $0) }
    }

    private var totalTasksThisWeek: Int {
        weekDates.reduce(0) { $0 + tasks(for: $1).count }
    }

    private var completedThisWeekCount: Int {
        weekDates.flatMap { tasks(for: $0) }.filter { $0.isCompleted }.count
    }

    private var thisWeekCompletionPercentage: Int {
        guard totalTasksThisWeek > 0 else { return 0 }
        return Int(Double(completedThisWeekCount) / Double(totalTasksThisWeek) * 100)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    let weekRange = ContentView.weekDateRange(for: Date(), weekStartDay: viewModel.weekStartDay)
                    Text("이번 주 (\(ContentView.formatDateRange(start: weekRange.start, end: weekRange.end)))")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("\(totalTasksThisWeek)개의 할 일")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()

                if totalTasksThisWeek > 0 {
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

                if totalTasksThisWeek > 0 {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("달성도")
                            .font(.callout)
                            .foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            Text("\(completedThisWeekCount)/\(totalTasksThisWeek)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(completedThisWeekCount == totalTasksThisWeek ? .green : .primary)
                            Text("(\(thisWeekCompletionPercentage)%)")
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

            if totalTasksThisWeek == 0 {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 52))
                        .foregroundColor(.green)
                    Text("이번 주 예정된 할 일이 없습니다")
                        .font(.headline)
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
                            tasks: allThisWeekTasks,
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
            let weekRange = ContentView.weekDateRange(for: Date(), weekStartDay: viewModel.weekStartDay)
            AddTaskView(defaultDueDate: weekRange.start)
        }
    }
}

// MARK: - Week Day Card Component

struct WeekDayCard: View {
    let date: Date
    let tasks: [Task]
    let isToday: Bool
    let isTomorrow: Bool
    @Binding var isEditMode: Bool
    @Binding var selectedTasks: Set<UUID>
    @EnvironmentObject var viewModel: TaskViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dayOfWeek)
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Text(dayAndMonth)
                        .font(.headline)
                }

                if isToday {
                    Text("오늘")
                        .font(.callout)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                } else if isTomorrow {
                    Text("내일")
                        .font(.callout)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }

                Spacer()

                if !tasks.isEmpty {
                    Text("\(completedCount)/\(tasks.count)")
                        .font(.callout)
                        .foregroundColor(completedCount == tasks.count ? .green : .secondary)
                }
            }

            Divider()

            if tasks.isEmpty {
                Text("할 일 없음")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(tasks) { task in
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
                            }
                            .buttonStyle(.plain)

                            CompactTaskRow(task: task)
                        }
                    } else {
                        CompactTaskRow(task: task)
                    }
                }
            }
        }
        .padding(12)
        .background(isToday ? Color.blue.opacity(0.05) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isToday ? Color.blue : Color.clear, lineWidth: 2)
        )
    }

    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    private var dayAndMonth: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일"
        return formatter.string(from: date)
    }

    private var completedCount: Int {
        tasks.filter { $0.isCompleted }.count
    }
}
