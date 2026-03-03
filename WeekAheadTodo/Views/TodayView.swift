import WeekAheadShared
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Today Task Drop Delegate

private struct TodayTaskDropDelegate: DropDelegate {
    let targetId: UUID
    let orderedIds: [UUID]
    @Binding var draggingId: UUID?
    let onMove: (UUID, UUID, [UUID]) -> Void

    func dropEntered(info: DropInfo) {
        guard let dragId = draggingId, dragId != targetId else { return }
        onMove(dragId, targetId, orderedIds)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingId = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// MARK: - Today View

struct TodayView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var calendarViewModel: CalendarViewModel
    @EnvironmentObject var assistantService: ProactiveAssistantService
    @EnvironmentObject var wikiViewModel: WikiViewModel
    @State private var showingAddTask = false
    @State private var editingTask: Task? = nil
    @State private var showingNotificationPreview = false
    @State private var isEditMode = false
    @State private var selectedTasks: Set<UUID> = []
    @State private var showingDeleteConfirmation = false
    @State private var showingCalendarAddConfirmation = false
    @State private var isAddingToCalendar = false
    @State private var showingMoveToTodayAlert = false
    @State private var movedTasksCount = 0
    @State private var showingTaskSelectionSheet = false
    @State private var taskIdsToSelect: [UUID] = []
    @State private var draggingTaskId: UUID? = nil
    @AppStorage("recommendationSectionExpanded") private var isRecommendationExpanded = true
    @AppStorage("focusModeEnabled") private var isFocusMode = false

    // 체크인 관련
    @State private var selectedCheckinTask: Task?

    private var displayedTasks: [Task] {
        // 미완료 태스크 + 오늘 완료된 태스크 (취소선으로 표시)
        return viewModel.todayTasks.filter { task in
            !task.isCompleted || task.isCompletedToday
        }
    }

    /// 포커스 모드에서 보여줄 최대 3개 태스크 (MIT 우선, 이후 sortOrder 순)
    private var focusTasks: [Task] {
        let mit = displayedTasks.filter { $0.isMIT }
        let nonMit = displayedTasks.filter { !$0.isMIT }
        return Array((mit + nonMit).prefix(3))
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()

            if isFocusMode {
                ScrollView {
                    focusModeSection
                        .padding(24)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(assistantService.activeSuggestions) { suggestion in
                            AssistantSuggestionBannerView(
                                suggestion: suggestion,
                                onDismiss: {
                                    assistantService.dismissSuggestion(suggestion)
                                },
                                onAction: { action in
                                    handleSuggestionAction(action, suggestion: suggestion)
                                }
                            )
                        }

                        // 미체크인 경고 배너
                        MissedCheckinBanner(
                            selectedCheckinTask: $selectedCheckinTask
                        )

                        // 체크인 필요 태스크 목록
                        CheckinNeededListView(
                            selectedCheckinTask: $selectedCheckinTask
                        )

                        if !viewModel.mitTasks.isEmpty {
                            mitPinnedSection
                        }

                        if !displayedTasks.isEmpty {
                            taskSection(
                                title: "오늘 해야 할 일",
                                subtitle: "역산 결과 기준",
                                tasks: displayedTasks
                            )
                        } else {
                            emptyStateView
                        }

                        if !viewModel.recommendPreparableTasks().isEmpty {
                            recommendationSection
                        }

                        if viewModel.isTodayOverCapacity {
                            reallocationSuggestionView
                        }

                        let futurePreps = viewModel.futureTasksPreparedToday()
                        if !futurePreps.isEmpty {
                            futureFeedbackSection(futurePreps: futurePreps)
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
            AddTaskView(defaultDueDate: Date())
        }
        .sheet(isPresented: $showingTaskSelectionSheet) {
            TaskSelectionSheet(
                taskIds: taskIdsToSelect,
                onSelect: { taskId in
                    moveTasksToToday(taskIds: [taskId])
                    showingTaskSelectionSheet = false
                }
            )
        }
        .sheet(item: $selectedCheckinTask) { task in
            CheckinView(task: task, isPresented: Binding(
                get: { selectedCheckinTask != nil },
                set: { if !$0 { selectedCheckinTask = nil } }
            ))
        }
        .sheet(item: $editingTask) { task in
            EditTaskView(task: task)
                .environmentObject(viewModel)
                .environmentObject(wikiViewModel)
        }
        .alert("오늘로 이동 완료", isPresented: $showingMoveToTodayAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("\(movedTasksCount)개의 할 일을 오늘로 옮겼습니다.")
        }
        .onAppear {
            assistantService.analyzeTasks(viewModel.tasks)
        }
        .onChange(of: viewModel.tasks.count) { _ in
            assistantService.analyzeTasks(viewModel.tasks)
        }
    }

    // MARK: - Suggestion Action Handler

    private func handleSuggestionAction(_ action: SuggestionAction, suggestion: AssistantSuggestion) {
        switch action.actionType {
        case .addTask:
            showingAddTask = true
        case .viewTasks:
            if suggestion.relatedTaskIds.count > 1 {
                taskIdsToSelect = suggestion.relatedTaskIds
                showingTaskSelectionSheet = true
            } else if let taskId = suggestion.relatedTaskIds.first {
                moveTasksToToday(taskIds: [taskId])
            }
        case .reschedule:
            if let taskId = suggestion.relatedTaskIds.first,
               let task = viewModel.tasks.first(where: { $0.id == taskId }) {
                editingTask = task
            }
        case .dismiss:
            assistantService.dismissSuggestion(suggestion)
        }
    }

    private func moveTasksToToday(taskIds: [UUID]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var count = 0

        for taskId in taskIds {
            if let task = viewModel.tasks.first(where: { $0.id == taskId }) {
                var updatedTask = task
                updatedTask.dueDate = today
                viewModel.updateTask(updatedTask)
                count += 1
            }
        }

        for taskId in taskIds {
            if let suggestion = assistantService.activeSuggestions.first(where: {
                $0.relatedTaskIds.contains(taskId)
            }) {
                assistantService.dismissSuggestion(suggestion)
            }
        }

        movedTasksCount = count
        showingMoveToTodayAlert = true
    }

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d"
        return formatter.string(from: Date())
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("오늘 \(todayDateString)")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Button(action: { isFocusMode.toggle() }) {
                        Image(systemName: "scope")
                            .font(.title2)
                            .foregroundColor(isFocusMode ? .blue : .gray.opacity(0.5))
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isFocusMode ? Color.blue.opacity(0.12) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(isFocusMode ? "포커스 모드 끄기" : "포커스 모드 켜기 (오늘 핵심 3개)")

                    if let furthestDays = furthestFutureDays, furthestDays > 0 {
                        Text("\(furthestDays)일 뒤를 살고 있어요! ✨")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.orange.opacity(0.15))
                            )
                    }
                }

                weekdayIndicator
            }
            Spacer()

            if totalTodayCount > 0 {
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 4) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("완료")
                                .font(.body)
                                .foregroundColor(.secondary)
                            Text("\(completedTodayCount)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }

                        Text("/")
                            .font(.title3)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("전체")
                                .font(.body)
                                .foregroundColor(.secondary)
                            Text("\(totalTodayCount)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                    }

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(todayCompletionPercentage)% 달성")
                            .font(.body)
                            .foregroundColor(todayCompletionPercentage == 100 ? .green : .blue)
                        if remainingTodayCount > 0 {
                            Text("남은 \(remainingTodayCount)개")
                                .font(.body)
                                .foregroundColor(.orange)
                        } else {
                            Text("모두 완료! 🎉")
                                .font(.body)
                                .foregroundColor(.green)
                        }
                    }
                }
            }

            Button(action: {
                showingNotificationPreview.toggle()
            }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: notificationService.isNotificationEnabled ? "bell.fill" : "bell.slash.fill")
                        .font(.title2)
                        .foregroundColor(notificationService.isNotificationEnabled ? .blue : .gray)

                    if notificationService.isNotificationEnabled && tasksNeedingAttentionCount > 0 {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Text("\(min(tasksNeedingAttentionCount, 9))")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 8, y: -8)
                    }
                }
            }
            .buttonStyle(.plain)
            .help("알림 미리보기")
            .popover(isPresented: $showingNotificationPreview, arrowEdge: .bottom) {
                NotificationPreviewView()
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
    }

    private var tasksNeedingAttentionCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        var count = 0

        for task in viewModel.tasks where !task.isCompleted {
            if task.effectiveStartDate < today && task.isNotStarted {
                count += 1
                continue
            }

            if calendar.isDate(task.effectiveStartDate, inSameDayAs: today) && !task.isCompleted {
                count += 1
                continue
            }

            if calendar.isDate(task.dueDate, inSameDayAs: tomorrow) && !task.isCompleted {
                count += 1
                continue
            }

            if task.isPreparation && calendar.isDate(task.effectiveStartDate, inSameDayAs: today) && !task.isCompleted {
                count += 1
                continue
            }
        }

        count += assistantService.activeSuggestions.count

        return count
    }

    private var furthestFutureDays: Int? {
        guard !viewModel.todayTasks.isEmpty else { return nil }

        var maxDays = 0

        for task in viewModel.todayTasks {
            if task.isPreparation {
                if let daysUntilTarget = task.daysUntilTarget, daysUntilTarget > maxDays {
                    maxDays = daysUntilTarget
                }
            } else if !task.isPreparation {
                if task.daysUntilDue > maxDays {
                    maxDays = task.daysUntilDue
                }
            }
        }

        return maxDays > 0 ? maxDays : nil
    }

    private var completedTodayCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return viewModel.todayTasks.filter { task in
            task.isCompleted && calendar.startOfDay(for: task.dueDate) >= today
        }.count
    }

    private var totalTodayCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return viewModel.todayTasks.filter { task in
            !task.isCompleted || calendar.startOfDay(for: task.dueDate) >= today
        }.count
    }

    private var remainingTodayCount: Int {
        totalTodayCount - completedTodayCount
    }

    private var todayCompletionPercentage: Int {
        guard totalTodayCount > 0 else { return 0 }
        return Int(Double(completedTodayCount) / Double(totalTodayCount) * 100)
    }

    private var timeBlockStatusView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("오늘의 시간 블록")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.formatMinutes(viewModel.todayUsedMinutes)) / \(viewModel.formatMinutes(viewModel.todayAvailableMinutes))")
                    .font(.subheadline)
                    .foregroundColor(viewModel.isTodayOverCapacity ? .red : .secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 8)
                        .fill(progressColor)
                        .frame(width: min(geometry.size.width * viewModel.todayUtilization, geometry.size.width))
                }
            }
            .frame(height: 12)

            HStack {
                if viewModel.isTodayOverCapacity {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("\(viewModel.formatMinutes(-viewModel.todayRemainingMinutes)) 초과")
                        .foregroundColor(.red)
                } else if viewModel.todayRemainingMinutes > 0 {
                    Image(systemName: "clock")
                        .foregroundColor(.green)
                    Text("\(viewModel.formatMinutes(viewModel.todayRemainingMinutes)) 여유")
                        .foregroundColor(.green)
                }
                Spacer()
            }
            .font(.callout)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private var progressColor: Color {
        if viewModel.todayUtilization > 1.0 {
            return .red
        } else if viewModel.todayUtilization > 0.8 {
            return .orange
        } else {
            return .blue
        }
    }

    // MARK: - Future Preparation Gauge

    private var futurePreparationGaugeView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("미래 준비 목표")
                        .font(.headline)
                    Text("얼마나 미리 준비하고 있나요?")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("현재")
                            .font(.callout)
                            .foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            Text("\(currentDaysAhead)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(gaugeColor)
                            Text("일 뒤")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("목표")
                            .font(.callout)
                            .foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            Text("\(viewModel.targetDaysAhead)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            Text("일 뒤")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.15))

                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: geometry.size.width * targetProgress)

                        RoundedRectangle(cornerRadius: 12)
                            .fill(gaugeColor)
                            .frame(width: geometry.size.width * currentProgress)

                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: 3)
                            .offset(x: geometry.size.width * targetProgress - 1.5)
                    }
                }
                .frame(height: 24)

                HStack {
                    Text(motivationalMessage)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(gaugeColor)

                    Spacer()

                    if currentDaysAhead < viewModel.targetDaysAhead {
                        Text("목표까지 \(viewModel.targetDaysAhead - currentDaysAhead)일")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    } else if currentDaysAhead == viewModel.targetDaysAhead {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("목표 달성!")
                                .font(.callout)
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("목표 초과 달성!")
                                .font(.callout)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    gaugeColor.opacity(0.05),
                    gaugeColor.opacity(0.02)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(gaugeColor.opacity(0.2), lineWidth: 1)
        )
    }

    private var currentDaysAhead: Int {
        furthestFutureDays ?? 0
    }

    private var currentProgress: CGFloat {
        let maxDays = max(viewModel.targetDaysAhead, currentDaysAhead)
        guard maxDays > 0 else { return 0 }
        return CGFloat(currentDaysAhead) / CGFloat(Double(maxDays) * 1.2)
    }

    private var targetProgress: CGFloat {
        let maxDays = max(viewModel.targetDaysAhead, currentDaysAhead)
        guard maxDays > 0 else { return 0 }
        return CGFloat(viewModel.targetDaysAhead) / CGFloat(Double(maxDays) * 1.2)
    }

    private var gaugeColor: Color {
        let progress = Double(currentDaysAhead) / Double(viewModel.targetDaysAhead)

        if currentDaysAhead >= viewModel.targetDaysAhead {
            return .green
        } else if progress >= 0.7 {
            return .orange
        } else {
            return .red
        }
    }

    private var motivationalMessage: String {
        let progress = Double(currentDaysAhead) / Double(viewModel.targetDaysAhead)

        if currentDaysAhead >= viewModel.targetDaysAhead {
            return "완벽해요! 계속 유지하세요! 🎉"
        } else if progress >= 0.7 {
            return "조금만 더! 거의 다 왔어요 💪"
        } else if progress >= 0.4 {
            return "좋은 시작이에요! 꾸준히 가세요 🚀"
        } else if currentDaysAhead > 0 {
            return "시작했어요! 조금씩 늘려가세요 📈"
        } else {
            return "\(viewModel.targetDaysAhead)일 뒤를 살기 위해 노력해보세요! 🎯"
        }
    }

    private func taskSection(title: String, subtitle: String, tasks: [Task]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                Spacer()

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

                    if viewModel.todayTasks.contains(where: { $0.manualPriority != nil }) {
                        Button(action: {
                            viewModel.resetManualPriorities()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                Text("자동 정렬")
                            }
                        }
                        .buttonStyle(.bordered)
                    }

                    if isEditMode && !selectedTasks.isEmpty {
                        Button(action: {
                            showingCalendarAddConfirmation = true
                        }) {
                            HStack(spacing: 4) {
                                if isAddingToCalendar {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "calendar.badge.plus")
                                    Text("\(selectedTasks.count)개 추가")
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .disabled(isAddingToCalendar)

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
                                .font(.title3)
                        }
                        .buttonStyle(.plain)

                        TaskRowView(task: task)
                    }
                } else {
                    TaskRowView(task: task)
                    .opacity(draggingTaskId == task.id ? 0.4 : 1.0)
                    .onDrag {
                        draggingTaskId = task.id
                        return NSItemProvider(object: task.id.uuidString as NSString)
                    }
                    .onDrop(
                        of: [UTType.plainText],
                        delegate: TodayTaskDropDelegate(
                            targetId: task.id,
                            orderedIds: tasks.map { $0.id },
                            draggingId: $draggingTaskId,
                            onMove: { draggedId, targetId, orderedIds in
                                viewModel.moveTodayTask(
                                    draggedId: draggedId,
                                    targetId: targetId,
                                    orderedIds: orderedIds
                                )
                            }
                        )
                    )
                }
            }
        }
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
        .confirmationDialog(
            "선택한 \(selectedTasks.count)개의 태스크를 캘린더에 추가하시겠습니까?",
            isPresented: $showingCalendarAddConfirmation,
            titleVisibility: .visible
        ) {
            Button("캘린더에 추가") {
                _Concurrency.Task {
                    await addSelectedTasksToCalendar()
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("태스크의 마감일과 예상 소요 시간을 기반으로 캘린더 이벤트가 생성됩니다.")
        }
    }

    private var weekdayIndicator: some View {
        let weekdays = ["월", "화", "수", "목", "금", "토", "일"]
        let calendar = Calendar.current
        let today = Date()
        let todayWeekday = calendar.component(.weekday, from: today)
        let todayIndex = (todayWeekday + 5) % 7

        return HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { index in
                Text(weekdays[index])
                    .font(.subheadline)
                    .fontWeight(index == todayIndex ? .bold : .regular)
                    .foregroundColor(index == todayIndex ? .white : .secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(index == todayIndex ? Color.blue : Color.clear)
                    )
            }
        }
    }

    // MARK: - MIT 핀 섹션

    private var mitPinnedSection: some View {
        let allMIT = viewModel.tasks.filter { $0.isMIT }
        let completedCount = allMIT.filter { $0.isCompleted }.count
        let totalCount = allMIT.count

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("오늘의 핵심")
                    .font(.headline)
                Spacer()
                Text("\(completedCount)/\(totalCount) 완료")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            ForEach(allMIT) { task in
                HStack(spacing: 10) {
                    Button(action: { viewModel.toggleTaskCompletion(task) }) {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.body)
                            .foregroundColor(task.isCompleted ? .green : .gray)
                    }
                    .buttonStyle(.plain)

                    Text(task.title)
                        .font(.body)
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)

                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color.yellow.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 52))
                .foregroundColor(.green)
            Text("오늘 할 일이 없습니다")
                .font(.headline)
            Text("새 할 일을 추가하거나 미리 준비할 일을 확인하세요")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }

    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                withAnimation {
                    isRecommendationExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: isRecommendationExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.yellow)
                        .font(.callout)
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text("여유 시간에 미리 해두면 좋을 일")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(viewModel.recommendPreparableTasks().count)개")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isRecommendationExpanded {
                ForEach(viewModel.recommendPreparableTasks()) { task in
                    HStack(spacing: 12) {
                        TaskRowView(task: task)

                        Text(daysUntilText(task.dueDate))
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)

                        Button("오늘 하기") {
                            var updatedTask = task
                            updatedTask.dueDate = Calendar.current.startOfDay(for: Date())
                            viewModel.updateTask(updatedTask)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
    }

    private func daysUntilText(_ date: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let targetDate = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: today, to: targetDate).day ?? 0

        if days == 1 {
            return "내일"
        } else if days == 2 {
            return "모레"
        } else {
            return "\(days)일 뒤"
        }
    }

    private var reallocationSuggestionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.orange)
                Text("용량 초과 - 재배치 제안")
                    .font(.headline)
            }

            Text("다음 태스크를 다른 날로 옮기면 오늘 부담을 줄일 수 있어요")
                .font(.callout)
                .foregroundColor(.secondary)

            ForEach(viewModel.suggestReallocation(), id: \.task.id) { suggestion in
                HStack {
                    Text(suggestion.task.title)
                    Spacer()
                    Text("→ \(suggestion.suggestedDate, style: .date)")
                        .foregroundColor(.secondary)
                    Button("옮기기") {
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    private var futurePreparationSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.blue)
                    .font(.title3)
                Text("오늘 하는 일이 준비하는 미래")
                    .font(.headline)
            }

            let todayDueTasks = viewModel.todayTasks.filter { !$0.isPreparation && $0.daysUntilDue == 0 }
            if !todayDueTasks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.circle.fill")
                            .foregroundColor(.red)
                        Text("오늘 마감")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                        Text("(\(todayDueTasks.count)개)")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    ForEach(todayDueTasks.prefix(3)) { task in
                        Text("⚡ \(task.title)")
                            .font(.callout)
                            .foregroundColor(.red)
                    }
                }
                .padding(12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }

            let preparationTasks = viewModel.todayTasks.filter { $0.isPreparation }
            if !preparationTasks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(.orange)
                        Text("미래 준비 중")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("(\(preparationTasks.count)개)")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }

                    let grouped = Dictionary(grouping: preparationTasks) { task -> Int in
                        task.daysUntilTarget ?? 999
                    }.sorted { $0.key < $1.key }

                    ForEach(grouped.prefix(5), id: \.key) { days, tasks in
                        HStack(spacing: 6) {
                            if days == 0 {
                                Text("🎯 오늘")
                            } else if days == 1 {
                                Text("📅 내일")
                            } else if days > 0 {
                                Text("🗓️ \(days)일 뒤")
                            } else {
                                Text("⏰ 지남")
                            }

                            Text("를 위한 준비 \(tasks.count)개")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                        .font(.callout)
                        .foregroundColor(days <= 1 ? .orange : .blue)
                    }
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            let upcomingMainTasks = viewModel.todayTasks.filter { !$0.isPreparation && $0.daysUntilDue > 0 }
            if !upcomingMainTasks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.blue)
                        Text("다가오는 마감")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("(\(upcomingMainTasks.count)개)")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }

                    ForEach(upcomingMainTasks.sorted { $0.daysUntilDue < $1.daysUntilDue }.prefix(3)) { task in
                        HStack(spacing: 6) {
                            let emoji = task.daysUntilDue == 1 ? "⏰" : "📌"
                            Text("\(emoji) \(task.dDayWithDate)")
                                .foregroundColor(task.daysUntilDue == 1 ? .orange : .blue)
                            Text(task.title)
                                .lineLimit(1)
                        }
                        .font(.callout)
                    }
                }
                .padding(12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func futureFeedbackSection(futurePreps: [(preparationTask: Task, mainTask: Task)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                Text("오늘 준비 완료!")
                    .font(.headline)
            }

            Text("오늘 완료한 준비로 미래가 준비되었어요 ✨")
                .font(.callout)
                .foregroundColor(.secondary)

            ForEach(futurePreps, id: \.preparationTask.id) { item in
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.green)
                        .font(.callout)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.preparationTask.title)
                            .font(.subheadline)
                            .strikethrough()

                        if let daysText = item.preparationTask.daysUntilTargetText {
                            HStack(spacing: 4) {
                                Text("\(daysText)")
                                    .fontWeight(.semibold)
                                Text("'\(item.mainTask.title)' 준비됨")
                            }
                            .font(.callout)
                            .foregroundColor(.green)
                        }
                    }
                }
                .padding(8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding(16)
        .background(Color.green.opacity(0.05))
        .cornerRadius(12)
    }

    // MARK: - 포커스 모드 섹션

    private var focusModeSection: some View {
        let completedCount = focusTasks.filter { $0.isCompleted }.count
        let totalCount = focusTasks.count
        let remainingCount = totalCount - completedCount
        let progress = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0.0
        let allCompleted = totalCount > 0 && remainingCount == 0

        return VStack(alignment: .leading, spacing: 20) {

            // 헤더: 타이틀 + 원형 진행 링
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "scope")
                            .font(.title2)
                            .foregroundColor(.blue)
                        Text("오늘의 포커스")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    Text(allCompleted ? "모두 완료했어요! 🎉" : "이 \(remainingCount)개만 끝내면 됩니다")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                Spacer()
                // 원형 진행 링
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.15), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(
                            allCompleted ? Color.green : Color.blue,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.4), value: progress)
                    VStack(spacing: 0) {
                        Text("\(completedCount)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(allCompleted ? .green : .blue)
                        Text("/\(totalCount)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 54, height: 54)
            }

            Divider()

            if focusTasks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.green)
                    Text("오늘 할 일이 없습니다!")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
            } else {
                // 번호 배지 + 태스크 목록
                VStack(spacing: 10) {
                    ForEach(Array(focusTasks.enumerated()), id: \.element.id) { index, task in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.callout)
                                .fontWeight(.bold)
                                .foregroundColor(task.isCompleted ? .secondary : .white)
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(task.isCompleted ? Color.secondary.opacity(0.2) : Color.blue)
                                )
                                .padding(.top, 10)
                            TaskRowView(task: task)
                        }
                    }
                }

                // 진행률 바
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.15))
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    allCompleted
                                        ? LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                                        : LinearGradient(colors: [.blue, .blue.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: geometry.size.width * CGFloat(progress))
                                .animation(.easeInOut(duration: 0.4), value: progress)
                        }
                    }
                    .frame(height: 12)

                    HStack {
                        Text("\(Int(progress * 100))% 완료")
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundColor(allCompleted ? .green : .blue)
                        Spacer()
                        if !allCompleted {
                            Text("\(remainingCount)개 남음")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // 동기부여 메시지 / 완료 버튼
                if allCompleted {
                    HStack {
                        Spacer()
                        Button(action: { isFocusMode = false }) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("포커스 모드 끄기")
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.green)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .font(.callout)
                            .foregroundColor(.blue)
                        Text(remainingCount == 1 ? "마지막 1개! 거의 다 왔어요!" : "집중해서 \(remainingCount)개 끝내봐요!")
                            .font(.callout)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(8)
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.07), Color.blue.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.4), lineWidth: 1.5)
        )
    }

    private func addSelectedTasksToCalendar() async {
        isAddingToCalendar = true
        defer { isAddingToCalendar = false }

        let tasksToAdd = viewModel.todayTasks.filter { selectedTasks.contains($0.id) }

        var events: [(title: String, startDate: Date, endDate: Date, notes: String?)] = []

        for task in tasksToAdd {
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: task.dueDate)
            components.hour = 14
            components.minute = 0

            guard let startDate = calendar.date(from: components) else { continue }
            let endDate = calendar.date(byAdding: .minute, value: task.estimatedMinutes, to: startDate) ?? startDate

            let notes = """
            예상 소요 시간: \(task.estimatedTimeFormatted)
            우선순위: \(task.priority.rawValue)
            \(task.description.isEmpty ? "" : "\n\(task.description)")
            """

            events.append((
                title: task.title,
                startDate: startDate,
                endDate: endDate,
                notes: notes
            ))
        }

        let calendarService = calendarViewModel.calendarService
        let result = await calendarService.createEvents(events)

        await MainActor.run {
            if result.success > 0 {
            }
            if result.failure > 0 {
            }

            selectedTasks.removeAll()
            isEditMode = false
        }
    }

    private func deleteSelectedTasks() {
        let tasksToDelete = viewModel.todayTasks.filter { selectedTasks.contains($0.id) }
        viewModel.deleteTasks(tasksToDelete)
        selectedTasks.removeAll()
        isEditMode = false
    }
}
