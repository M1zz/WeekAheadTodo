import SwiftUI

/// 패턴 상세 및 Task 설정 뷰
struct PatternDetailView: View {
    @EnvironmentObject var calendarViewModel: CalendarViewModel
    @EnvironmentObject var taskViewModel: TaskViewModel
    @Environment(\.dismiss) var dismiss

    let pattern: RecurrencePattern

    @State private var title: String
    @State private var estimatedHours: Int
    @State private var estimatedMinutes: Int
    @State private var leadTimeDays: Int
    @State private var taskType: TaskType

    init(pattern: RecurrencePattern) {
        self.pattern = pattern
        _title = State(initialValue: pattern.suggestedTask.title)
        _estimatedHours = State(initialValue: pattern.suggestedTask.estimatedMinutes / 60)
        _estimatedMinutes = State(initialValue: pattern.suggestedTask.estimatedMinutes % 60)
        _leadTimeDays = State(initialValue: pattern.suggestedTask.leadTimeDays)
        _taskType = State(initialValue: pattern.suggestedTask.taskType)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // 패턴 정보
                        patternInfoSection

                        Divider()

                        // 과거 이벤트 목록
                        pastEventsSection

                        Divider()

                        // Task 설정
                        taskSettingsSection
                    }
                    .padding(24)
                }
            }
            .navigationTitle("패턴 상세")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Task 생성") {
                        createTaskAndDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 700)
    }

    // MARK: - Pattern Info Section

    private var patternInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("패턴 정보")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                infoRow(label: "유형", value: pattern.type.rawValue, icon: pattern.type.icon)
                infoRow(label: "빈도", value: pattern.frequency, icon: "calendar")
                infoRow(label: "시간대", value: pattern.timeRange, icon: "clock")
                infoRow(label: "신뢰도", value: "\(pattern.confidencePercent)%", icon: "chart.bar.fill")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("감지 근거:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ForEach(pattern.detectedCharacteristics, id: \.self) { characteristic in
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text(characteristic)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func infoRow(label: String, value: String, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .fontWeight(.medium)
            Spacer()
        }
        .font(.subheadline)
    }

    // MARK: - Past Events Section

    private var pastEventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("과거 이벤트 (\(pattern.events.count)회)")
                .font(.headline)

            // 최근 5개 날짜 요약
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.blue)
                    .font(.caption)
                Text("최근 5회:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(pattern.recentEventDatesFormatted)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.05))
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(pattern.events.prefix(10)) { event in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(.subheadline)
                            Text("\(event.startDate.formatted(date: .abbreviated, time: .omitted)) (\(event.dayOfWeekString)) \(event.startTimeFormatted)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(event.calendarTitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .padding(.vertical, 4)
                }

                if pattern.events.count > 10 {
                    Text("... 외 \(pattern.events.count - 10)개")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Task Settings Section

    private var taskSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Task 설정")
                .font(.headline)

            Form {
                Section {
                    TextField("제목", text: $title)

                    HStack {
                        Text("예상 소요 시간")
                        Spacer()
                        Picker("시간", selection: $estimatedHours) {
                            ForEach(0..<13) { hour in
                                Text("\(hour)시간").tag(hour)
                            }
                        }
                        .frame(width: 80)
                        Picker("분", selection: $estimatedMinutes) {
                            ForEach([0, 15, 30, 45], id: \.self) { minute in
                                Text("\(minute)분").tag(minute)
                            }
                        }
                        .frame(width: 70)
                    }

                    Stepper("선행 소요 일수: \(leadTimeDays)일", value: $leadTimeDays, in: 0...14)

                    if leadTimeDays > 0 {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("마감 \(leadTimeDays)일 전부터 '오늘 할 일'에 표시됩니다")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section {
                    Picker("태스크 유형", selection: $taskType) {
                        ForEach(TaskType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    if taskType == .preparable {
                        Text("미리 시간이 있을 때 해둘 수 있는 일입니다")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("해당 날짜에만 할 수 있는 일입니다 (회의, 미팅 등)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let recurrenceRule = pattern.suggestedTask.recurrenceRule {
                    Section("반복 설정") {
                        HStack {
                            Text("자동 반복 생성")
                            Spacer()
                            Text("켜짐")
                                .foregroundColor(.green)
                        }

                        HStack {
                            Text("빈도")
                            Spacer()
                            Text(recurrenceRule.description)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("다음 발생")
                            Spacer()
                            Text(recurrenceRule.nextOccurrenceDate.formatted(date: .abbreviated, time: .omitted))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
    }

    // MARK: - Actions

    private func createTaskAndDismiss() {
        // 수정된 Task 제안 생성
        let modifiedTask = SuggestedTask(
            title: title,
            estimatedMinutes: estimatedHours * 60 + estimatedMinutes,
            leadTimeDays: leadTimeDays,
            taskType: taskType,
            recurrenceRule: pattern.suggestedTask.recurrenceRule,
            userModified: true
        )

        // 패턴 업데이트
        var updatedPattern = pattern
        updatedPattern.suggestedTask = modifiedTask

        // Task 생성
        taskViewModel.createTaskFromPattern(updatedPattern)

        // 패턴 제거
        calendarViewModel.approvePatterns([pattern.id])

        // 완료 메시지
        print("✅ Task 생성 완료: \(title)")

        dismiss()
    }
}
