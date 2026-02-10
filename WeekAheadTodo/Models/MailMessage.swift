import Foundation

/// 메일 계정 정보
struct MailAccount: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let emailAddress: String
}

/// 메일 메시지 모델
struct MailMessage: Identifiable, Codable, Hashable {
    let id: UUID
    var mailAppId: String?  // Mail.app의 실제 message ID
    var sender: String
    var senderEmail: String
    var subject: String
    var body: String
    var date: Date
    var isRead: Bool
    var isStarred: Bool
    var hasAttachment: Bool
    var accountEmail: String?  // 어느 계정에서 온 메일인지

    // 일정 관련
    var extractedDate: Date?      // 본문에서 추출한 날짜
    var extractedDuration: Int?   // 추출한 소요 시간 (분)
    var containsSchedule: Bool    // 일정 정보 포함 여부

    init(
        id: UUID = UUID(),
        mailAppId: String? = nil,
        sender: String,
        senderEmail: String,
        subject: String,
        body: String,
        date: Date = Date(),
        isRead: Bool = false,
        isStarred: Bool = false,
        hasAttachment: Bool = false,
        accountEmail: String? = nil,
        extractedDate: Date? = nil,
        extractedDuration: Int? = nil,
        containsSchedule: Bool = false
    ) {
        self.id = id
        self.mailAppId = mailAppId
        self.sender = sender
        self.senderEmail = senderEmail
        self.subject = subject
        self.body = body
        self.date = date
        self.isRead = isRead
        self.isStarred = isStarred
        self.hasAttachment = hasAttachment
        self.accountEmail = accountEmail
        self.extractedDate = extractedDate
        self.extractedDuration = extractedDuration
        self.containsSchedule = containsSchedule
    }
}
