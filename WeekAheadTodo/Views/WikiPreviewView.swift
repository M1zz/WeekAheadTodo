import SwiftUI

// MARK: - Wiki Preview View (마크다운 미리보기 렌더러)

struct WikiPreviewView: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }

    // MARK: - Block Parsing

    private enum MarkdownBlock {
        case heading(level: Int, text: String)
        case unorderedList(text: String)
        case checkbox(checked: Bool, text: String)
        case codeBlock(lines: [String])
        case horizontalRule
        case paragraph(text: String)
        case blank
    }

    private func parseBlocks() -> [MarkdownBlock] {
        let lines = content.components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var inCodeBlock = false
        var codeLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 코드 블록 시작/끝
            if trimmed.hasPrefix("```") {
                if inCodeBlock {
                    blocks.append(.codeBlock(lines: codeLines))
                    codeLines = []
                    inCodeBlock = false
                } else {
                    inCodeBlock = true
                }
                continue
            }

            if inCodeBlock {
                codeLines.append(line)
                continue
            }

            // 빈 줄
            if trimmed.isEmpty {
                blocks.append(.blank)
                continue
            }

            // 수평선
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                blocks.append(.horizontalRule)
                continue
            }

            // 제목
            if let headingMatch = parseHeading(trimmed) {
                blocks.append(headingMatch)
                continue
            }

            // 체크박스
            if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
                let text = String(trimmed.dropFirst(6))
                blocks.append(.checkbox(checked: true, text: text))
                continue
            }
            if trimmed.hasPrefix("- [ ] ") {
                let text = String(trimmed.dropFirst(6))
                blocks.append(.checkbox(checked: false, text: text))
                continue
            }

            // 목록
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let text = String(trimmed.dropFirst(2))
                blocks.append(.unorderedList(text: text))
                continue
            }

            // 일반 텍스트
            blocks.append(.paragraph(text: trimmed))
        }

        // 닫히지 않은 코드 블록
        if inCodeBlock && !codeLines.isEmpty {
            blocks.append(.codeBlock(lines: codeLines))
        }

        return blocks
    }

    private func parseHeading(_ line: String) -> MarkdownBlock? {
        if line.hasPrefix("### ") { return .heading(level: 3, text: String(line.dropFirst(4))) }
        if line.hasPrefix("## ") { return .heading(level: 2, text: String(line.dropFirst(3))) }
        if line.hasPrefix("# ") { return .heading(level: 1, text: String(line.dropFirst(2))) }
        return nil
    }

    // MARK: - Block Rendering

    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            renderHeading(level: level, text: text)
        case .unorderedList(let text):
            HStack(alignment: .top, spacing: 6) {
                Text("•")
                    .font(.body)
                renderInlineMarkdown(text)
            }
            .padding(.leading, 8)
        case .checkbox(let checked, let text):
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .foregroundColor(checked ? .green : .secondary)
                renderInlineMarkdown(text)
                    .strikethrough(checked, color: .secondary)
            }
            .padding(.leading, 8)
        case .codeBlock(let lines):
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(.callout, design: .monospaced))
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.separatorColor).opacity(0.15))
            .cornerRadius(6)
        case .horizontalRule:
            Divider()
                .padding(.vertical, 4)
        case .paragraph(let text):
            renderInlineMarkdown(text)
        case .blank:
            Spacer()
                .frame(height: 4)
        }
    }

    @ViewBuilder
    private func renderHeading(level: Int, text: String) -> some View {
        switch level {
        case 1:
            Text(text)
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 8)
                .padding(.bottom, 2)
        case 2:
            Text(text)
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 6)
                .padding(.bottom, 2)
        default:
            Text(text)
                .font(.title3)
                .fontWeight(.medium)
                .padding(.top, 4)
                .padding(.bottom, 2)
        }
    }

    /// 인라인 마크다운 렌더링 (굵게, 기울임, 코드, 링크)
    @ViewBuilder
    private func renderInlineMarkdown(_ text: String) -> some View {
        if let attributed = try? AttributedString(markdown: text) {
            Text(attributed)
                .font(.body)
        } else {
            Text(text)
                .font(.body)
        }
    }
}
