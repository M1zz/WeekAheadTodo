import SwiftUI

/// 메일 통합 뷰
struct MailIntegrationView: View {
    @EnvironmentObject var mailViewModel: MailViewModel
    @EnvironmentObject var taskViewModel: TaskViewModel
    @State private var selectedMailIds: Set<UUID> = []
    @State private var mailLimit: Int = 50
    @State private var showAccountSettingsSheet: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            headerSection

            Divider()

            // 메일 목록
            if mailViewModel.isLoading {
                ProgressView("메일 로딩 중...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if mailViewModel.mails.isEmpty {
                emptyStateView
            } else {
                mailListSection
            }
        }
        .navigationTitle("📧 메일")
        .task {
            // 계정 목록 먼저 로드
            mailViewModel.loadAccounts()
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

                // 계정 선택 (연동된 계정만)
                if !mailViewModel.enabledAccounts.isEmpty {
                    Picker("계정", selection: $mailViewModel.selectedAccountName) {
                        Text("전체 연동 계정").tag(String?.none)
                        ForEach(mailViewModel.enabledAccounts) { account in
                            Text(account.name).tag(String?.some(account.name))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 200)
                    .onChange(of: mailViewModel.selectedAccountName) { oldValue, newValue in
                        _Concurrency.Task {
                            await mailViewModel.loadMails(limit: mailLimit)
                        }
                    }
                }

                // 메일 개수 선택
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
                        await mailViewModel.loadMails(limit: mailLimit)
                    }
                }

                // 일정만 표시 토글
                Toggle("일정만", isOn: $mailViewModel.showScheduleOnly)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: mailViewModel.showScheduleOnly) { oldValue, newValue in
                        _Concurrency.Task {
                            await mailViewModel.loadMails(limit: mailLimit)
                        }
                    }

                // 새로고침 버튼
                Button {
                    _Concurrency.Task {
                        await mailViewModel.loadMails(limit: mailLimit)
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
            ForEach(mailViewModel.mails) { mail in
                mailRow(mail: mail)
                    .tag(mail.id)
            }
        }
        .listStyle(.inset)
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
            Image(systemName: "envelope.open")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("메일이 없습니다")
                .font(.title3)
                .fontWeight(.medium)

            Text("Mail.app의 받은 편지함에 메일이 없거나\n접근 권한이 필요합니다.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                _Concurrency.Task {
                    await mailViewModel.loadMails(limit: mailLimit)
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
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("사용 가능한 메일 계정이 없습니다")
                    .font(.headline)

                Text("Mail.app에서 먼저 메일 계정을 추가해주세요")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.internetaccounts")!)
                } label: {
                    Label("시스템 설정 - 인터넷 계정", systemImage: "gear")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    NSWorkspace.shared.launchApplication("Mail")
                } label: {
                    Label("Mail.app 열기", systemImage: "envelope")
                }
                .buttonStyle(.bordered)

                Button {
                    mailViewModel.loadAccounts()
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
