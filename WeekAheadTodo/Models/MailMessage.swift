import Foundation

/// 메일 메시지 모델
struct MailMessage: Identifiable, Codable, Hashable {
    let id: UUID
    var sender: String
    var senderEmail: String
    var subject: String
    var body: String
    var date: Date
    var isRead: Bool
    var isStarred: Bool
    var hasAttachment: Bool

    // 일정 관련
    var extractedDate: Date?      // 본문에서 추출한 날짜
    var extractedDuration: Int?   // 추출한 소요 시간 (분)
    var containsSchedule: Bool    // 일정 정보 포함 여부

    init(
        id: UUID = UUID(),
        sender: String,
        senderEmail: String,
        subject: String,
        body: String,
        date: Date = Date(),
        isRead: Bool = false,
        isStarred: Bool = false,
        hasAttachment: Bool = false,
        extractedDate: Date? = nil,
        extractedDuration: Int? = nil,
        containsSchedule: Bool = false
    ) {
        self.id = id
        self.sender = sender
        self.senderEmail = senderEmail
        self.subject = subject
        self.body = body
        self.date = date
        self.isRead = isRead
        self.isStarred = isStarred
        self.hasAttachment = hasAttachment
        self.extractedDate = extractedDate
        self.extractedDuration = extractedDuration
        self.containsSchedule = containsSchedule
    }
}
