import WeekAheadShared
import SwiftUI
import SwiftData

struct EditApprovedPatternView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let pattern: ApprovedPattern

    @State private var title: String
    @State private var estimatedHours: Int
    @State private var estimatedMinutes: Int
    @State private var leadTimeDays: Int
    @State private var taskType: TaskType

    init(pattern: ApprovedPattern) {
        self.pattern = pattern
        _title = State(initialValue: pattern.taskTitle)
        _estimatedHours = State(initialValue: pattern.estimatedMinutes / 60)
        _estimatedMinutes = State(initialValue: pattern.estimatedMinutes % 60)
        _leadTimeDays = State(initialValue: pattern.leadTimeDays)
        _taskType = State(initialValue: pattern.taskType)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("패턴 정보") {
                    LabeledContent("유형", value: pattern.patternTypeEnum.rawValue)
                    LabeledContent("빈도", value: pattern.frequency.rawValue)
                    LabeledContent("캘린더", value: pattern.primaryCalendar)
                    LabeledContent("승인일", value: pattern.approvedAt.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("신뢰도", value: "\(Int(pattern.confidenceScore * 100))%")
                }

                Section("할 일 설정") {
                    TextField("제목", text: $title)

                    HStack {
                        Text("예상 소요 시간")
                        Spacer()
                        Picker("시간", selection: $estimatedHours) {
                            ForEach(0..<13) { hour in
                                Text("\(hour)시간").tag(hour)
                            }
                        }
                        .frame(width: 100)
                        Picker("분", selection: $estimatedMinutes) {
                            ForEach([0, 15, 30, 45], id: \.self) { minute in
                                Text("\(minute)분").tag(minute)
                            }
                        }
                        .frame(width: 80)
                    }

                    Stepper("선행 소요 일수: \(leadTimeDays)일", value: $leadTimeDays, in: 0...14)
                }

                Section("태스크 유형") {
                    Picker("유형", selection: $taskType) {
                        ForEach(TaskType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    if taskType == .preparable {
                        Text("미리 시간이 있을 때 해둘 수 있는 일입니다")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    } else {
                        Text("해당 날짜에만 할 수 있는 일입니다 (회의, 미팅 등)")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                }

                Section("반복 정보") {
                    LabeledContent("다음 발생", value: pattern.nextOccurrenceDate.formatted(date: .abbreviated, time: .omitted))
                    if let lastGenerated = pattern.lastGeneratedTaskDate {
                        LabeledContent("마지막 생성", value: lastGenerated.formatted(date: .abbreviated, time: .omitted))
                    }
                    LabeledContent("상태", value: pattern.isActive ? "활성" : "비활성")
                }

                Section("샘플 이벤트") {
                    ForEach(Array(zip(pattern.sampleEventTitles, pattern.sampleEventDates)), id: \.0) { title, date in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(.subheadline)
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("패턴 편집")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("저장") { saveChanges() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(width: 500, height: 700)
    }

    private func saveChanges() {
        pattern.taskTitle = title
        pattern.estimatedMinutes = estimatedHours * 60 + estimatedMinutes
        pattern.leadTimeDays = leadTimeDays
        pattern.taskTypeRaw = taskType.rawValue
        pattern.isUserModified = true

        do {
            try modelContext.save()
            dismiss()
        } catch {
        }
    }
}
