import Foundation
import AppKit

/// Mail.app에서 메일을 가져오는 서비스
@MainActor
class MailService {

    /// 받은 편지함에서 최근 메일 가져오기
    func fetchRecentMails(limit: Int = 50) -> [MailMessage] {
        print("📧 [MailService] 메일 가져오기 시작 (최대 \(limit)개)")

        let script = """
        tell application "Mail"
            set messageList to messages of inbox
            set messageCount to count of messageList
            if messageCount > \(limit) then
                set messageList to items 1 thru \(limit) of messageList
            end if

            set resultList to {}
            repeat with aMessage in messageList
                set messageInfo to {¬
                    subject of aMessage, ¬
                    sender of aMessage, ¬
                    date received of aMessage, ¬
                    read status of aMessage, ¬
                    flagged status of aMessage, ¬
                    content of aMessage, ¬
                    id of aMessage}
                set end of resultList to messageInfo
            end repeat
            return resultList
        end tell
        """

        guard let appleScript = NSAppleScript(source: script) else {
            print("❌ AppleScript 생성 실패")
            return []
        }

        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)

        if let error = error {
            print("❌ AppleScript 실행 오류: \(error)")
            return []
        }

        // AppleScript 결과 파싱
        var mails: [MailMessage] = []
        guard let listDescriptor = result.coerce(toDescriptorType: typeAEList) else {
            print("❌ 결과 파싱 실패")
            return []
        }

        for i in 1...listDescriptor.numberOfItems {
            guard let itemDescriptor = listDescriptor.atIndex(i),
                  let recordDescriptor = itemDescriptor.coerce(toDescriptorType: typeAEList) else {
                continue
            }

            // 각 필드 추출
            let subject = recordDescriptor.atIndex(1)?.stringValue ?? "제목 없음"
            let sender = recordDescriptor.atIndex(2)?.stringValue ?? "발신자 없음"
            let dateReceived = recordDescriptor.atIndex(3)?.dateValue ?? Date()
            let isRead = recordDescriptor.atIndex(4)?.booleanValue ?? false
            let isStarred = recordDescriptor.atIndex(5)?.booleanValue ?? false
            let body = recordDescriptor.atIndex(6)?.stringValue ?? ""
            let messageId = recordDescriptor.atIndex(7)?.int32Value ?? 0

            // 발신자 이메일 추출 (간단하게 전체 문자열 사용)
            let senderEmail = extractEmail(from: sender)

            // MailMessage 생성
            let mail = MailMessage(
                sender: sender,
                senderEmail: senderEmail,
                subject: subject,
                body: body,
                date: dateReceived,
                isRead: isRead,
                isStarred: isStarred,
                hasAttachment: false
            )

            mails.append(mail)
        }

        print("✅ [MailService] \(mails.count)개 메일 가져오기 완료")
        return mails
    }

    /// 일정이 포함된 메일만 필터링
    func fetchMailsWithSchedule(limit: Int = 50) -> [MailMessage] {
        let allMails = fetchRecentMails(limit: limit)
        return allMails.filter { detectScheduleInMail($0) != nil }
    }

    /// 메일에서 일정 정보 감지
    func detectScheduleInMail(_ mail: MailMessage) -> (date: Date, duration: Int)? {
        let text = mail.subject + " " + mail.body

        // 날짜 패턴 감지
        let datePatterns = [
            // "내일", "모레"
            ("내일", Calendar.current.date(byAdding: .day, value: 1, to: Date())),
            ("모레", Calendar.current.date(byAdding: .day, value: 2, to: Date())),
            // "다음주 월요일" 등
        ]

        var extractedDate: Date?
        for (pattern, date) in datePatterns {
            if text.contains(pattern), let date = date {
                extractedDate = date
                break
            }
        }

        // 시간 패턴 감지 (예: "3시간", "30분")
        var extractedDuration: Int = 60 // 기본 1시간
        if let hoursMatch = text.range(of: #"(\d+)시간"#, options: .regularExpression) {
            let hoursStr = String(text[hoursMatch]).replacingOccurrences(of: "시간", with: "")
            if let hours = Int(hoursStr) {
                extractedDuration = hours * 60
            }
        } else if let minutesMatch = text.range(of: #"(\d+)분"#, options: .regularExpression) {
            let minutesStr = String(text[minutesMatch]).replacingOccurrences(of: "분", with: "")
            if let minutes = Int(minutesStr) {
                extractedDuration = minutes
            }
        }

        if let date = extractedDate {
            return (date, extractedDuration)
        }

        // 날짜 정보가 없으면 메일 받은 시간 기준
        return nil
    }

    /// 이메일 주소 추출 (간단한 버전)
    private func extractEmail(from sender: String) -> String {
        // "홍길동 <hong@example.com>" 형식에서 이메일 추출
        if let emailMatch = sender.range(of: #"<(.+?)>"#, options: .regularExpression) {
            let email = String(sender[emailMatch])
                .replacingOccurrences(of: "<", with: "")
                .replacingOccurrences(of: ">", with: "")
            return email
        }
        return sender
    }
}

// MARK: - NSAppleEventDescriptor Extensions

extension NSAppleEventDescriptor {
    var booleanValue: Bool {
        return self.int32Value != 0
    }

    var dateValue: Date? {
        guard let dateStr = self.stringValue else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return formatter.date(from: dateStr) ?? Date()
    }
}
