import Foundation

// MARK: - Wiki Folder

/// 위키 폴더 모델 - 페이지를 그룹핑
public struct WikiFolder: Identifiable, Codable, Hashable {
    public let id: UUID
    public var name: String
    public var icon: String        // SF Symbol, 기본 "folder.fill"
    public var sortOrder: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        icon: String = "folder.fill",
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Wiki Page

/// 위키 페이지 모델 - 마크다운 문서
public struct WikiPage: Identifiable, Codable, Hashable {
    public let id: UUID
    public var folderId: UUID      // 소속 폴더
    public var title: String
    public var content: String     // 마크다운 본문
    public var isPinned: Bool
    public var sortOrder: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        folderId: UUID,
        title: String,
        content: String = "",
        isPinned: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.folderId = folderId
        self.title = title
        self.content = content
        self.isPinned = isPinned
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
