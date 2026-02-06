import Foundation

/// 메일 통합 ViewModel
@MainActor
class MailViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var mails: [MailMessage] = []
    @Published var accounts: [MailAccount] = []
    @Published var enabledAccountIds: Set<String> = []  // 연동 활성화된 계정 ID
    @Published var selectedAccountName: String?  // nil이면 전체 계정
    @Published var selectedMailId: UUID?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var showScheduleOnly: Bool = false  // 일정 포함 메일만 표시

    // MARK: - Services

    private let mailService: MailService

    // MARK: - Initialization

    init() {
        self.mailService = MailService()

        // 저장된 연동 계정 목록 로드
        if let savedIds = UserDefaults.standard.array(forKey: "enabledMailAccountIds") as? [String] {
            self.enabledAccountIds = Set(savedIds)
        }
    }

    /// 연동 계정 설정 저장
    func saveEnabledAccounts() {
        UserDefaults.standard.set(Array(enabledAccountIds), forKey: "enabledMailAccountIds")
        print("✅ [MailViewModel] 연동 계정 저장: \(enabledAccountIds.count)개")
    }

    // MARK: - Account Loading

    /// 메일 계정 목록 가져오기
    func loadAccounts() {
        accounts = mailService.fetchAccounts()

        // 처음 로드 시 모든 계정을 기본으로 활성화
        if enabledAccountIds.isEmpty && !accounts.isEmpty {
            enabledAccountIds = Set(accounts.map { $0.id })
            saveEnabledAccounts()
        }

        print("📧 계정: \(accounts.count)개 (연동: \(enabledAccountIds.count)개)")
    }

    /// 계정 활성화/비활성화 토글
    func toggleAccount(_ accountId: String) {
        if enabledAccountIds.contains(accountId) {
            enabledAccountIds.remove(accountId)
        } else {
            enabledAccountIds.insert(accountId)
        }
        saveEnabledAccounts()
    }

    /// 연동 활성화된 계정 목록
    var enabledAccounts: [MailAccount] {
        accounts.filter { enabledAccountIds.contains($0.id) }
    }

    // MARK: - Mail Loading

    /// 메일 가져오기
    func loadMails(limit: Int = 50) async {
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🚀 메일 가져오기 시작")
        print("   • 계정: \(selectedAccountName ?? "전체 연동 계정")")
        print("   • 개수: \(limit)개")
        print("   • 필터: \(showScheduleOnly ? "일정만" : "전체")")
        print("   • 연동 계정 수: \(enabledAccountIds.count)개")

        isLoading = true
        errorMessage = nil

        do {
            if showScheduleOnly {
                var fetchedMails = mailService.fetchMailsWithSchedule(limit: limit, accountName: selectedAccountName)
                print("📊 일정 포함 메일: \(fetchedMails.count)개")

                // 일정 정보 추가
                for i in 0..<fetchedMails.count {
                    if let schedule = mailService.detectScheduleInMail(fetchedMails[i]) {
                        fetchedMails[i].extractedDate = schedule.date
                        fetchedMails[i].extractedDuration = schedule.duration
                        fetchedMails[i].containsSchedule = true
                    }
                }

                mails = fetchedMails
            } else {
                mails = mailService.fetchRecentMails(limit: limit, accountName: selectedAccountName)
                print("📊 전체 메일: \(mails.count)개")
            }

            successMessage = "✅ \(mails.count)개 메일을 가져왔습니다."

            if mails.isEmpty {
                print("⚠️ 메일이 0개입니다!")
                if enabledAccountIds.isEmpty {
                    print("   → 원인: 연동된 계정이 없음")
                } else if selectedAccountName != nil {
                    print("   → 원인: 선택된 계정에 메일이 없거나 Mail.app에 문제")
                } else {
                    print("   → 원인: Mail.app에 메일이 없거나 AppleScript 오류")
                }
            }

            print("✅ 완료")
        } catch {
            errorMessage = "메일을 가져올 수 없습니다: \(error.localizedDescription)"
            print("❌ 에러: \(error)")
        }

        isLoading = false
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }

    /// 선택한 메일들을 Task로 변환
    func convertMailsToTasks(mailIds: Set<UUID>, taskViewModel: TaskViewModel) {
        print("\n╔════════════════════════════════════════════════════════╗")
        print("║  메일 → 태스크 변환 시작                                ║")
        print("╚════════════════════════════════════════════════════════╝")

        let selectedMails = mails.filter { mailIds.contains($0.id) }
        print("   선택된 메일: \(selectedMails.count)개")

        var createdCount = 0

        for mail in selectedMails {
            // 일정 정보가 있으면 사용, 없으면 메일 받은 날짜 + 1일
            let dueDate: Date
            let duration: Int

            if let extractedDate = mail.extractedDate {
                dueDate = extractedDate
                duration = mail.extractedDuration ?? 60
            } else {
                // 메일 받은 날짜 다음 날
                dueDate = Calendar.current.date(byAdding: .day, value: 1, to: mail.date) ?? Date()
                duration = 60
            }

            // Task 생성
            let task = Task(
                title: mail.subject,
                description: "📧 \(mail.sender)에게서 온 메일\n\n\(mail.body.prefix(200))...",
                dueDate: dueDate,
                estimatedMinutes: duration,
                leadTimeDays: 0,
                taskType: .preparable,
                taskRole: .none,
                status: .notStarted
            )

            taskViewModel.addTask(task)
            createdCount += 1

            print("   ✅ [\(mail.sender)] \(mail.subject)")
        }

        successMessage = "✅ \(createdCount)개 메일을 태스크로 변환했습니다."
        print("\n📊 변환 완료: \(createdCount)개")
        print("════════════════════════════════════════════════════════\n")
    }

    // MARK: - Computed Properties

    var selectedMail: MailMessage? {
        guard let id = selectedMailId else { return nil }
        return mails.first { $0.id == id }
    }

    /// 일정 포함 메일 개수
    var scheduleMailCount: Int {
        mails.filter { $0.containsSchedule }.count
    }
}
