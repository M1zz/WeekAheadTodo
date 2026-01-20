import SwiftUI

// MARK: - Time Based Week Calendar

struct TimeBasedWeekCalendar: View {
    let weekDates: [Date]
    let tasksForDate: (Date) -> [Task]

    @EnvironmentObject var viewModel: TaskViewModel
    private let calendar = Calendar.current
    // 30분 단위로 변경 (설정된 시간 범위만)
    private var timeSlots: [Double] {
        let start = Double(viewModel.calendarStartHour)
        let end = Double(viewModel.calendarEndHour) + 0.75
        return stride(from: start, through: end, by: 0.25).map { $0 }
    }

    private let slotHeight: CGFloat = 30  // 15분당 30px (1시간 = 120px)
    private var totalHeight: CGFloat { CGFloat(timeSlots.count) * slotHeight }

    @State private var currentTimeOffset: CGFloat = 0
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            // 날짜 헤더 (고정) - 구글 캘린더 스타일
            HStack(spacing: 0) {
                // 시간 레이블 공간
                Text("GMT+9")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .frame(width: 50)
                    .opacity(0.5)

                // 날짜 헤더들
                HStack(spacing: 0) {
                    ForEach(weekDates, id: \.self) { date in
                        VStack(spacing: 3) {
                            Text(dayOfWeekString(date))
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(isToday(date) ? .blue : .secondary)
                                .textCase(.uppercase)

                            ZStack {
                                if isToday(date) {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 28, height: 28)
                                }
                                Text(dayString(date))
                                    .font(.system(size: 17, weight: isToday(date) ? .semibold : .regular))
                                    .foregroundColor(isToday(date) ? .white : .primary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                }
            }
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // 스크롤 가능한 시간 그리드 (구글 캘린더 스타일)
            ScrollViewReader { proxy in
                ScrollView {
                    HStack(alignment: .top, spacing: 0) {
                        // 시간 레이블 (정각만 표시)
                        VStack(alignment: .trailing, spacing: 0) {
                            ForEach(Array(stride(from: viewModel.calendarStartHour, through: viewModel.calendarEndHour, by: 1)), id: \.self) { hour in
                                let isLast = (hour == viewModel.calendarEndHour)

                                Text(String(format: "%02d:00", hour))
                                    .font(.system(size: 17))
                                    .foregroundColor(.secondary)
                                    .padding(.trailing, 4)
                                    .offset(y: -6)
                                    .frame(width: 45, height: isLast ? slotHeight : slotHeight * 2, alignment: .topTrailing)
                                    .id("time-\(hour)")
                            }
                        }
                        .frame(width: 50)

                        // 날짜별 컬럼
                        GeometryReader { geometry in
                            HStack(spacing: 0) {
                                ForEach(weekDates, id: \.self) { date in
                                    GeometryReader { columnGeometry in
                                        ZStack(alignment: .topLeading) {
                                            // 배경 (흰색)
                                            Rectangle()
                                                .fill(Color(NSColor.controlBackgroundColor))
                                                .frame(height: totalHeight)

                                            // 30분 단위 구분선 (Canvas로 정확하게 그리기)
                                            Canvas { context, size in
                                                for (index, slot) in timeSlots.enumerated() {
                                                    let isHour = slot.truncatingRemainder(dividingBy: 1.0) == 0
                                                    let y = CGFloat(index) * slotHeight

                                                    var path = Path()
                                                    path.move(to: CGPoint(x: 0, y: y))
                                                    path.addLine(to: CGPoint(x: size.width, y: y))

                                                    context.stroke(
                                                        path,
                                                        with: .color(Color.gray.opacity(isHour ? 0.2 : 0.08)),
                                                        lineWidth: isHour ? 1 : 0.5
                                                    )
                                                }
                                            }
                                            .frame(height: totalHeight)

                                            // 태스크 배치
                                            TaskLayoutView(
                                                tasks: tasksForDate(date),
                                                hourHeight: slotHeight,  // 30분 단위 고정 높이
                                                dayColumnWidth: columnGeometry.size.width,
                                                date: date
                                            )

                                            // 현재 시간 표시 (구글 캘린더 스타일)
                                            if isToday(date) {
                                                ZStack(alignment: .leading) {
                                                    // 빨간 선
                                                    Rectangle()
                                                        .fill(Color.red)
                                                        .frame(height: 2)
                                                        .offset(y: currentTimeOffset)

                                                    // 빨간 원 (왼쪽)
                                                    Circle()
                                                        .fill(Color.red)
                                                        .frame(width: 12, height: 12)
                                                        .offset(x: -6, y: currentTimeOffset - 5)
                                                }
                                            }
                                        }
                                        .frame(height: totalHeight)
                                        .onDrop(of: [.text], delegate: TaskDropDelegate(
                                            date: date,
                                            slotHeight: slotHeight,
                                            viewModel: viewModel
                                        ))
                                    }

                                    if date != weekDates.last {
                                        Divider()
                                    }
                                }
                            }
                        }
                        .frame(height: totalHeight)
                    }
                }
                .onAppear {
                    updateCurrentTimeLine()
                    // 1분마다 현재 시간 선 업데이트
                    timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                        updateCurrentTimeLine()
                    }
                }
                .onDisappear {
                    timer?.invalidate()
                }
            }
        }
    }

    private func updateCurrentTimeLine() {
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)

        // 시작 시간을 기준으로 오프셋 계산 (15분 단위)
        let startHour = viewModel.calendarStartHour
        let minutesFromStart = (hour - startHour) * 60 + minute
        currentTimeOffset = (CGFloat(minutesFromStart) / 15.0) * slotHeight
    }

    private func timeSlotString(_ slot: Double) -> String {
        let hour = Int(slot)
        let minute = slot.truncatingRemainder(dividingBy: 1.0) == 0 ? 0 : 30
        return String(format: "%02d:%02d", hour, minute)
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

// MARK: - Task Layout Info (for overlap detection)

struct TaskLayoutInfo {
    let task: Task
    let column: Int
    let totalColumns: Int

    static func calculateLayout(for tasks: [Task]) -> [TaskLayoutInfo] {
        guard !tasks.isEmpty else { return [] }

        let calendar = Calendar.current

        // targetDate가 없는 경우 9:00로 기본 설정하는 헬퍼 함수
        func effectiveStartTime(for task: Task) -> Date {
            if let targetDate = task.targetDate {
                return targetDate
            } else {
                // targetDate가 없으면 dueDate의 9:00로 설정
                var components = calendar.dateComponents([.year, .month, .day], from: task.dueDate)
                components.hour = 9
                components.minute = 0
                return calendar.date(from: components) ?? task.dueDate
            }
        }

        // 시간순으로 정렬
        let sortedTasks = tasks.sorted { task1, task2 in
            let start1 = effectiveStartTime(for: task1)
            let start2 = effectiveStartTime(for: task2)
            return start1 < start2
        }

        var layoutInfos: [TaskLayoutInfo] = []
        var columns: [[Task]] = []

        for task in sortedTasks {
            let taskStart = effectiveStartTime(for: task)
            let taskEnd = calendar.date(byAdding: .minute, value: task.estimatedMinutes, to: taskStart) ?? taskStart

            // 겹치지 않는 컬럼 찾기
            var placedInColumn = false
            for (columnIndex, column) in columns.enumerated() {
                let canPlace = column.allSatisfy { existingTask in
                    let existingStart = effectiveStartTime(for: existingTask)
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

        // 각 태스크에 레이아웃 정보 할당
        let totalColumns = columns.count
        for (columnIndex, column) in columns.enumerated() {
            for task in column {
                layoutInfos.append(TaskLayoutInfo(task: task, column: columnIndex, totalColumns: totalColumns))
            }
        }

        return layoutInfos
    }
}

// MARK: - Task Layout View (Helper)

struct TaskLayoutView: View {
    let tasks: [Task]
    let hourHeight: CGFloat
    let dayColumnWidth: CGFloat
    let date: Date

    @EnvironmentObject var viewModel: TaskViewModel
    private let calendar = Calendar.current

    var body: some View {
        let layoutInfos = TaskLayoutInfo.calculateLayout(for: tasks)

        ZStack(alignment: .topLeading) {
            // 실제 태스크들
            ForEach(layoutInfos, id: \.task.id) { layoutInfo in
                TaskTimeBlock(
                    task: layoutInfo.task,
                    hourHeight: hourHeight,
                    column: layoutInfo.column,
                    totalColumns: layoutInfo.totalColumns,
                    dayColumnWidth: dayColumnWidth,
                    onTap: { viewModel.toggleTaskCompletion(layoutInfo.task) },
                    onDragEnd: { newDate, newTargetTime in
                        var updatedTask = layoutInfo.task
                        updatedTask.targetDate = newTargetTime
                        updatedTask.dueDate = newDate
                        viewModel.updateTask(updatedTask)
                    }
                )
            }

            // 드래그 프리뷰 (드래그 중인 위치에 항상 표시)
            if let preview = viewModel.dragPreview,
               calendar.isDate(preview.targetDate, inSameDayAs: date) {

                // 프리뷰도 실제 레이아웃 계산에 포함시켜 정확한 크기 표시
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

    // 프리뷰를 위한 임시 태스크 생성
    private func createPreviewTask(from preview: DragPreviewInfo) -> Task {
        var task = Task(
            id: preview.taskId,  // ID를 초기화 시 전달
            title: "Preview",
            description: "",
            dueDate: preview.targetDate,
            estimatedMinutes: preview.estimatedMinutes
        )
        task.targetDate = preview.targetDate
        return task
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
            // 반투명 배경
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.blue.opacity(0.2))

            // 점선 테두리
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(Color.blue, style: StrokeStyle(lineWidth: 2.5, dash: [6, 4]))
        }
        .frame(width: columnWidth, height: previewHeight)
        .offset(x: columnOffset, y: previewOffset)
        .animation(.easeOut(duration: 0.15), value: previewOffset)
    }

    // TaskTimeBlock과 동일한 너비 계산
    private var columnWidth: CGFloat {
        if totalColumns > 1 {
            let spacing: CGFloat = 3
            return (dayColumnWidth - CGFloat(totalColumns + 1) * spacing) / CGFloat(totalColumns)
        }
        return dayColumnWidth - 12  // 좌우 6px씩 여백
    }

    // TaskTimeBlock과 동일한 오프셋 계산
    private var columnOffset: CGFloat {
        if totalColumns > 1 {
            let spacing: CGFloat = 3
            return spacing + CGFloat(column) * (columnWidth + spacing)
        }
        return 6  // 왼쪽 6px 여백
    }

    private var previewOffset: CGFloat {
        let hour = calendar.component(.hour, from: preview.targetDate)
        let minute = calendar.component(.minute, from: preview.targetDate)

        let minutesFromStart = (hour - calendarStartHour) * 60 + minute
        let slotIndex = CGFloat(minutesFromStart) / 15.0
        return slotIndex * hourHeight + 2  // 위쪽 2px 여백
    }

    private var previewHeight: CGFloat {
        let durationInMinutes = CGFloat(preview.estimatedMinutes)
        return max((durationInMinutes / 15.0) * hourHeight - 4, 20)  // 최소 높이 20
    }
}

// MARK: - Task Drop Delegate

struct TaskDropDelegate: DropDelegate {
    let date: Date
    let slotHeight: CGFloat  // 15분 단위 높이
    let viewModel: TaskViewModel

    private let calendar = Calendar.current

    func performDrop(info: DropInfo) -> Bool {
        // 드래그 상태 초기화
        viewModel.dragPreview = nil
        viewModel.currentDraggingTaskId = nil

        guard let itemProvider = info.itemProviders(for: [.text]).first else {
            return false
        }

        itemProvider.loadItem(forTypeIdentifier: "public.text", options: nil) { (item, error) in
            guard let data = item as? Data,
                  let taskIdString = String(data: data, encoding: .utf8),
                  let taskId = UUID(uuidString: taskIdString) else {
                return
            }

            DispatchQueue.main.async {
                guard let task = viewModel.tasks.first(where: { $0.id == taskId }) else {
                    return
                }

                // Calculate new time based on drop position (15분 단위로 스냅)
                let dropY = info.location.y
                let slotIndex = Int(floor(dropY / slotHeight))  // 칸 안에 들어가도록 floor 사용

                // 슬롯 인덱스를 시간과 분으로 변환 (시작 시간 고려, 15분 단위)
                let startHour = viewModel.calendarStartHour
                let totalMinutesFromStart = slotIndex * 15
                let hour = min(startHour + (totalMinutesFromStart / 60), 23)
                let minute = totalMinutesFromStart % 60

                // Create new target time
                var components = calendar.dateComponents([.year, .month, .day], from: date)
                components.hour = hour
                components.minute = minute

                guard let newTargetTime = calendar.date(from: components) else {
                    return
                }

                // Update task
                var updatedTask = task
                updatedTask.targetDate = newTargetTime
                updatedTask.dueDate = date
                viewModel.updateTask(updatedTask)
            }
        }

        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        // currentDraggingTaskId를 사용하여 즉시 프리뷰 업데이트
        guard let taskId = viewModel.currentDraggingTaskId,
              let task = viewModel.tasks.first(where: { $0.id == taskId }) else {
            return DropProposal(operation: .move)
        }

        // Calculate preview position (15분 단위)
        let dropY = info.location.y
        let slotIndex = Int(floor(dropY / slotHeight))

        let startHour = viewModel.calendarStartHour
        let totalMinutesFromStart = slotIndex * 15  // 15분 단위
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
        // 드래그가 영역을 벗어나면 프리뷰 제거
        viewModel.dragPreview = nil
    }

    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.text])
    }
}

// MARK: - Task Time Block

struct TaskTimeBlock: View {
    let task: Task
    let hourHeight: CGFloat
    let column: Int
    let totalColumns: Int
    let dayColumnWidth: CGFloat  // 각 날짜 컬럼의 실제 너비
    let onTap: () -> Void
    let onDragEnd: (Date, Date) -> Void  // (newDate, newTargetTime)

    @EnvironmentObject var viewModel: TaskViewModel
    private let calendar = Calendar.current

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 17, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(.white)

                // 시작 - 종료 시간 표시
                Text(timeRangeString)
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(taskColor)
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(taskBorderColor, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .offset(x: columnOffset, y: taskOffset)
        .frame(width: columnWidth, height: taskHeight)
        .opacity(viewModel.currentDraggingTaskId == task.id ? 0.3 : 1.0)  // 드래그 중이면 거의 투명하게
        .onDrag {
            viewModel.currentDraggingTaskId = task.id  // 드래그 시작 시 태스크 ID 저장
            return NSItemProvider(object: task.id.uuidString as NSString)
        }
    }

    private var columnWidth: CGFloat {
        if totalColumns > 1 {
            // 여러 컬럼이 있으면 날짜 컬럼 너비를 나눔 (약간의 간격 포함)
            let spacing: CGFloat = 3
            return (dayColumnWidth - CGFloat(totalColumns + 1) * spacing) / CGFloat(totalColumns)
        }
        return dayColumnWidth - 12  // 좌우 6px씩 여백
    }

    private var columnOffset: CGFloat {
        if totalColumns > 1 {
            let spacing: CGFloat = 3
            return spacing + CGFloat(column) * (columnWidth + spacing)
        }
        return 6  // 왼쪽 6px 여백
    }

    private var taskOffset: CGFloat {
        let hour: Int
        let minute: Int

        if let targetDate = task.targetDate {
            hour = calendar.component(.hour, from: targetDate)
            minute = calendar.component(.minute, from: targetDate)
        } else {
            // 시간이 설정되지 않은 경우 9:00로 기본 설정
            hour = 9
            minute = 0
        }

        // 시작 시간을 기준으로 슬롯 인덱스 계산 (15분 단위)
        let startHour = viewModel.calendarStartHour
        let minutesFromStart = (hour - startHour) * 60 + minute
        let slotIndex = CGFloat(minutesFromStart) / 15.0
        return slotIndex * hourHeight + 2  // 위쪽 2px 여백
    }

    private var taskHeight: CGFloat {
        let durationInMinutes = CGFloat(task.estimatedMinutes)
        // hourHeight는 15분 단위 높이이므로 15분으로 나눔
        // 위아래 2px씩 여백을 위해 4px 빼기
        return max((durationInMinutes / 15.0) * hourHeight - 4, 20)  // 최소 높이 20
    }

    private var taskColor: Color {
        if task.isCompleted {
            return Color(red: 0.46, green: 0.76, blue: 0.44)  // 구글 캘린더 초록
        } else if task.isInProgress {
            return Color(red: 0.98, green: 0.76, blue: 0.18)  // 노란색 (진행 중)
        } else if task.priority == .urgent {
            return Color(red: 0.91, green: 0.35, blue: 0.32)  // 구글 캘린더 빨강
        } else if task.priority == .high {
            return Color(red: 0.96, green: 0.65, blue: 0.26)  // 구글 캘린더 주황
        } else {
            return Color(red: 0.26, green: 0.52, blue: 0.96)  // 구글 캘린더 파랑
        }
    }

    private var taskBorderColor: Color {
        if task.isCompleted {
            return Color(red: 0.36, green: 0.66, blue: 0.34)
        } else if task.isInProgress {
            return Color(red: 0.88, green: 0.66, blue: 0.08)  // 진한 노란색
        } else if task.priority == .urgent {
            return Color(red: 0.81, green: 0.25, blue: 0.22)
        } else if task.priority == .high {
            return Color(red: 0.86, green: 0.55, blue: 0.16)
        } else {
            return Color(red: 0.16, green: 0.42, blue: 0.86)
        }
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    // 시작 - 종료 시간 문자열
    private var timeRangeString: String {
        let startDate: Date

        // targetDate가 없으면 기본 9:00 사용
        if let targetDate = task.targetDate {
            startDate = targetDate
        } else {
            var components = calendar.dateComponents([.year, .month, .day], from: task.dueDate)
            components.hour = 9
            components.minute = 0
            startDate = calendar.date(from: components) ?? task.dueDate
        }

        // 종료 시간 계산
        let endDate = calendar.date(byAdding: .minute, value: task.estimatedMinutes, to: startDate) ?? startDate

        return "\(timeString(from: startDate)) - \(timeString(from: endDate))"
    }
}
