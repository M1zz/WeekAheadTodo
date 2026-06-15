import WeekAheadShared
import SwiftUI

// MARK: - Time Based Week Calendar (Google Calendar Style)

// 하위 할 일 시트 표시용 식별자
struct SubtaskSelection: Identifiable {
    let id: UUID          // subtaskId
    let parentTaskId: UUID
}

struct TimeBasedWeekCalendar: View {
    let weekDates: [Date]
    let tasksForDate: (Date) -> [Task]

    @EnvironmentObject var viewModel: TaskViewModel
    @State private var showingAddTask = false
    @State private var showingEditTask: Task?
    @State private var showingSubtask: SubtaskSelection?
    @State private var newTaskDate: Date = Date()
    @State private var newTaskTime: Date = Date()
    @State private var hoveredTaskId: UUID?
    @State private var currentTimeOffset: CGFloat = 0
    @State private var timer: Timer?
    @State private var scrollProxy: ScrollViewProxy?

    private let calendar = Calendar.current
    private let slotHeight: CGFloat = 30  // 15분당 30px (1시간 = 120px)

    private var timeSlots: [Double] {
        let start = Double(viewModel.calendarStartHour)
        let end = Double(viewModel.calendarEndHour) + 0.75
        return stride(from: start, through: end, by: 0.25).map { $0 }
    }

    private var totalHeight: CGFloat { CGFloat(timeSlots.count) * slotHeight }

    var body: some View {
        VStack(spacing: 0) {
            // 날짜 헤더 (고정)
            dateHeader

            Divider()

            // 스크롤 가능한 시간 그리드
            ScrollViewReader { proxy in
                ScrollView {
                    HStack(alignment: .top, spacing: 0) {
                        // 시간 레이블
                        timeLabels

                        // 날짜별 컬럼
                        dayColumns
                    }
                    .id("calendarContent")
                }
                .onAppear {
                    scrollProxy = proxy
                    updateCurrentTimeLine()
                    scrollToCurrentTime(proxy: proxy)

                    timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                        updateCurrentTimeLine()
                    }
                }
                .onDisappear {
                    timer?.invalidate()
                }
            }
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(initialDate: newTaskDate, initialTime: newTaskTime)
                .environmentObject(viewModel)
        }
        .sheet(item: $showingEditTask) { task in
            EditTaskView(task: task)
                .environmentObject(viewModel)
        }
        .sheet(item: $showingSubtask) { selection in
            SubtaskDetailSheet(
                parentTaskId: selection.parentTaskId,
                subtaskId: selection.id
            )
            .environmentObject(viewModel)
        }
    }

    // MARK: - Date Header

    private var dateHeader: some View {
        HStack(spacing: 0) {
            // 시간 레이블 공간
            Text("GMT+9")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 55)
                .opacity(0.5)

            // 날짜 헤더들
            HStack(spacing: 0) {
                ForEach(weekDates, id: \.self) { date in
                    VStack(spacing: 3) {
                        Text(dayOfWeekString(date))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(isToday(date) ? .blue : .secondary)
                            .textCase(.uppercase)

                        ZStack {
                            if isToday(date) {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 28, height: 28)
                            }
                            Text(dayString(date))
                                .font(.system(size: 15, weight: isToday(date) ? .semibold : .regular))
                                .foregroundColor(isToday(date) ? .white : .primary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Time Labels

    private var timeLabels: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(Array(stride(from: viewModel.calendarStartHour, through: viewModel.calendarEndHour, by: 1)), id: \.self) { hour in
                let isLast = (hour == viewModel.calendarEndHour)

                Text(String(format: "%02d:00", hour))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.trailing, 4)
                    .offset(y: -8)
                    .frame(width: 50, height: isLast ? slotHeight : slotHeight * 4, alignment: .topTrailing)
                    .id("time-\(hour)")
            }
        }
        .frame(width: 55)
    }

    // MARK: - Day Columns

    private var dayColumns: some View {
        GeometryReader { geometry in
            // 내부 GeometryReader 중첩 없이 외부 너비로 직접 계산
            let dividerCount = CGFloat(max(weekDates.count - 1, 0))
            let columnWidth = (geometry.size.width - dividerCount) / CGFloat(max(weekDates.count, 1))

            HStack(spacing: 0) {
                ForEach(weekDates, id: \.self) { date in
                    ZStack(alignment: .topLeading) {
                        // 배경 + 클릭 영역
                        dayColumnBackground(date: date, columnWidth: columnWidth)

                        // 시간 그리드 선
                        timeGridLines

                        // 태스크 배치
                        TaskLayoutView(
                            tasks: tasksForDate(date),
                            hourHeight: slotHeight,
                            dayColumnWidth: columnWidth,
                            date: date,
                            hoveredTaskId: $hoveredTaskId,
                            onTaskTap: { task in
                                // 하위 할 일(synthetic Task)은 하위 할 일 전용 시트 열기
                                if let parentId = task.parentTaskId,
                                   !viewModel.tasks.contains(where: { $0.id == task.id }) {
                                    showingSubtask = SubtaskSelection(id: task.id, parentTaskId: parentId)
                                } else {
                                    showingEditTask = task
                                }
                            }
                        )

                        // 현재 시간 표시
                        if isToday(date) {
                            currentTimeIndicator
                        }
                    }
                    .frame(width: columnWidth, height: totalHeight)
                    .onDrop(of: [.text], delegate: TaskDropDelegate(
                        date: date,
                        slotHeight: slotHeight,
                        viewModel: viewModel
                    ))

                    if date != weekDates.last {
                        Divider()
                    }
                }
            }
        }
        .frame(height: totalHeight)
    }

    // MARK: - Day Column Background (Clickable)

    private func dayColumnBackground(date: Date, columnWidth: CGFloat) -> some View {
        Rectangle()
            .fill(Color(NSColor.controlBackgroundColor))
            .frame(height: totalHeight)
            .contentShape(Rectangle())
            .onTapGesture { location in
                // 클릭한 위치에서 시간 계산
                let slotIndex = Int(floor(location.y / slotHeight))
                let totalMinutesFromStart = slotIndex * 15
                let hour = viewModel.calendarStartHour + (totalMinutesFromStart / 60)
                let minute = totalMinutesFromStart % 60

                // 새 태스크 날짜/시간 설정
                var components = calendar.dateComponents([.year, .month, .day], from: date)
                components.hour = hour
                components.minute = minute

                if let taskTime = calendar.date(from: components) {
                    newTaskDate = date
                    newTaskTime = taskTime
                    showingAddTask = true
                }
            }
    }

    // MARK: - Time Grid Lines

    private var timeGridLines: some View {
        Canvas { context, size in
            for (index, slot) in timeSlots.enumerated() {
                let remainder = slot.truncatingRemainder(dividingBy: 1.0)
                let isHour = remainder == 0.0
                let isHalfHour = abs(remainder - 0.5) < 0.01
                let y = CGFloat(index) * slotHeight

                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))

                if isHour {
                    context.stroke(path, with: .color(Color.gray.opacity(0.25)), lineWidth: 1.0)
                } else if isHalfHour {
                    context.stroke(path, with: .color(Color.gray.opacity(0.12)), lineWidth: 0.5)
                } else {
                    context.stroke(path, with: .color(Color.gray.opacity(0.06)), lineWidth: 0.5)
                }
            }
        }
        .frame(height: totalHeight)
        .allowsHitTesting(false)
    }

    // MARK: - Current Time Indicator

    private var currentTimeIndicator: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color.red)
                .frame(height: 2)
                .offset(y: currentTimeOffset)

            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .offset(x: -6, y: currentTimeOffset - 5)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Helper Functions

    private func updateCurrentTimeLine() {
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)

        let startHour = viewModel.calendarStartHour
        let minutesFromStart = (hour - startHour) * 60 + minute
        currentTimeOffset = (CGFloat(minutesFromStart) / 15.0) * slotHeight
    }

    private func scrollToCurrentTime(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let now = Date()
            let hour = calendar.component(.hour, from: now)
            let targetHour = max(viewModel.calendarStartHour, hour - 1)
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo("time-\(targetHour)", anchor: .top)
            }
        }
    }

    private func dayOfWeekString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    private func dayString(_ date: Date) -> String {
        let day = calendar.component(.day, from: date)
        return "\(day)"
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }
}

// MARK: - Task Layout Info

struct TaskLayoutInfo {
    let task: Task
    let column: Int
    let totalColumns: Int
    /// 실제 표시에 사용할 시작 시간 (미지정 태스크는 순차 배치된 가상 시간)
    let startTime: Date

    static func calculateLayout(for tasks: [Task]) -> [TaskLayoutInfo] {
        guard !tasks.isEmpty else { return [] }

        let calendar = Calendar.current

        // targetDate가 있는 태스크(시간 지정)와 없는 태스크(미지정) 분리
        let scheduledTasks = tasks.filter { $0.targetDate != nil }
        let unscheduledTasks = tasks.filter { $0.targetDate == nil }

        var layoutInfos: [TaskLayoutInfo] = []

        // 시간 지정 태스크: 겹침 감지 후 다중 컬럼 배치
        var columns: [[Task]] = []
        let sortedScheduled = scheduledTasks.sorted { $0.targetDate! < $1.targetDate! }

        for task in sortedScheduled {
            let taskStart = task.targetDate!
            let taskEnd = calendar.date(byAdding: .minute, value: task.estimatedMinutes, to: taskStart) ?? taskStart

            var placedInColumn = false
            for (columnIndex, column) in columns.enumerated() {
                let canPlace = column.allSatisfy { existingTask in
                    let existingStart = existingTask.targetDate!
                    let existingEnd = calendar.date(byAdding: .minute, value: existingTask.estimatedMinutes, to: existingStart) ?? existingStart
                    return taskEnd <= existingStart || taskStart >= existingEnd
                }
                if canPlace {
                    columns[columnIndex].append(task)
                    placedInColumn = true
                    break
                }
            }
            if !placedInColumn {
                columns.append([task])
            }
        }

        let totalColumns = max(columns.count, 1)
        for (columnIndex, column) in columns.enumerated() {
            for task in column {
                layoutInfos.append(TaskLayoutInfo(
                    task: task,
                    column: columnIndex,
                    totalColumns: totalColumns,
                    startTime: task.targetDate!
                ))
            }
        }

        // 미지정 태스크: 겹침 감지 없이 9시부터 순차 세로 배치 (전체 너비 사용)
        var accumulatedMinutes = 0
        for task in unscheduledTasks {
            var components = calendar.dateComponents([.year, .month, .day], from: task.dueDate)
            let totalMinutesFrom9 = accumulatedMinutes
            components.hour = 9 + totalMinutesFrom9 / 60
            components.minute = totalMinutesFrom9 % 60
            let sequentialStart = calendar.date(from: components) ?? task.dueDate

            layoutInfos.append(TaskLayoutInfo(
                task: task,
                column: 0,
                totalColumns: 1,
                startTime: sequentialStart
            ))
            accumulatedMinutes += task.estimatedMinutes
        }

        return layoutInfos
    }
}

// MARK: - Task Layout View

struct TaskLayoutView: View {
    let tasks: [Task]
    let hourHeight: CGFloat
    let dayColumnWidth: CGFloat
    let date: Date
    @Binding var hoveredTaskId: UUID?
    let onTaskTap: (Task) -> Void

    @EnvironmentObject var viewModel: TaskViewModel
    private let calendar = Calendar.current

    var body: some View {
        let layoutInfos = TaskLayoutInfo.calculateLayout(for: tasks)

        ZStack(alignment: .topLeading) {
            ForEach(layoutInfos, id: \.task.id) { layoutInfo in
                TaskTimeBlock(
                    task: layoutInfo.task,
                    startTime: layoutInfo.startTime,
                    hourHeight: hourHeight,
                    column: layoutInfo.column,
                    totalColumns: layoutInfo.totalColumns,
                    dayColumnWidth: dayColumnWidth,
                    isHovered: hoveredTaskId == layoutInfo.task.id,
                    onTap: { onTaskTap(layoutInfo.task) },
                    onToggleComplete: {
                        // 하위 할 일(synthetic Task)이면 subtask 토글, 아니면 일반 토글
                        if let parentId = layoutInfo.task.parentTaskId,
                           viewModel.tasks.contains(where: { $0.id == parentId }),
                           !viewModel.tasks.contains(where: { $0.id == layoutInfo.task.id }) {
                            viewModel.toggleSubtaskCompletion(taskId: parentId, subtaskId: layoutInfo.task.id)
                        } else {
                            viewModel.toggleTaskCompletion(layoutInfo.task)
                        }
                    },
                    onHover: { isHovered in
                        hoveredTaskId = isHovered ? layoutInfo.task.id : nil
                    }
                )
            }

            // 드래그 프리뷰
            if let preview = viewModel.dragPreview,
               calendar.isDate(preview.targetDate, inSameDayAs: date) {
                let previewTask = createPreviewTask(from: preview)
                let allTasksWithPreview = tasks.filter { $0.id != preview.taskId } + [previewTask]
                let previewLayoutInfos = TaskLayoutInfo.calculateLayout(for: allTasksWithPreview)

                if let previewLayout = previewLayoutInfos.first(where: { $0.task.id == preview.taskId }) {
                    DragPreviewBlock(
                        preview: preview,
                        hourHeight: hourHeight,
                        column: previewLayout.column,
                        totalColumns: previewLayout.totalColumns,
                        dayColumnWidth: dayColumnWidth,
                        calendarStartHour: viewModel.calendarStartHour
                    )
                }
            }
        }
    }

    private func createPreviewTask(from preview: DragPreviewInfo) -> Task {
        var task = Task(
            id: preview.taskId,
            title: "Preview",
            description: "",
            dueDate: preview.targetDate,
            estimatedMinutes: preview.estimatedMinutes
        )
        task.targetDate = preview.targetDate
        return task
    }
}

// MARK: - Task Time Block

struct TaskTimeBlock: View {
    let task: Task
    let startTime: Date   // 실제 표시 시작 시간 (미지정 태스크는 순차 배치된 가상 시간)
    let hourHeight: CGFloat
    let column: Int
    let totalColumns: Int
    let dayColumnWidth: CGFloat
    let isHovered: Bool
    let onTap: () -> Void
    let onToggleComplete: () -> Void
    let onHover: (Bool) -> Void

    @EnvironmentObject var viewModel: TaskViewModel
    @State private var isResizing = false
    @State private var resizeStartY: CGFloat = 0
    @State private var originalMinutes: Int = 0

    private let calendar = Calendar.current
    private let resizeHandleHeight: CGFloat = 12

    /// 가상 하위 할 일 Task인지 확인 (실제 viewModel.tasks에 없는 synthetic Task)
    private var isSubtaskItem: Bool {
        guard task.parentTaskId != nil else { return false }
        return !viewModel.tasks.contains(where: { $0.id == task.id })
    }

    var body: some View {
        VStack(spacing: 0) {
            // 메인 영역 (하위 할 일은 드래그 비활성화)
            mainContent
                .frame(height: max(taskHeight - resizeHandleHeight, 20))
                .contentShape(Rectangle())
                .onTapGesture {
                    onTap()
                }
                .onDrag {
                    viewModel.currentDraggingTaskId = task.id
                    if isSubtaskItem {
                        viewModel.currentDraggingSubtaskParentId = task.parentTaskId
                    } else {
                        viewModel.currentDraggingSubtaskParentId = nil
                    }
                    return NSItemProvider(object: task.id.uuidString as NSString)
                }

            // 리사이즈 핸들 영역 (하위 할 일은 비활성화)
            if !isSubtaskItem {
                resizeHandle
                    .frame(height: min(resizeHandleHeight, taskHeight - 20))
            } else {
                Color.clear
                    .frame(height: min(resizeHandleHeight, taskHeight - 20))
            }
        }
        .frame(width: columnWidth, height: taskHeight)
        .background(taskColor.opacity(isSubtaskItem ? 0.7 : 1.0))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(taskBorderColor, lineWidth: isHovered ? 2 : 1)
        )
        .overlay(alignment: .leading) {
            // 하위 할 일 표시 인디케이터
            if isSubtaskItem {
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 3)
                    .padding(.vertical, 4)
            }
        }
        .shadow(color: isHovered ? Color.black.opacity(0.2) : Color.clear, radius: 4, x: 0, y: 2)
        .offset(x: columnOffset, y: taskOffset)
        .opacity(viewModel.currentDraggingTaskId == task.id ? 0.3 : 1.0)
        .onHover { hovering in
            onHover(hovering)
        }
    }

    // MARK: - Main Content (Draggable)

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                // 완료 체크박스 (호버 시에만 표시)
                if isHovered {
                    Button(action: onToggleComplete) {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                }

                Text(task.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(taskHeight > 40 ? 2 : 1)
                    .foregroundColor(.white)
            }

            if taskHeight > 35 {
                HStack(spacing: 6) {
                    Text(timeRangeString)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)

                    if !isSubtaskItem, let progressText = task.subtaskProgressText {
                        Text(progressText)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(task.allSubtasksCompleted ? 0.35 : 0.2))
                            .cornerRadius(4)
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Resize Handle

    private var resizeHandle: some View {
        ZStack {
            // 투명한 히트 영역
            Color.clear
                .contentShape(Rectangle())

            // 호버 시 리사이즈 핸들 표시
            if isHovered && taskHeight > 30 {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 30, height: 4)
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if !isResizing {
                        isResizing = true
                        resizeStartY = value.startLocation.y
                        originalMinutes = task.estimatedMinutes
                    }

                    let deltaY = value.location.y - resizeStartY
                    let deltaMinutes = Int(deltaY / hourHeight * 15)
                    let newMinutes = max(15, originalMinutes + deltaMinutes)

                    var updatedTask = task
                    updatedTask.estimatedMinutes = newMinutes
                    viewModel.updateTask(updatedTask)
                }
                .onEnded { _ in
                    isResizing = false
                }
        )
        .cursor(.resizeUpDown)
    }

    // MARK: - Computed Properties

    private var columnWidth: CGFloat {
        if totalColumns > 1 {
            let spacing: CGFloat = 2
            return (dayColumnWidth - CGFloat(totalColumns + 1) * spacing) / CGFloat(totalColumns)
        }
        return dayColumnWidth - 8
    }

    private var columnOffset: CGFloat {
        if totalColumns > 1 {
            let spacing: CGFloat = 2
            return spacing + CGFloat(column) * (columnWidth + spacing)
        }
        return 4
    }

    private var taskOffset: CGFloat {
        let hour = calendar.component(.hour, from: startTime)
        let minute = calendar.component(.minute, from: startTime)
        let startHour = viewModel.calendarStartHour
        let minutesFromStart = (hour - startHour) * 60 + minute
        let slotIndex = CGFloat(minutesFromStart) / 15.0
        return slotIndex * hourHeight + 1
    }

    private var taskHeight: CGFloat {
        let durationInMinutes = CGFloat(task.estimatedMinutes)
        return max((durationInMinutes / 15.0) * hourHeight - 2, 20)
    }

    private var taskColor: Color {
        if task.isCompleted {
            return Color(red: 0.46, green: 0.76, blue: 0.44)
        } else if task.isInProgress {
            return Color(red: 0.98, green: 0.76, blue: 0.18)
        } else if task.priority == .urgent {
            return Color(red: 0.91, green: 0.35, blue: 0.32)
        } else if task.priority == .high {
            return Color(red: 0.96, green: 0.65, blue: 0.26)
        } else {
            return Color(red: 0.26, green: 0.52, blue: 0.96)
        }
    }

    private var taskBorderColor: Color {
        if task.isCompleted {
            return Color(red: 0.36, green: 0.66, blue: 0.34)
        } else if task.isInProgress {
            return Color(red: 0.88, green: 0.66, blue: 0.08)
        } else if task.priority == .urgent {
            return Color(red: 0.81, green: 0.25, blue: 0.22)
        } else if task.priority == .high {
            return Color(red: 0.86, green: 0.55, blue: 0.16)
        } else {
            return Color(red: 0.16, green: 0.42, blue: 0.86)
        }
    }

    private var timeRangeString: String {
        let endDate = calendar.date(byAdding: .minute, value: task.estimatedMinutes, to: startTime) ?? startTime
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endDate))"
    }
}

// MARK: - Drag Preview Block

struct DragPreviewBlock: View {
    let preview: DragPreviewInfo
    let hourHeight: CGFloat
    let column: Int
    let totalColumns: Int
    let dayColumnWidth: CGFloat
    let calendarStartHour: Int

    private let calendar = Calendar.current

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.blue.opacity(0.2))

            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
        }
        .frame(width: columnWidth, height: previewHeight)
        .offset(x: columnOffset, y: previewOffset)
        .animation(.easeOut(duration: 0.1), value: previewOffset)
        .allowsHitTesting(false)
    }

    private var columnWidth: CGFloat {
        if totalColumns > 1 {
            let spacing: CGFloat = 2
            return (dayColumnWidth - CGFloat(totalColumns + 1) * spacing) / CGFloat(totalColumns)
        }
        return dayColumnWidth - 8
    }

    private var columnOffset: CGFloat {
        if totalColumns > 1 {
            let spacing: CGFloat = 2
            return spacing + CGFloat(column) * (columnWidth + spacing)
        }
        return 4
    }

    private var previewOffset: CGFloat {
        let hour = calendar.component(.hour, from: preview.targetDate)
        let minute = calendar.component(.minute, from: preview.targetDate)

        let minutesFromStart = (hour - calendarStartHour) * 60 + minute
        let slotIndex = CGFloat(minutesFromStart) / 15.0
        return slotIndex * hourHeight + 1
    }

    private var previewHeight: CGFloat {
        let durationInMinutes = CGFloat(preview.estimatedMinutes)
        return max((durationInMinutes / 15.0) * hourHeight - 2, 20)
    }
}

// MARK: - Task Drop Delegate

struct TaskDropDelegate: DropDelegate {
    let date: Date
    let slotHeight: CGFloat
    let viewModel: TaskViewModel

    private let calendar = Calendar.current

    func performDrop(info: DropInfo) -> Bool {
        // currentDraggingTaskId를 직접 사용해 동기적으로 처리 (비동기 loadItem 사용 시 드롭 후 순간 원위치 복귀 버그 발생)
        guard let taskId = viewModel.currentDraggingTaskId else {
            viewModel.dragPreview = nil
            viewModel.currentDraggingTaskId = nil
            viewModel.currentDraggingSubtaskParentId = nil
            return false
        }

        let dropY = info.location.y
        let slotIndex = Int(floor(dropY / slotHeight))

        let startHour = viewModel.calendarStartHour
        let totalMinutesFromStart = slotIndex * 15
        let hour = min(startHour + (totalMinutesFromStart / 60), 23)
        let minute = totalMinutesFromStart % 60

        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute

        guard let newTargetTime = calendar.date(from: components) else {
            viewModel.dragPreview = nil
            viewModel.currentDraggingTaskId = nil
            viewModel.currentDraggingSubtaskParentId = nil
            return false
        }

        // 하위 할 일 드롭 처리
        if let parentTaskId = viewModel.currentDraggingSubtaskParentId {
            viewModel.updateSubtaskSchedule(parentTaskId: parentTaskId, subtaskId: taskId, newDate: newTargetTime)
            viewModel.dragPreview = nil
            viewModel.currentDraggingTaskId = nil
            viewModel.currentDraggingSubtaskParentId = nil
            return true
        }

        // 일반 태스크 드롭 처리
        guard let task = viewModel.tasks.first(where: { $0.id == taskId }) else {
            viewModel.dragPreview = nil
            viewModel.currentDraggingTaskId = nil
            return false
        }

        var updatedTask = task
        updatedTask.targetDate = newTargetTime
        updatedTask.dueDate = date

        // 태스크 업데이트 후 드래그 상태 초기화 (즉시 반영)
        viewModel.updateTask(updatedTask)
        viewModel.dragPreview = nil
        viewModel.currentDraggingTaskId = nil

        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard let taskId = viewModel.currentDraggingTaskId else {
            return DropProposal(operation: .move)
        }
        // 하위 할 일인 경우 dragPreview는 부모 태스크 기준으로 표시 (또는 생략)
        guard viewModel.currentDraggingSubtaskParentId == nil,
              let task = viewModel.tasks.first(where: { $0.id == taskId }) else {
            return DropProposal(operation: .move)
        }

        let dropY = info.location.y
        let slotIndex = Int(floor(dropY / slotHeight))

        let startHour = viewModel.calendarStartHour
        let totalMinutesFromStart = slotIndex * 15
        let hour = min(startHour + (totalMinutesFromStart / 60), 23)
        let minute = totalMinutesFromStart % 60

        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute

        if let newTargetTime = calendar.date(from: components) {
            viewModel.dragPreview = DragPreviewInfo(
                taskId: taskId,
                targetDate: newTargetTime,
                estimatedMinutes: task.estimatedMinutes
            )
        }

        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        viewModel.dragPreview = nil
    }

    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.text])
    }
}

// MARK: - Subtask Detail Sheet

struct SubtaskDetailSheet: View {
    @EnvironmentObject var viewModel: TaskViewModel
    let parentTaskId: UUID
    let subtaskId: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""

    private var parentTask: Task? {
        viewModel.tasks.first(where: { $0.id == parentTaskId })
    }

    private var subtask: Subtask? {
        parentTask?.subtasks.first(where: { $0.id == subtaskId })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 헤더
            HStack {
                Text("하위 할 일")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button("닫기") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }

            // 완료 토글 + 제목
            HStack(spacing: 12) {
                Button(action: {
                    viewModel.toggleSubtaskCompletion(taskId: parentTaskId, subtaskId: subtaskId)
                }) {
                    Image(systemName: subtask?.isCompleted == true ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(subtask?.isCompleted == true ? .green : .gray)
                }
                .buttonStyle(.plain)

                TextField("하위 할 일 제목", text: $title)
                    .font(.body)
                    .textFieldStyle(.plain)
                    .onSubmit { saveTitle() }
            }

            // 상위 태스크 정보
            if let parent = parentTask {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.turn.up.left")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Text("상위 태스크: \(parent.title)")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Spacer()
                Button("저장") { saveTitle(); dismiss() }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 360, minHeight: 180)
        .onAppear {
            title = subtask?.title ?? ""
        }
    }

    private func saveTitle() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              var parentTask = parentTask,
              let idx = parentTask.subtasks.firstIndex(where: { $0.id == subtaskId }) else { return }
        parentTask.subtasks[idx].title = trimmed
        viewModel.updateTask(parentTask)
    }
}

// MARK: - Cursor Extension

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { hovering in
            if hovering {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
