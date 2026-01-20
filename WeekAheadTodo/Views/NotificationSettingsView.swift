import SwiftUI

// MARK: - Notification Settings View

/// 알림 시간 커스터마이징 설정 뷰
struct NotificationSettingsView: View {
    @EnvironmentObject var notificationService: NotificationService
    @Environment(\.dismiss) private var dismiss

    @State private var showingAddTime = false
    @State private var newHour: Int = 9
    @State private var newMinute: Int = 0
    @State private var newLabel: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("알림 시간 관리")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("알림을 받을 시간을 자유롭게 설정하세요")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("완료") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // 알림 시간 목록
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 재촉 알림 설정
                    nudgeNotificationSection

                    Divider()

                    // 알림 시간 목록
                    alarmTimesSection
                }
                .padding()
            }
        }
        .frame(width: 600, height: 500)
        .sheet(isPresented: $showingAddTime) {
            addTimeSheet
        }
    }

    // MARK: - 재촉 알림 섹션

    private var nudgeNotificationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bell.badge.fill")
                    .foregroundColor(.orange)
                Text("재촉 알림")
                    .font(.headline)
            }

            Toggle("마감 임박 태스크 재촉 알림 활성화", isOn: Binding(
                get: { notificationService.nudgeNotificationEnabled },
                set: { notificationService.setNudgeNotificationEnabled($0) }
            ))

            Text("마감 2일 이내 시작 안 한 일, 마감 당일 진행 중인 일을 추가로 알려드려요")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - 알림 시간 섹션

    private var alarmTimesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.blue)
                Text("알림 시간")
                    .font(.headline)

                Spacer()

                Button(action: { showingAddTime = true }) {
                    Label("추가", systemImage: "plus.circle.fill")
                }
            }

            if notificationService.notificationTimes.isEmpty {
                emptyStateView
            } else {
                ForEach(notificationService.notificationTimes) { time in
                    NotificationTimeRow(time: time)
                        .environmentObject(notificationService)
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text("알림 시간이 없습니다")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("새 알림 시간을 추가하세요")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    // MARK: - 알림 시간 추가 시트

    private var addTimeSheet: some View {
        VStack(spacing: 20) {
            Text("새 알림 시간 추가")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {
                Text("라벨")
                    .font(.headline)
                TextField("예: 아침 체크", text: $newLabel)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("시간")
                    .font(.headline)

                HStack(spacing: 16) {
                    // 시간 Picker
                    VStack {
                        Text("시")
                            .font(.callout)
                            .foregroundColor(.secondary)
                        Picker("시", selection: $newHour) {
                            ForEach(0..<24) { hour in
                                Text("\(hour)")
                                    .tag(hour)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                    }

                    Text(":")
                        .font(.largeTitle)

                    // 분 Picker
                    VStack {
                        Text("분")
                            .font(.callout)
                            .foregroundColor(.secondary)
                        Picker("분", selection: $newMinute) {
                            ForEach(0..<60) { minute in
                                Text(String(format: "%02d", minute))
                                    .tag(minute)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                    }
                }
            }

            HStack(spacing: 12) {
                Button("취소") {
                    showingAddTime = false
                    resetNewTimeFields()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("추가") {
                    notificationService.addNotificationTime(
                        hour: newHour,
                        minute: newMinute,
                        label: newLabel.isEmpty ? "\(newHour)시 \(newMinute)분" : newLabel
                    )
                    showingAddTime = false
                    resetNewTimeFields()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(newLabel.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
    }

    private func resetNewTimeFields() {
        newHour = 9
        newMinute = 0
        newLabel = ""
    }
}

// MARK: - Notification Time Row

struct NotificationTimeRow: View {
    let time: NotificationTime
    @EnvironmentObject var notificationService: NotificationService

    @State private var showingEdit = false
    @State private var editHour: Int
    @State private var editMinute: Int
    @State private var editLabel: String
    @State private var editIsEnabled: Bool

    init(time: NotificationTime) {
        self.time = time
        _editHour = State(initialValue: time.hour)
        _editMinute = State(initialValue: time.minute)
        _editLabel = State(initialValue: time.label)
        _editIsEnabled = State(initialValue: time.isEnabled)
    }

    var body: some View {
        HStack(spacing: 12) {
            // 활성화 토글
            Toggle("", isOn: Binding(
                get: { time.isEnabled },
                set: { newValue in
                    notificationService.updateNotificationTime(
                        id: time.id,
                        hour: time.hour,
                        minute: time.minute,
                        label: time.label,
                        isEnabled: newValue
                    )
                }
            ))
            .labelsHidden()

            // 시간 표시
            VStack(alignment: .leading, spacing: 4) {
                Text(time.label)
                    .font(.headline)
                    .foregroundColor(time.isEnabled ? .primary : .secondary)

                Text(String(format: "%02d:%02d", time.hour, time.minute))
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 편집 버튼
            Button(action: {
                editHour = time.hour
                editMinute = time.minute
                editLabel = time.label
                editIsEnabled = time.isEnabled
                showingEdit = true
            }) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)

            // 삭제 버튼
            Button(action: {
                notificationService.removeNotificationTime(id: time.id)
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(time.isEnabled ? Color(NSColor.controlBackgroundColor) : Color.gray.opacity(0.1))
        .cornerRadius(8)
        .sheet(isPresented: $showingEdit) {
            editTimeSheet
        }
    }

    private var editTimeSheet: some View {
        VStack(spacing: 20) {
            Text("알림 시간 수정")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {
                Text("라벨")
                    .font(.headline)
                TextField("라벨", text: $editLabel)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("시간")
                    .font(.headline)

                HStack(spacing: 16) {
                    VStack {
                        Text("시")
                            .font(.callout)
                            .foregroundColor(.secondary)
                        Picker("시", selection: $editHour) {
                            ForEach(0..<24) { hour in
                                Text("\(hour)").tag(hour)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                    }

                    Text(":")
                        .font(.largeTitle)

                    VStack {
                        Text("분")
                            .font(.callout)
                            .foregroundColor(.secondary)
                        Picker("분", selection: $editMinute) {
                            ForEach(0..<60) { minute in
                                Text(String(format: "%02d", minute)).tag(minute)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                    }
                }
            }

            Toggle("활성화", isOn: $editIsEnabled)

            HStack(spacing: 12) {
                Button("취소") {
                    showingEdit = false
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("저장") {
                    notificationService.updateNotificationTime(
                        id: time.id,
                        hour: editHour,
                        minute: editMinute,
                        label: editLabel,
                        isEnabled: editIsEnabled
                    )
                    showingEdit = false
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}
