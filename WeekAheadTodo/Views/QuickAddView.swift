import SwiftUI

// MARK: - Quick Add View

/// 빠른 태스크 추가 윈도우 (Cmd+Shift+N)
struct QuickAddView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: TaskViewModel

    @State private var input: String = ""
    @FocusState private var isFocused: Bool

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
                    .onSubmit {
                        parseAndAddTask()
                    }

                Text("자연어로 입력하세요: \"내일\", \"3시간\", \"긴급\" 등")
                    .font(.callout)
                    .foregroundColor(.secondary)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
    }

    private func parseAndAddTask() {
        let trimmedInput = input.trimmingCharacters(in: .whitespaces)
        guard !trimmedInput.isEmpty else { return }

        let parsedInfo = TaskInputParser.parse(trimmedInput)
        let title = parsedInfo.title.isEmpty ? trimmedInput : parsedInfo.title
        let dueDate = parsedInfo.dueDate ?? Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let estimatedMinutes = parsedInfo.estimatedMinutes ?? 30
        let priority = parsedInfo.priority ?? .normal
        let leadTimeDays = parsedInfo.leadTimeDays ?? 0

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

        viewModel.addTask(task)
        print("✅ [QuickAddView] 태스크 추가: \(title)")
        dismiss()
    }
}
