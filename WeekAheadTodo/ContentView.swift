import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TaskViewModel()
    @StateObject private var calendarViewModel = CalendarViewModel()
    @State private var selectedSection: SidebarSection = .today
    
    enum SidebarSection: String, CaseIterable {
        case today = "오늘"
        case thisWeek = "이번 주"
        case nextWeek = "다음 주"
        case weekOverview = "주간 개요"
        case settings = "설정"
        
        var icon: String {
            switch self {
            case .today: return "sun.max.fill"
            case .thisWeek: return "calendar.badge.clock"
            case .nextWeek: return "calendar.badge.plus"
            case .weekOverview: return "chart.bar.fill"
            case .settings: return "gear"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            // 사이드바
            List(selection: $selectedSection) {
                Section("할 일") {
                    ForEach([SidebarSection.today, .thisWeek, .nextWeek], id: \.self) { section in
                        sidebarItem(section)
                    }
                }
                
                Section("관리") {
                    sidebarItem(.weekOverview)
                    sidebarItem(.settings)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 200)
        } detail: {
            // 메인 콘텐츠
            mainContent
        }
        .frame(minWidth: 900, minHeight: 600)
        .environmentObject(viewModel)
        .environmentObject(calendarViewModel)
    }
    
    @ViewBuilder
    private func sidebarItem(_ section: SidebarSection) -> some View {
        Label {
            HStack {
                Text(section.rawValue)
                Spacer()
                if let count = taskCount(for: section), count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(badgeColor(for: section))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
        } icon: {
            Image(systemName: section.icon)
        }
        .tag(section)
    }
    
    private func taskCount(for section: SidebarSection) -> Int? {
        switch section {
        case .today: return viewModel.todayTasks.count
        case .thisWeek: return viewModel.thisWeekTasks.count
        case .nextWeek: return viewModel.nextWeekTasks.count
        default: return nil
        }
    }
    
    private func badgeColor(for section: SidebarSection) -> Color {
        switch section {
        case .today: return viewModel.isTodayOverCapacity ? .red : .blue
        case .thisWeek: return .orange
        case .nextWeek: return .green
        default: return .gray
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        switch selectedSection {
        case .today:
            TodayView()
        case .thisWeek:
            ThisWeekView()
        case .nextWeek:
            NextWeekView()
        case .weekOverview:
            WeekOverviewView()
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - Today View

struct TodayView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @State private var showingAddTask = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            headerView
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 시간 블록 상태
                    timeBlockStatusView
                    
                    // 오늘 할 일
                    if !viewModel.todayTasks.isEmpty {
                        taskSection(
                            title: "오늘 해야 할 일",
                            subtitle: "역산 결과 기준",
                            tasks: viewModel.todayTasks
                        )
                    } else {
                        emptyStateView
                    }
                    
                    // 여유 시간에 미리 할 수 있는 일
                    if !viewModel.recommendPreparableTasks().isEmpty {
                        recommendationSection
                    }
                    
                    // 용량 초과 시 재배치 제안
                    if viewModel.isTodayOverCapacity {
                        reallocationSuggestionView
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
            VStack(alignment: .leading, spacing: 4) {
                Text("오늘")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text(Date(), style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(24)
        .background(Color(NSColor.windowBackgroundColor))
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
            
            // 프로그레스 바
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
            
            // 남은 시간 또는 초과 경고
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
            .font(.caption)
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
    
    private func taskSection(title: String, subtitle: String, tasks: [Task]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ForEach(tasks) { task in
                TaskRowView(task: task)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
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
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("여유 시간에 미리 해두면 좋을 일")
                    .font(.headline)
            }
            
            ForEach(viewModel.recommendPreparableTasks()) { task in
                HStack {
                    TaskRowView(task: task)
                    
                    Button("오늘 하기") {
                        // 오늘로 당기기 로직
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding(16)
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
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
                .font(.caption)
                .foregroundColor(.secondary)
            
            ForEach(viewModel.suggestReallocation(), id: \.task.id) { suggestion in
                HStack {
                    Text(suggestion.task.title)
                    Spacer()
                    Text("→ \(suggestion.suggestedDate, style: .date)")
                        .foregroundColor(.secondary)
                    Button("옮기기") {
                        // 재배치 로직
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
}

// MARK: - Task Row View

struct TaskRowView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    let task: Task
    
    var body: some View {
        HStack(spacing: 12) {
            // 완료 체크박스
            Button(action: { viewModel.toggleTaskCompletion(task) }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(task.isCompleted ? .green : .gray)
            }
            .buttonStyle(.plain)
            
            // 태스크 정보
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(task.title)
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                    
                    // 태스크 타입 뱃지
                    Image(systemName: task.taskType.icon)
                        .font(.caption)
                        .foregroundColor(task.taskType == .preparable ? .blue : .orange)
                }
                
                HStack(spacing: 8) {
                    // 예상 시간
                    Label(task.estimatedTimeFormatted, systemImage: "clock")
                    
                    // 마감일 표시
                    if task.daysUntilDue > 0 {
                        Label("D-\(task.daysUntilDue)", systemImage: "calendar")
                    } else if task.daysUntilDue == 0 {
                        Label("오늘 마감", systemImage: "calendar")
                            .foregroundColor(.red)
                    } else {
                        Label("마감 지남", systemImage: "calendar")
                            .foregroundColor(.red)
                    }
                    
                    // 선행 일수 (역산 정보)
                    if task.leadTimeDays > 0 {
                        Label("\(task.leadTimeDays)일 전 시작", systemImage: "arrow.counterclockwise")
                            .foregroundColor(.blue)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 긴급도 표시
            urgencyIndicator
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private var urgencyIndicator: some View {
        if task.daysUntilStart <= 0 {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
        } else if task.daysUntilStart <= 2 {
            Circle()
                .fill(Color.orange)
                .frame(width: 8, height: 8)
        }
    }
}

// MARK: - This Week View

struct ThisWeekView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @State private var showingAddTask = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("이번 주")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("\(viewModel.thisWeekTasks.count)개의 할 일")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(24)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            if viewModel.thisWeekTasks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("이번 주 예정된 할 일이 없습니다")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.thisWeekTasks) { task in
                            TaskRowView(task: task)
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
    }
}

// MARK: - Next Week View

struct NextWeekView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @State private var showingAddTask = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("다음 주")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("\(viewModel.nextWeekTasks.count)개의 할 일")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                // 다음 주 미리보기 힌트
                if !viewModel.nextWeekTasks.isEmpty {
                    VStack(alignment: .trailing) {
                        Text("총 예상 시간")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(viewModel.formatMinutes(viewModel.nextWeekTasks.reduce(0) { $0 + $1.estimatedMinutes }))
                            .font(.headline)
                    }
                }
            }
            .padding(24)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            if viewModel.nextWeekTasks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    Text("다음 주 계획을 세워보세요")
                        .font(.headline)
                    Text("지금 추가하면 필요한 준비 시간을 역산해서 알려드려요")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.nextWeekTasks) { task in
                            TaskRowView(task: task)
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
    }
}

// MARK: - Week Overview View

struct WeekOverviewView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("주간 개요")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(24)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 2주간 워크로드 차트
                    workloadChart
                    
                    // 일별 상세
                    dailyBreakdown
                }
                .padding(24)
            }
        }
    }
    
    private var workloadChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("2주간 워크로드")
                .font(.headline)
            
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(viewModel.weeklyWorkload(), id: \.date) { day in
                    VStack(spacing: 4) {
                        // 바 차트
                        ZStack(alignment: .bottom) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 40, height: 100)
                            
                            Rectangle()
                                .fill(barColor(minutes: day.minutes, capacity: day.capacity))
                                .frame(width: 40, height: barHeight(minutes: day.minutes, capacity: day.capacity))
                        }
                        .cornerRadius(4)
                        
                        // 요일
                        Text(dayLabel(day.date))
                            .font(.caption2)
                            .foregroundColor(Calendar.current.isDateInToday(day.date) ? .blue : .secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func barColor(minutes: Int, capacity: Int) -> Color {
        let ratio = Double(minutes) / Double(capacity)
        if ratio > 1.0 { return .red }
        if ratio > 0.8 { return .orange }
        return .blue
    }
    
    private func barHeight(minutes: Int, capacity: Int) -> CGFloat {
        let ratio = min(Double(minutes) / Double(capacity), 1.5)
        return CGFloat(ratio * 100)
    }
    
    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
    
    private var dailyBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("일별 상세")
                .font(.headline)
            
            ForEach(viewModel.weeklyWorkload().prefix(7), id: \.date) { day in
                if !viewModel.tasks(for: day.date).isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(formatDate(day.date))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if Calendar.current.isDateInToday(day.date) {
                                Text("오늘")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                            
                            Spacer()
                            
                            Text("\(viewModel.formatMinutes(day.minutes)) / \(viewModel.formatMinutes(day.capacity))")
                                .font(.caption)
                                .foregroundColor(day.minutes > day.capacity ? .red : .secondary)
                        }
                        
                        ForEach(viewModel.tasks(for: day.date)) { task in
                            HStack {
                                Circle()
                                    .fill(task.taskType == .preparable ? Color.blue : Color.orange)
                                    .frame(width: 6, height: 6)
                                Text(task.title)
                                    .font(.caption)
                                Spacer()
                                Text(task.estimatedTimeFormatted)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 8)
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 (E)"
        return formatter.string(from: date)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @EnvironmentObject var calendarViewModel: CalendarViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("설정")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(24)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 캘린더 연동
                    CalendarIntegrationView()

                    // 시간 블록 설정
                    timeBlockSection
                }
                .padding(24)
            }

            Spacer()
        }
    }

    private var timeBlockSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("시간 블록")
                .font(.headline)

            Form {
                Section {
                    HStack {
                        Text("하루 가용 시간")
                        Spacer()
                        Slider(value: $viewModel.dailyAvailableHours, in: 1...12, step: 0.5)
                            .frame(width: 200)
                        Text("\(viewModel.dailyAvailableHours, specifier: "%.1f")시간")
                            .frame(width: 60)
                    }
                }

                Section("정보") {
                    LabeledContent("버전", value: "1.0.0 프로토타입")
                    LabeledContent("개발", value: "Leeo")
                }
            }
            .formStyle(.grouped)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Add Task View

struct AddTaskView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var dueDate = Date()
    @State private var estimatedHours = 1
    @State private var estimatedMinutes = 0
    @State private var leadTimeDays = 0
    @State private var taskType: TaskType = .preparable
    @State private var useTemplate = false
    @State private var selectedTemplate: TaskTemplate?
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Button("취소") { dismiss() }
                Spacer()
                Text("새 할 일")
                    .font(.headline)
                Spacer()
                Button("추가") { addTask() }
                    .disabled(title.isEmpty)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            
            Divider()
            
            Form {
                Section("기본 정보") {
                    TextField("제목", text: $title)
                    TextField("설명 (선택)", text: $description)
                    DatePicker("마감일", selection: $dueDate, displayedComponents: .date)
                }
                
                Section("시간 설정") {
                    HStack {
                        Text("예상 소요 시간")
                        Spacer()
                        Picker("시간", selection: $estimatedHours) {
                            ForEach(0..<13) { Text("\($0)시간").tag($0) }
                        }
                        .frame(width: 80)
                        Picker("분", selection: $estimatedMinutes) {
                            ForEach([0, 15, 30, 45], id: \.self) { Text("\($0)분").tag($0) }
                        }
                        .frame(width: 70)
                    }
                    
                    Stepper("선행 소요 일수: \(leadTimeDays)일", value: $leadTimeDays, in: 0...14)
                    
                    if leadTimeDays > 0 {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("마감 \(leadTimeDays)일 전부터 '오늘 할 일'에 표시됩니다")
                                .font(.caption)
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
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("해당 날짜에만 할 수 있는 일입니다 (회의, 미팅 등)")
                            .font(.caption)
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
                                            .font(.caption)
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
            }
            .formStyle(.grouped)
        }
        .frame(width: 500, height: 600)
    }
    
    private func addTask() {
        let task = Task(
            title: title,
            description: description,
            dueDate: dueDate,
            estimatedMinutes: estimatedHours * 60 + estimatedMinutes,
            leadTimeDays: leadTimeDays,
            taskType: taskType
        )
        
        if useTemplate, let template = selectedTemplate {
            viewModel.addTaskWithSubtasks(mainTask: task, template: template)
        } else {
            viewModel.addTask(task)
        }
        
        dismiss()
    }
}
