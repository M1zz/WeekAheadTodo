import WeekAheadShared
import SwiftUI
import Combine

// MARK: - Wiki Editor View (마크다운 에디터 + 자동 저장)

struct WikiEditorView: View {
    @EnvironmentObject var wikiViewModel: WikiViewModel
    let pageId: UUID

    @State private var content: String = ""
    @State private var saveTimer: AnyCancellable? = nil
    @State private var isInitialized: Bool = false

    var body: some View {
        TextEditor(text: $content)
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(12)
            .background(Color(NSColor.textBackgroundColor))
            .onAppear {
                loadContent()
            }
            .onChange(of: pageId) { _, _ in
                loadContent()
            }
            .onChange(of: content) { _, newValue in
                guard isInitialized else { return }
                scheduleSave(content: newValue)
            }
    }

    // MARK: - Load / Save

    private func loadContent() {
        isInitialized = false
        if let page = wikiViewModel.page(for: pageId) {
            content = page.content
        }
        // 약간의 딜레이 후 초기화 완료 (초기 로드 시 onChange 트리거 방지)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isInitialized = true
        }
    }

    /// 0.5초 디바운스 자동 저장
    private func scheduleSave(content: String) {
        saveTimer?.cancel()
        saveTimer = Just(content)
            .delay(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { value in
                wikiViewModel.updatePageContent(pageId: pageId, content: value)
            }
    }
}
