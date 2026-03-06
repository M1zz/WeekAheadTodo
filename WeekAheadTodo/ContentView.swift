import WeekAheadShared
import SwiftUI
import SwiftData

// MARK: - Content View

struct ContentView: View {
    @StateObject private var viewModel = TaskViewModel()
    @StateObject private var calendarViewModel = CalendarViewModel()
    @StateObject private var mailViewModel = MailViewModel()
    @StateObject private var wikiViewModel = WikiViewModel()
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var assistantService = ProactiveAssistantService.shared
    @AppStorage("selectedSection") private var selectedSectionRawValue: String = SidebarSection.today.rawValue
    @AppStorage("taskSectionOrder") private var taskSectionOrderData: Data = Data()
    @State private var selectedProjectId: UUID? = nil
    @State private var showingAddProject = false
    @State private var showingQuickAdd = false
    @Environment(\.modelContext) private var modelContext

    private var currentSection: SidebarSection {
        SidebarSection(rawValue: selectedSectionRawValue) ?? .today
    }

    private var selectedSectionBinding: Binding<SidebarSection> {
        Binding(
            get: { SidebarSection(rawValue: selectedSectionRawValue) ?? .today },
            set: {
                selectedSectionRawValue = $0.rawValue
                selectedProjectId = nil  // 섹션 선택 시 프로젝트 선택 해제
            }
        )
    }

    private var orderedTaskSections: [SidebarSection] {
        // UserDefaults에서 저장된 순서 불러오기
        if let order = try? JSONDecoder().decode([String].self, from: taskSectionOrderData),
           !order.isEmpty {
            let sections = order.compactMap { SidebarSection(rawValue: $0) }
            // 저장된 순서에 없는 새로운 섹션이 있을 수 있으므로 확인
            let defaultSections: [SidebarSection] = [.today, .thisWeek, .nextWeek, .monthCalendar, .someday, .completed]
            let missingSections = defaultSections.filter { !sections.contains($0) }
            return sections + missingSections
        } else {
            // 기본 순서
            return [.today, .thisWeek, .nextWeek, .monthCalendar, .someday, .completed]
        }
    }

    // MARK: - Sidebar Section Enum

    enum SidebarSection: String, CaseIterable, Hashable {
        case today = "오늘"
        case thisWeek = "이번 주"
        case nextWeek = "다음 주"
        case monthCalendar = "캘린더"
        case someday = "언젠가"
        case completed = "완료된 일"
        case upcomingReminders = "잊지 않으셨죠?"
        case assistantHistory = "알림 히스토리"
        case todayInsights = "오늘 통계"
        case weekOverview = "주간 개요"
        case importTasks = "가져오기"
        case patterns = "패턴 관리"
        case wiki = "위키"
        case mail = "메일"
        case settings = "설정"

        var icon: String {
            switch self {
            case .today: return "sun.max.fill"
            case .thisWeek: return "calendar.badge.clock"
            case .nextWeek: return "calendar.badge.plus"
            case .monthCalendar: return "calendar"
            case .someday: return "tray.fill"
            case .completed: return "checkmark.circle.fill"
            case .upcomingReminders: return "hand.wave.fill"
            case .assistantHistory: return "bell.badge.fill"
            case .todayInsights: return "chart.line.uptrend.xyaxis"
            case .weekOverview: return "chart.bar.fill"
            case .importTasks: return "square.and.arrow.down"
            case .patterns: return "arrow.triangle.2.circlepath"
            case .wiki: return "book.closed.fill"
            case .mail: return "envelope.fill"
            case .settings: return "gear"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationSplitView {
            // 사이드바
            List(selection: selectedSectionBinding) {
                Section("할 일") {
                    ForEach(orderedTaskSections, id: \.self) { section in
                        sidebarItem(section)
                    }
                }

                Section("비서") {
                    sidebarItem(.upcomingReminders)
                    sidebarItem(.assistantHistory)
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

                Section("문서") {
                    sidebarItem(.wiki)
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
                .id(selectedSectionRawValue)
        }
        .frame(minWidth: 900, minHeight: 600)
        .environmentObject(viewModel)
        .environmentObject(calendarViewModel)
        .environmentObject(mailViewModel)
        .environmentObject(wikiViewModel)
        .environmentObject(notificationService)
        .environmentObject(assistantService)
        // TODO: URLHandler.swift를 Xcode 프로젝트에 추가한 후 주석 해제
        // .onOpenURL { url in
        //     _ = URLHandler.handle(url: url, taskViewModel: viewModel)
        // }
        .sheet(isPresented: $showingAddProject) {
            AddProjectView(onProjectAdded: { projectId in
                // 새로 추가된 프로젝트 자동 선택
                selectedProjectId = projectId
                selectedSectionRawValue = "_project_\(projectId.uuidString)"
            })
            .environmentObject(viewModel)
        }
        .sheet(isPresented: $showingQuickAdd) {
            QuickAddView()
                .environmentObject(viewModel)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showQuickAdd)) { _ in
            showingQuickAdd = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            _Concurrency.Task { @MainActor in
                await viewModel.syncOnForeground()
                await generateTasksIfNeeded()
            }
        }
        .task {
            // SwiftData ModelContext 연결 (CloudKit 자동 동기화)
            viewModel.setModelContext(modelContext)

            // SwiftData에서 최신 데이터 로드
            await viewModel.performInitialSync()

            // 서비스 설정
            setupServices()

            // 승인된 패턴에서 태스크 생성
            await generateTasksIfNeeded()
        }
    }

    // MARK: - Setup Services

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

        // 미체크인 태스크 감지
        viewModel.detectMissedCheckins()
    }

    private func generateTasksIfNeeded() async {
        let patternService = PatternManagementService(modelContext: modelContext)
        await viewModel.generateTasksFromApprovedPatterns(patternService: patternService)
    }

    // MARK: - Sidebar Item

    @ViewBuilder
    private func sidebarItem(_ section: SidebarSection) -> some View {
        Label {
            HStack {
                Text(section.rawValue)
                Spacer()
                if let count = taskCount(for: section), count > 0 {
                    Text("\(count)")
                        .font(.callout)
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
            selectedSectionRawValue = "_project_\(project.id.uuidString)" // 유효하지 않은 섹션값으로 설정
        } label: {
            HStack {
                Image(systemName: project.icon)
                    .foregroundColor(Color(hex: project.color))
                Text(project.name)
                Spacer()
                let count = viewModel.incompleteTasks(for: project.id).count
                if count > 0 {
                    Text("\(count)")
                        .font(.callout)
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

    // MARK: - Task Count & Badge

    private func taskCount(for section: SidebarSection) -> Int? {
        switch section {
        case .today: return viewModel.todayIncompleteTasks.count
        case .thisWeek: return viewModel.thisWeekIncompleteTasks.count
        case .nextWeek: return viewModel.nextWeekIncompleteTasks.count
        case .someday: return viewModel.somedayIncompleteTasks.count
        case .upcomingReminders: return upcomingRemindersCount
        case .completed: return nil  // 완료된 일은 뱃지 표시 안 함
        default: return nil
        }
    }

    private var upcomingRemindersCount: Int {
        let tasks = viewModel.tasks.filter { !$0.isCompleted }
        let overdue = tasks.filter { $0.daysUntilDue < 0 }.count
        let dueWithin3Days = tasks.filter { $0.daysUntilDue >= 0 && $0.daysUntilDue <= 3 }.count
        let shouldStart = tasks.filter { $0.daysUntilStart <= 0 && $0.daysUntilDue > 3 && $0.leadTimeDays > 0 }.count
        let startingSoon = tasks.filter { $0.daysUntilStart > 0 && $0.daysUntilStart <= 3 && $0.leadTimeDays > 0 }.count
        return overdue + dueWithin3Days + shouldStart + startingSoon
    }

    private func badgeColor(for section: SidebarSection) -> Color {
        switch section {
        case .today: return viewModel.isTodayOverCapacity ? .red : .blue
        case .thisWeek: return .orange
        case .nextWeek: return .green
        case .someday: return .purple
        case .upcomingReminders:
            // 마감 지난 태스크가 있으면 빨간색
            let hasOverdue = viewModel.tasks.contains { !$0.isCompleted && $0.daysUntilDue < 0 }
            return hasOverdue ? .red : .orange
        default: return .gray
        }
    }

    // MARK: - Main Content

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
                case .monthCalendar:
                    MonthCalendarView()
                case .someday:
                    SomedayView()
                case .completed:
                    CompletedTasksView()
                case .upcomingReminders:
                    UpcomingRemindersView()
                case .assistantHistory:
                    AssistantHistoryView()
                case .todayInsights:
                    TodayInsightsView()
                case .weekOverview:
                    WeekOverviewView()
                case .importTasks:
                    ImportView()
                case .patterns:
                    ApprovedPatternManagementView()
                case .wiki:
                    WikiView()
                case .mail:
                    MailIntegrationView()
                case .settings:
                    SettingsView()
                }
            }
        }
    }
}
