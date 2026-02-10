import Foundation

/// 메일 우선순위
enum MailPriority: String, Codable, CaseIterable {
    case high = "높음"
    case normal = "보통"
    case low = "낮음"
    
    var icon: String {
        switch self {
        case .high: return "exclamationmark.circle.fill"
        case .normal: return "minus.circle"
        case .low: return "arrow.down.circle"
        }
    }
    
    var color: String {
        switch self {
        case .high: return "red"
        case .normal: return "gray"
        case .low: return "blue"
        }
    }
}

/// 메일 모델
struct Mail: Identifiable, Codable, Hashable {
    let id: UUID
    var sender: String
    var senderEmail: String
    var recipients: [String]
    var ccRecipients: [String]
    var subject: String
    var body: String
    var date: Date
    var isRead: Bool
    var isStarred: Bool
    var isFlagged: Bool
    var hasAttachment: Bool
    var attachmentNames: [String]
    var priority: MailPriority
    var labels: [String]
    var mailboxID: UUID?
    var isArchived: Bool
    var isTrashed: Bool
    var isSpam: Bool
    var isDraft: Bool

    // IMAP 관련 필드
    var accountID: UUID?        // 어떤 계정의 메일인지
    var accountEmail: String?   // 메일을 받은 계정 이메일
    var imapUID: UInt32?        // IMAP 서버의 고유 ID
    var messageID: String?      // Message-ID 헤더
    var inReplyTo: String?      // In-Reply-To 헤더
    var needsSync: Bool = false // 서버 동기화 필요 여부
    
    init(
        id: UUID = UUID(),
        sender: String,
        senderEmail: String,
        recipients: [String] = [],
        ccRecipients: [String] = [],
        subject: String,
        body: String,
        date: Date = Date(),
        isRead: Bool = false,
        isStarred: Bool = false,
        isFlagged: Bool = false,
        hasAttachment: Bool = false,
        attachmentNames: [String] = [],
        priority: MailPriority = .normal,
        labels: [String] = [],
        mailboxID: UUID? = nil,
        isArchived: Bool = false,
        isTrashed: Bool = false,
        isSpam: Bool = false,
        isDraft: Bool = false,
        accountID: UUID? = nil,
        accountEmail: String? = nil,
        imapUID: UInt32? = nil,
        messageID: String? = nil,
        inReplyTo: String? = nil,
        needsSync: Bool = false
    ) {
        self.id = id
        self.sender = sender
        self.senderEmail = senderEmail
        self.recipients = recipients
        self.ccRecipients = ccRecipients
        self.subject = subject
        self.body = body
        self.date = date
        self.isRead = isRead
        self.isStarred = isStarred
        self.isFlagged = isFlagged
        self.hasAttachment = hasAttachment
        self.attachmentNames = attachmentNames
        self.priority = priority
        self.labels = labels
        self.mailboxID = mailboxID
        self.isArchived = isArchived
        self.isTrashed = isTrashed
        self.isSpam = isSpam
        self.isDraft = isDraft
        self.accountID = accountID
        self.accountEmail = accountEmail
        self.imapUID = imapUID
        self.messageID = messageID
        self.inReplyTo = inReplyTo
        self.needsSync = needsSync
    }
    
    /// 메일 본문 미리보기 (첫 100자)
    var bodyPreview: String {
        let cleaned = body.replacingOccurrences(of: "\n", with: " ")
        if cleaned.count > 100 {
            return String(cleaned.prefix(100)) + "..."
        }
        return cleaned
    }
    
    /// 상대 시간 표시
    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    /// 포맷된 날짜
    var formattedDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "a h:mm"
            formatter.locale = Locale(identifier: "ko_KR")
        } else if calendar.isDateInYesterday(date) {
            return "어제"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE"
            formatter.locale = Locale(identifier: "ko_KR")
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "M월 d일"
        } else {
            formatter.dateFormat = "yyyy. M. d."
        }
        
        return formatter.string(from: date)
    }
    
    /// 전체 날짜 포맷
    var fullFormattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일 (E) a h:mm"
        return formatter.string(from: date)
    }
}
