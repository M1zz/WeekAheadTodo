import WeekAheadShared
import SwiftUI

// MARK: - Wiki Content View (에디터/미리보기 전환)

struct WikiContentView: View {
    @EnvironmentObject var wikiViewModel: WikiViewModel

    enum ViewMode: String, CaseIterable {
        case edit = "편집"
        case preview = "미리보기"
        case split = "분할"

        var icon: String {
            switch self {
            case .edit: return "pencil"
            case .preview: return "eye"
            case .split: return "rectangle.split.2x1"
            }
        }
    }

    @State private var viewMode: ViewMode = .split
    @State private var isEditingTitle: Bool = false
    @State private var editingTitle: String = ""

    var body: some View {
        VStack(spacing: 0) {
            if let page = wikiViewModel.selectedPage {
                // 툴바
                toolbar(page: page)
                Divider()

                // 콘텐츠 영역
                contentArea(page: page)
            } else {
                emptyState
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }

    // MARK: - Toolbar

    private func toolbar(page: WikiPage) -> some View {
        HStack(spacing: 12) {
            // 제목
            if isEditingTitle {
                TextField("페이지 제목", text: $editingTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        wikiViewModel.updatePageTitle(pageId: page.id, title: editingTitle)
                        isEditingTitle = false
                    }
            } else {
                Text(page.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .onTapGesture {
                        editingTitle = page.title
                        isEditingTitle = true
                    }
            }

            Spacer()

            // 뷰 모드 전환
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Button {
                    viewMode = mode
                } label: {
                    Image(systemName: mode.icon)
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .foregroundColor(viewMode == mode ? .accentColor : .secondary)
                .help(mode.rawValue)
            }

            // 고정 토글
            Button {
                wikiViewModel.togglePin(page.id)
            } label: {
                Image(systemName: page.isPinned ? "pin.fill" : "pin")
                    .font(.callout)
                    .foregroundColor(page.isPinned ? .orange : .secondary)
            }
            .buttonStyle(.plain)
            .help(page.isPinned ? "고정 해제" : "고정")

            // 수정 시간
            Text(page.updatedAt.formatted(.relative(presentation: .named)))
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Content Area

    @ViewBuilder
    private func contentArea(page: WikiPage) -> some View {
        switch viewMode {
        case .edit:
            WikiEditorView(pageId: page.id)
        case .preview:
            ScrollView {
                WikiPreviewView(content: page.content)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .split:
            HSplitView {
                WikiEditorView(pageId: page.id)
                    .frame(minWidth: 200)
                Divider()
                ScrollView {
                    WikiPreviewView(content: page.content)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minWidth: 200)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text("페이지를 선택하세요")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("좌측에서 폴더를 만들고 페이지를 추가할 수 있습니다")
                .font(.callout)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
