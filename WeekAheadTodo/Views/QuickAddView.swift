import SwiftUI

/// 빠른 태스크 추가 윈도우
/// Cmd+Shift+N 단축키로 호출
struct QuickAddView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: TaskViewModel

    @State private var input: String = ""
    @FocusState private var isFocused: Bool
    @State private var showingParseError = false
    @State private var parseErrorMessage = ""

    var body: some View {
        VStack(spacing: 20) {
            // 헤더
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)

                Text("빠른 추가")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape)
            }

            // 입력 필드
            VStack(alignment: .leading, spacing: 8) {
                TextField("예: 내일까지 보고서 작성 (2시간)", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .focused($isFocused)
                    .multilineTextAlignment(.leading)
                    .environment(\.layoutDirection, .leftToRight)
                    .onSubmit {
                        parseAndAddTask()
                    }

                Text("자연어로 입력하세요: \"내일\", \"3시간\", \"긴급\" 등")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            // 파싱 에러 표시
            if showingParseError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(parseErrorMessage)
                        .font(.callout)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            // 액션 버튼
            HStack(spacing: 12) {
                Button("취소") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("추가") {
                    parseAndAddTask()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            // 윈도우 표시 시 즉시 포커스
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
    }

    /// 입력된 텍스트를 파싱하여 태스크 추가
    private func parseAndAddTask() {
        let trimmedInput = input.trimmingCharacters(in: .whitespaces)
        guard !trimmedInput.isEmpty else { return }

        // TaskInputParser 사용
        let parsedInfo = TaskInputParser.parse(trimmedInput)

        // 제목이 비어있으면 원본 입력을 제목으로 사용
        let title = parsedInfo.title.isEmpty ? trimmedInput : parsedInfo.title

        // 기본값 설정
        let dueDate = parsedInfo.dueDate ?? Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let estimatedMinutes = parsedInfo.estimatedMinutes ?? 30
        let priority = parsedInfo.priority ?? .normal
        let leadTimeDays = parsedInfo.leadTimeDays ?? 0

        // 태스크 생성
        let task = Task(
            title: title,
            description: "",
            dueDate: dueDate,
            estimatedMinutes: estimatedMinutes,
            leadTimeDays: leadTimeDays,
            taskType: .preparable,
            taskRole: .none,
            status: .notStarted,
            priority: priority
        )

        // 태스크 추가
        viewModel.addTask(task)

        print("✅ [QuickAddView] 태스크 추가 완료: \(title)")
        print("  - 마감일: \(dueDate.formatted(date: .abbreviated, time: .omitted))")
        print("  - 예상 시간: \(estimatedMinutes)분")
        print("  - 우선순위: \(priority.rawValue)")

        // 윈도우 닫기
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    QuickAddView()
        .environmentObject(TaskViewModel())
}
