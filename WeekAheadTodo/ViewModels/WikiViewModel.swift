import WeekAheadShared
import Foundation
import SwiftUI
import Combine

/// 위키 시스템의 CRUD, 검색, 저장을 담당하는 ViewModel
@MainActor
class WikiViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var folders: [WikiFolder] = [] {
        didSet { saveFolders() }
    }

    @Published var pages: [WikiPage] = [] {
        didSet { savePages() }
    }

    @Published var selectedFolderId: UUID? = nil
    @Published var selectedPageId: UUID? = nil
    @Published var searchText: String = ""

    // MARK: - Storage Keys

    private let foldersKey = "WikiFolders"
    private let pagesKey = "WikiPages"

    // MARK: - Init

    init() {
        loadFolders()
        loadPages()
    }

    // MARK: - Computed Properties

    /// 정렬된 폴더 목록
    var sortedFolders: [WikiFolder] {
        folders.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// 현재 선택된 폴더의 페이지 목록
    var pagesForSelectedFolder: [WikiPage] {
        guard let folderId = selectedFolderId else { return [] }
        return pages
            .filter { $0.folderId == folderId }
            .sorted { (lhs, rhs) in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                return lhs.sortOrder < rhs.sortOrder
            }
    }

    /// 현재 선택된 페이지
    var selectedPage: WikiPage? {
        guard let pageId = selectedPageId else { return nil }
        return pages.first { $0.id == pageId }
    }

    /// 검색 결과 (제목 + 본문)
    var searchResults: [WikiPage] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        return pages.filter {
            $0.title.lowercased().contains(query) ||
            $0.content.lowercased().contains(query)
        }
    }

    /// 특정 폴더의 페이지 목록
    func pages(for folderId: UUID) -> [WikiPage] {
        pages
            .filter { $0.folderId == folderId }
            .sorted { (lhs, rhs) in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                return lhs.sortOrder < rhs.sortOrder
            }
    }

    /// 특정 폴더의 페이지 수
    func pageCount(for folderId: UUID) -> Int {
        pages.filter { $0.folderId == folderId }.count
    }

    // MARK: - Folder CRUD

    /// 새 폴더 생성
    func createFolder(name: String, icon: String = "folder.fill") {
        let maxOrder = folders.map(\.sortOrder).max() ?? -1
        let folder = WikiFolder(name: name, icon: icon, sortOrder: maxOrder + 1)
        folders.append(folder)
        print("✅ [WikiViewModel] 폴더 생성: \(name)")
    }

    /// 폴더 이름 수정
    func updateFolder(_ folder: WikiFolder) {
        guard let index = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[index] = folder
        folders[index].updatedAt = Date()
        print("✅ [WikiViewModel] 폴더 수정: \(folder.name)")
    }

    /// 폴더 삭제 (하위 페이지도 함께 삭제)
    func deleteFolder(_ folderId: UUID) {
        pages.removeAll { $0.folderId == folderId }
        folders.removeAll { $0.id == folderId }
        if selectedFolderId == folderId {
            selectedFolderId = nil
            selectedPageId = nil
        }
        print("✅ [WikiViewModel] 폴더 삭제됨")
    }

    // MARK: - Page CRUD

    /// 새 페이지 생성
    func createPage(folderId: UUID, title: String, content: String = "") -> WikiPage {
        let maxOrder = pages.filter({ $0.folderId == folderId }).map(\.sortOrder).max() ?? -1
        let page = WikiPage(folderId: folderId, title: title, content: content, sortOrder: maxOrder + 1)
        pages.append(page)
        print("✅ [WikiViewModel] 페이지 생성: \(title)")
        return page
    }

    /// 페이지 업데이트
    func updatePage(_ page: WikiPage) {
        guard let index = pages.firstIndex(where: { $0.id == page.id }) else { return }
        pages[index] = page
        pages[index].updatedAt = Date()
    }

    /// 페이지 내용 업데이트 (자동 저장용)
    func updatePageContent(pageId: UUID, content: String) {
        guard let index = pages.firstIndex(where: { $0.id == pageId }) else { return }
        pages[index].content = content
        pages[index].updatedAt = Date()
    }

    /// 페이지 제목 업데이트
    func updatePageTitle(pageId: UUID, title: String) {
        guard let index = pages.firstIndex(where: { $0.id == pageId }) else { return }
        pages[index].title = title
        pages[index].updatedAt = Date()
    }

    /// 페이지 삭제
    func deletePage(_ pageId: UUID) {
        pages.removeAll { $0.id == pageId }
        if selectedPageId == pageId {
            selectedPageId = nil
        }
        print("✅ [WikiViewModel] 페이지 삭제됨")
    }

    /// 페이지 고정/해제 토글
    func togglePin(_ pageId: UUID) {
        guard let index = pages.firstIndex(where: { $0.id == pageId }) else { return }
        pages[index].isPinned.toggle()
        pages[index].updatedAt = Date()
    }

    // MARK: - Task → Wiki 연동

    /// 태스크에서 위키 페이지 빠른 생성
    func createPageFromTask(_ task: Task, folderId: UUID) -> WikiPage {
        let template = """
        # \(task.title)

        **마감일**: \(task.dueDateWithWeekday)
        **상태**: \(task.status.rawValue)
        **우선순위**: \(task.priority.rawValue)

        ---

        ## 내용


        """
        let page = createPage(folderId: folderId, title: task.title, content: template)
        print("✅ [WikiViewModel] 태스크에서 위키 페이지 생성: \(task.title)")
        return page
    }

    /// 페이지 ID로 페이지 조회
    func page(for id: UUID) -> WikiPage? {
        pages.first { $0.id == id }
    }

    /// 폴더 ID로 폴더 조회
    func folder(for id: UUID) -> WikiFolder? {
        folders.first { $0.id == id }
    }

    // MARK: - Persistence

    private func saveFolders() {
        guard let data = try? JSONEncoder().encode(folders) else { return }
        UserDefaults.standard.set(data, forKey: foldersKey)
    }

    private func loadFolders() {
        guard let data = UserDefaults.standard.data(forKey: foldersKey),
              let decoded = try? JSONDecoder().decode([WikiFolder].self, from: data) else { return }
        folders = decoded
    }

    private func savePages() {
        guard let data = try? JSONEncoder().encode(pages) else { return }
        UserDefaults.standard.set(data, forKey: pagesKey)
    }

    private func loadPages() {
        guard let data = UserDefaults.standard.data(forKey: pagesKey),
              let decoded = try? JSONDecoder().decode([WikiPage].self, from: data) else { return }
        pages = decoded
    }
}
