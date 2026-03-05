import WeekAheadShared
import SwiftUI

struct FlexiblePatternScheduleView: View {
    let pattern: ApprovedPattern
    @Binding var selectedDate: Date
    let onConfirm: (Date) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .foregroundColor(.blue)
                                .font(.title3)
                            Text(pattern.taskTitle)
                                .font(.headline)
                        }

                        HStack(spacing: 12) {
                            Label(pattern.patternTypeEnum.rawValue, systemImage: pattern.patternTypeEnum.icon)
                            Label(pattern.frequency.rawValue, systemImage: "arrow.triangle.2.circlepath")
                            Label(pattern.estimatedTimeFormatted, systemImage: "clock")
                        }
                        .font(.callout)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("유동 일정 패턴")
                }

                Section {
                    DatePicker(
                        "다음 발생일",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                } header: {
                    Text("날짜 선택")
                } footer: {
                    Text("이 날짜에 할 일이 자동으로 생성됩니다. 패턴이 다시 활성화됩니다.")
                        .font(.callout)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("다음 날짜 설정")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("확인") {
                        onConfirm(selectedDate)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(width: 400, height: 320)
    }
}
