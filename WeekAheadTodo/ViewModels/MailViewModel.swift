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

    private let mailService = MailService.shared

    // MARK: - Initialization

    init() {
        // 저장된 연동 계정 목록 로드
        if let savedIds = UserDefaults.standard.array(forKey: "enabledMailAccountIds") as? [String] {
            self.enabledAccountIds = Set(savedIds)
        }
    }

    /// 연동 계정 설정 저장
    func saveEnabledAccounts() {
        UserDefaults.standard.set(Array(enabledAccountIds), forKey: "enabledMailAccountIds")
    }

    // MARK: - Account Loading

    /// 메일 계정 목록 가져오기 (캐시 우선)
    func loadAccounts() async {
        // 캐시된 데이터가 있으면 사용
        let cached = mailService.getCachedAccounts()
        if !cached.isEmpty {
            accounts = cached
            print("📦 [MailViewModel] 캐시된 계정 \(cached.count)개 사용")
            
            // 처음 로드 시 모든 계정을 기본으로 활성화
            if enabledAccountIds.isEmpty {
                enabledAccountIds = Set(accounts.map { $0.id })
                saveEnabledAccounts()
            }
            return
        }
        
        // 캐시 없으면 API 호출
        isLoading = true
        accounts = await mailService.fetchAccounts()
        isLoading = false

        // 처음 로드 시 모든 계정을 기본으로 활성화
        if enabledAccountIds.isEmpty && !accounts.isEmpty {
            enabledAccountIds = Set(accounts.map { $0.id })
            saveEnabledAccounts()
        }
    }
    
    /// 계정 강제 새로고침 (API 호출)
    func refreshAccounts() async {
        isLoading = true
        accounts = await mailService.fetchAccounts()
        isLoading = false
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

    /// 메일 가져오기 (캐시 우선)
    func loadMails(limit: Int = 50) async {
        // 캐시된 데이터가 있으면 사용
        let cached = mailService.getCachedMails()
        if !cached.isEmpty {
            mails = cached
            print("📦 [MailViewModel] 캐시된 메일 \(cached.count)개 사용")
            successMessage = "📦 캐시에서 \(mails.count)개 메일 로드"
            return
        }
        
        // 캐시 없으면 API 호출
        await refreshMails(limit: limit)
    }
    
    /// 메일 강제 새로고침 (API 호출)
    func refreshMails(limit: Int = 50) async {
        isLoading = true
        errorMessage = nil

        if showScheduleOnly {
            var fetchedMails = await mailService.fetchMailsWithSchedule(limit: limit, accountName: selectedAccountName)

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
            mails = await mailService.fetchRecentMails(limit: limit, accountName: selectedAccountName)
        }

        if let error = mailService.lastError {
            errorMessage = error
        } else {
            successMessage = "✅ \(mails.count)개 메일을 새로 가져왔습니다."
        }

        isLoading = false
    }

    /// Mail.app 연결 테스트
    func testConnection() async -> (success: Bool, message: String) {
        isLoading = true
        let result = await mailService.testMailAccess()
        isLoading = false
        
        if result.success {
            successMessage = result.message
        } else {
            errorMessage = result.message
        }
        
        return result
    }

    /// 선택한 메일들을 Task로 변환
    func convertMailsToTasks(mailIds: Set<UUID>, taskViewModel: TaskViewModel) {
        let selectedMails = mails.filter { mailIds.contains($0.id) }

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
        }

        successMessage = "✅ \(createdCount)개 메일을 태스크로 변환했습니다."
    }

    // MARK: - Computed Properties

    var selectedMail: MailMessage? {
        guard let id = selectedMailId else { return nil }
        return mails.first { $0.id == id }
    }
    
    /// 메일 읽음 처리
    func markSelectedAsRead() async {
        guard let mail = selectedMail, !mail.isRead else { return }
        
        await mailService.markAsRead(mail: mail)
        
        // 로컬 mails 배열도 업데이트
        if let index = mails.firstIndex(where: { $0.id == mail.id }) {
            mails[index].isRead = true
        }
    }

    /// 일정 포함 메일 개수
    var scheduleMailCount: Int {
        mails.filter { $0.containsSchedule }.count
    }
}
