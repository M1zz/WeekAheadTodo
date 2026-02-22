import WeekAheadShared
import SwiftUI

// MARK: - Wiki Sidebar View (폴더/페이지 브라우저)

struct WikiSidebarView: View {
    @EnvironmentObject var wikiViewModel: WikiViewModel
    @State private var newFolderName: String = ""
    @State private var showingNewFolder: Bool = false
    @State private var renamingFolderId: UUID? = nil
    @State private var renameFolderText: String = ""
    @State private var newPageTitle: String = ""
    @State private var addingPageToFolderId: UUID? = nil

    var body: some View {
        VStack(spacing: 0) {
            // 검색 바
            searchBar

            Divider()

            // 폴더/페이지 목록 또는 검색 결과
            if wikiViewModel.searchText.isEmpty {
                folderList
            } else {
                searchResultsList
            }

            Divider()

            // 새 폴더 추가 버튼
            newFolderButton
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("검색...", text: $wikiViewModel.searchText)
                .textFieldStyle(.plain)
                .font(.callout)
        }
        .padding(8)
    }

    // MARK: - Folder List

    private var folderList: some View {
        List(selection: $wikiViewModel.selectedPageId) {
            ForEach(wikiViewModel.sortedFolders) { folder in
                Section {
                    ForEach(wikiViewModel.pages(for: folder.id)) { page in
                        pageRow(page)
                            .tag(page.id)
                    }

                    // 새 페이지 추가 인라인
                    if addingPageToFolderId == folder.id {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.badge.plus")
                                .foregroundColor(.blue)
                            TextField("페이지 제목", text: $newPageTitle)
                                .font(.callout)
                                .textFieldStyle(.plain)
                                .onSubmit { addPage(to: folder.id) }
                            Button("추가") { addPage(to: folder.id) }
                                .font(.callout)
                                .disabled(newPageTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    folderHeader(folder)
                }
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Folder Header

    private func folderHeader(_ folder: WikiFolder) -> some View {
        HStack(spacing: 6) {
            if renamingFolderId == folder.id {
                TextField("폴더 이름", text: $renameFolderText)
                    .font(.callout)
                    .textFieldStyle(.plain)
                    .onSubmit { renameFolder(folder) }
            } else {
                Image(systemName: folder.icon)
                    .foregroundColor(.secondary)
                Text(folder.name)
                    .font(.callout)
                    .fontWeight(.semibold)
                Text("(\(wikiViewModel.pageCount(for: folder.id)))")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 페이지 추가 버튼
            Button {
                if addingPageToFolderId == folder.id {
                    addingPageToFolderId = nil
                } else {
                    addingPageToFolderId = folder.id
                    newPageTitle = ""
                }
            } label: {
                Image(systemName: "plus")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            // 폴더 컨텍스트 메뉴
            Menu {
                Button("이름 변경") {
                    renamingFolderId = folder.id
                    renameFolderText = folder.name
                }
                Divider()
                Button("삭제", role: .destructive) {
                    wikiViewModel.deleteFolder(folder.id)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .menuStyle(.borderlessButton)
            .frame(width: 20)
        }
    }

    // MARK: - Page Row

    private func pageRow(_ page: WikiPage) -> some View {
        HStack(spacing: 6) {
            if page.isPinned {
                Image(systemName: "pin.fill")
                    .foregroundColor(.orange)
                    .font(.callout)
            }
            Text(page.title)
                .font(.callout)
                .lineLimit(1)
        }
        .contextMenu {
            Button(page.isPinned ? "고정 해제" : "고정") {
                wikiViewModel.togglePin(page.id)
            }
            Divider()
            Button("삭제", role: .destructive) {
                wikiViewModel.deletePage(page.id)
            }
        }
    }

    // MARK: - Search Results

    private var searchResultsList: some View {
        List(selection: $wikiViewModel.selectedPageId) {
            ForEach(wikiViewModel.searchResults) { page in
                VStack(alignment: .leading, spacing: 2) {
                    Text(page.title)
                        .font(.callout)
                        .fontWeight(.medium)
                    if let folderName = wikiViewModel.folder(for: page.folderId)?.name {
                        Text(folderName)
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                }
                .tag(page.id)
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - New Folder Button

    private var newFolderButton: some View {
        VStack(spacing: 6) {
            if showingNewFolder {
                HStack(spacing: 6) {
                    TextField("폴더 이름", text: $newFolderName)
                        .font(.callout)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addFolder() }
                    Button("추가") { addFolder() }
                        .font(.callout)
                        .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button("취소") {
                        showingNewFolder = false
                        newFolderName = ""
                    }
                    .font(.callout)
                }
                .padding(.horizontal, 8)
            } else {
                Button {
                    showingNewFolder = true
                } label: {
                    Label("새 폴더", systemImage: "folder.badge.plus")
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
            }
        }
        .padding(8)
    }

    // MARK: - Actions

    private func addFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        wikiViewModel.createFolder(name: name)
        newFolderName = ""
        showingNewFolder = false
    }

    private func addPage(to folderId: UUID) {
        let title = newPageTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let page = wikiViewModel.createPage(folderId: folderId, title: title)
        wikiViewModel.selectedFolderId = folderId
        wikiViewModel.selectedPageId = page.id
        newPageTitle = ""
        addingPageToFolderId = nil
    }

    private func renameFolder(_ folder: WikiFolder) {
        let name = renameFolderText.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            renamingFolderId = nil
            return
        }
        var updated = folder
        updated.name = name
        wikiViewModel.updateFolder(updated)
        renamingFolderId = nil
    }
}
