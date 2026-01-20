import SwiftUI

// MARK: - Month Calendar View (Apple Calendar Style)

struct MonthCalendarView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @State private var currentWeekStart: Date = Date()
    @State private var currentMonthStart: Date = Date()
    @State private var showingAddTask = false
    @AppStorage("calendarViewMode") private var viewMode: CalendarViewMode = .week

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
            // 헤더: 주 네비게이션 (구글 캘린더 스타일)
            HStack(spacing: 16) {
                HStack(spacing: 8) {
                    Button(action: {
                        if viewMode == .week {
                            moveWeek(by: -1)
                        } else {
                            moveMonth(by: -1)
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        if viewMode == .week {
                            moveWeek(by: 1)
                        } else {
                            moveMonth(by: 1)
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 17))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Text(viewMode == .week ? weekRangeString : monthRangeString)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.primary)

                Button(action: {
                    if viewMode == .week {
                        currentWeekStart = calendar.startOfDay(for: Date())
                        currentWeekStart = getWeekStart(for: currentWeekStart)
                    } else {
                        currentMonthStart = getMonthStart(for: Date())
                    }
                }) {
                    Text("오늘")
                        .font(.system(size: 17))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)

                Spacer()

                // 주간/월간 전환 Picker
                Picker("", selection: $viewMode) {
                    ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // 보기 모드에 따라 다른 캘린더 표시
            if viewMode == .week {
                weekCalendarView
            } else {
                monthCalendarView
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
        .onAppear {
            currentWeekStart = getWeekStart(for: Date())
            currentMonthStart = getMonthStart(for: Date())
        }
    }

    // MARK: - Week Calendar View

    private var weekCalendarView: some View {
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
                                .frame(width: 45, height: isLast ? slotHeight : slotHeight * 4, alignment: .topTrailing)
                        }
                    }
                    .frame(width: 50)

                    Divider()

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

                                        // 15분 단위 구분선 (Canvas로 정확하게 그리기)
                                        Canvas { context, size in
                                            for (index, slot) in timeSlots.enumerated() {
                                                let remainder = slot.truncatingRemainder(dividingBy: 1.0)
                                                let isHour = remainder == 0.0
                                                let isHalfHour = remainder == 0.5
                                                let isQuarter = remainder == 0.25 || remainder == 0.75

                                                let y = CGFloat(index) * slotHeight

                                                var path = Path()
                                                path.move(to: CGPoint(x: 0, y: y))
                                                path.addLine(to: CGPoint(x: size.width, y: y))

                                                // 선 스타일 결정
                                                if isHour {
                                                    // 정각: 진한 선
                                                    context.stroke(
                                                        path,
                                                        with: .color(Color.gray.opacity(0.25)),
                                                        lineWidth: 1.0
                                                    )
                                                } else if isHalfHour {
                                                    // 30분: 중간 선
                                                    context.stroke(
                                                        path,
                                                        with: .color(Color.gray.opacity(0.15)),
                                                        lineWidth: 0.7
                                                    )
                                                } else if isQuarter {
                                                    // 15분, 45분: 얇은 선
                                                    context.stroke(
                                                        path,
                                                        with: .color(Color.gray.opacity(0.08)),
                                                        lineWidth: 0.5
                                                    )
                                                }
                                            }
                                        }
                                        .frame(height: totalHeight)

                                        // 태스크 배치
                                        TaskLayoutView(
                                            tasks: tasksForDate(date),
                                            hourHeight: slotHeight,
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
                timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                    updateCurrentTimeLine()
                }
            }
            .onDisappear {
                timer?.invalidate()
            }
        }
        .onAppear {
            updateCurrentTimeLine()
            timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                updateCurrentTimeLine()
            }
        }
    }

    // MARK: - Month Calendar View

    private var monthCalendarView: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 1) {
                // 요일 헤더
                ForEach(Array(["일", "월", "화", "수", "목", "금", "토"].enumerated()), id: \.element) { index, day in
                    Text(day)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(index == 0 || index == 6 ? .red : .secondary)
                        .frame(height: 30)
                        .frame(maxWidth: .infinity)
                        .background(Color(NSColor.controlBackgroundColor))
                }

                // 날짜 셀들
                ForEach(monthDates, id: \.self) { date in
                    MonthDateCell(
                        date: date,
                        tasks: tasksForDate(date),
                        isToday: isToday(date),
                        isCurrentMonth: isCurrentMonth(date)
                    )
                }
            }
            .padding(1)
        }
    }

    // MARK: - Helper Properties

    private var weekRangeString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일"

        let start = currentWeekStart
        guard let end = calendar.date(byAdding: .day, value: 6, to: start) else {
            return formatter.string(from: start)
        }

        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    private var monthRangeString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월"
        return formatter.string(from: currentMonthStart)
    }

    private var weekDates: [Date] {
        var dates: [Date] = []
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: currentWeekStart) {
                dates.append(date)
            }
        }
        return dates
    }

    private var monthDates: [Date] {
        var dates: [Date] = []

        // 월의 첫날
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonthStart)) else {
            return []
        }

        // 첫 주 시작일 (일요일부터)
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let daysToSubtract = firstWeekday - 1  // 일요일은 1
        guard let firstDisplayDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: monthStart) else {
            return []
        }

        // 6주치 날짜 (42일)
        for i in 0..<42 {
            if let date = calendar.date(byAdding: .day, value: i, to: firstDisplayDate) {
                dates.append(date)
            }
        }

        return dates
    }

    // MARK: - Helper Functions

    private func getWeekStart(for date: Date) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }

    private func getMonthStart(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    private func moveWeek(by value: Int) {
        if let newWeek = calendar.date(byAdding: .weekOfYear, value: value, to: currentWeekStart) {
            currentWeekStart = newWeek
        }
    }

    private func moveMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonthStart) {
            currentMonthStart = newMonth
        }
    }

    private func isCurrentMonth(_ date: Date) -> Bool {
        calendar.isDate(date, equalTo: currentMonthStart, toGranularity: .month)
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

    private func tasksForDate(_ date: Date) -> [Task] {
        viewModel.tasks.filter { task in
            calendar.isDate(task.dueDate, inSameDayAs: date)
        }
    }
}

// MARK: - Month Date Cell

struct MonthDateCell: View {
    @EnvironmentObject var viewModel: TaskViewModel
    let date: Date
    let tasks: [Task]
    let isToday: Bool
    let isCurrentMonth: Bool

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 날짜 숫자
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 18, weight: isToday ? .bold : .regular))
                .foregroundColor(dateTextColor)
                .frame(width: 24, height: 24)
                .background(isToday ? Color.blue : Color.clear)
                .clipShape(Circle())
                .padding(.horizontal, 4)
                .padding(.top, 4)

            // 태스크 표시 (최대 3개)
            VStack(alignment: .leading, spacing: 2) {
                ForEach(tasks.prefix(3)) { task in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(taskColor(task))
                            .frame(width: 6, height: 6)
                        Text(task.title)
                            .font(.system(size: 17))
                            .lineLimit(1)
                            .foregroundColor(isCurrentMonth ? .primary : .secondary)
                    }
                }

                // 더 많은 태스크가 있으면 표시
                if tasks.count > 3 {
                    Text("+\(tasks.count - 3)개 더")
                        .font(.system(size: 17))
                        .foregroundColor(.secondary)
                        .padding(.leading, 10)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)

            Spacer()
        }
        .frame(minHeight: 80)
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .border(Color.gray.opacity(0.2), width: 0.5)
    }

    private var dateTextColor: Color {
        if isToday {
            return .white  // 오늘은 파란 원 배경이므로 흰색
        }

        let weekday = calendar.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7  // 일요일(1) 또는 토요일(7)

        if isWeekend {
            return .red  // 주말은 빨간색
        }

        return isCurrentMonth ? .primary : .secondary
    }

    private func taskColor(_ task: Task) -> Color {
        if task.isCompleted {
            return Color(red: 0.46, green: 0.76, blue: 0.44)  // 초록
        } else if task.priority == .urgent {
            return Color(red: 0.91, green: 0.35, blue: 0.32)  // 빨강
        } else if task.priority == .high {
            return Color(red: 0.96, green: 0.65, blue: 0.26)  // 주황
        } else {
            return Color(red: 0.16, green: 0.42, blue: 0.86)  // 파랑
        }
    }
}
