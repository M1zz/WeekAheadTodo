import Foundation
import SwiftUI

/// 시스템 메일함 타입
enum SystemMailbox: String, CaseIterable {
    case inbox = "받은 편지함"
    case unread = "읽지 않음"
    case starred = "중요 편지함"
    case sent = "보낸 편지함"
    case drafts = "임시 보관함"
    case archive = "보관함"
    case spam = "스팸"
    case trash = "휴지통"
    case allMail = "전체 메일"

    var icon: String {
        switch self {
        case .inbox: return "tray.fill"
        case .unread: return "envelope.badge.fill"
        case .starred: return "star.fill"
        case .sent: return "paperplane.fill"
        case .drafts: return "doc.fill"
        case .archive: return "archivebox.fill"
        case .spam: return "xmark.octagon.fill"
        case .trash: return "trash.fill"
        case .allMail: return "tray.2.fill"
        }
    }

    var color: Color {
        switch self {
        case .inbox: return .blue
        case .unread: return .cyan
        case .starred: return .yellow
        case .sent: return .green
        case .drafts: return .gray
        case .archive: return .purple
        case .spam: return .orange
        case .trash: return .red
        case .allMail: return .indigo
        }
    }
}

/// 사용자 정의 메일함
struct Mailbox: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var iconName: String
    var colorHex: String
    var parentID: UUID?
    var sortOrder: Int
    
    init(
        id: UUID = UUID(),
        name: String,
        iconName: String = "folder.fill",
        colorHex: String = "#007AFF",
        parentID: UUID? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.parentID = parentID
        self.sortOrder = sortOrder
    }
    
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
}

/// 사이드바 항목 타입
enum SidebarItem: Hashable {
    case system(SystemMailbox)
    case custom(Mailbox)
    case filterResult(UUID)
    case account(String) // 계정 이메일 주소
    
    var displayName: String {
        switch self {
        case .system(let box): return box.rawValue
        case .custom(let box): return box.name
        case .filterResult(let id): return "필터: \(id.uuidString.prefix(8))"
        case .account(let email): return email
        }
    }
}

// Color extension은 ColorExtension.swift에 있음
