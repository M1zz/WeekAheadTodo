import WeekAheadShared
import SwiftUI

// MARK: - Wiki Link Picker View (태스크 ↔ 위키 연결 피커)

struct WikiLinkPickerView: View {
    @EnvironmentObject var wikiViewModel: WikiViewModel
    @Environment(\.dismiss) var dismiss

    @Binding var linkedPageIds: [UUID]

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("위키 페이지 연결")
                    .font(.headline)
                Spacer()
                Button("완료") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            if wikiViewModel.folders.isEmpty {
                emptyState
            } else {
                pageSelectionList
            }
        }
        .frame(width: 420, height: 500)
    }

    // MARK: - Page Selection List

    private var pageSelectionList: some View {
        List {
            ForEach(wikiViewModel.sortedFolders) { folder in
                let folderPages = wikiViewModel.pages(for: folder.id)
                if !folderPages.isEmpty {
                    Section {
                        ForEach(folderPages) { page in
                            HStack(spacing: 8) {
                                Image(systemName: linkedPageIds.contains(page.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(linkedPageIds.contains(page.id) ? .blue : .secondary)
                                    .font(.callout)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(page.title)
                                        .font(.callout)
                                    Text(page.updatedAt.formatted(.relative(presentation: .named)))
                                        .font(.callout)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                togglePage(page.id)
                            }
                        }
                    } header: {
                        HStack(spacing: 4) {
                            Image(systemName: folder.icon)
                            Text(folder.name)
                        }
                        .font(.callout)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.5))
            Text("위키 폴더가 없습니다")
                .font(.body)
                .foregroundColor(.secondary)
            Text("먼저 위키 탭에서 폴더와 페이지를 만들어주세요")
                .font(.callout)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toggle

    private func togglePage(_ pageId: UUID) {
        if let index = linkedPageIds.firstIndex(of: pageId) {
            linkedPageIds.remove(at: index)
        } else {
            linkedPageIds.append(pageId)
        }
    }
}
