import WeekAheadShared
import SwiftUI

// MARK: - 심플 홈 화면
// 시각장애인(VoiceOver) 및 모든 사용자를 위한 최소한의 직관적 화면.
// 원칙: 큰 글씨, 고대비, 큰 터치 영역, 명확한 음성 라벨, 한 화면에 한 가지 일.

struct SimpleHomeView: View {
    @EnvironmentObject var viewModel: TaskViewModel

    /// 고급(기존 전체) 모드로 전환하는 콜백
    var onOpenAdvanced: () -> Void

    @State private var showingAdd = false
    @State private var newTitle = ""
    @State private var newWhen: SimpleWhen = .today
    /// 완료 항목이 펼쳐진 섹션들 (섹션 제목 기준)
    @State private var expandedCompleted: Set<String> = []

    /// 오늘 이후의 "이번 주" 항목에서 오늘 섹션과 겹치는 것 제거하기 위한 ID 집합
    private var todayIds: Set<UUID> {
        Set(viewModel.todayTasks.map { $0.id })
    }

    private var todaySection: [Task] {
        viewModel.todayTasks
    }

    private var weekSection: [Task] {
        viewModel.thisWeekTasks.filter { !todayIds.contains($0.id) }
    }

    private var nextWeekSection: [Task] {
        viewModel.nextWeekTasks
    }

    private var isAllEmpty: Bool {
        todaySection.isEmpty && weekSection.isEmpty && nextWeekSection.isEmpty
    }

    private var remainingCount: Int {
        let union = viewModel.todayTasks
            + viewModel.thisWeekTasks.filter { !todayIds.contains($0.id) }
            + viewModel.nextWeekTasks
        return union.filter { !$0.isCompleted }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if isAllEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                        sectionView("오늘", todaySection)
                        sectionView("이번 주", weekSection)
                        sectionView("다음 주", nextWeekSection)
                    }
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.vertical, DS.Spacing.lg)
                }
            }

            Divider()

            addButton
        }
        .frame(minWidth: 360, idealWidth: 420, maxWidth: 560, minHeight: 460)
        .sheet(isPresented: $showingAdd) {
            SimpleAddSheet(
                title: $newTitle,
                when: $newWhen,
                onCancel: { resetAndCloseAdd() },
                onSave: { saveNewTask() }
            )
        }
    }

    // MARK: - 헤더

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("할 일")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("고급 모드", action: onOpenAdvanced)
                    .accessibilityLabel("고급 모드 열기")
                    .accessibilityHint("캘린더, 패턴, 통계 등 모든 기능이 있는 화면으로 이동합니다")
            }

            Text(remainingCount == 0 ? "남은 할 일이 없습니다" : "남은 할 일 \(remainingCount)개")
                .font(.headline)
                .foregroundStyle(.secondary)
                .accessibilityLabel(remainingCount == 0 ? "남은 할 일이 없습니다" : "남은 할 일 \(remainingCount)개")
        }
        .padding(DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.xs)
    }

    // MARK: - 섹션 (오늘 / 이번 주 / 다음 주)

    @ViewBuilder
    private func sectionView(_ title: String, _ items: [Task]) -> some View {
        let incomplete = items.filter { !$0.isCompleted }
        let completed = items.filter { $0.isCompleted }

        if !incomplete.isEmpty || !completed.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)

                ForEach(incomplete) { task in
                    row(task)
                }

                // 완료된 항목 — 섹션 맨 아래에서 접었다 폈다
                if !completed.isEmpty {
                    completedDisclosure(sectionTitle: title, completed: completed)
                }
            }
        }
    }

    private func row(_ task: Task) -> some View {
        SimpleTaskRow(
            task: task,
            onToggle: { viewModel.toggleTaskCompletion(task) },
            onDelete: { viewModel.deleteTask(task) }
        )
    }

    @ViewBuilder
    private func completedDisclosure(sectionTitle: String, completed: [Task]) -> some View {
        let isExpanded = expandedCompleted.contains(sectionTitle)

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isExpanded { expandedCompleted.remove(sectionTitle) }
                else { expandedCompleted.insert(sectionTitle) }
            }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                Text("완료된 항목 \(completed.count)개")
                Spacer()
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.vertical, DS.Spacing.xs)
            .padding(.horizontal, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("완료된 항목 \(completed.count)개")
        .accessibilityValue(isExpanded ? "펼쳐짐" : "접힘")
        .accessibilityHint("두 번 탭하면 완료된 할 일을 펼치거나 접습니다")

        if isExpanded {
            ForEach(completed) { task in
                row(task)
            }
        }
    }

    // MARK: - 빈 상태

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 44))
                .foregroundStyle(DS.Color.success)
                .accessibilityHidden(true)
            Text("할 일이 없어요")
                .font(.title3)
                .fontWeight(.semibold)
            Text("아래 '할 일 추가' 버튼으로 새 할 일을 만들 수 있어요")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DS.Spacing.xl)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 추가 버튼

    private var addButton: some View {
        HStack {
            Button(action: { showingAdd = true }) {
                Label("할 일 추가", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut("n", modifiers: .command)
            .accessibilityLabel("할 일 추가")
            .accessibilityHint("새 할 일을 입력하는 창을 엽니다")
            Spacer()
        }
        .padding(DS.Spacing.lg)
    }

    // MARK: - 동작

    private func saveNewTask() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let due = newWhen.date
        let task = Task(title: trimmed, dueDate: due)
        viewModel.addTask(task)
        resetAndCloseAdd()
    }

    private func resetAndCloseAdd() {
        newTitle = ""
        newWhen = .today
        showingAdd = false
    }
}

// MARK: - 심플 할 일 한 줄

private struct SimpleTaskRow: View {
    let task: Task
    let onToggle: () -> Void
    let onDelete: () -> Void

    private var dueText: String? {
        let cal = Calendar.current
        if cal.isDateInToday(task.dueDate) { return nil }
        return task.dueDateWithWeekday
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(task.isCompleted ? DS.Color.success : Color.primary)

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(task.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .strikethrough(task.isCompleted, color: .secondary)
                        .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                        .multilineTextAlignment(.leading)

                    if let dueText {
                        Text(dueText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("삭제", systemImage: "trash")
            }
        }
        // VoiceOver: 한 줄을 하나의 버튼으로 읽고, 완료 상태와 삭제 동작 제공
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(task.title)
        .accessibilityValue(task.isCompleted ? "완료됨" : "미완료")
        .accessibilityHint("두 번 탭하면 완료 상태가 바뀝니다")
        .accessibilityAddTraits(task.isCompleted ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(named: "삭제", onDelete)
    }
}

// MARK: - 언제 할지

enum SimpleWhen: String, CaseIterable, Identifiable {
    case today = "오늘"
    case tomorrow = "내일"
    case thisWeekend = "이번 주말"
    var id: String { rawValue }

    var date: Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        switch self {
        case .today:
            return today
        case .tomorrow:
            return cal.date(byAdding: .day, value: 1, to: today) ?? today
        case .thisWeekend:
            // 다가오는 토요일
            let weekday = cal.component(.weekday, from: today) // 1=일 ... 7=토
            let daysUntilSaturday = (7 - weekday + 7) % 7
            let offset = daysUntilSaturday == 0 ? 7 : daysUntilSaturday
            return cal.date(byAdding: .day, value: offset, to: today) ?? today
        }
    }
}

// MARK: - 심플 추가 시트

private struct SimpleAddSheet: View {
    @Binding var title: String
    @Binding var when: SimpleWhen
    var onCancel: () -> Void
    var onSave: () -> Void

    @FocusState private var titleFocused: Bool

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Text("새 할 일")
                .font(.title2)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("무엇을 할까요?")
                    .font(.headline)
                TextField("예: 약 먹기", text: $title)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding(DS.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous)
                            .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                    )
                    .focused($titleFocused)
                    .accessibilityLabel("할 일 제목")
                    .onSubmit { if canSave { onSave() } }
            }

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("언제 할까요?")
                    .font(.headline)
                Picker("언제", selection: $when) {
                    ForEach(SimpleWhen.allCases) { w in
                        Text(w.rawValue).tag(w)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("언제 할지 선택")
            }

            Spacer()

            HStack(spacing: DS.Spacing.md) {
                Spacer()
                Button("취소", action: onCancel)
                    .controlSize(.large)
                    .keyboardShortcut(.cancelAction)

                Button("저장", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!canSave)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(DS.Spacing.xl)
        .frame(width: 400, height: 320)
        .onAppear { titleFocused = true }
    }
}
