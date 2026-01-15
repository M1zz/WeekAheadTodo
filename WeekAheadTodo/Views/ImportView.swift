import SwiftUI
import AppKit

struct ImportView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @State private var markdownText: String = ""
    @State private var parseResult: MarkdownParseResult?
    @State private var showingImportConfirmation = false
    @State private var importedCount = 0
    @State private var showingFilePicker = false
    @State private var showingHelp = false
    @State private var startDate: Date = Date()
    @State private var showingEditSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("마크다운 가져오기")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()

                Button(action: { showingHelp = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "questionmark.circle")
                        Text("도움말")
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding(24)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Main Content: Split view (editor + preview)
            HSplitView {
                // Left: Markdown Editor
                editorSection
                    .frame(minWidth: 300)

                // Right: Preview
                previewSection
                    .frame(minWidth: 350)
            }
        }
        .alert("가져오기 완료", isPresented: $showingImportConfirmation) {
            Button("확인", role: .cancel) {
                markdownText = ""
                parseResult = nil
                importedCount = 0
            }
        } message: {
            Text("\(importedCount)개의 태스크를 가져왔습니다.")
        }
        .sheet(isPresented: $showingHelp) {
            HelpSheetView()
        }
    }

    // MARK: - Editor Section

    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("마크다운 입력")
                    .font(.headline)

                Spacer()

                // 추가 기능 버튼들
                Menu {
                    Button("파일에서 불러오기...") {
                        loadFromFile()
                    }

                    Button("클립보드에서 붙여넣기") {
                        pasteFromClipboard()
                    }

                    Divider()

                    Button("샘플 템플릿 삽입") {
                        insertSampleTemplate()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
                .menuStyle(.borderlessButton)
            }

            // 시작일자 선택
            HStack {
                Text("시작일자:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                DatePicker("", selection: $startDate, displayedComponents: .date)
                    .labelsHidden()
                    .onChange(of: startDate) { _ in
                        // 시작일자가 변경되면 파싱 결과 업데이트
                        if !markdownText.isEmpty && parseResult != nil {
                            parseMarkdown()
                        }
                    }

                Spacer()
            }

            TextEditor(text: $markdownText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 300)
                .border(Color.gray.opacity(0.3), width: 1)
                .cornerRadius(4)

            HStack {
                Button("파싱하기") {
                    parseMarkdown()
                }
                .buttonStyle(.borderedProminent)
                .disabled(markdownText.isEmpty)

                Button("초기화") {
                    markdownText = ""
                    parseResult = nil
                }

                Spacer()

                if let result = parseResult {
                    Text("\(result.tasks.count)개 태스크 발견")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("미리보기")
                    .font(.headline)

                Spacer()

                if parseResult != nil {
                    Button(action: { showingEditSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("편집하기")
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }

            if let result = parseResult {
                ScrollView {
                    previewContent(result)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                placeholderView
            }

            Divider()

            HStack {
                Spacer()

                Button("취소") {
                    markdownText = ""
                    parseResult = nil
                }

                Button("가져오기") {
                    importTasks()
                }
                .buttonStyle(.borderedProminent)
                .disabled(parseResult == nil || parseResult!.tasks.isEmpty)
            }
        }
        .padding(24)
        .sheet(isPresented: $showingEditSheet) {
            if let result = parseResult {
                TaskEditSheet(parseResult: result, startDate: $startDate)
            }
        }
    }

    // MARK: - Placeholder View

    private var placeholderView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)

                    Text("빠른 시작 가이드")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("1️⃣ AI로 Todo 리스트 생성")
                        .font(.headline)

                    Text("Claude나 ChatGPT에게 요청하세요:")
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("• 우측 상단 '도움말' 버튼 클릭")
                        Text("• AI 프롬프트 템플릿 복사")
                        Text("• AI에게 붙여넣기 & 목표 입력")
                    }
                    .font(.body)
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("2️⃣ 마크다운 가져오기")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("• AI가 생성한 마크다운 복사")
                        Text("• 좌측 상단 ⋯ 메뉴 클릭")
                        Text("• '클립보드에서 붙여넣기' 선택")
                    }
                    .font(.body)
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("3️⃣ 파싱 & 가져오기")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("• '파싱하기' 버튼으로 미리보기")
                        Text("• 날짜가 올바른지 확인")
                        Text("• '가져오기' 버튼으로 완료")
                    }
                    .font(.body)
                }

                Divider()

                HStack {
                    Spacer()
                    Button(action: { showingHelp = true }) {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                            Text("자세한 도움말 보기")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
                .padding(.top, 8)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Preview Content

    @ViewBuilder
    private func previewContent(_ result: MarkdownParseResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 시작일자 정보 표시
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                Text("시작일자: \(formatDate(result.startDate))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)

            // Group tasks by week section
            let grouped = Dictionary(grouping: result.tasks) { $0.weekSection }
            let sortedSections = grouped.keys.sorted { section1, section2 in
                section1.daysFromNow(startDate: result.startDate) < section2.daysFromNow(startDate: result.startDate)
            }

            ForEach(sortedSections, id: \.self) { section in
                if let tasks = grouped[section] {
                    sectionPreview(section: section, tasks: tasks, startDate: result.startDate)
                }
            }

            // Show errors if any
            if !result.errors.isEmpty {
                errorSection(result.errors)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Section Preview

    private func sectionPreview(section: WeekSection, tasks: [ParsedTask], startDate: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(section.displayName)
                    .font(.headline)
                Spacer()
                Text("\(tasks.count)개")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(tasks.indices, id: \.self) { index in
                let task = tasks[index]

                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(task.isCompleted ? Color.gray : Color.blue)
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title)
                            .font(.body)
                            .strikethrough(task.isCompleted)
                            .foregroundColor(task.isCompleted ? .secondary : .primary)

                        Text(formatDate(task.dueDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.leading, 24)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Error Section

    private func errorSection(_ errors: [ParseError]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("파싱 오류")
                    .font(.headline)
                    .foregroundColor(.orange)
            }

            ForEach(errors.indices, id: \.self) { index in
                Text("Line \(errors[index].line): \(errors[index].message)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Helper Methods

    private func parseMarkdown() {
        let parser = MarkdownParser()
        parseResult = parser.parse(markdownText, startDate: startDate)
    }

    private func importTasks() {
        guard let result = parseResult else { return }

        importedCount = 0

        for parsedTask in result.tasks {
            // Skip completed tasks
            guard !parsedTask.isCompleted else { continue }

            // Use the dueDate from parsedTask (which can be edited by user)
            let task = Task(
                title: parsedTask.title,
                description: "마크다운에서 가져옴",
                dueDate: parsedTask.dueDate,
                estimatedMinutes: parsedTask.estimatedMinutes,
                leadTimeDays: parsedTask.leadTimeDays,
                taskType: .preparable,
                taskRole: .main,
                status: .notStarted
            )

            viewModel.addTask(task)
            importedCount += 1
        }

        showingImportConfirmation = true
    }

    private func formatDate(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M/d"
        let dateString = dateFormatter.string(from: date)

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = Locale(identifier: "ko_KR")
        weekdayFormatter.dateFormat = "E"
        let weekdayString = weekdayFormatter.string(from: date)

        return "\(dateString) (\(weekdayString))"
    }

    // MARK: - Additional Import Methods

    /// 파일에서 마크다운 불러오기
    private func loadFromFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.plainText, .text]
        panel.message = "마크다운 파일을 선택하세요"

        // .md 파일 필터링
        panel.allowedContentTypes = [.init(filenameExtension: "md")!]

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    self.markdownText = content
                    self.parseResult = nil  // 기존 파싱 결과 초기화
                } catch {
                    print("파일 읽기 실패: \(error)")
                }
            }
        }
    }

    /// 클립보드에서 텍스트 붙여넣기
    private func pasteFromClipboard() {
        let pasteboard = NSPasteboard.general
        if let content = pasteboard.string(forType: .string) {
            markdownText = content
            parseResult = nil  // 기존 파싱 결과 초기화
        }
    }

    /// 샘플 템플릿 삽입
    private func insertSampleTemplate() {
        let sample = """
## Week 0 (이번 주)
- [ ] 프로젝트 목표 정의하기
- [ ] 필요한 리소스 조사하기
- [ ] 첫 번째 마일스톤 설정하기

## Week 1 Day 1
- [ ] 기초 작업 시작하기
- [ ] 필요한 도구 설치하기

## Week 1 Day 3
- [ ] 중간 점검 및 피드백 받기
- [ ] 다음 단계 계획 수립하기

## Week 2
- [ ] 주요 기능 구현하기
- [ ] 테스트 코드 작성하기

## Week 3
- [ ] 전체 테스트 및 검증하기
- [ ] 개선사항 반영하기
- [ ] 문서화 작업하기
"""
        markdownText = sample
        parseResult = nil  // 기존 파싱 결과 초기화
    }
}

// MARK: - Help Sheet View

struct HelpSheetView: View {
    @Environment(\.dismiss) var dismiss
    @State private var copiedPromptIndex: Int? = nil

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 소개
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.title)
                                .foregroundColor(.blue)
                            Text("AI로 Todo 리스트 자동 생성하기")
                                .font(.title2)
                                .fontWeight(.bold)
                        }

                        Text("Claude나 ChatGPT 같은 AI에게 프롬프트를 보내면 자동으로 주차별 Todo 리스트를 생성해줍니다.")
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // 프롬프트 템플릿들
                    promptTemplateSection(
                        title: "기본 템플릿",
                        description: "간단한 프로젝트나 목표를 위한 기본 프롬프트",
                        prompt: basicPrompt,
                        index: 0
                    )

                    Divider()

                    promptTemplateSection(
                        title: "상세 템플릿",
                        description: "구체적인 목표와 현재 상황을 포함하는 상세 프롬프트",
                        prompt: detailedPrompt,
                        index: 1
                    )

                    Divider()

                    promptTemplateSection(
                        title: "독립 준비 예시",
                        description: "조직에서 독립하여 사업을 시작하는 경우",
                        prompt: independencePrompt,
                        index: 2
                    )

                    Divider()

                    // 사용 방법
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "list.number")
                                .foregroundColor(.green)
                            Text("사용 방법")
                                .font(.headline)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            stepView(number: "1", text: "위의 템플릿 중 하나를 복사하세요")
                            stepView(number: "2", text: "AI (Claude, ChatGPT)에게 붙여넣고 [프로젝트 설명] 부분을 수정하세요")
                            stepView(number: "3", text: "AI가 생성한 마크다운을 복사하세요")
                            stepView(number: "4", text: "앱의 '⋯ 메뉴 → 클립보드에서 붙여넣기'를 선택하세요")
                            stepView(number: "5", text: "'파싱하기' → '가져오기' 버튼을 클릭하세요")
                        }
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)

                    Divider()

                    // 지원하는 형식
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(.orange)
                            Text("지원하는 Week 형식")
                                .font(.headline)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            formatRow("Week 0 또는 이번 주", "→ 시작일 + 3일")
                            formatRow("Week N", "→ 시작일 + N주")
                            formatRow("Week N Day M", "→ 시작일 + N주 + (M-1)일")
                            formatRow("Week 1-2", "→ 시작일 + 10일")
                            formatRow("Week 3", "→ 시작일 + 21일")
                        }
                        .font(.caption)
                    }
                }
                .padding(24)
            }
            .navigationTitle("AI 프롬프트 가이드")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 700, height: 600)
    }

    // MARK: - Helper Views

    private func promptTemplateSection(title: String, description: String, prompt: String, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    Text(prompt)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .frame(height: 120)
                .background(Color(NSColor.textBackgroundColor))

                HStack {
                    Spacer()
                    Button(action: {
                        copyToClipboard(prompt, index: index)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: copiedPromptIndex == index ? "checkmark" : "doc.on.doc")
                            Text(copiedPromptIndex == index ? "복사됨!" : "복사하기")
                        }
                    }
                    .buttonStyle(.bordered)
                    .padding(8)
                }
                .background(Color(NSColor.controlBackgroundColor))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private func stepView(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.blue))

            Text(text)
                .font(.body)
        }
    }

    private func formatRow(_ format: String, _ result: String) -> some View {
        HStack {
            Text(format)
                .fontWeight(.medium)
            Spacer()
            Text(result)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Actions

    private func copyToClipboard(_ text: String, index: Int) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        copiedPromptIndex = index

        // 2초 후 복사 상태 초기화
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if copiedPromptIndex == index {
                copiedPromptIndex = nil
            }
        }
    }

    // MARK: - Prompt Templates

    private var basicPrompt: String {
        """
        [프로젝트나 목표 설명]을 위한 주차별 Todo 리스트를 마크다운 형식으로 만들어줘.

        다음 형식을 따라줘:
        - Week 0 (이번 주)
        - Week 1 Day 1, Week 1 Day 2, ... (각 일자별)
        - Week 1-2
        - Week 3

        각 섹션은 ## 헤더로 시작하고, 할 일은 - [ ] 체크박스 형식으로 작성해줘.
        """
    }

    private var detailedPrompt: String {
        """
        나는 [목표/프로젝트]를 진행하려고 해.

        목표:
        - [구체적인 목표 1]
        - [구체적인 목표 2]
        - [구체적인 목표 3]

        현재 상황:
        - [현재 진행 상황이나 제약사항]

        이를 위한 주차별 Todo 리스트를 다음 형식으로 만들어줘:

        ## Week 0 (이번 주)
        ## Week 1 Day 1
        ## Week 1 Day 3
        ## Week 2
        ## Week 3

        각 할 일은 - [ ] 체크박스 형식으로 작성하고, 구체적이고 실행 가능한 행동으로 작성해줘.
        Week N Day M 형식으로 일자별로 세부적으로 나눠줘.
        """
    }

    private var independencePrompt: String {
        """
        조직에서 독립하여 교육 사업을 시작하려고 해.

        목표:
        - 월 수입 500만원 이상 확보
        - 100명의 유료 고객 확보
        - 3개의 검증된 커리큘럼 완성

        현재 상황:
        - 현재 직장인으로 일하고 있음
        - 주말과 평일 저녁에만 작업 가능
        - 개발 교육 경험 있음

        이를 위한 주차별 Todo 리스트를 다음 형식으로 만들어줘:

        ## Week 0 (이번 주)
        ## Week 1 Day 1
        ## Week 1 Day 5
        ## Week 2
        ## Week 3

        각 단계는 구체적이고 실행 가능한 행동으로 작성해줘.
        각 할 일은 - [ ] 체크박스 형식으로 작성해줘.
        Week N Day M 형식으로 일자별로 세부적으로 계획을 나눠줘.
        """
    }
}

// MARK: - Task Edit Sheet

struct TaskEditSheet: View {
    let parseResult: MarkdownParseResult
    @Binding var startDate: Date
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 시작일자 조정
                HStack {
                    Text("시작일자:")
                        .font(.headline)
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                    Spacer()
                    Text("총 \(parseResult.tasks.count)개 작업")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // 태스크 리스트
                ScrollView {
                    VStack(spacing: 16) {
                        let grouped = Dictionary(grouping: parseResult.tasks) { $0.weekSection }
                        let sortedSections = grouped.keys.sorted { section1, section2 in
                            section1.daysFromNow(startDate: startDate) < section2.daysFromNow(startDate: startDate)
                        }

                        ForEach(sortedSections, id: \.self) { section in
                            if let tasks = grouped[section] {
                                editableSection(section: section, tasks: tasks)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("작업 편집")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 800, height: 600)
    }

    @ViewBuilder
    private func editableSection(section: WeekSection, tasks: [ParsedTask]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(section.displayName)
                    .font(.headline)
                Spacer()
                Text("\(tasks.count)개")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(tasks) { task in
                EditableTaskRow(task: task, startDate: startDate)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Editable Task Row

struct EditableTaskRow: View {
    @ObservedObject var task: ParsedTask
    let startDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? .green : .gray)

                TextField("작업 제목", text: .constant(task.title))
                    .textFieldStyle(.roundedBorder)
                    .disabled(true)
            }

            HStack {
                Text("기한:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                DatePicker("", selection: $task.dueDate, displayedComponents: .date)
                    .labelsHidden()

                Spacer()

                Text("예상 시간:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Stepper("\(task.estimatedMinutes)분", value: $task.estimatedMinutes, in: 15...240, step: 15)
                    .labelsHidden()
                    .frame(width: 100)

                Text("\(task.estimatedMinutes)분")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }
        }
        .padding(8)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(6)
    }
}

// MARK: - Preview

#Preview {
    ImportView()
        .environmentObject(TaskViewModel())
        .frame(width: 900, height: 600)
}
