import Foundation
import AppKit

/// Mail.app에서 메일을 가져오는 서비스
@MainActor
class MailService {

    /// 사용 가능한 메일 계정 목록 가져오기
    func fetchAccounts() -> [MailAccount] {
        print("📧 [MailService] 메일 계정 목록 가져오기")

        let script = """
        -- Mail.app이 실행되지 않았으면 숨김 상태로 실행
        if not (application "Mail" is running) then
            tell application "Mail" to launch
            delay 0.5
        end if

        tell application "Mail"
            set visible to false
            set accountList to {}
            repeat with acc in accounts
                set accountInfo to {¬
                    name of acc, ¬
                    id of acc}
                set end of accountList to accountInfo
            end repeat
            return accountList
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

        // 결과 파싱
        var accounts: [MailAccount] = []
        guard let listDescriptor = result.coerce(toDescriptorType: typeAEList) else {
            print("❌ 계정 목록 파싱 실패")
            return []
        }

        for i in 1...listDescriptor.numberOfItems {
            guard let itemDescriptor = listDescriptor.atIndex(i),
                  let recordDescriptor = itemDescriptor.coerce(toDescriptorType: typeAEList) else {
                continue
            }

            let name = recordDescriptor.atIndex(1)?.stringValue ?? "알 수 없는 계정"
            let accountId = recordDescriptor.atIndex(2)?.stringValue ?? UUID().uuidString

            let account = MailAccount(
                id: accountId,
                name: name,
                emailAddress: name // Mail.app에서 이메일 주소 추출은 복잡하므로 이름 사용
            )

            accounts.append(account)
            print("   ✅ 계정 발견: \(name)")
        }

        print("✅ [MailService] \(accounts.count)개 계정 발견")
        return accounts
    }

    /// 받은 편지함에서 최근 메일 가져오기
    /// - Parameters:
    ///   - limit: 가져올 메일 최대 개수
    ///   - accountName: 특정 계정 이름 (nil이면 전체 받은편지함)
    func fetchRecentMails(limit: Int = 50, accountName: String? = nil) -> [MailMessage] {
        if let accountName = accountName {
            print("📧 [MailService] 메일 가져오기 시작 (계정: \(accountName), 최대 \(limit)개)")
        } else {
            print("📧 [MailService] 메일 가져오기 시작 (전체 계정, 최대 \(limit)개)")
        }

        // AppleScript 생성 - 계정별로 다르게
        let inboxSource: String
        if let accountName = accountName {
            // 특정 계정의 받은편지함
            inboxSource = "inbox of account \"\(accountName)\""
        } else {
            // 전체 받은편지함 (모든 계정 통합)
            inboxSource = "inbox"
        }

        let script = """
        -- Mail.app이 실행되지 않았으면 숨김 상태로 실행
        if not (application "Mail" is running) then
            tell application "Mail" to launch
            delay 0.5
        end if

        tell application "Mail"
            set visible to false
            set messageList to messages of \(inboxSource)
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
            print("❌ AppleScript 실행 오류:")
            print("   Error Number: \(error["NSAppleScriptErrorNumber"] ?? "unknown")")
            print("   Error Message: \(error["NSAppleScriptErrorMessage"] ?? "unknown")")
            print("   Full Error: \(error)")
            return []
        }

        print("✅ AppleScript 실행 완료")
        print("   Result Type: \(result.descriptorType)")
        print("   Result Description: \(result)")

        // AppleScript 결과 파싱
        var mails: [MailMessage] = []
        guard let listDescriptor = result.coerce(toDescriptorType: typeAEList) else {
            print("❌ 결과 파싱 실패 - List로 변환 불가")
            print("   Result Type: \(result.descriptorType)")
            print("   Expected: \(typeAEList)")
            return []
        }

        print("✅ List 변환 성공 - 아이템 개수: \(listDescriptor.numberOfItems)")

        for i in 1...listDescriptor.numberOfItems {
            guard let itemDescriptor = listDescriptor.atIndex(i) else {
                print("⚠️ 아이템 \(i) 가져오기 실패")
                continue
            }

            guard let recordDescriptor = itemDescriptor.coerce(toDescriptorType: typeAEList) else {
                print("⚠️ 아이템 \(i) Record 변환 실패")
                continue
            }

            print("   메일 \(i) 파싱 중... (필드 수: \(recordDescriptor.numberOfItems))")

            // 각 필드 추출
            let subject = recordDescriptor.atIndex(1)?.stringValue ?? "제목 없음"
            let sender = recordDescriptor.atIndex(2)?.stringValue ?? "발신자 없음"
            let dateReceived = recordDescriptor.atIndex(3)?.dateValue ?? Date()
            let isRead = recordDescriptor.atIndex(4)?.booleanValue ?? false
            let isStarred = recordDescriptor.atIndex(5)?.booleanValue ?? false
            let body = recordDescriptor.atIndex(6)?.stringValue ?? ""
            let messageId = recordDescriptor.atIndex(7)?.int32Value ?? 0

            print("      제목: \(subject.prefix(50))...")

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
    func fetchMailsWithSchedule(limit: Int = 50, accountName: String? = nil) -> [MailMessage] {
        let allMails = fetchRecentMails(limit: limit, accountName: accountName)
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
