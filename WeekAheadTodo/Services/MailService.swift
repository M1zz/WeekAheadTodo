import Foundation
import AppKit

/// Mail.app에서 메일을 가져오는 서비스
/// MailAppService를 래핑하여 기존 인터페이스 유지
@MainActor
class MailService: ObservableObject {
    
    static let shared = MailService()
    
    private let mailAppService = MailAppService.shared
    
    @Published var isLoading = false
    @Published var lastError: String?
    @Published var accounts: [MailAccount] = []
    @Published var recentMails: [MailMessage] = []
    
    // 캐시 파일 경로
    private var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WeekAheadTodo", isDirectory: true)
    }
    private var accountsCacheFile: URL { cacheDirectory.appendingPathComponent("mail_accounts.json") }
    private var mailsCacheFile: URL { cacheDirectory.appendingPathComponent("mail_messages.json") }
    
    private init() {
        // 캐시 디렉토리 생성
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        // 캐시에서 로드 (메인 스레드에서 지연 실행)
        DispatchQueue.main.async { [weak self] in
            self?.loadFromCache()
        }
    }
    
    // MARK: - 캐시
    
    /// 캐시에서 로드
    private func loadFromCache() {
        // 계정 로드
        if let data = try? Data(contentsOf: accountsCacheFile),
           let cached = try? JSONDecoder().decode([MailAccount].self, from: data) {
            accounts = cached
            print("📦 [MailService] 캐시에서 계정 \(cached.count)개 로드")
        }
        
        // 메일 로드
        if let data = try? Data(contentsOf: mailsCacheFile),
           let cached = try? JSONDecoder().decode([MailMessage].self, from: data) {
            recentMails = cached
            print("📦 [MailService] 캐시에서 메일 \(cached.count)개 로드")
        }
    }
    
    /// 캐시에 저장
    private func saveToCache() {
        // 계정 저장
        if let data = try? JSONEncoder().encode(accounts) {
            try? data.write(to: accountsCacheFile)
            print("💾 [MailService] 계정 \(accounts.count)개 캐시 저장")
        }
        
        // 메일 저장
        if let data = try? JSONEncoder().encode(recentMails) {
            try? data.write(to: mailsCacheFile)
            print("💾 [MailService] 메일 \(recentMails.count)개 캐시 저장")
        }
    }
    
    /// 캐시된 데이터가 있는지
    var hasCachedData: Bool {
        !accounts.isEmpty || !recentMails.isEmpty
    }
    
    // MARK: - 계정
    
    /// 계정 목록 가져오기
    func fetchAccounts() async -> [MailAccount] {
        isLoading = true
        lastError = nil
        
        do {
            print("📧 [MailService] 계정 목록 가져오는 중...")
            let mailAccounts = try await mailAppService.getAccounts()
            let result = mailAccounts.map { account in
                MailAccount(
                    id: account.name,  // 이름으로 ID 사용 (중복 이메일 문제 해결)
                    name: account.name,
                    emailAddress: account.email
                )
            }
            accounts = result
            saveToCache()
            print("✅ [MailService] 계정 \(result.count)개 로드 완료")
            isLoading = false
            return result
        } catch {
            print("❌ [MailService] 계정 로드 실패: \(error.localizedDescription)")
            lastError = error.localizedDescription
            isLoading = false
            return []
        }
    }
    
    /// 캐시된 계정 반환 (API 호출 안 함)
    func getCachedAccounts() -> [MailAccount] {
        return accounts
    }
    
    // MARK: - 메일 목록
    
    /// 최근 메일 가져오기
    func fetchRecentMails(limit: Int = 50, accountName: String? = nil) async -> [MailMessage] {
        isLoading = true
        lastError = nil
        
        do {
            print("📧 [MailService] 메일 \(limit)개 가져오는 중...")
            let messages = try await mailAppService.getMessages(offset: 1, limit: limit)
            print("📧 [MailService] MailAppService에서 \(messages.count)개 받음")
            
            let result = messages.compactMap { msg -> MailMessage? in
                // accountName 필터 적용
                if let accountName = accountName, msg.account != accountName {
                    return nil
                }
                return MailMessage(
                    id: UUID(),
                    mailAppId: msg.id,
                    sender: msg.sender,
                    senderEmail: msg.senderEmail,
                    subject: msg.subject,
                    body: msg.content ?? "",
                    date: msg.dateReceived,
                    isRead: msg.isRead,
                    isStarred: msg.isFlagged,
                    hasAttachment: false,
                    accountEmail: msg.account
                )
            }
            
            recentMails = result
            saveToCache()
            print("✅ [MailService] 메일 \(result.count)개 로드 완료")
            isLoading = false
            return result
        } catch {
            print("❌ [MailService] 메일 로드 실패: \(error.localizedDescription)")
            lastError = error.localizedDescription
            isLoading = false
            return []
        }
    }
    
    /// 캐시된 메일 반환 (API 호출 안 함)
    func getCachedMails() -> [MailMessage] {
        return recentMails
    }
    
    /// 메일 읽음 상태 변경
    func markAsRead(mail: MailMessage) async {
        guard let mailAppId = mail.mailAppId else {
            print("❌ [MailService] mailAppId 없음")
            return
        }
        
        do {
            try await mailAppService.markAsRead(messageId: mailAppId, isRead: true)
            print("✅ [MailService] 메일 읽음 처리: \(mail.subject)")
            
            // 로컬 상태도 업데이트
            if let index = recentMails.firstIndex(where: { $0.id == mail.id }) {
                recentMails[index].isRead = true
                saveToCache()
            }
        } catch {
            print("❌ [MailService] 읽음 처리 실패: \(error)")
        }
    }
    
    /// 메일 본문 가져오기
    func fetchMailBody(subject: String, date: Date) async -> String? {
        do {
            let messages = try await mailAppService.getMessages(offset: 1, limit: 100)
            if let msg = messages.first(where: { 
                $0.subject == subject && 
                Calendar.current.isDate($0.dateReceived, inSameDayAs: date)
            }) {
                return msg.content
            }
        } catch {
            print("❌ [MailService] 메일 본문 로드 실패: \(error)")
        }
        return nil
    }
    
    // MARK: - 권한
    
    /// Mail.app 권한 요청 및 실행 확인
    func requestMailAccess() async -> Bool {
        do {
            print("📧 [MailService] Mail.app 권한 확인 중...")
            try await mailAppService.ensureMailAppRunning()
            print("✅ [MailService] Mail.app 권한 OK")
            return true
        } catch {
            print("❌ [MailService] Mail.app 권한 실패: \(error.localizedDescription)")
            lastError = error.localizedDescription
            return false
        }
    }
    
    /// 메일 접근 테스트
    func testMailAccess() async -> (success: Bool, message: String) {
        do {
            // 1. Mail.app 실행 확인
            try await mailAppService.ensureMailAppRunning()
            
            // 2. 계정 가져오기
            let accounts = try await mailAppService.getAccounts()
            guard !accounts.isEmpty else {
                return (false, "Mail.app에 계정이 없습니다")
            }
            
            // 3. 메일 개수 확인
            let count = try await mailAppService.getInboxCount()
            
            return (true, "성공! \(accounts.count)개 계정, \(count)개 메일")
        } catch {
            return (false, "실패: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 일정 감지
    
    /// 일정이 포함된 메일만 가져오기
    func fetchMailsWithSchedule(limit: Int = 50, accountName: String? = nil) async -> [MailMessage] {
        let allMails = await fetchRecentMails(limit: limit * 2, accountName: accountName)
        
        // 일정 관련 키워드가 포함된 메일만 필터링
        let scheduleKeywords = ["회의", "미팅", "약속", "일정", "meeting", "schedule", "appointment",
                                 "시", "분", "오전", "오후", "AM", "PM", "월", "일", "요일"]
        
        return Array(allMails.filter { mail in
            let text = (mail.subject + " " + mail.body).lowercased()
            return scheduleKeywords.contains { keyword in
                text.contains(keyword.lowercased())
            }
        }.prefix(limit))
    }
    
    /// 메일에서 일정 정보 감지
    func detectScheduleInMail(_ mail: MailMessage) -> (date: Date, duration: Int)? {
        let text = mail.subject + " " + mail.body
        
        // 날짜 패턴 감지
        let dateDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        
        if let match = dateDetector?.firstMatch(in: text, options: [], range: range),
           let detectedDate = match.date {
            // 기본 소요 시간 60분
            var duration = 60
            
            // 시간 패턴에서 소요 시간 추출 시도
            if text.contains("30분") { duration = 30 }
            else if text.contains("1시간") || text.contains("한시간") { duration = 60 }
            else if text.contains("2시간") || text.contains("두시간") { duration = 120 }
            else if text.contains("3시간") || text.contains("세시간") { duration = 180 }
            
            return (date: detectedDate, duration: duration)
        }
        
        return nil
    }
}
