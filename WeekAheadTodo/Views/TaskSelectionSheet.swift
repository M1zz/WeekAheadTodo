import SwiftUI

// MARK: - Task Selection Sheet

struct TaskSelectionSheet: View {
    @EnvironmentObject var viewModel: TaskViewModel
    let taskIds: [UUID]
    let onSelect: (UUID) -> Void
    @Environment(\.dismiss) var dismiss

    private let calendar = Calendar.current

    private var tasks: [Task] {
        taskIds.compactMap { id in
            viewModel.tasks.first(where: { $0.id == id })
        }
    }

    // 며칠 뒤인지 계산
    private func daysUntil(_ date: Date) -> String {
        let today = calendar.startOfDay(for: Date())
        let targetDate = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: today, to: targetDate).day ?? 0

        if days == 1 {
            return "내일"
        } else if days == 2 {
            return "모레"
        } else {
            return "\(days)일 뒤"
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 헤더 설명
                VStack(alignment: .leading, spacing: 8) {
                    Text("오늘로 당겨올 할 일을 선택하세요")
                        .font(.headline)
                    Text("한 번에 하나씩만 선택할 수 있습니다")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // 태스크 리스트
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(tasks) { task in
                            Button(action: {
                                onSelect(task.id)
                            }) {
                                HStack(spacing: 12) {
                                    // 태스크 아이콘
                                    Image(systemName: task.taskType.icon)
                                        .font(.title3)
                                        .foregroundColor(task.taskType == .preparable ? .blue : .orange)
                                        .frame(width: 32)

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(task.title)
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.leading)

                                        HStack(spacing: 12) {
                                            // 예상 시간
                                            HStack(spacing: 4) {
                                                Image(systemName: "clock")
                                                    .font(.body)
                                                Text(task.estimatedTimeFormatted)
                                                    .font(.body)
                                            }
                                            .foregroundColor(.secondary)

                                            // 며칠 뒤인지 강조 표시
                                            HStack(spacing: 4) {
                                                Image(systemName: "calendar")
                                                    .font(.body)
                                                Text(daysUntil(task.dueDate))
                                                    .font(.body)
                                                    .fontWeight(.semibold)
                                            }
                                            .foregroundColor(.blue)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(4)
                                        }
                                    }

                                    Spacer()

                                    // 화살표
                                    Image(systemName: "arrow.forward.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                                .padding()
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("미리 하기")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 500, height: 400)
    }
}
