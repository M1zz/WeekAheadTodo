//
//  MailAppService.swift
//  MailFilter
//
//  AppleScript로 Mail.app 제어하는 서비스
//

import Foundation
import AppKit

/// Mail.app AppleScript 서비스 에러
enum MailAppServiceError: Error, LocalizedError {
    case scriptExecutionFailed(String)
    case mailAppNotRunning
    case invalidResponse
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .scriptExecutionFailed(let message):
            return "스크립트 실행 실패: \(message)"
        case .mailAppNotRunning:
            return "Mail.app이 실행되지 않았습니다."
        case .invalidResponse:
            return "잘못된 응답입니다."
        case .parseError(let message):
            return "파싱 오류: \(message)"
        }
    }
}

/// Mail.app 계정 정보
struct MailAppAccount: Identifiable, Codable {
    let id = UUID()
    let name: String
    let email: String

    enum CodingKeys: String, CodingKey {
        case name, email
    }
}

/// Mail.app 메일함 정보
struct MailAppMailbox: Identifiable {
    let id = UUID()
    let name: String
    let account: String?
}

/// Mail.app 메일 정보
struct MailAppMessage: Identifiable {
    let id: String // Message ID
    let subject: String
    let sender: String
    let senderEmail: String
    let dateReceived: Date
    let isRead: Bool
    let isFlagged: Bool
    let content: String?
    let account: String?
}

/// Mail.app 제어 서비스
@MainActor
class MailAppService {

    static let shared = MailAppService()

    private init() {}

    // MARK: - Mail.app 제어

    /// Mail.app 실행 확인 및 시작
    func ensureMailAppRunning() async throws {
        let script = """
        tell application "Mail"
            if not running then
                activate
                delay 2
            end if
            return "running"
        end tell
        """

        _ = try await executeScript(script)
    }

    // MARK: - 계정 관리

    /// 모든 계정 가져오기
    func getAccounts() async throws -> [MailAppAccount] {
        let script = """
        tell application "Mail"
            set accountList to {}
            repeat with acc in accounts
                set accountName to name of acc
                set accountEmails to email addresses of acc
                if (count of accountEmails) > 0 then
                    set accountEmail to item 1 of accountEmails
                    set end of accountList to {accountName, accountEmail}
                end if
            end repeat
            return accountList
        end tell
        """

        print("📧 [MailAppService] getAccounts 스크립트 실행 중...")
        let result = try await executeScript(script)
        print("📧 [MailAppService] getAccounts 결과: '\(result)'")
        let accounts = try parseAccountsResponse(result)
        print("📧 [MailAppService] 파싱된 계정 수: \(accounts.count)")
        return accounts
    }

    // MARK: - 메일함 관리

    /// 특정 계정의 메일함 목록
    func getMailboxes(accountName: String? = nil) async throws -> [MailAppMailbox] {
        let script: String

        if let accountName = accountName {
            script = """
            tell application "Mail"
                set boxList to {}
                set acc to account "\(accountName)"
                repeat with box in mailboxes of acc
                    set end of boxList to name of box
                end repeat
                return boxList
            end tell
            """
        } else {
            script = """
            tell application "Mail"
                set boxList to {}
                repeat with box in mailboxes
                    set end of boxList to name of box
                end repeat
                return boxList
            end tell
            """
        }

        let result = try await executeScript(script)
        return try parseMailboxesResponse(result, account: accountName)
    }

    // MARK: - 메일 조회

    /// Inbox 메일 개수
    func getInboxCount() async throws -> Int {
        let script = """
        tell application "Mail"
            return count of messages of inbox
        end tell
        """

        let result = try await executeScript(script)
        return Int(result.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    /// 모든 계정의 Inbox에서 메일 가져오기
    /// - Parameters:
    ///   - offset: 시작 인덱스 (1부터 시작)
    ///   - limit: 가져올 개수
    func getMessages(offset: Int = 1, limit: Int = 50) async throws -> [MailAppMessage] {
        // 계정별로 INBOX/Inbox 메일함에서 가져오기
        let perAccount = max(5, limit / 4)
        let script = """
        tell application "Mail"
            set msgList to {}
            set kstOffset to 9 * 60 * 60
            
            repeat with acc in accounts
                set accountEmail to ""
                try
                    set accEmails to email addresses of acc
                    if (count of accEmails) > 0 then
                        set accountEmail to item 1 of accEmails
                    end if
                end try
                
                -- INBOX 또는 Inbox 메일함 찾기
                set inboxBox to missing value
                repeat with box in mailboxes of acc
                    set boxName to name of box
                    if boxName is "INBOX" or boxName is "Inbox" then
                        set inboxBox to box
                        exit repeat
                    end if
                end repeat
                
                if inboxBox is not missing value then
                    try
                        set inboxMsgs to messages of inboxBox
                        set msgCount to count of inboxMsgs
                        
                        set endIdx to \(perAccount)
                        if endIdx > msgCount then
                            set endIdx to msgCount
                        end if
                        
                        repeat with i from 1 to endIdx
                            try
                                set msg to item i of inboxMsgs
                                set msgSubject to subject of msg
                                set msgSender to sender of msg
                                set msgDate to date received of msg
                                set msgRead to read status of msg
                                set msgFlagged to flagged status of msg
                                set msgId to id of msg as string
                                
                                -- 내용 가져오기 (처음 1500자만, 개행을 공백으로)
                                set msgContent to ""
                                try
                                    set msgContent to content of msg
                                    if length of msgContent > 1500 then
                                        set msgContent to text 1 thru 1500 of msgContent
                                    end if
                                end try
                                
                                -- Unix timestamp 변환 (KST 보정)
                                set unixEpoch to current date
                                set year of unixEpoch to 1970
                                set month of unixEpoch to 1
                                set day of unixEpoch to 1
                                set hours of unixEpoch to 0
                                set minutes of unixEpoch to 0
                                set seconds of unixEpoch to 0
                                set msgTimestamp to ((msgDate - unixEpoch) - kstOffset) as integer
                                
                                -- content는 Base64로 인코딩하여 구분자 문제 회피
                                set msgInfo to msgId & "|||" & msgSubject & "|||" & msgSender & "|||" & msgTimestamp & "|||" & msgRead & "|||" & msgFlagged & "|||" & accountEmail & "|||" & msgContent
                                copy msgInfo to end of msgList
                            end try
                        end repeat
                    end try
                end if
            end repeat
            
            set AppleScript's text item delimiters to ":::"
            set msgListStr to msgList as string
            set AppleScript's text item delimiters to ""
            
            return msgListStr
        end tell
        """

        let result = try await executeScript(script)
        return try parseMessagesResponse(result)
    }

    /// 메일 내용 가져오기
    func getMessageContent(messageId: String) async throws -> String {
        let script = """
        tell application "Mail"
            set msg to first message of inbox whose id is \(messageId)
            return content of msg
        end tell
        """

        return try await executeScript(script)
    }

    /// 메일 읽음 상태 변경
    func markAsRead(messageId: String, isRead: Bool) async throws {
        let script = """
        tell application "Mail"
            set msg to first message of inbox whose id is \(messageId)
            set read status of msg to \(isRead)
        end tell
        """

        _ = try await executeScript(script)
    }

    /// 메일 플래그 변경
    func setFlagged(messageId: String, isFlagged: Bool) async throws {
        let script = """
        tell application "Mail"
            set msg to first message of inbox whose id is \(messageId)
            set flagged status of msg to \(isFlagged)
        end tell
        """

        _ = try await executeScript(script)
    }

    // MARK: - 메일 전송

    /// 메일 보내기
    /// - Parameters:
    ///   - to: 받는 사람 이메일
    ///   - subject: 제목
    ///   - body: 본문
    ///   - cc: 참조 (선택)
    ///   - bcc: 숨은 참조 (선택)
    /// - Returns: 성공 여부
    func sendMail(to: String, subject: String, body: String, cc: String? = nil, bcc: String? = nil) async throws {
        // AppleScript 특수문자 이스케이프
        let escapedSubject = subject.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedBody = body.replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")

        var recipientParts = """
            make new to recipient at end of to recipients with properties {address:"\(to)"}
        """

        if let cc = cc, !cc.isEmpty {
            recipientParts += """

                make new cc recipient at end of cc recipients with properties {address:"\(cc)"}
            """
        }

        if let bcc = bcc, !bcc.isEmpty {
            recipientParts += """

                make new bcc recipient at end of bcc recipients with properties {address:"\(bcc)"}
            """
        }

        let script = """
        tell application "Mail"
            set newMessage to make new outgoing message with properties {subject:"\(escapedSubject)", content:"\(escapedBody)", visible:false}
            tell newMessage
                \(recipientParts)
            end tell
            send newMessage
        end tell
        """

        print("📤 메일 전송 시도: \(to)")
        _ = try await executeScript(script)
        print("✅ 메일 전송 완료")
    }

    /// 메일 작성 화면 열기 (보내지 않고 초안으로)
    func composeMail(to: String, subject: String, body: String, cc: String? = nil) async throws {
        let escapedSubject = subject.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedBody = body.replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")

        var recipientParts = """
            make new to recipient at end of to recipients with properties {address:"\(to)"}
        """

        if let cc = cc, !cc.isEmpty {
            recipientParts += """

                make new cc recipient at end of cc recipients with properties {address:"\(cc)"}
            """
        }

        let script = """
        tell application "Mail"
            activate
            set newMessage to make new outgoing message with properties {subject:"\(escapedSubject)", content:"\(escapedBody)", visible:true}
            tell newMessage
                \(recipientParts)
            end tell
        end tell
        """

        print("📝 메일 작성 화면 열기: \(to)")
        _ = try await executeScript(script)
    }

    /// 답장 메일 작성
    func replyToMail(messageId: String, body: String, replyAll: Bool = false) async throws {
        let escapedBody = body.replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")

        let replyType = replyAll ? "reply to" : "reply to"

        let script = """
        tell application "Mail"
            set originalMsg to first message of inbox whose id is \(messageId)
            set replyMsg to \(replyType) originalMsg with opening window
            tell replyMsg
                set content to "\(escapedBody)" & return & return & content
            end tell
            activate
        end tell
        """

        _ = try await executeScript(script)
    }

    // MARK: - 검색

    /// 메일 검색
    func searchMessages(query: String, limit: Int = 50) async throws -> [MailAppMessage] {
        let script = """
        tell application "Mail"
            set msgList to {}
            set searchResults to (messages of inbox whose subject contains "\(query)" or sender contains "\(query)")
            set resultCount to count of searchResults

            if resultCount = 0 then
                return ""
            end if

            set endIdx to \(limit)
            if endIdx > resultCount then
                set endIdx to resultCount
            end if

            -- KST 시간대 오프셋 (UTC+9 = 32400초)
            set kstOffset to 9 * 60 * 60

            repeat with i from 1 to endIdx
                set msg to item i of searchResults
                try
                    set msgSubject to subject of msg
                    set msgSender to sender of msg
                    set msgDate to date received of msg
                    set msgRead to read status of msg
                    set msgFlagged to flagged status of msg
                    set msgId to id of msg as string

                    -- 날짜를 Unix timestamp로 변환 (KST 보정)
                    set unixEpoch to current date
                    set year of unixEpoch to 1970
                    set month of unixEpoch to 1
                    set day of unixEpoch to 1
                    set hours of unixEpoch to 0
                    set minutes of unixEpoch to 0
                    set seconds of unixEpoch to 0
                    set msgTimestamp to ((msgDate - unixEpoch) - kstOffset) as integer

                    set msgInfo to msgId & "|||" & msgSubject & "|||" & msgSender & "|||" & msgTimestamp & "|||" & msgRead & "|||" & msgFlagged
                    set end of msgList to msgInfo
                end try
            end repeat

            set AppleScript's text item delimiters to ":::"
            set msgListStr to msgList as string
            set AppleScript's text item delimiters to ""

            return msgListStr
        end tell
        """

        let result = try await executeScript(script)
        return try parseMessagesResponse(result)
    }

    // MARK: - AppleScript 실행

    private func executeScript(_ script: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                print("🔧 [AppleScript] osascript로 실행 중...")
                
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", script]
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                    
                    if process.terminationStatus != 0 {
                        print("❌ [AppleScript] osascript 에러: \(errorOutput)")
                        continuation.resume(throwing: MailAppServiceError.scriptExecutionFailed(errorOutput))
                        return
                    }
                    
                    print("✅ [AppleScript] 성공, 결과 길이: \(output.count)자")
                    if !output.isEmpty {
                        print("✅ [AppleScript] 결과 미리보기: \(String(output.prefix(200)))")
                    }
                    continuation.resume(returning: output)
                } catch {
                    print("❌ [AppleScript] Process 실행 실패: \(error)")
                    continuation.resume(throwing: MailAppServiceError.scriptExecutionFailed(error.localizedDescription))
                }
            }
        }
    }

    // MARK: - 응답 파싱

    private func parseAccountsResponse(_ response: String) throws -> [MailAppAccount] {
        // "name1, email1, name2, email2, ..." 형식
        let parts = response.components(separatedBy: ", ")
        var accounts: [MailAppAccount] = []

        for i in stride(from: 0, to: parts.count - 1, by: 2) {
            let name = parts[i]
            let email = parts[i + 1]
            accounts.append(MailAppAccount(name: name, email: email))
        }

        return accounts
    }

    private func parseMailboxesResponse(_ response: String, account: String?) throws -> [MailAppMailbox] {
        let names = response.components(separatedBy: ", ")
        return names.map { MailAppMailbox(name: $0, account: account) }
    }

    private func parseMessagesResponse(_ response: String) throws -> [MailAppMessage] {
        if response.isEmpty {
            return []
        }

        let messages = response.components(separatedBy: ":::")
        var result: [MailAppMessage] = []

        for msgStr in messages {
            let parts = msgStr.components(separatedBy: "|||")
            guard parts.count >= 6 else { continue }

            let messageId = parts[0]
            let subject = parts[1]
            let sender = parts[2]
            let timestampStr = parts[3]
            let isRead = parts[4] == "true"
            let isFlagged = parts[5] == "true"
            let accountEmail = parts.count >= 7 ? parts[6] : nil
            
            // content는 8번째 필드부터 끝까지 (구분자가 내용에 포함될 수 있으므로)
            var content: String? = nil
            if parts.count >= 8 {
                content = parts[7...].joined(separator: "|||")
            }

            // 발신자에서 이메일 추출
            let senderEmail = extractEmail(from: sender)

            // Unix timestamp를 Date로 변환
            let date: Date
            if let timestamp = TimeInterval(timestampStr) {
                date = Date(timeIntervalSince1970: timestamp)
            } else {
                date = Date() // 실패 시 현재 시간
            }

            let message = MailAppMessage(
                id: messageId,
                subject: subject,
                sender: sender,
                senderEmail: senderEmail,
                dateReceived: date,
                isRead: isRead,
                isFlagged: isFlagged,
                content: content,
                account: accountEmail
            )

            result.append(message)
        }

        return result
    }

    private func extractEmail(from sender: String) -> String {
        // "Name <email@domain.com>" 형식에서 이메일 추출
        if let startIndex = sender.firstIndex(of: "<"),
           let endIndex = sender.firstIndex(of: ">") {
            let emailStartIndex = sender.index(after: startIndex)
            return String(sender[emailStartIndex..<endIndex])
        }
        return sender
    }

    private func parseAppleScriptDate(_ dateString: String) -> Date? {
        // "date 2026년 2월 9일 월요일 오후 12:00:17" 형식
        print("🕐 파싱할 날짜: \(dateString)")

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")

        // "date " 제거
        var cleanedString = dateString.replacingOccurrences(of: "date ", with: "")
        cleanedString = cleanedString.trimmingCharacters(in: .whitespaces)

        // 요일 제거 (월요일, 화요일 등)
        let weekdays = ["월요일", "화요일", "수요일", "목요일", "금요일", "토요일", "일요일"]
        for weekday in weekdays {
            cleanedString = cleanedString.replacingOccurrences(of: " \(weekday)", with: "")
            cleanedString = cleanedString.replacingOccurrences(of: weekday, with: "")
        }

        cleanedString = cleanedString.trimmingCharacters(in: .whitespaces)
        print("🧹 정리된 날짜: \(cleanedString)")

        // 여러 날짜 형식 시도
        let formats = [
            "yyyy년 M월 d일 a h:mm:ss",
            "yyyy년 M월 d일 a h:m:s",
            "yyyy년 M월 d일 a hh:mm:ss",
            "yyyy년 MM월 dd일 a h:mm:ss",
            "yyyy년 M월 d일 오후 h:mm:ss",
            "yyyy년 M월 d일 오전 h:mm:ss"
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: cleanedString) {
                print("✅ 파싱 성공: \(date)")
                return date
            }
        }

        print("❌ 날짜 파싱 실패: \(cleanedString)")

        // 파싱 실패 시에도 문자열에서 정보를 추출해보기
        // 마지막 시도: ISO8601 형식이나 다른 표준 형식 확인
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: dateString) {
            return date
        }

        // 완전히 실패하면 nil 반환 (Date() 대신)
        return nil
    }
}
