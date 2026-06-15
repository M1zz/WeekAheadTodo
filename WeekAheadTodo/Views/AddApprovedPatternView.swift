import WeekAheadShared
import SwiftUI
import SwiftData

struct AddApprovedPatternView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var estimatedHours: Int = 0
    @State private var estimatedMinutes: Int = 30
    @State private var leadTimeDays: Int = 0
    @State private var taskType: TaskType = .preparable
    @State private var frequency: RecurrenceFrequency = .weekly
    @State private var selectedDays: Set<Int> = []
    @State private var nextOccurrenceDate: Date = Date()
    @State private var isFlexibleSchedule: Bool = false

    // 요일: 1=일, 2=월, 3=화, 4=수, 5=목, 6=금, 7=토
    private let weekdays: [(Int, String)] = [
        (2, "월"), (3, "화"), (4, "수"), (5, "목"), (6, "금"), (7, "토"), (1, "일")
    ]

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && (estimatedHours > 0 || estimatedMinutes > 0)
            && (frequency == .daily || isFlexibleSchedule || !selectedDays.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("할 일 설정") {
                    TextField("제목", text: $title)

                    HStack {
                        Text("예상 소요 시간")
                        Spacer()
                        Picker("시간", selection: $estimatedHours) {
                            ForEach(0..<13) { Text("\($0)시간").tag($0) }
                        }
                        .frame(width: 100)
                        Picker("분", selection: $estimatedMinutes) {
                            ForEach([0, 15, 30, 45], id: \.self) { Text("\($0)분").tag($0) }
                        }
                        .frame(width: 80)
                    }

                    Stepper("선행 소요 일수: \(leadTimeDays)일", value: $leadTimeDays, in: 0...14)

                    Picker("태스크 유형", selection: $taskType) {
                        ForEach(TaskType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("반복 설정") {
                    Picker("빈도", selection: $frequency) {
                        Text(RecurrenceFrequency.daily.rawValue).tag(RecurrenceFrequency.daily)
                        Text(RecurrenceFrequency.weekly.rawValue).tag(RecurrenceFrequency.weekly)
                        Text(RecurrenceFrequency.biweekly.rawValue).tag(RecurrenceFrequency.biweekly)
                        Text(RecurrenceFrequency.monthly.rawValue).tag(RecurrenceFrequency.monthly)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: frequency) { _ in
                        if frequency == .daily {
                            selectedDays = []
                            isFlexibleSchedule = false
                        }
                    }

                    if frequency != .daily {
                        Toggle(isOn: $isFlexibleSchedule) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("유동 일정 (매번 날짜 직접 설정)")
                                Text("요일이 매주 바뀌어서 직접 날짜를 지정해야 하는 경우")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .onChange(of: isFlexibleSchedule) { flexible in
                            if flexible { selectedDays = [] }
                        }
                    }

                    if frequency != .daily && !isFlexibleSchedule {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("요일 선택")
                                .font(.callout)
                                .foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                ForEach(weekdays, id: \.0) { (dayNum, dayLabel) in
                                    let isSelected = selectedDays.contains(dayNum)
                                    Button(dayLabel) {
                                        if isSelected {
                                            selectedDays.remove(dayNum)
                                        } else {
                                            selectedDays.insert(dayNum)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(isSelected ? .blue : .gray)
                                    .controlSize(.small)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    DatePicker("다음 발생일", selection: $nextOccurrenceDate, displayedComponents: .date)
                }

                if !isValid {
                    Section {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(.orange)
                            if title.trimmingCharacters(in: .whitespaces).isEmpty {
                                Text("제목을 입력해주세요")
                            } else if estimatedHours == 0 && estimatedMinutes == 0 {
                                Text("예상 소요 시간을 설정해주세요")
                            } else {
                                Text("반복할 요일을 하나 이상 선택해주세요")
                            }
                        }
                        .font(.callout)
                        .foregroundColor(.orange)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("패턴 추가")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("추가") { savePattern() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isValid)
                }
            }
        }
        .frame(width: 500, height: 620)
    }

    private func savePattern() {
        let totalMinutes = estimatedHours * 60 + estimatedMinutes
        let daysArray = selectedDays.isEmpty ? nil : Array(selectedDays).sorted()

        let pattern = ApprovedPattern(
            taskTitle: title.trimmingCharacters(in: .whitespaces),
            estimatedMinutes: totalMinutes,
            leadTimeDays: leadTimeDays,
            taskType: taskType,
            frequency: frequency,
            daysOfWeek: daysArray,
            nextOccurrenceDate: nextOccurrenceDate,
            isFlexibleSchedule: isFlexibleSchedule
        )

        modelContext.insert(pattern)

        do {
            try modelContext.save()
            // 패턴 추가 직후 즉시 태스크가 생성되도록 알림 (앱 재시작 없이 반영)
            NotificationCenter.default.post(name: .approvedPatternsDidChange, object: nil)
            dismiss()
        } catch {
            print("❌ [AddApprovedPatternView] 저장 실패: \(error)")
        }
    }
}
