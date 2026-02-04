import SwiftUI

// MARK: - Settings View

enum SyncOperation {
    case save
    case restore
}

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
    @AppStorage("appFontSizeLevel") private var appFontSizeLevel: Int = 1
    @AppStorage("taskSectionOrder") private var taskSectionOrderData: Data = Data()
    @State private var editableTaskSections: [ContentView.SidebarSection] = []

    // 데이터 차이 확인 관련
    @State private var showingDataDifferenceAlert = false
    @State private var dataComparison: TaskViewModel.DataComparisonResult?
    @State private var pendingSyncOperation: SyncOperation = .save

    // 클라우드 데이터 미리보기
    @State private var showingCloudPreviewAlert = false
    @State private var cloudPreview: TaskViewModel.CloudDataPreview?

    // MARK: - Computed Properties

    /// 클라우드에 동기화된 태스크 개수
    private var cloudTaskCount: Int {
        UserDefaults.standard.stringArray(forKey: "cloudTaskRecordNames")?.count ?? 0
    }

    /// 클라우드에 동기화된 프로젝트 개수
    private var cloudProjectCount: Int {
        UserDefaults.standard.stringArray(forKey: "cloudProjectRecordNames")?.count ?? 0
    }

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
                    notificationSection
                    cloudSyncSection
                    CalendarIntegrationView()
                    calendarResetSection
                    fontSizeSection
                    taskSectionOrderView
                    weekStartDaySection
                    calendarDisplayHoursSection
                    futurePreparationGoalSection
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
                HStack {
                    Image(systemName: notificationService.notificationPermissionStatus == .authorized ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(notificationService.notificationPermissionStatus == .authorized ? .green : .orange)

                    Text(notificationPermissionStatusText)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }

                Toggle("리마인더 알림 활성화", isOn: Binding(
                    get: { notificationService.isNotificationEnabled },
                    set: { newValue in
                        if newValue && notificationService.notificationPermissionStatus != .authorized {
                            _Concurrency.Task {
                                try? await viewModel.requestNotificationAuthorization()
                            }
                        }
                        viewModel.setNotificationEnabled(newValue)
                    }
                ))
                .disabled(notificationService.notificationPermissionStatus == .denied)

                NavigationLink {
                    NotificationSettingsView()
                        .environmentObject(notificationService)
                } label: {
                    HStack {
                        Label("알림 시간 커스터마이징", systemImage: "clock.arrow.circlepath")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)

                Text("현재 \(notificationService.notificationTimes.filter { $0.isEnabled }.count)개 알림 시간이 활성화되어 있습니다.")
                    .font(.callout)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("다음과 같은 상황에서 알림을 받습니다:")
                        .font(.callout)
                        .foregroundColor(.secondary)

                    notificationDescriptionItem("시작일이 지났는데 아직 시작하지 않은 일")
                    notificationDescriptionItem("오늘 해야 할 일이 아직 완료되지 않은 경우")
                    notificationDescriptionItem("내일이 마감일인 경우")
                    notificationDescriptionItem("준비 태스크를 시작할 시간")
                }
                .padding(.top, 4)

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

    private func notificationDescriptionItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text("•")
            Text(text)
        }
        .font(.callout)
        .foregroundColor(.secondary)
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
                // 클라우드 동기화 정보
                VStack(alignment: .leading, spacing: 8) {
                    if let lastSync = viewModel.lastSyncDate {
                        HStack {
                            Image(systemName: "checkmark.icloud")
                                .foregroundColor(.green)
                            Text("마지막 동기화: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }

                    // 클라우드 동기화된 데이터 개수
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("클라우드: 태스크 \(cloudTaskCount)개")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("프로젝트 \(cloudProjectCount)개")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }

                    // 로컬 데이터 개수
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "laptopcomputer")
                                .foregroundColor(.purple)
                                .font(.caption)
                            Text("로컬: 태스크 \(viewModel.tasks.count)개")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("프로젝트 \(viewModel.projects.count)개")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)

                if let error = cloudOperationError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.callout)
                            .foregroundColor(.red)
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
                }

                HStack(spacing: 12) {
                    Button(action: { checkDataDifferenceBeforeSync(operation: .save) }) {
                        Label("클라우드에 저장", systemImage: "icloud.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .disabled(cloudOperationInProgress)

                    Button(action: { showCloudDataPreview() }) {
                        Label("클라우드에서 복원", systemImage: "icloud.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .disabled(cloudOperationInProgress)
                }

                Divider()

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
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
        .alert("데이터 차이 확인", isPresented: $showingDataDifferenceAlert) {
            Button("취소", role: .cancel) { }
            Button("로컬로 클라우드 덮어쓰기") {
                _Concurrency.Task { await saveToCloud() }
            }
            Button("클라우드로 로컬 덮어쓰기", role: .destructive) {
                _Concurrency.Task { await restoreFromCloud() }
            }
        } message: {
            if let comparison = dataComparison {
                Text("""
                로컬과 클라우드 데이터에 큰 차이가 있습니다:

                로컬: 태스크 \(comparison.localTaskCount)개, 프로젝트 \(comparison.localProjectCount)개
                클라우드: 태스크 \(comparison.cloudTaskCount)개, 프로젝트 \(comparison.cloudProjectCount)개

                어떻게 하시겠습니까?
                """)
            } else {
                Text("데이터를 동기화하시겠습니까?")
            }
        }
        .alert("클라우드에 저장", isPresented: $showingSaveToCloudAlert) {
            Button("취소", role: .cancel) { }
            Button("저장") {
                _Concurrency.Task { await saveToCloud() }
            }
        } message: {
            Text("현재 \(viewModel.tasks.count)개의 할 일을 클라우드에 저장합니다. 기존 클라우드 데이터는 덮어씌워집니다.")
        }
        .alert("클라우드 데이터 미리보기", isPresented: $showingCloudPreviewAlert) {
            Button("취소", role: .cancel) { }
            Button("이 데이터로 복원", role: .destructive) {
                _Concurrency.Task { await restoreFromCloud() }
            }
        } message: {
            if let preview = cloudPreview {
                if preview.isEmpty {
                    Text("클라우드에 저장된 데이터가 없습니다.")
                } else {
                    if let lastSync = preview.lastSyncDate {
                        Text("""
                        클라우드 데이터 정보:

                        • 태스크: \(preview.taskCount)개
                        • 프로젝트: \(preview.projectCount)개
                        • 마지막 동기화: \(lastSync.formatted(date: .abbreviated, time: .shortened))

                        이 데이터로 복원하시겠습니까?
                        현재 로컬 데이터(\(viewModel.tasks.count)개 태스크)는 덮어씌워집니다.
                        """)
                    } else {
                        Text("""
                        클라우드 데이터 정보:

                        • 태스크: \(preview.taskCount)개
                        • 프로젝트: \(preview.projectCount)개
                        • 마지막 동기화: 기록 없음

                        이 데이터로 복원하시겠습니까?
                        현재 로컬 데이터(\(viewModel.tasks.count)개 태스크)는 덮어씌워집니다.
                        """)
                    }
                }
            } else {
                Text("클라우드 데이터를 확인하는 중...")
            }
        }
        .alert("클라우드에서 복원", isPresented: $showingRestoreFromCloudAlert) {
            Button("취소", role: .cancel) { }
            Button("복원", role: .destructive) {
                _Concurrency.Task { await restoreFromCloud() }
            }
        } message: {
            Text("클라우드 데이터로 복원합니다. 현재 로컬 데이터는 덮어씌워집니다.")
        }
        .alert("모든 데이터 초기화", isPresented: $showingResetDataAlert) {
            Button("취소", role: .cancel) { }
            Button("초기화", role: .destructive) {
                _Concurrency.Task { await resetAllData() }
            }
        } message: {
            Text("로컬 및 클라우드의 모든 데이터를 삭제합니다. 이 작업은 되돌릴 수 없습니다!")
        }
    }

    /// 클라우드 데이터 미리보기 표시
    private func showCloudDataPreview() {
        _Concurrency.Task {
            do {
                let preview = try await viewModel.getCloudDataPreview()

                await MainActor.run {
                    cloudPreview = preview
                    showingCloudPreviewAlert = true
                }
            } catch {
                await MainActor.run {
                    cloudOperationError = "클라우드 데이터 확인 실패: \(error.localizedDescription)"
                }
                print("❌ Failed to get cloud preview: \(error)")
            }
        }
    }

    /// 동기화 전 데이터 차이 확인
    private func checkDataDifferenceBeforeSync(operation: SyncOperation) {
        pendingSyncOperation = operation

        _Concurrency.Task {
            do {
                let comparison = try await viewModel.compareLocalAndCloudData()

                // 차이가 큰 경우 사용자에게 확인
                if comparison.hasSignificantDifference {
                    await MainActor.run {
                        dataComparison = comparison
                        showingDataDifferenceAlert = true
                    }
                } else {
                    // 차이가 작으면 기존 확인 alert 표시
                    await MainActor.run {
                        switch operation {
                        case .save:
                            showingSaveToCloudAlert = true
                        case .restore:
                            showingRestoreFromCloudAlert = true
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    cloudOperationError = "데이터 비교 실패: \(error.localizedDescription)"
                }
                print("❌ Failed to compare data: \(error)")
            }
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
                                    .font(.callout)
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
                Section {
                    Toggle(isOn: $viewModel.useCalendarForTimeBlocks) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("캘린더 일정으로 가용 시간 계산")
                                .font(.subheadline)
                            Text("선택한 캘린더의 일정을 기반으로 실제 가용 시간을 계산합니다")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: viewModel.useCalendarForTimeBlocks) { _, _ in
                        viewModel.updateTimeBlocksWithCalendar()
                    }
                }

                Section("근무 시간 설정") {
                    HStack {
                        Text("하루 근무 시간")
                        Spacer()
                        Slider(value: $viewModel.workHoursPerDay, in: 4...12, step: 0.5)
                            .frame(width: 200)
                        Text("\(viewModel.workHoursPerDay, specifier: "%.1f")시간")
                            .frame(width: 70)
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
                }

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
                    .font(.callout)
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
                    Text("앱 폰트 크기 단계")
                        .font(.subheadline)
                    Spacer()
                    Picker("", selection: $appFontSizeLevel) {
                        ForEach(1...6, id: \.self) { level in
                            Text("단계 \(level)").tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("현재 단계: \(appFontSizeLevel)")
                        .font(.callout)
                        .fontWeight(.semibold)
                    Text(fontSizeDescription(for: appFontSizeLevel))
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)

                Button(action: { appFontSizeLevel = 1 }) {
                    Text("기본값으로 재설정 (단계 1)")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    private func fontSizeDescription(for level: Int) -> String {
        let increase = (level - 1) * 2
        let titleSize = 28 + increase
        let bodySize = 18 + increase
        return "제목: \(titleSize)pt, 본문: \(bodySize)pt (최소 18pt)"
    }

    private var taskSectionOrderView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("할 일 탭 순서")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                Text("탭을 드래그하여 순서를 변경할 수 있습니다")
                    .font(.callout)
                    .foregroundColor(.secondary)

                List {
                    ForEach(editableTaskSections, id: \.self) { section in
                        HStack(spacing: 12) {
                            Image(systemName: section.icon)
                                .foregroundColor(.blue)
                            Text(section.rawValue)
                            Spacer()
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .onMove { from, to in
                        editableTaskSections.move(fromOffsets: from, toOffset: to)
                        saveTaskSectionOrder()
                    }
                }
                .frame(height: 300)
                .listStyle(.plain)

                Button(action: { resetTaskSectionOrder() }) {
                    Text("기본 순서로 재설정")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .onAppear { loadTaskSectionOrder() }
    }

    private func loadTaskSectionOrder() {
        if let order = try? JSONDecoder().decode([String].self, from: taskSectionOrderData),
           !order.isEmpty {
            editableTaskSections = order.compactMap { ContentView.SidebarSection(rawValue: $0) }
        } else {
            editableTaskSections = [.today, .thisWeek, .nextWeek, .monthCalendar, .someday, .completed]
        }
    }

    private func saveTaskSectionOrder() {
        let order = editableTaskSections.map { $0.rawValue }
        if let data = try? JSONEncoder().encode(order) {
            taskSectionOrderData = data
        }
    }

    private func resetTaskSectionOrder() {
        editableTaskSections = [.today, .thisWeek, .nextWeek, .monthCalendar, .someday, .completed]
        saveTaskSectionOrder()
    }

    private var calendarDisplayHoursSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("캘린더 표시 시간")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("시작 시간:")
                        .font(.callout)
                    Picker("", selection: $viewModel.calendarStartHour) {
                        ForEach(0..<24) { hour in
                            Text(String(format: "%02d:00", hour)).tag(hour)
                        }
                    }
                    .frame(width: 100)

                    Spacer()

                    Text("종료 시간:")
                        .font(.callout)
                    Picker("", selection: $viewModel.calendarEndHour) {
                        ForEach(1..<25) { hour in
                            Text(String(format: "%02d:00", hour % 24)).tag(hour % 24)
                        }
                    }
                    .frame(width: 100)
                }

                Text("캘린더 뷰에 표시할 시간 범위를 설정합니다. (기본: 06:00 - 22:00)")
                    .font(.callout)
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
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}
