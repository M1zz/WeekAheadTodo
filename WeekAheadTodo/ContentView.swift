import SwiftUI
import SwiftData

// MARK: - Shared Enums

enum WeekViewMode: String, CaseIterable {
    case calendar = "캘린더"
    case list = "리스트"
}

enum TaskFilterMode: String, CaseIterable {
    case byStartDate = "시작일 기준"
    case byDueDate = "마감일 기준"
}

struct ContentView: View {
    @StateObject private var viewModel = TaskViewModel()
    @StateObject private var calendarViewModel = CalendarViewModel()
    @StateObject private var notificationService = NotificationService.shared
    @AppStorage("selectedSection") private var selectedSectionRawValue: String = SidebarSection.today.rawValue
    @State private var selectedProjectId: UUID? = nil
    @State private var showingAddProject = false
    @Environment(\.modelContext) private var modelContext

    private var currentSection: SidebarSection {
        SidebarSection(rawValue: selectedSectionRawValue) ?? .today
    }

    private var selectedSectionBinding: Binding<SidebarSection> {
        Binding(
            get: { SidebarSection(rawValue: selectedSectionRawValue) ?? .today },
            set: { selectedSectionRawValue = $0.rawValue }
        )
    }

    enum SidebarSection: String, CaseIterable {
        case today = "오늘"
        case thisWeek = "이번 주"
        case nextWeek = "다음 주"
        case someday = "언젠가"
        case todayInsights = "오늘 통계"
        case weekOverview = "주간 개요"
        case importTasks = "가져오기"
        case patterns = "패턴 관리"
        case settings = "설정"

        var icon: String {
            switch self {
            case .today: return "sun.max.fill"
            case .thisWeek: return "calendar.badge.clock"
            case .nextWeek: return "calendar.badge.plus"
            case .someday: return "tray.fill"
            case .todayInsights: return "chart.line.uptrend.xyaxis"
            case .weekOverview: return "chart.bar.fill"
            case .importTasks: return "square.and.arrow.down"
            case .patterns: return "arrow.triangle.2.circlepath"
            case .settings: return "gear"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            // 사이드바
            List(selection: selectedSectionBinding) {
                Section("할 일") {
                    ForEach([SidebarSection.today, .thisWeek, .nextWeek, .someday], id: \.self) { section in
                        sidebarItem(section)
                    }
                }

                Section {
                    ForEach(viewModel.projects) { project in
                        projectSidebarItem(project)
                    }

                    Button {
                        showingAddProject = true
                    } label: {
                        Label("새 프로젝트", systemImage: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                } header: {
                    HStack {
                        Text("프로젝트")
                        Spacer()
                    }
                }

                Section("관리") {
                    sidebarItem(.todayInsights)
                    sidebarItem(.weekOverview)
                    sidebarItem(.importTasks)
                    sidebarItem(.patterns)
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
        .environmentObject(notificationService)
        .sheet(isPresented: $showingAddProject) {
            AddProjectView()
        }
        .onAppear {
            setupServices()
            _Concurrency.Task {
                await generateTasksIfNeeded()
            }
        }
    }

    private func setupServices() {
        let patternService = PatternManagementService(modelContext: modelContext)
        calendarViewModel.setPatternManagementService(patternService)

        // TaskViewModel과 CalendarViewModel 연결 (타임 블록 계산용)
        viewModel.setCalendarViewModel(calendarViewModel)

        // NotificationService 연결 및 초기화
        viewModel.setNotificationService(notificationService)

        // 알림 권한 확인
        _Concurrency.Task {
            await notificationService.checkAuthorizationStatus()
        }
    }

    private func generateTasksIfNeeded() async {
        print("🚀 [ContentView] generateTasksIfNeeded 호출됨")
        let patternService = PatternManagementService(modelContext: modelContext)
        await viewModel.generateTasksFromApprovedPatterns(patternService: patternService)
        print("✅ [ContentView] Task 생성 완료 - 총 \(viewModel.tasks.count)개")
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

    @ViewBuilder
    private func projectSidebarItem(_ project: Project) -> some View {
        Button {
            selectedProjectId = project.id
            selectedSectionRawValue = "" // Clear section selection
        } label: {
            HStack {
                Image(systemName: project.icon)
                    .foregroundColor(Color(hex: project.color))
                Text(project.name)
                Spacer()
                let count = viewModel.incompleteTasks(for: project.id).count
                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(hex: project.color))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(selectedProjectId == project.id ? Color.blue.opacity(0.15) : Color.clear)
    }

    private func taskCount(for section: SidebarSection) -> Int? {
        switch section {
        case .today: return viewModel.todayIncompleteTasks.count
        case .thisWeek: return viewModel.thisWeekIncompleteTasks.count
        case .nextWeek: return viewModel.nextWeekIncompleteTasks.count
        case .someday: return viewModel.somedayIncompleteTasks.count
        default: return nil
        }
    }
    
    private func badgeColor(for section: SidebarSection) -> Color {
        switch section {
        case .today: return viewModel.isTodayOverCapacity ? .red : .blue
        case .thisWeek: return .orange
        case .nextWeek: return .green
        case .someday: return .purple
        default: return .gray
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        Group {
            if let projectId = selectedProjectId,
               let project = viewModel.projects.first(where: { $0.id == projectId }) {
                ProjectView(project: project)
            } else {
                switch currentSection {
                case .today:
                    TodayView()
                case .thisWeek:
                    ThisWeekView()
                case .nextWeek:
                    NextWeekView()
                case .someday:
                    SomedayView()
                case .todayInsights:
                    TodayInsightsView()
                case .weekOverview:
                    WeekOverviewView()
                case .importTasks:
                    ImportView()
                case .patterns:
                    ApprovedPatternManagementView()
                case .settings:
                    SettingsView()
                }
            }
        }
    }
}

// MARK: - Today View

struct TodayView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var calendarViewModel: CalendarViewModel
    @State private var showingAddTask = false
    @State private var showingNotificationPreview = false
    @State private var isEditMode = false
    @State private var selectedTasks: Set<UUID> = []
    @State private var showingDeleteConfirmation = false
    @State private var showingCalendarAddConfirmation = false
    @State private var isAddingToCalendar = false
    @AppStorage("recommendationSectionExpanded") private var isRecommendationExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            headerView
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
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

                    // 오늘 완료한 준비 태스크들의 미래 피드백
                    let futurePreps = viewModel.futureTasksPreparedToday()
                    if !futurePreps.isEmpty {
                        futureFeedbackSection(futurePreps: futurePreps)
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

                    // 가장 먼 미래를 준비하고 있는지 표시
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

                // 요일 표시
                weekdayIndicator
            }
            Spacer()

            // 달성도 표시
            if !viewModel.todayTasks.isEmpty {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("달성도")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Text("\(completedTodayCount)/\(viewModel.todayTasks.count)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(completedTodayCount == viewModel.todayTasks.count ? .green : .primary)
                        Text("(\(todayCompletionPercentage)%)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // 알림 미리보기 버튼 (가장 오른쪽)
            Button(action: {
                showingNotificationPreview.toggle()
            }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: notificationService.isNotificationEnabled ? "bell.fill" : "bell.slash.fill")
                        .font(.title2)
                        .foregroundColor(notificationService.isNotificationEnabled ? .blue : .gray)

                    // 알림 필요한 태스크가 있으면 배지 표시
                    if notificationService.isNotificationEnabled && tasksNeedingAttentionCount > 0 {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .overlay(
                                Text("\(min(tasksNeedingAttentionCount, 9))")
                                    .font(.system(size: 7, weight: .bold))
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

    // 알림 필요한 태스크 개수
    private var tasksNeedingAttentionCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        var count = 0

        for task in viewModel.tasks where !task.isCompleted {
            // 1. 시작일이 지났는데 아직 시작 안한 일
            if task.effectiveStartDate < today && task.isNotStarted {
                count += 1
                continue
            }

            // 2. 오늘 해야 할 일이 아직 완료되지 않은 경우
            if calendar.isDate(task.effectiveStartDate, inSameDayAs: today) && !task.isCompleted {
                count += 1
                continue
            }

            // 3. 마감 1일 전 알림 (내일이 마감일)
            if calendar.isDate(task.dueDate, inSameDayAs: tomorrow) && !task.isCompleted {
                count += 1
                continue
            }

            // 4. 준비 태스크를 시작할 시간
            if task.isPreparation && calendar.isDate(task.effectiveStartDate, inSameDayAs: today) && !task.isCompleted {
                count += 1
                continue
            }
        }

        return count
    }

    // 오늘 준비하고 있는 가장 먼 미래 (일 수)
    private var furthestFutureDays: Int? {
        guard !viewModel.todayTasks.isEmpty else { return nil }

        var maxDays = 0

        for task in viewModel.todayTasks {
            if task.isPreparation {
                // 준비 태스크: targetDate까지의 일수
                if let daysUntilTarget = task.daysUntilTarget, daysUntilTarget > maxDays {
                    maxDays = daysUntilTarget
                }
            } else if task.isMain {
                // 메인 태스크: dueDate까지의 일수
                if task.daysUntilDue > maxDays {
                    maxDays = task.daysUntilDue
                }
            }
        }

        return maxDays > 0 ? maxDays : nil
    }

    private var completedTodayCount: Int {
        viewModel.todayTasks.filter { $0.isCompleted }.count
    }

    private var todayCompletionPercentage: Int {
        guard viewModel.todayTasks.count > 0 else { return 0 }
        return Int(Double(completedTodayCount) / Double(viewModel.todayTasks.count) * 100)
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

    // MARK: - Future Preparation Gauge

    private var futurePreparationGaugeView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("미래 준비 목표")
                        .font(.headline)
                    Text("얼마나 미리 준비하고 있나요?")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            // 게이지
            VStack(spacing: 12) {
                // 현재 vs 목표
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("현재")
                            .font(.caption)
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
                            .font(.caption)
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

                // 프로그레스 바
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 배경 (전체)
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.15))

                        // 목표 지점 표시
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: geometry.size.width * targetProgress)

                        // 현재 진행도
                        RoundedRectangle(cornerRadius: 12)
                            .fill(gaugeColor)
                            .frame(width: geometry.size.width * currentProgress)

                        // 목표 마커
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: 3)
                            .offset(x: geometry.size.width * targetProgress - 1.5)
                    }
                }
                .frame(height: 24)

                // 진행률 표시
                HStack {
                    Text(motivationalMessage)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(gaugeColor)

                    Spacer()

                    if currentDaysAhead < viewModel.targetDaysAhead {
                        Text("목표까지 \(viewModel.targetDaysAhead - currentDaysAhead)일")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if currentDaysAhead == viewModel.targetDaysAhead {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("목표 달성!")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("목표 초과 달성!")
                                .font(.caption)
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
        return CGFloat(currentDaysAhead) / CGFloat(Double(maxDays) * 1.2) // 120% for visual padding
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
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()

                // 편집 모드 버튼
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

                    // 캘린더 추가 & 삭제 버튼 (편집 모드이고 선택된 항목이 있을 때만)
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
        // Swift Calendar: 1=일, 2=월, 3=화, 4=수, 5=목, 6=금, 7=토
        // 우리 배열: 0=월, 1=화, 2=수, 3=목, 4=금, 5=토, 6=일
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
            Button(action: {
                withAnimation {
                    isRecommendationExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: isRecommendationExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text("여유 시간에 미리 해두면 좋을 일")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(viewModel.recommendPreparableTasks().count)개")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isRecommendationExpanded {
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

    private var futurePreparationSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.blue)
                    .font(.title3)
                Text("오늘 하는 일이 준비하는 미래")
                    .font(.headline)
            }

            // 오늘 마감인 메인 태스크
            let todayDueTasks = viewModel.todayTasks.filter { $0.isMain && $0.daysUntilDue == 0 }
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
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    ForEach(todayDueTasks.prefix(3)) { task in
                        Text("⚡ \(task.title)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }

            // 준비 태스크 요약 - 며칠 뒤를 준비하는지
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
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // 날짜별로 그룹화
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
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                        .foregroundColor(days <= 1 ? .orange : .blue)
                    }
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            // 메인 태스크 요약 (오늘 마감 제외)
            let upcomingMainTasks = viewModel.todayTasks.filter { $0.isMain && $0.daysUntilDue > 0 }
            if !upcomingMainTasks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.blue)
                        Text("다가오는 마감")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("(\(upcomingMainTasks.count)개)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // 가장 가까운 3개
                    ForEach(upcomingMainTasks.sorted { $0.daysUntilDue < $1.daysUntilDue }.prefix(3)) { task in
                        HStack(spacing: 6) {
                            let emoji = task.daysUntilDue == 1 ? "⏰" : "📌"
                            Text("\(emoji) \(task.dDayWithDate)")
                                .foregroundColor(task.daysUntilDue == 1 ? .orange : .blue)
                            Text(task.title)
                                .lineLimit(1)
                        }
                        .font(.caption)
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
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(futurePreps, id: \.preparationTask.id) { item in
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)

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
                            .font(.caption)
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

    private func addSelectedTasksToCalendar() async {
        isAddingToCalendar = true
        defer { isAddingToCalendar = false }

        // 선택된 태스크들 가져오기
        let tasksToAdd = viewModel.todayTasks.filter { selectedTasks.contains($0.id) }

        // 태스크를 캘린더 이벤트로 변환
        var events: [(title: String, startDate: Date, endDate: Date, notes: String?)] = []

        for task in tasksToAdd {
            // 마감일의 오후 시간으로 설정 (예: 14:00 ~ 14:30)
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: task.dueDate)
            components.hour = 14 // 오후 2시
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

        // CalendarService를 통해 이벤트 생성
        let calendarService = calendarViewModel.calendarService
        let result = await calendarService.createEvents(events)

        // 결과 알림
        await MainActor.run {
            if result.success > 0 {
                print("✅ \(result.success)개 태스크를 캘린더에 추가했습니다")
            }
            if result.failure > 0 {
                print("❌ \(result.failure)개 태스크 추가 실패")
            }

            // 선택 해제 및 편집 모드 종료
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

// MARK: - Today Insights View

struct TodayInsightsView: View {
    @EnvironmentObject var viewModel: TaskViewModel

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d"
        return formatter.string(from: Date())
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("오늘 통계 \(todayDateString)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("오늘의 시간 블록과 미래 준비 현황을 확인하세요")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 오늘의 시간 블록
                    timeBlockStatusView

                    // 미래 준비 게이지
                    futurePreparationGaugeView

                    // 미래 준비 요약
                    if !viewModel.todayTasks.isEmpty {
                        futurePreparationSummary
                    }

                    // 오늘 완료한 준비 태스크들의 미래 피드백
                    let futurePreps = viewModel.futureTasksPreparedToday()
                    if !futurePreps.isEmpty {
                        futureFeedbackSection(futurePreps: futurePreps)
                    }
                }
                .padding(24)
            }
        }
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

    private var futurePreparationGaugeView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("미래 준비 목표")
                        .font(.headline)
                    Text("얼마나 미리 준비하고 있나요?")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            // 게이지
            VStack(spacing: 12) {
                // 현재 vs 목표
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("현재")
                            .font(.caption)
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
                            .font(.caption)
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

                // 프로그레스 바
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 배경 (전체)
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.15))

                        // 목표 지점 표시
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: geometry.size.width)

                        // 현재 지점 표시
                        RoundedRectangle(cornerRadius: 12)
                            .fill(gaugeColor)
                            .frame(width: min(
                                geometry.size.width * CGFloat(currentDaysAhead) / CGFloat(viewModel.targetDaysAhead),
                                geometry.size.width
                            ))
                    }
                }
                .frame(height: 24)

                // 달성률
                HStack(spacing: 8) {
                    if currentDaysAhead >= viewModel.targetDaysAhead {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("목표 달성! 🎉")
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    } else {
                        let percentage = min(Int(Double(currentDaysAhead) / Double(viewModel.targetDaysAhead) * 100), 100)
                        Text("\(percentage)%")
                            .fontWeight(.semibold)
                            .foregroundColor(gaugeColor)
                        Text(gaugeMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private var currentDaysAhead: Int {
        guard !viewModel.todayTasks.isEmpty else { return 0 }

        var maxDays = 0
        for task in viewModel.todayTasks {
            if task.isPreparation {
                if let daysUntilTarget = task.daysUntilTarget, daysUntilTarget > maxDays {
                    maxDays = daysUntilTarget
                }
            } else if task.isMain {
                if task.daysUntilDue > maxDays {
                    maxDays = task.daysUntilDue
                }
            }
        }
        return maxDays
    }

    private var gaugeColor: Color {
        let ratio = Double(currentDaysAhead) / Double(viewModel.targetDaysAhead)
        if ratio >= 1.0 {
            return .green
        } else if ratio >= 0.7 {
            return .blue
        } else if ratio >= 0.4 {
            return .orange
        } else {
            return .red
        }
    }

    private var gaugeMessage: String {
        let ratio = Double(currentDaysAhead) / Double(viewModel.targetDaysAhead)
        if ratio >= 0.7 {
            return "좋은 페이스예요! 👍"
        } else if ratio >= 0.4 {
            return "\(viewModel.targetDaysAhead)일 뒤를 살기 위해 노력해보세요! 🎯"
        } else {
            return "\(viewModel.targetDaysAhead)일 뒤를 살기 위해 노력해보세요! 🎯"
        }
    }

    private var futurePreparationSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.blue)
                    .font(.title3)
                Text("미래 준비 현황")
                    .font(.headline)
            }

            // 오늘 마감인 메인 태스크
            let todayDueTasks = viewModel.todayTasks.filter { $0.isMain && $0.daysUntilDue == 0 }
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
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    ForEach(todayDueTasks.prefix(3)) { task in
                        Text("⚡ \(task.title)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }

            // 준비 태스크 요약
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
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    ForEach(preparationTasks.prefix(5)) { task in
                        if let daysText = task.daysUntilTargetText {
                            HStack(spacing: 4) {
                                Text("•")
                                Text("\(daysText)")
                                    .fontWeight(.semibold)
                                Text("준비:")
                                Text(task.title)
                            }
                            .font(.caption)
                            .foregroundColor(.orange)
                        }
                    }
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
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
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(futurePreps, id: \.preparationTask.id) { item in
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)

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
                            .font(.caption)
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
}

// MARK: - Task Row View

struct TaskRowView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    let task: Task

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // 상태 토글 버튼
            Button(action: { viewModel.toggleTaskCompletion(task) }) {
                Image(systemName: task.status.icon)
                    .font(.title2)
                    .foregroundColor(statusColor)
            }
            .buttonStyle(.plain)
            .help(task.status.rawValue)
            
            // 태스크 정보
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    // 역할 뱃지 (준비 vs 메인) - 더 눈에 띄게
                    HStack(spacing: 4) {
                        Image(systemName: task.taskRole.icon)
                            .font(.caption2)
                        Text(task.taskRole.rawValue)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(roleBackgroundColor)
                    .foregroundColor(roleForegroundColor)
                    .cornerRadius(6)

                    Text(task.title)
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)

                    // 진행 중 뱃지
                    if task.isInProgress {
                        Text("진행 중")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }

                    // 태스크 타입 뱃지
                    Image(systemName: task.taskType.icon)
                        .font(.caption)
                        .foregroundColor(task.taskType == .preparable ? .blue : .orange)
                }

                // 준비 태스크의 경우 미래 연결 표시 - 더 눈에 띄게!
                if task.isPreparation, let mainTask = viewModel.mainTask(for: task) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        if let daysUntil = task.daysUntilTarget {
                            if daysUntil == 0 {
                                Text("오늘 '\(mainTask.title)'를 위한 준비 🎯")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.red)
                            } else if daysUntil == 1 {
                                Text("내일 '\(mainTask.title)'를 위한 준비 📅")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                            } else if daysUntil > 0 {
                                Text("\(daysUntil)일 뒤 '\(mainTask.title)'를 위한 준비 🗓️")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                            } else {
                                Text("지난 '\(mainTask.title)'의 준비")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                }

                // 메인 태스크의 경우 마감까지 며칠 남았는지 강조
                if task.isMain && !task.isCompleted {
                    HStack(spacing: 6) {
                        Image(systemName: "star.circle.fill")
                            .font(.caption)
                            .foregroundColor(task.daysUntilDue <= 0 ? .red : task.daysUntilDue == 1 ? .orange : .blue)

                        let emoji = task.daysUntilDue == 0 ? "⚡" : task.daysUntilDue == 1 ? "⏰" : task.daysUntilDue > 0 && task.daysUntilDue <= 7 ? "📌" : task.daysUntilDue < 0 ? "❗" : ""
                        Text("\(task.dDayWithDate) \(emoji)")
                            .font(.caption)
                            .fontWeight(task.daysUntilDue <= 1 ? .bold : task.daysUntilDue <= 7 ? .semibold : .medium)
                            .foregroundColor(task.daysUntilDue <= 0 ? .red : task.daysUntilDue == 1 ? .orange : task.daysUntilDue <= 7 ? .blue : .secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(task.daysUntilDue <= 0 ? Color.red.opacity(0.1) : task.daysUntilDue <= 1 ? Color.orange.opacity(0.1) : Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }

                // 메인 태스크의 경우 준비도 표시
                if task.isMain {
                    let progress = viewModel.preparationProgress(for: task)
                    if progress.total > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle")
                                .font(.caption2)
                            Text("준비: \(progress.completed)/\(progress.total) (\(progress.percentage)%)")
                                .font(.caption)
                                .foregroundColor(progress.percentage == 100 ? .green : .blue)
                        }
                    }
                }

                HStack(spacing: 8) {
                    // 예상 시간
                    Label(task.estimatedTimeFormatted, systemImage: "clock")

                    // 마감일 표시
                    Label(task.dDayWithDate, systemImage: "calendar")
                        .foregroundColor(task.daysUntilDue <= 0 ? .red : .primary)

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

            // 편집/삭제 버튼 (호버 시 표시)
            HStack(spacing: 4) {
                Button(action: { showingEditSheet = true }) {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .help("수정")

                Button(action: { showingDeleteAlert = true }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("삭제")
            }
            .padding(.horizontal, 8)
            .opacity(isHovered ? 1.0 : 0.0)

            // 긴급도 표시
            urgencyIndicator
        }
        .padding(12)
        .background(taskBackgroundColor)
        .cornerRadius(8)
        .overlay(
            HStack(spacing: 0) {
                // 왼쪽 색상 바 (역할 구분)
                RoundedRectangle(cornerRadius: 8)
                    .fill(roleAccentColor)
                    .frame(width: 4)
                    .padding(.trailing, -4)

                Spacer()
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColorForStatus, lineWidth: task.isInProgress ? 2 : 0)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button(action: { showingEditSheet = true }) {
                Label("수정", systemImage: "pencil")
            }
            Button(action: { showingDeleteAlert = true }) {
                Label("삭제", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditTaskView(task: task)
        }
        .alert("할 일 삭제", isPresented: $showingDeleteAlert) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) {
                viewModel.deleteTask(task)
            }
        } message: {
            Text("'\(task.title)'를 삭제하시겠습니까?")
        }
    }

    private var statusColor: Color {
        switch task.status {
        case .notStarted: return .gray
        case .inProgress: return .blue
        case .completed: return .green
        }
    }

    private var taskBackgroundColor: Color {
        // 진행 중 상태 우선
        if task.isInProgress {
            return Color.blue.opacity(0.08)
        }

        // 역할별 배경색
        switch task.taskRole {
        case .main:
            return Color.blue.opacity(0.03)
        case .preparation:
            return Color.orange.opacity(0.03)
        }
    }

    private var borderColorForStatus: Color {
        task.isInProgress ? .blue : .clear
    }

    // 역할 뱃지 색상
    private var roleBackgroundColor: Color {
        switch task.taskRole {
        case .main:
            return Color.blue.opacity(0.15)
        case .preparation:
            return Color.orange.opacity(0.15)
        }
    }

    private var roleForegroundColor: Color {
        switch task.taskRole {
        case .main:
            return .blue
        case .preparation:
            return .orange
        }
    }

    // 왼쪽 액센트 바 색상
    private var roleAccentColor: Color {
        switch task.taskRole {
        case .main:
            return .blue
        case .preparation:
            return .orange
        }
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
    @State private var viewMode: WeekViewMode = .calendar
    @State private var taskFilterMode: TaskFilterMode = .byStartDate
    @State private var isEditMode = false
    @State private var selectedTasks: Set<UUID> = []
    @State private var showingDeleteConfirmation = false

    // 이번 주: 오늘부터 7일
    private var weekDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    // 날짜별로 그룹화된 태스크 (완료된 것 포함)
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

    // 이번 주 전체 태스크
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
        let _ = print("📅 [ThisWeekView] 렌더링 시작")
        let _ = print("📅 [ThisWeekView] 전체 Task 개수: \(viewModel.tasks.count)")
        let _ = print("📅 [ThisWeekView] weekDates: \(weekDates.map { $0.formatted(date: .abbreviated, time: .omitted) })")
        let _ = viewModel.tasks.enumerated().forEach { index, task in
            print("📅 [ThisWeekView] Task[\(index)]: '\(task.title)' - dueDate: \(task.dueDate.formatted(date: .abbreviated, time: .omitted)), leadTimeDays: \(task.leadTimeDays), effectiveStartDate: \(task.effectiveStartDate.formatted(date: .abbreviated, time: .omitted)), isCompleted: \(task.isCompleted)")
        }
        let _ = weekDates.forEach { date in
            let tasksForDate = tasks(for: date)
            print("📅 [ThisWeekView] \(date.formatted(date: .abbreviated, time: .omitted)): \(tasksForDate.count)개 할 일")
        }
        let _ = print("📅 [ThisWeekView] 총 할 일: \(totalTasksThisWeek)개")

        return VStack(spacing: 0) {
            // 헤더
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

                // 편집 모드 버튼 및 삭제 버튼
                if totalTasksThisWeek > 0 {
                    HStack(spacing: 12) {
                        // 편집 모드 토글
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

                        // 삭제 버튼 (편집 모드일 때만 표시)
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

                // 달성도 표시
                if totalTasksThisWeek > 0 {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("달성도")
                            .font(.caption)
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

            // 뷰 모드 및 필터 선택
            HStack(spacing: 12) {
                // 뷰 모드 토글
                Picker("보기 모드", selection: $viewMode) {
                    ForEach(WeekViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                // 필터 모드 토글
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
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("이번 주 예정된 할 일이 없습니다")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Group {
                    switch viewMode {
                    case .calendar:
                        ScrollView([.horizontal, .vertical], showsIndicators: true) {
                            HStack(alignment: .top, spacing: 12) {
                                ForEach(weekDates, id: \.self) { date in
                                    WeekDayCard(
                                        date: date,
                                        tasks: tasks(for: date),
                                        isToday: Calendar.current.isDateInToday(date),
                                        isTomorrow: Calendar.current.isDateInTomorrow(date),
                                        isEditMode: $isEditMode,
                                        selectedTasks: $selectedTasks
                                    )
                                    .frame(width: 200)
                                }
                            }
                            .padding(16)
                        }
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
            AddTaskView()
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
            // 날짜 헤더
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dayOfWeek)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(dayAndMonth)
                        .font(.headline)
                }

                if isToday {
                    Text("오늘")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                } else if isTomorrow {
                    Text("내일")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }

                Spacer()

                if !tasks.isEmpty {
                    Text("\(completedCount)/\(tasks.count)")
                        .font(.caption)
                        .foregroundColor(completedCount == tasks.count ? .green : .secondary)
                }
            }

            Divider()

            // 태스크 목록 또는 빈 상태
            if tasks.isEmpty {
                Text("할 일 없음")
                    .font(.caption)
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

    private var completionPercentage: Int {
        guard tasks.count > 0 else { return 0 }
        return Int(Double(completedCount) / Double(tasks.count) * 100)
    }
}

// MARK: - Compact Task Row (for Calendar View)

struct CompactTaskRow: View {
    @EnvironmentObject var viewModel: TaskViewModel
    let task: Task

    var body: some View {
        Button(action: {
            viewModel.toggleTaskCompletion(task)
        }) {
            HStack(spacing: 6) {
                // 상태 아이콘
                Image(systemName: task.status.icon)
                    .font(.caption)
                    .foregroundColor(statusColor)

                // 제목
                Text(task.title)
                    .font(.caption)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                    .lineLimit(1)

                Spacer()

                // 우선순위 (긴급/높음만 표시)
                if task.priority == .urgent || task.priority == .high {
                    Image(systemName: task.priority.icon)
                        .font(.caption2)
                        .foregroundColor(Color(task.priority.color))
                }

                // 시간
                Text(task.estimatedTimeFormatted)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(task.isCompleted ? Color.clear : Color.gray.opacity(0.05))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    private var statusColor: Color {
        switch task.status {
        case .notStarted: return .gray
        case .inProgress: return .blue
        case .completed: return .green
        }
    }
}

// MARK: - Next Week View

struct NextWeekView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @State private var showingAddTask = false
    @State private var viewMode: WeekViewMode = .calendar
    @State private var taskFilterMode: TaskFilterMode = .byStartDate
    @State private var isEditMode = false
    @State private var selectedTasks: Set<UUID> = []
    @State private var showingDeleteConfirmation = false

    // 다음 주: 오늘로부터 8일째부터 14일째까지 (7일간)
    private var weekDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (7..<14).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    // 날짜별로 그룹화된 태스크 (완료된 것 포함)
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

    // 다음 주 전체 태스크 (필터 모드에 따라)
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
        let _ = print("📆 [NextWeekView] 렌더링 시작")
        let _ = print("📆 [NextWeekView] 전체 Task 개수: \(viewModel.tasks.count)")
        let _ = print("📆 [NextWeekView] weekDates: \(weekDates.map { $0.formatted(date: .abbreviated, time: .omitted) })")
        let _ = weekDates.forEach { date in
            let tasksForDate = tasks(for: date)
            print("📆 [NextWeekView] \(date.formatted(date: .abbreviated, time: .omitted)): \(tasksForDate.count)개 할 일")
        }
        let _ = print("📆 [NextWeekView] 총 할 일: \(totalTasksNextWeek)개")

        return VStack(spacing: 0) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    let calendar = Calendar.current
                    let nextWeekStart = calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date()
                    let weekRange = ContentView.weekDateRange(for: nextWeekStart, weekStartDay: viewModel.weekStartDay)

                    Text("다음 주 (\(ContentView.formatDateRange(start: weekRange.start, end: weekRange.end)))")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("\(totalTasksNextWeek)개의 할 일")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()

                // 편집 모드 버튼 및 삭제 버튼
                if totalTasksNextWeek > 0 {
                    HStack(spacing: 12) {
                        // 편집 모드 토글
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

                        // 삭제 버튼 (편집 모드일 때만 표시)
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

                // 달성도 및 예상 시간
                if totalTasksNextWeek > 0 {
                    HStack(spacing: 16) {
                        // 달성도
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("달성도")
                                .font(.caption)
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

                        // 총 예상 시간
                        let totalMinutes = weekDates.flatMap { tasks(for: $0) }.reduce(0) { $0 + $1.estimatedMinutes }
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("총 예상 시간")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(viewModel.formatMinutes(totalMinutes))
                                .font(.title2)
                                .fontWeight(.semibold)
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

            // 뷰 모드 및 필터 선택
            HStack(spacing: 12) {
                // 뷰 모드 토글
                Picker("보기 모드", selection: $viewMode) {
                    ForEach(WeekViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                // 필터 모드 토글
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
                Group {
                    switch viewMode {
                    case .calendar:
                        ScrollView([.horizontal, .vertical], showsIndicators: true) {
                            HStack(alignment: .top, spacing: 12) {
                                ForEach(weekDates, id: \.self) { date in
                                    WeekDayCard(
                                        date: date,
                                        tasks: tasks(for: date),
                                        isToday: false,
                                        isTomorrow: false,
                                        isEditMode: $isEditMode,
                                        selectedTasks: $selectedTasks
                                    )
                                    .frame(width: 200)
                                }
                            }
                            .padding(16)
                        }
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
            AddTaskView()
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
            // viewModel.tasks를 직접 필터링 (캘린더 모드와 동일한 데이터 소스 사용)
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
                            // 날짜 헤더
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dayOfWeek(group.date))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(dayAndMonth(group.date))
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }

                                Spacer()

                                // 완료 상태
                                let completed = group.tasks.filter { $0.isCompleted }.count
                                Text("\(completed)/\(group.tasks.count) 완료")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)

                            // 태스크 목록
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

// MARK: - Someday View

struct SomedayView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @State private var showingAddTask = false
    @State private var isEditMode = false
    @State private var selectedTasks: Set<UUID> = []
    @State private var showingDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
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

            // 편집 모드 버튼 및 삭제 버튼
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
                .font(.system(size: 48))
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
    @EnvironmentObject var notificationService: NotificationService

    @State private var showingSaveToCloudAlert = false
    @State private var showingRestoreFromCloudAlert = false
    @State private var showingResetDataAlert = false
    @State private var showingResetCalendarAlert = false
    @State private var cloudOperationInProgress = false
    @State private var cloudOperationError: String?
    @AppStorage("appFontSize") private var appFontSize: Double = 20.0

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
                    // 리마인더 알림
                    notificationSection

                    // 클라우드 동기화
                    cloudSyncSection

                    // 캘린더 연동
                    CalendarIntegrationView()

                    // 캘린더 초기화
                    calendarResetSection

                    // 폰트 크기
                    fontSizeSection

                    // 주 시작 요일
                    weekStartDaySection

                    // 미래 준비 목표
                    futurePreparationGoalSection

                    // 시간 블록 설정
                    timeBlockSection
                }
                .padding(24)
            }

            Spacer()
        }
    }

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("리마인더 알림")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                // 알림 권한 상태
                HStack {
                    Image(systemName: notificationService.notificationPermissionStatus == .authorized ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(notificationService.notificationPermissionStatus == .authorized ? .green : .orange)

                    Text(notificationPermissionStatusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 알림 기능 토글
                Toggle("리마인더 알림 활성화", isOn: Binding(
                    get: { notificationService.isNotificationEnabled },
                    set: { newValue in
                        if newValue && notificationService.notificationPermissionStatus != .authorized {
                            // 권한이 없으면 권한 요청
                            _Concurrency.Task {
                                try? await viewModel.requestNotificationAuthorization()
                            }
                        }
                        viewModel.setNotificationEnabled(newValue)
                    }
                ))
                .disabled(notificationService.notificationPermissionStatus == .denied)

                // 알림 설명
                Text("하루 3번(오전 9시, 오후 3시, 저녁 9시) 할 일 진행 상황을 체크합니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // 알림 내용 설명
                VStack(alignment: .leading, spacing: 4) {
                    Text("다음과 같은 상황에서 알림을 받습니다:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(alignment: .top, spacing: 4) {
                        Text("•")
                        Text("시작일이 지났는데 아직 시작하지 않은 일")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    HStack(alignment: .top, spacing: 4) {
                        Text("•")
                        Text("오늘 해야 할 일이 아직 완료되지 않은 경우")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    HStack(alignment: .top, spacing: 4) {
                        Text("•")
                        Text("내일이 마감일인 경우")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    HStack(alignment: .top, spacing: 4) {
                        Text("•")
                        Text("준비 태스크를 시작할 시간")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.top, 4)

                // 테스트 버튼
                if notificationService.isNotificationEnabled {
                    Button(action: {
                        _Concurrency.Task {
                            await notificationService.sendTestNotification()
                        }
                    }) {
                        Label("테스트 알림 보내기", systemImage: "bell.badge")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    private var notificationPermissionStatusText: String {
        switch notificationService.notificationPermissionStatus {
        case .authorized:
            return "알림 권한이 승인되었습니다"
        case .denied:
            return "알림 권한이 거부되었습니다. 시스템 설정에서 권한을 허용해주세요."
        case .notDetermined:
            return "알림 권한이 아직 요청되지 않았습니다"
        case .provisional:
            return "임시 알림 권한이 부여되었습니다"
        case .ephemeral:
            return "임시 앱 알림 권한이 부여되었습니다"
        @unknown default:
            return "알 수 없는 권한 상태"
        }
    }

    private var cloudSyncSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("클라우드 동기화")
                .font(.headline)

            VStack(spacing: 12) {
                // 마지막 동기화 시간
                if let lastSync = viewModel.lastSyncDate {
                    HStack {
                        Image(systemName: "checkmark.icloud")
                            .foregroundColor(.green)
                        Text("마지막 동기화: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // 에러 메시지
                if let error = cloudOperationError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
                }

                // 동기화 버튼들
                HStack(spacing: 12) {
                    Button(action: { showingSaveToCloudAlert = true }) {
                        Label("클라우드에 저장", systemImage: "icloud.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .disabled(cloudOperationInProgress)

                    Button(action: { showingRestoreFromCloudAlert = true }) {
                        Label("클라우드에서 복원", systemImage: "icloud.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .disabled(cloudOperationInProgress)
                }

                Divider()

                // 데이터 초기화
                Button(role: .destructive, action: { showingResetDataAlert = true }) {
                    Label("모든 데이터 초기화", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(cloudOperationInProgress)

                if cloudOperationInProgress {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("처리 중...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
        .alert("클라우드에 저장", isPresented: $showingSaveToCloudAlert) {
            Button("취소", role: .cancel) { }
            Button("저장") {
                _Concurrency.Task {
                    await saveToCloud()
                }
            }
        } message: {
            Text("현재 \(viewModel.tasks.count)개의 할 일을 클라우드에 저장합니다. 기존 클라우드 데이터는 덮어씌워집니다.")
        }
        .alert("클라우드에서 복원", isPresented: $showingRestoreFromCloudAlert) {
            Button("취소", role: .cancel) { }
            Button("복원", role: .destructive) {
                _Concurrency.Task {
                    await restoreFromCloud()
                }
            }
        } message: {
            Text("클라우드 데이터로 복원합니다. 현재 로컬 데이터는 덮어씌워집니다.")
        }
        .alert("모든 데이터 초기화", isPresented: $showingResetDataAlert) {
            Button("취소", role: .cancel) { }
            Button("초기화", role: .destructive) {
                _Concurrency.Task {
                    await resetAllData()
                }
            }
        } message: {
            Text("로컬 및 클라우드의 모든 데이터를 삭제합니다. 이 작업은 되돌릴 수 없습니다!")
        }
    }

    private func saveToCloud() async {
        cloudOperationInProgress = true
        cloudOperationError = nil

        do {
            try await viewModel.saveToCloud()
            print("✅ Successfully saved to cloud")
        } catch {
            cloudOperationError = "저장 실패: \(error.localizedDescription)"
            print("❌ Failed to save to cloud: \(error)")
        }

        cloudOperationInProgress = false
    }

    private func restoreFromCloud() async {
        cloudOperationInProgress = true
        cloudOperationError = nil

        do {
            try await viewModel.restoreFromCloud()
            print("✅ Successfully restored from cloud")
        } catch {
            cloudOperationError = "복원 실패: \(error.localizedDescription)"
            print("❌ Failed to restore from cloud: \(error)")
        }

        cloudOperationInProgress = false
    }

    private func resetAllData() async {
        cloudOperationInProgress = true
        cloudOperationError = nil

        do {
            try await viewModel.resetAllData()
            print("✅ Successfully reset all data")
        } catch {
            cloudOperationError = "초기화 실패: \(error.localizedDescription)"
            print("❌ Failed to reset data: \(error)")
        }

        cloudOperationInProgress = false
    }

    private var futurePreparationGoalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("미래 준비 목표")
                .font(.headline)

            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("목표 설정")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("며칠 뒤를 미리 준비하고 싶나요?")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }

                        HStack {
                            Text("목표")
                                .font(.subheadline)
                            Spacer()
                            Slider(value: Binding(
                                get: { Double(viewModel.targetDaysAhead) },
                                set: { viewModel.targetDaysAhead = Int($0) }
                            ), in: 3...14, step: 1)
                                .frame(width: 200)
                            HStack(spacing: 4) {
                                Text("\(viewModel.targetDaysAhead)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                    .frame(width: 40, alignment: .trailing)
                                Text("일 뒤")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("💡 추천")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                            Text("• 7일 (일주일): 대부분의 업무에 적합한 목표입니다")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("• 3-5일: 짧은 프로젝트나 빠른 업무 환경")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("• 10-14일: 장기 프로젝트나 여유로운 계획")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private var timeBlockSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("시간 블록")
                .font(.headline)

            Form {
                // 캘린더 기반 타임 블록 사용 여부
                Section {
                    Toggle(isOn: $viewModel.useCalendarForTimeBlocks) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("캘린더 일정으로 가용 시간 계산")
                                .font(.subheadline)
                            Text("선택한 캘린더의 일정을 기반으로 실제 가용 시간을 계산합니다")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: viewModel.useCalendarForTimeBlocks) { oldValue, newValue in
                        if newValue {
                            viewModel.updateTimeBlocksWithCalendar()
                        } else {
                            viewModel.updateTimeBlocksWithCalendar()  // Will use fixed hours
                        }
                    }
                }

                // 근무 시간 설정
                Section("근무 시간 설정") {
                    HStack {
                        Text("하루 근무 시간")
                        Spacer()
                        Slider(value: $viewModel.workHoursPerDay, in: 4...12, step: 0.5)
                            .frame(width: 200)
                        Text("\(viewModel.workHoursPerDay, specifier: "%.1f")시간")
                            .frame(width: 70)
                    }
                    .onChange(of: viewModel.workHoursPerDay) { oldValue, newValue in
                        if viewModel.useCalendarForTimeBlocks {
                            viewModel.updateTimeBlocksWithCalendar()
                        }
                    }

                    HStack {
                        Text("점심시간")
                        Spacer()
                        Slider(value: Binding(
                            get: { Double(viewModel.lunchBreakMinutes) },
                            set: { viewModel.lunchBreakMinutes = Int($0) }
                        ), in: 0...120, step: 15)
                            .frame(width: 200)
                        Text("\(viewModel.lunchBreakMinutes)분")
                            .frame(width: 70)
                    }
                    .onChange(of: viewModel.lunchBreakMinutes) { oldValue, newValue in
                        if viewModel.useCalendarForTimeBlocks {
                            viewModel.updateTimeBlocksWithCalendar()
                        }
                    }

                    if viewModel.useCalendarForTimeBlocks {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("계산 공식")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            Text("실제 가용 시간 = 근무 시간 - 캘린더 일정 - 점심시간")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                }

                // 타임 블록용 캘린더 선택
                if viewModel.useCalendarForTimeBlocks {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("바쁜 정도 계산용 캘린더", systemImage: "calendar.badge.clock")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("모든 일정을 포함하여 실제 가용 시간을 계산합니다")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                HStack(spacing: 4) {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                    Text("예: 업무 + 회의 + 개인 일정 + 가족 일정 모두 선택")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                        .padding(.bottom, 8)

                        if calendarViewModel.availableCalendars.isEmpty {
                            Text("캘린더 연동을 먼저 활성화해주세요")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Button(action: {
                                        if viewModel.timeBlockCalendarIds.count == calendarViewModel.availableCalendars.count {
                                            viewModel.timeBlockCalendarIds.removeAll()
                                        } else {
                                            viewModel.timeBlockCalendarIds = Set(calendarViewModel.availableCalendars.map { $0.calendarIdentifier })
                                        }
                                        viewModel.updateTimeBlocksWithCalendar()
                                    }) {
                                        Text(viewModel.timeBlockCalendarIds.count == calendarViewModel.availableCalendars.count ? "전체 해제" : "전체 선택")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)

                                    Spacer()

                                    Text("\(viewModel.timeBlockCalendarIds.count) / \(calendarViewModel.availableCalendars.count) 선택됨")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                ForEach(calendarViewModel.availableCalendars, id: \.calendarIdentifier) { calendar in
                                    Button(action: {
                                        if viewModel.timeBlockCalendarIds.contains(calendar.calendarIdentifier) {
                                            viewModel.timeBlockCalendarIds.remove(calendar.calendarIdentifier)
                                        } else {
                                            viewModel.timeBlockCalendarIds.insert(calendar.calendarIdentifier)
                                        }
                                        viewModel.updateTimeBlocksWithCalendar()
                                    }) {
                                        HStack {
                                            Image(systemName: viewModel.timeBlockCalendarIds.contains(calendar.calendarIdentifier) ? "checkmark.square.fill" : "square")
                                                .foregroundColor(viewModel.timeBlockCalendarIds.contains(calendar.calendarIdentifier) ? .blue : .gray)

                                            Circle()
                                                .fill(Color(calendar.color))
                                                .frame(width: 12, height: 12)

                                            Text(calendar.title)
                                                .font(.subheadline)

                                            Spacer()
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }

                // 기본 가용 시간 (캘린더 미사용 시)
                if !viewModel.useCalendarForTimeBlocks {
                    Section {
                        HStack {
                            Text("하루 가용 시간")
                            Spacer()
                            Slider(value: $viewModel.dailyAvailableHours, in: 1...12, step: 0.5)
                                .frame(width: 200)
                            Text("\(viewModel.dailyAvailableHours, specifier: "%.1f")시간")
                                .frame(width: 70)
                        }
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

    private var calendarResetSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("캘린더 연동 초기화")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                Text("캘린더 연동 설정과 감지된 패턴을 모두 제거합니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(role: .destructive, action: { showingResetCalendarAlert = true }) {
                    Label("캘린더 연동 초기화", systemImage: "calendar.badge.minus")
                }
                .buttonStyle(.bordered)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .alert("캘린더 연동 초기화", isPresented: $showingResetCalendarAlert) {
            Button("취소", role: .cancel) { }
            Button("초기화", role: .destructive) {
                calendarViewModel.resetCalendarIntegration()
            }
        } message: {
            Text("캘린더 연동 설정과 감지된 모든 패턴을 제거합니다. 승인된 패턴은 유지됩니다.")
        }
    }

    private var fontSizeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("폰트 크기")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("앱 폰트 크기")
                        .font(.subheadline)
                    Spacer()
                    Slider(value: $appFontSize, in: 16...32, step: 1)
                        .frame(width: 200)
                    Text("\(Int(appFontSize))pt")
                        .frame(width: 50, alignment: .trailing)
                        .font(.subheadline)
                }

                Button(action: {
                    appFontSize = 20.0
                }) {
                    Text("기본값으로 재설정")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Text("슬라이더를 조정하면 즉시 적용됩니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    private var weekStartDaySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("주 시작 요일")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                Picker("한 주의 시작", selection: $viewModel.weekStartDay) {
                    Text("일요일").tag(1)
                    Text("월요일").tag(2)
                }
                .pickerStyle(.segmented)

                Text("이번 주와 다음 주 범위 계산에 적용됩니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

// MARK: - Add Task View

struct AddTaskView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @Environment(\.dismiss) var dismiss

    var preselectedProjectId: UUID? = nil

    @State private var quickInput = ""
    @State private var title = ""
    @State private var description = ""
    @State private var dueDate = Date()
    @State private var estimatedHours = 1
    @State private var estimatedMinutes = 0
    @State private var leadTimeDays = 0
    @State private var priority: TaskPriority = .normal
    @State private var taskType: TaskType = .preparable
    @State private var useTemplate = false
    @State private var selectedTemplate: TaskTemplate?
    @State private var showDetailedForm = false
    @State private var selectedProjectId: UUID? = nil
    
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
                    .disabled(title.isEmpty && quickInput.isEmpty)
                    .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            Form {
                // 빠른 입력
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("예: 내일까지 회의 자료 준비 2시간 중요", text: $quickInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                            .onSubmit {
                                parseQuickInput()
                            }

                        HStack(spacing: 4) {
                            Image(systemName: "lightbulb.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text("자연어로 입력하면 자동으로 파싱됩니다")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if !quickInput.isEmpty {
                            Button(action: parseQuickInput) {
                                Label("입력 분석", systemImage: "wand.and.stars")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                } header: {
                    HStack {
                        Text("빠른 입력")
                        Spacer()
                        Button(action: { showDetailedForm.toggle() }) {
                            Text(showDetailedForm ? "간단히 보기" : "상세 설정")
                                .font(.caption)
                        }
                    }
                }

                if showDetailedForm {
                    Section("기본 정보") {
                        TextField("제목", text: $title)
                        TextField("설명 (선택)", text: $description)
                        DatePicker("마감일", selection: $dueDate, displayedComponents: .date)

                        Picker("우선순위", selection: $priority) {
                            ForEach(TaskPriority.allCases, id: \.self) { priority in
                                HStack {
                                    Image(systemName: priority.icon)
                                    Text(priority.rawValue)
                                }
                                .tag(priority)
                            }
                        }

                        Picker("프로젝트", selection: $selectedProjectId) {
                            Text("프로젝트 없음").tag(nil as UUID?)
                            ForEach(viewModel.projects) { project in
                                HStack {
                                    Image(systemName: project.icon)
                                        .foregroundColor(Color(hex: project.color))
                                    Text(project.name)
                                }
                                .tag(project.id as UUID?)
                            }
                        }
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
                } else {
                    // 간단 모드: 파싱된 정보만 표시
                    if !title.isEmpty {
                        Section("파싱 결과") {
                            LabeledContent("제목", value: title)
                            LabeledContent("마감일", value: dueDate.formatted(date: .abbreviated, time: .omitted))
                            LabeledContent("예상 시간", value: "\(estimatedHours)시간 \(estimatedMinutes)분")
                            if priority != .normal {
                                LabeledContent("우선순위", value: priority.rawValue)
                            }
                            if leadTimeDays > 0 {
                                LabeledContent("선행 일수", value: "\(leadTimeDays)일 전")
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 500, height: showDetailedForm ? 700 : 400)
        .onAppear {
            selectedProjectId = preselectedProjectId
        }
    }

    private func parseQuickInput() {
        let parsed = TaskInputParser.parse(quickInput)

        print("📝 입력 분석 시작: '\(quickInput)'")
        print("   제목: '\(parsed.title)'")
        print("   마감일: \(parsed.dueDate?.description ?? "없음")")
        print("   예상 시간: \(parsed.estimatedMinutes ?? 0)분")
        print("   우선순위: \(parsed.priority?.rawValue ?? "없음")")
        print("   선행 일수: \(parsed.leadTimeDays ?? 0)일")

        // 제목 설정
        title = parsed.title

        // 마감일 설정
        if let date = parsed.dueDate {
            dueDate = date
        }

        // 예상 시간 설정
        if let minutes = parsed.estimatedMinutes {
            estimatedHours = minutes / 60
            estimatedMinutes = minutes % 60
        }

        // 우선순위 설정
        if let parsedPriority = parsed.priority {
            priority = parsedPriority
        }

        // 선행 일수 설정
        if let days = parsed.leadTimeDays {
            leadTimeDays = days
        }

        // 상세 폼 보여주기
        showDetailedForm = true
    }

    private func addTask() {
        // 빠른 입력이 비어있지 않으면 먼저 파싱
        if !quickInput.isEmpty && title.isEmpty {
            parseQuickInput()
        }

        guard !title.isEmpty else { return }

        var task = Task(
            title: title,
            description: description,
            dueDate: dueDate,
            estimatedMinutes: estimatedHours * 60 + estimatedMinutes,
            leadTimeDays: leadTimeDays,
            taskType: taskType,
            taskRole: .main,
            priority: priority,
            projectId: selectedProjectId
        )

        if useTemplate, let template = selectedTemplate {
            // 템플릿 사용: 메인 태스크 + 준비 태스크들 자동 생성
            viewModel.addTaskWithSubtasks(mainTask: task, template: template)
        } else {
            // 템플릿 미사용: 단일 메인 태스크만 생성
            viewModel.addTask(task)
        }

        dismiss()
    }
}

// MARK: - Edit Task View

struct EditTaskView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @Environment(\.dismiss) var dismiss

    let task: Task

    @State private var title: String
    @State private var description: String
    @State private var dueDate: Date
    @State private var estimatedHours: Int
    @State private var estimatedMinutes: Int
    @State private var leadTimeDays: Int
    @State private var priority: TaskPriority
    @State private var taskType: TaskType
    @State private var selectedProjectId: UUID?

    init(task: Task) {
        self.task = task
        _title = State(initialValue: task.title)
        _description = State(initialValue: task.description)
        _dueDate = State(initialValue: task.dueDate)
        _estimatedHours = State(initialValue: task.estimatedMinutes / 60)
        _estimatedMinutes = State(initialValue: task.estimatedMinutes % 60)
        _leadTimeDays = State(initialValue: task.leadTimeDays)
        _priority = State(initialValue: task.priority)
        _taskType = State(initialValue: task.taskType)
        _selectedProjectId = State(initialValue: task.projectId)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Button("취소") { dismiss() }
                Spacer()
                Text("할 일 수정")
                    .font(.headline)
                Spacer()
                Button("저장") { saveTask() }
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

                    Picker("우선순위", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            HStack {
                                Image(systemName: priority.icon)
                                Text(priority.rawValue)
                            }
                            .tag(priority)
                        }
                    }

                    Picker("프로젝트", selection: $selectedProjectId) {
                        Text("프로젝트 없음").tag(nil as UUID?)
                        ForEach(viewModel.projects) { project in
                            HStack {
                                Image(systemName: project.icon)
                                    .foregroundColor(Color(hex: project.color))
                                Text(project.name)
                            }
                            .tag(project.id as UUID?)
                        }
                    }
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

                Section("정보") {
                    LabeledContent("역할", value: task.taskRole.rawValue)
                    LabeledContent("상태", value: task.status.rawValue)
                    if task.isPreparation, let mainTask = viewModel.mainTask(for: task) {
                        LabeledContent("메인 태스크", value: mainTask.title)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 500, height: 600)
    }

    private func saveTask() {
        var updatedTask = task
        updatedTask.title = title
        updatedTask.description = description
        updatedTask.dueDate = dueDate
        updatedTask.estimatedMinutes = estimatedHours * 60 + estimatedMinutes
        updatedTask.leadTimeDays = leadTimeDays
        updatedTask.priority = priority
        updatedTask.taskType = taskType
        updatedTask.projectId = selectedProjectId

        viewModel.updateTask(updatedTask)
        dismiss()
    }
}

// MARK: - Date Range Helpers

extension ContentView {
    static func weekDateRange(for date: Date, weekStartDay: Int) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)

        // Calculate days to subtract to get to week start
        let daysFromStart = (weekday - weekStartDay + 7) % 7

        guard let weekStart = calendar.date(byAdding: .day, value: -daysFromStart, to: calendar.startOfDay(for: date)),
              let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else {
            return (calendar.startOfDay(for: date), calendar.startOfDay(for: date))
        }

        return (weekStart, weekEnd)
    }

    static func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d"

        return "\(formatter.string(from: start)) ~ \(formatter.string(from: end))"
    }
}

// MARK: - Dynamic Font Support

// Font Scale Environment Key
struct FontScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    var fontScale: CGFloat {
        get { self[FontScaleKey.self] }
        set { self[FontScaleKey.self] = newValue }
    }
}

// Observable Font Manager
class FontScaleManager: ObservableObject {
    @Published var scale: CGFloat = 1.0

    init() {
        // 저장된 폰트 크기를 스케일로 변환 (기본 20pt 기준)
        let savedSize = UserDefaults.standard.double(forKey: "appFontSize")
        if savedSize > 0 {
            self.scale = savedSize / 20.0
        }
    }

    func updateScale(from fontSize: Double) {
        self.scale = fontSize / 20.0
        UserDefaults.standard.set(fontSize, forKey: "appFontSize")
    }
}

struct DynamicFontModifier: ViewModifier {
    @StateObject private var fontManager = FontScaleManager()
    @AppStorage("appFontSize") private var appFontSize: Double = 20.0

    func body(content: Content) -> some View {
        let scale = appFontSize / 20.0
        let dynamicTypeSize = fontSizeToDynamicTypeSize(appFontSize)

        return content
            .environment(\.fontScale, scale)
            .dynamicTypeSize(dynamicTypeSize)
            .onChange(of: appFontSize) { oldValue, newValue in
                fontManager.updateScale(from: newValue)
            }
            .onAppear {
                fontManager.updateScale(from: appFontSize)
            }
    }

    private func fontSizeToDynamicTypeSize(_ size: Double) -> DynamicTypeSize {
        // 폰트 크기를 DynamicTypeSize로 매핑 (16pt ~ 32pt 범위)
        // 20pt를 기준(large)으로 비례 계산
        switch size {
        case ..<17: return .xSmall     // 16pt
        case 17..<18: return .small    // 17pt
        case 18..<19: return .medium   // 18pt
        case 19..<21: return .large    // 19-20pt (기본값)
        case 21..<23: return .xLarge   // 21-22pt
        case 23..<25: return .xxLarge  // 23-24pt
        case 25..<27: return .xxxLarge // 25-26pt
        case 27..<29: return .accessibility1 // 27-28pt
        case 29..<31: return .accessibility2 // 29-30pt
        case 31..<32: return .accessibility3 // 31pt
        default: return .accessibility4      // 32pt+
        }
    }
}

extension View {
    func applyDynamicFont() -> some View {
        self.modifier(DynamicFontModifier())
    }

    // 스케일이 적용된 폰트를 반환하는 헬퍼
    func scaledFont(_ textStyle: Font.TextStyle = .body, design: Font.Design = .default) -> some View {
        self.modifier(ScaledFontModifier(textStyle: textStyle, design: design))
    }
}

// MARK: - Project View

struct ProjectView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    let project: Project
    @State private var showingAddTask = false
    @State private var showingEditProject = false
    @State private var isEditMode = false
    @State private var selectedTasks: Set<UUID> = []
    @AppStorage("appFontSize") private var appFontSize: Double = 20.0

    private var projectTasks: [Task] {
        viewModel.tasks(for: project.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: project.icon)
                    .foregroundColor(Color(hex: project.color))
                    .font(.title)
                Text(project.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()

                Button {
                    showingEditProject = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)

                Button {
                    showingAddTask = true
                } label: {
                    Label("새 할 일", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)

                if !projectTasks.isEmpty {
                    Button(isEditMode ? "완료" : "편집") {
                        isEditMode.toggle()
                        if !isEditMode {
                            selectedTasks.removeAll()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()

            Divider()

            // Task List
            if projectTasks.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("할 일이 없습니다")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Button {
                        showingAddTask = true
                    } label: {
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

                                Button {
                                    viewModel.toggleTaskCompletion(task)
                                } label: {
                                    Image(systemName: task.status.icon)
                                        .foregroundColor(Color(task.status.color))
                                }
                                .buttonStyle(.plain)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(task.title)
                                        .font(.body)
                                        .strikethrough(task.isCompleted)
                                    HStack(spacing: 8) {
                                        Text(task.dueDateWithWeekday)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(task.estimatedTimeFormatted)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if task.priority != .normal {
                                            Image(systemName: task.priority.icon)
                                                .foregroundColor(Color(task.priority.color))
                                                .font(.caption)
                                        }
                                    }
                                }

                                Spacer()

                                Text(task.dDayText)
                                    .font(.caption)
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
    }
}

// MARK: - Add Project View

struct AddProjectView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedColor = "#007AFF"
    @State private var selectedIcon = "folder.fill"
    @AppStorage("appFontSize") private var appFontSize: Double = 20.0

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
                            .onTapGesture {
                                selectedColor = color
                            }
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
                            .onTapGesture {
                                selectedIcon = icon
                            }
                    }
                }
            }

            Spacer()

            HStack {
                Button("취소") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("추가") {
                    let project = Project(
                        name: name,
                        color: selectedColor,
                        icon: selectedIcon
                    )
                    viewModel.addProject(project)
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
    @AppStorage("appFontSize") private var appFontSize: Double = 20.0

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
                            .onTapGesture {
                                selectedColor = color
                            }
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
                            .onTapGesture {
                                selectedIcon = icon
                            }
                    }
                }
            }

            Spacer()

            HStack {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("삭제", systemImage: "trash")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("취소") {
                    dismiss()
                }
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

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// 각 텍스트 스타일에 스케일을 적용하는 Modifier
struct ScaledFontModifier: ViewModifier {
    @Environment(\.fontScale) var fontScale
    let textStyle: Font.TextStyle
    let design: Font.Design

    func body(content: Content) -> some View {
        content.font(.system(textStyle, design: design))
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge) // 최대 크기 제한
    }
}

// Font extension for easy scaling
extension Font {
    static func scaled(_ style: TextStyle, scale: CGFloat = 1.0) -> Font {
        return .system(style).weight(.regular)
    }
}
