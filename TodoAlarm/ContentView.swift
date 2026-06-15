//
//  ContentView.swift
//  TodoAlarm
//
//  macOS 심플 화면과 통일된 섹션형 UI (오늘 / 이번 주 / 다음 주 + 완료 접기)
//  iOS는 CloudKit 읽기 전용 뷰어 — 추가는 macOS 앱에서.
//

import WeekAheadShared
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @State private var expandedCompleted: Set<String> = []
    @State private var showingSettings = false

    private var isAllEmpty: Bool {
        viewModel.todaySectionTasks.isEmpty
            && viewModel.thisWeekSectionTasks.isEmpty
            && viewModel.nextWeekSectionTasks.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isSyncing && viewModel.tasks.isEmpty {
                    ProgressView("동기화 중...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isAllEmpty {
                    ContentUnavailableView(
                        "할 일이 없습니다",
                        systemImage: "checkmark.circle",
                        description: Text("macOS 앱에서 새 할 일을 추가하세요")
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            Text(viewModel.remainingCount == 0
                                 ? "남은 할 일이 없습니다"
                                 : "남은 할 일 \(viewModel.remainingCount)개")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .accessibilityAddTraits(.isHeader)

                            sectionView("오늘", viewModel.todaySectionTasks)
                            sectionView("이번 주", viewModel.thisWeekSectionTasks)
                            sectionView("다음 주", viewModel.nextWeekSectionTasks)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("할 일")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        _Concurrency.Task { await viewModel.syncFromCloud() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isSyncing)
                    .accessibilityLabel("동기화")
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("설정")
                }
            }
            .refreshable {
                await viewModel.syncFromCloud()
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    SettingsView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("완료") { showingSettings = false }
                            }
                        }
                }
            }
            .alert("동기화 오류", isPresented: .constant(viewModel.syncError != nil)) {
                Button("확인") { viewModel.syncError = nil }
            } message: {
                if let error = viewModel.syncError {
                    Text(error)
                }
            }
        }
    }

    // MARK: - 섹션 (오늘 / 이번 주 / 다음 주)

    @ViewBuilder
    private func sectionView(_ title: String, _ items: [TaskModel]) -> some View {
        let incomplete = items.filter { !$0.isCompleted }
        let completed = items.filter { $0.isCompleted }

        if !incomplete.isEmpty || !completed.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)

                ForEach(incomplete) { task in
                    SimpleTaskRowiOS(task: task) { viewModel.toggleTaskCompletion(task) }
                }

                if !completed.isEmpty {
                    completedDisclosure(sectionTitle: title, completed: completed)
                }
            }
        }
    }

    @ViewBuilder
    private func completedDisclosure(sectionTitle: String, completed: [TaskModel]) -> some View {
        let isExpanded = expandedCompleted.contains(sectionTitle)

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isExpanded { expandedCompleted.remove(sectionTitle) }
                else { expandedCompleted.insert(sectionTitle) }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                Text("완료된 항목 \(completed.count)개")
                Spacer()
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("완료된 항목 \(completed.count)개")
        .accessibilityValue(isExpanded ? "펼쳐짐" : "접힘")
        .accessibilityHint("두 번 탭하면 완료된 할 일을 펼치거나 접습니다")

        if isExpanded {
            ForEach(completed) { task in
                SimpleTaskRowiOS(task: task) { viewModel.toggleTaskCompletion(task) }
            }
        }
    }
}

// MARK: - 심플 할 일 한 줄 (iOS)

private struct SimpleTaskRowiOS: View {
    let task: TaskModel
    let onToggle: () -> Void

    private var dueText: String? {
        Calendar.current.isDateInToday(task.dueDate) ? nil : task.dueDateWithWeekday
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(task.isCompleted ? Color.green : Color.primary)

                VStack(alignment: .leading, spacing: 2) {
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
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(task.title)
        .accessibilityValue(task.isCompleted ? "완료됨" : "미완료")
        .accessibilityHint("두 번 탭하면 완료 상태가 바뀝니다")
        .accessibilityAddTraits(task.isCompleted ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    ContentView()
        .environmentObject(TaskViewModel())
}
