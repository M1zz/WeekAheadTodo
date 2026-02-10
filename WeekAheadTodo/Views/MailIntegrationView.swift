import SwiftUI

/// 메일 통합 뷰
struct MailIntegrationView: View {
    @EnvironmentObject var mailViewModel: MailViewModel
    @EnvironmentObject var taskViewModel: TaskViewModel
    @StateObject private var ollamaService = OllamaService.shared
    @State private var selectedMailIds: Set<UUID> = []
    @State private var mailLimit: Int = 50
    @State private var showAccountSettingsSheet: Bool = false
    @State private var permissionTestResult: String = ""
    @State private var analysisResult: MailAnalysisResult?
    @State private var isAnalyzing: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            headerSection

            Divider()

            // 메일 목록 + 상세 보기
            if mailViewModel.isLoading {
                ProgressView("메일 로딩 중...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredMails.isEmpty {
                emptyStateView
            } else {
                HSplitView {
                    // 왼쪽: 메일 목록
                    mailListSection
                        .frame(minWidth: 300, idealWidth: 400)
                    
                    // 오른쪽: 메일 상세
                    mailDetailView
                        .frame(minWidth: 400)
                }
            }
        }
        .navigationTitle("📧 메일")
        .task {
            // 계정 목록 먼저 로드
            await mailViewModel.loadAccounts()
            // 메일 로드
            await mailViewModel.loadMails(limit: mailLimit)
        }
        .sheet(isPresented: $showAccountSettingsSheet) {
            AccountSettingsSheet()
                .environmentObject(mailViewModel)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Mail.app 통합")
                    .font(.headline)

                Spacer()

                // 계정 설정 버튼
                Button {
                    showAccountSettingsSheet = true
                } label: {
                    Label("연동 계정 설정", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                // 계정 선택
                if !mailViewModel.accounts.isEmpty {
                    Picker("계정", selection: $mailViewModel.selectedAccountName) {
                        Text("전체").tag(String?.none)
                        ForEach(mailViewModel.accounts) { account in
                            Text(account.name).tag(String?.some(account.name))
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // 메일 개수 선택 (변경 시 API 호출)
                Picker("개수", selection: $mailLimit) {
                    Text("20개").tag(20)
                    Text("50개").tag(50)
                    Text("100개").tag(100)
                    Text("200개").tag(200)
                    Text("500개").tag(500)
                    Text("1000개").tag(1000)
                    Text("전체").tag(9999)
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 120)
                .onChange(of: mailLimit) { oldValue, newValue in
                    _Concurrency.Task {
                        await mailViewModel.refreshMails(limit: mailLimit)
                    }
                }

                // 일정만 표시 토글 (변경 시 API 호출)
                Toggle("일정만", isOn: $mailViewModel.showScheduleOnly)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: mailViewModel.showScheduleOnly) { oldValue, newValue in
                        _Concurrency.Task {
                            await mailViewModel.refreshMails(limit: mailLimit)
                        }
                    }

                // 새로고침 버튼 (API 호출)
                Button {
                    _Concurrency.Task {
                        await mailViewModel.refreshAccounts()
                        await mailViewModel.refreshMails(limit: mailLimit)
                    }
                } label: {
                    Label("새로고침", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(mailViewModel.isLoading)
            }

            // 메시지
            if let successMessage = mailViewModel.successMessage {
                Text(successMessage)
                    .font(.callout)
                    .foregroundColor(.green)
            }
            if let errorMessage = mailViewModel.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundColor(.red)
            }

            // 선택된 메일 액션
            if !selectedMailIds.isEmpty {
                HStack {
                    Text("\(selectedMailIds.count)개 선택됨")
                        .font(.callout)
                        .foregroundColor(.secondary)

                    Button {
                        mailViewModel.convertMailsToTasks(mailIds: selectedMailIds, taskViewModel: taskViewModel)
                        selectedMailIds.removeAll()
                    } label: {
                        Label("태스크로 변환", systemImage: "arrow.right.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    Button("선택 해제") {
                        selectedMailIds.removeAll()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Mail List Section

    private var mailListSection: some View {
        List(selection: $mailViewModel.selectedMailId) {
            ForEach(filteredMails) { mail in
                mailRow(mail: mail)
                    .tag(mail.id)
            }
        }
        .listStyle(.inset)
        .onChange(of: mailViewModel.selectedMailId) { oldValue, newValue in
            // 메일 선택 시 읽음 처리
            if newValue != nil {
                _Concurrency.Task {
                    await mailViewModel.markSelectedAsRead()
                }
            }
        }
    }
    
    /// 선택된 계정에 맞는 메일만 필터링
    private var filteredMails: [MailMessage] {
        if let selectedAccount = mailViewModel.selectedAccountName {
            // 선택된 계정의 이메일 주소 찾기
            if let account = mailViewModel.accounts.first(where: { $0.name == selectedAccount }) {
                return mailViewModel.mails.filter { $0.accountEmail == account.emailAddress }
            }
            return []
        }
        return mailViewModel.mails
    }
    
    /// 계정별 메일 개수
    private func mailCountFor(_ account: MailAccount) -> Int {
        mailViewModel.mails.filter { $0.accountEmail == account.emailAddress }.count
    }
    
    // MARK: - Mail Detail View
    
    private var mailDetailView: some View {
        Group {
            if let selectedId = mailViewModel.selectedMailId,
               let mail = filteredMails.first(where: { $0.id == selectedId }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // 헤더
                        VStack(alignment: .leading, spacing: 8) {
                            Text(mail.subject)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading) {
                                    Text(mail.sender)
                                        .font(.headline)
                                    Text(mail.senderEmail)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                
                                // AI 분석 버튼
                                Button {
                                    _Concurrency.Task {
                                        isAnalyzing = true
                                        analysisResult = await ollamaService.analyzeMail(mail)
                                        isAnalyzing = false
                                    }
                                } label: {
                                    if isAnalyzing {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Label("AI 분석", systemImage: "sparkles")
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.purple)
                                .disabled(isAnalyzing)
                                
                                Text(mail.date.formatted(date: .long, time: .shortened))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let account = mail.accountEmail {
                                HStack {
                                    Image(systemName: "tray")
                                    Text(account)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        
                        // AI 분석 결과
                        if let result = analysisResult {
                            analysisResultView(result)
                        }
                        
                        Divider()
                        
                        // 본문
                        Text(mail.body)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "envelope.open")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("메일을 선택하세요")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // MARK: - Analysis Result View
    
    private func analysisResultView(_ result: MailAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 요약
            if !result.summary.isEmpty {
                HStack {
                    Image(systemName: "text.quote")
                        .foregroundColor(.purple)
                    Text(result.summary)
                        .font(.callout)
                        .italic()
                }
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
            }
            
            // 일정
            if !result.events.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("추출된 일정", systemImage: "calendar")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    ForEach(result.events) { event in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(event.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                HStack {
                                    Text("📅 \(event.date)")
                                    if let time = event.time {
                                        Text("🕐 \(time)")
                                    }
                                    if let location = event.location {
                                        Text("📍 \(location)")
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("캘린더 추가") {
                                // TODO: 캘린더 이벤트 생성
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
            }
            
            // 할일
            if !result.todos.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("추출된 할일", systemImage: "checklist")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    ForEach(result.todos) { todo in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(todo.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if let deadline = todo.deadline {
                                    Text("마감: \(deadline)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if let priority = todo.priority {
                                Text(priority)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(priorityColor(priority).opacity(0.2))
                                    .foregroundColor(priorityColor(priority))
                                    .cornerRadius(4)
                            }
                            Button("태스크 추가") {
                                // TODO: 태스크 생성
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
            }
            
            // 결과 없음
            if result.events.isEmpty && result.todos.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                    Text("이 메일에서 일정이나 할일을 찾지 못했습니다.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "high": return .red
        case "medium": return .orange
        case "low": return .green
        default: return .gray
        }
    }

    private func mailRow(mail: MailMessage) -> some View {
        HStack(spacing: 12) {
            // 선택 체크박스
            Button {
                if selectedMailIds.contains(mail.id) {
                    selectedMailIds.remove(mail.id)
                } else {
                    selectedMailIds.insert(mail.id)
                }
            } label: {
                Image(systemName: selectedMailIds.contains(mail.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedMailIds.contains(mail.id) ? .blue : .gray)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(mail.subject)
                        .font(.headline)
                        .lineLimit(1)

                    if mail.containsSchedule {
                        Image(systemName: "calendar.badge.clock")
                            .font(.callout)
                            .foregroundColor(.orange)
                    }

                    if !mail.isRead {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                    }

                    if mail.isStarred {
                        Image(systemName: "star.fill")
                            .font(.callout)
                            .foregroundColor(.yellow)
                    }

                    Spacer()

                    Text(mail.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.callout)
                        .foregroundColor(.secondary)
                }

                Text(mail.sender)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if mail.containsSchedule, let extractedDate = mail.extractedDate {
                    HStack {
                        Image(systemName: "clock")
                        Text("일정: \(extractedDate.formatted(date: .abbreviated, time: .shortened))")
                        if let duration = mail.extractedDuration {
                            Text("(\(duration)분)")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                }

                Text(mail.body)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }


    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            if let selectedAccount = mailViewModel.selectedAccountName {
                Text("\(selectedAccount) 계정에 메일이 없습니다")
                    .font(.title3)
                    .fontWeight(.medium)
            } else {
                Text("메일이 없습니다")
                    .font(.title3)
                    .fontWeight(.medium)
            }

            Text("새로고침 버튼을 눌러 메일을 가져오세요")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                _Concurrency.Task {
                    await mailViewModel.refreshAccounts()
                    await mailViewModel.refreshMails(limit: mailLimit)
                }
            } label: {
                Label("새로고침", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Account Settings Sheet

/// 메일 계정 연동 설정 시트
struct AccountSettingsSheet: View {
    @EnvironmentObject var mailViewModel: MailViewModel
    @Environment(\.dismiss) var dismiss
    @State private var permissionTestResult: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("메일 계정 연동 설정")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // 내용
            if mailViewModel.accounts.isEmpty {
                emptyAccountsView
            } else {
                accountListView
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    // MARK: - Empty Accounts View
    
    private var emptyAccountsView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 64))
                .foregroundColor(.orange)

            VStack(spacing: 8) {
                Text("Mail.app 연결 필요")
                    .font(.title2.bold())

                Text("Mail.app 자동화 권한이 필요합니다.\n아래 버튼을 눌러 권한을 요청하세요.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                // 권한 요청 버튼 (가장 중요)
                Button {
                    _Concurrency.Task {
                        permissionTestResult = "테스트 중..."
                        let result = await mailViewModel.testConnection()
                        permissionTestResult = result.message
                        if result.success {
                            await mailViewModel.loadAccounts()
                            await mailViewModel.loadMails(limit: 50)
                        }
                    }
                } label: {
                    Label("Mail.app 권한 요청", systemImage: "lock.open")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.large)
                
                // 테스트 결과
                if !permissionTestResult.isEmpty {
                    HStack {
                        Image(systemName: permissionTestResult.contains("성공") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(permissionTestResult.contains("성공") ? .green : .red)
                        Text(permissionTestResult)
                            .font(.caption)
                    }
                    .padding(.horizontal)
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                Text("권한이 거부되었다면:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button {
                    // 시스템 설정 - 개인정보 보호 - 자동화
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
                } label: {
                    Label("시스템 설정 → 자동화", systemImage: "gear")
                }
                .buttonStyle(.bordered)

                Button {
                    NSWorkspace.shared.launchApplication("Mail")
                } label: {
                    Label("Mail.app 열기", systemImage: "envelope")
                }
                .buttonStyle(.bordered)

                Button {
                    _Concurrency.Task {
                        await mailViewModel.loadAccounts()
                    }
                } label: {
                    Label("다시 확인", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding()

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Account List View

    private var accountListView: some View {
        VStack(spacing: 0) {
            // 안내
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("체크된 계정의 메일만 WeekAheadTodo에서 조회합니다")
                    .font(.callout)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .background(Color.blue.opacity(0.1))

            // 계정 목록
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(mailViewModel.accounts) { account in
                        accountRow(account)
                    }
                }
                .padding()
            }

            Divider()

            // 하단 정보
            HStack {
                Text("총 \(mailViewModel.accounts.count)개 계정 중 \(mailViewModel.enabledAccountIds.count)개 연동 중")
                    .font(.callout)
                    .foregroundColor(.secondary)

                Spacer()

                Button("완료") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    // MARK: - Account Row

    private func accountRow(_ account: MailAccount) -> some View {
        HStack(spacing: 16) {
            // 아이콘
            Image(systemName: mailViewModel.enabledAccountIds.contains(account.id) ? "envelope.circle.fill" : "envelope.circle")
                .font(.system(size: 32))
                .foregroundColor(mailViewModel.enabledAccountIds.contains(account.id) ? .blue : .secondary)

            // 계정 정보
            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .font(.headline)

                Text(account.emailAddress)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 토글
            Toggle("", isOn: Binding(
                get: { mailViewModel.enabledAccountIds.contains(account.id) },
                set: { _ in mailViewModel.toggleAccount(account.id) }
            ))
            .toggleStyle(.switch)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(mailViewModel.enabledAccountIds.contains(account.id) ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}
