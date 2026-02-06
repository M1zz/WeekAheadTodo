import SwiftUI

/// 메일 통합 뷰
struct MailIntegrationView: View {
    @EnvironmentObject var mailViewModel: MailViewModel
    @EnvironmentObject var taskViewModel: TaskViewModel
    @State private var selectedMailIds: Set<UUID> = []
    @State private var mailLimit: Int = 50

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
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Mail.app 통합")
                    .font(.headline)

                Spacer()

                // 계정 선택
                if !mailViewModel.accounts.isEmpty {
                    Picker("계정", selection: $mailViewModel.selectedAccountName) {
                        Text("전체 계정").tag(String?.none)
                        ForEach(mailViewModel.accounts) { account in
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
