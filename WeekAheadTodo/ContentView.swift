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
    @State private var selectedSection: SidebarSection = .today
    @Environment(\.modelContext) private var modelContext

    enum SidebarSection: String, CaseIterable {
        case today = "오늘"
        case thisWeek = "이번 주"
        case nextWeek = "다음 주"
        case weekOverview = "주간 개요"
        case patterns = "패턴 관리"
        case settings = "설정"

        var icon: String {
            switch self {
            case .today: return "sun.max.fill"
            case .thisWeek: return "calendar.badge.clock"
            case .nextWeek: return "calendar.badge.plus"
            case .weekOverview: return "chart.bar.fill"
            case .patterns: return "arrow.triangle.2.circlepath"
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
    
    private func taskCount(for section: SidebarSection) -> Int? {
        switch section {
        case .today: return viewModel.todayIncompleteTasks.count
        case .thisWeek: return viewModel.thisWeekIncompleteTasks.count
        case .nextWeek: return viewModel.nextWeekIncompleteTasks.count
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
        case .patterns:
            ApprovedPatternManagementView()
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - Today View

struct TodayView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @EnvironmentObject var notificationService: NotificationService
    @State private var showingAddTask = false
    @State private var showingNotificationPreview = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            headerView
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 미래 준비 게이지 - 목표 대비 현재 위치
                    futurePreparationGaugeView

                    // 시간 블록 상태
                    timeBlockStatusView

                    // 미래 준비 요약 - 오늘 하는 일이 며칠 뒤를 위한 것인지
                    if !viewModel.todayTasks.isEmpty {
                        futurePreparationSummary
                    }

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
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("오늘")
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

                Text(Date(), style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
                            if task.daysUntilDue == 1 {
                                Text("⏰ 내일")
                                    .foregroundColor(.orange)
                            } else {
                                Text("📌 \(task.daysUntilDue)일 뒤")
                                    .foregroundColor(.blue)
                            }
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
                            .foregroundColor(.blue)
                        if task.daysUntilDue == 0 {
                            Text("오늘 마감 ⚡")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        } else if task.daysUntilDue == 1 {
                            Text("내일 마감 ⏰")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        } else if task.daysUntilDue > 0 && task.daysUntilDue <= 7 {
                            Text("\(task.daysUntilDue)일 뒤 마감 📌")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        } else if task.daysUntilDue > 7 {
                            Text("\(task.daysUntilDue)일 뒤 마감")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("마감 지남 ❗")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(task.daysUntilDue <= 1 ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
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

            // 편집/삭제 버튼 (호버 시 표시)
            if isHovered {
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
            }

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
                    Text("이번 주")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("\(totalTasksThisWeek)개의 할 일")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()

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
                        ScrollView(.horizontal, showsIndicators: true) {
                            HStack(alignment: .top, spacing: 16) {
                                ForEach(weekDates, id: \.self) { date in
                                    WeekDayCard(
                                        date: date,
                                        tasks: tasks(for: date),
                                        isToday: Calendar.current.isDateInToday(date),
                                        isTomorrow: Calendar.current.isDateInTomorrow(date)
                                    )
                                    .frame(width: 280)
                                }
                            }
                            .padding(24)
                        }
                    case .list:
                        WeekListView(
                            weekDates: weekDates,
                            tasks: allThisWeekTasks,
                            filterMode: taskFilterMode
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 날짜 헤더
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dayOfWeek)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(dayAndMonth)
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                if isToday {
                    Text("오늘")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                } else if isTomorrow {
                    Text("내일")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }

                Spacer()

                if !tasks.isEmpty {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(completedCount)/\(tasks.count)")
                            .font(.caption)
                            .foregroundColor(completedCount == tasks.count ? .green : .secondary)
                        if tasks.count > 0 {
                            Text("\(completionPercentage)%")
                                .font(.caption2)
                                .foregroundColor(completedCount == tasks.count ? .green : .secondary)
                        }
                    }
                }
            }

            // 태스크 목록 또는 빈 상태
            if tasks.isEmpty {
                Text("할 일 없음")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(tasks) { task in
                    TaskRowView(task: task)
                }
            }
        }
        .padding(16)
        .background(isToday ? Color.blue.opacity(0.05) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
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

// MARK: - Next Week View

struct NextWeekView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @State private var showingAddTask = false
    @State private var viewMode: WeekViewMode = .calendar
    @State private var taskFilterMode: TaskFilterMode = .byStartDate

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
                    Text("다음 주")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("\(totalTasksNextWeek)개의 할 일")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()

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
                        ScrollView(.horizontal, showsIndicators: true) {
                            HStack(alignment: .top, spacing: 16) {
                                ForEach(weekDates, id: \.self) { date in
                                    WeekDayCard(
                                        date: date,
                                        tasks: tasks(for: date),
                                        isToday: false,
                                        isTomorrow: false
                                    )
                                    .frame(width: 280)
                                }
                            }
                            .padding(24)
                        }
                    case .list:
                        WeekListView(
                            weekDates: weekDates,
                            tasks: allNextWeekTasks,
                            filterMode: taskFilterMode
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

    private var groupedTasks: [(date: Date, tasks: [Task])] {
        weekDates.map { date in
            let calendar = Calendar.current
            let tasksForDate = tasks.filter { task in
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
                                    TaskRowView(task: task)
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
    @State private var cloudOperationInProgress = false
    @State private var cloudOperationError: String?

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
        var task = Task(
            title: title,
            description: description,
            dueDate: dueDate,
            estimatedMinutes: estimatedHours * 60 + estimatedMinutes,
            leadTimeDays: leadTimeDays,
            taskType: taskType,
            taskRole: .main  // 기본적으로 메인 태스크
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
    @State private var taskType: TaskType

    init(task: Task) {
        self.task = task
        _title = State(initialValue: task.title)
        _description = State(initialValue: task.description)
        _dueDate = State(initialValue: task.dueDate)
        _estimatedHours = State(initialValue: task.estimatedMinutes / 60)
        _estimatedMinutes = State(initialValue: task.estimatedMinutes % 60)
        _leadTimeDays = State(initialValue: task.leadTimeDays)
        _taskType = State(initialValue: task.taskType)
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
        updatedTask.taskType = taskType

        viewModel.updateTask(updatedTask)
        dismiss()
    }
}
