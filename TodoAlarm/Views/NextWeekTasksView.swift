//
//  NextWeekTasksView.swift
//  TodoAlarm (iOS)
//
//  다음 주 할 일 탭
//

import SwiftUI

struct NextWeekTasksView: View {
    @EnvironmentObject var viewModel: TaskViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isSyncing {
                    ProgressView("동기화 중...")
                } else if viewModel.nextWeekTasks.isEmpty {
                    ContentUnavailableView(
                        "다음 주 할 일이 없습니다",
                        systemImage: "calendar.badge.clock",
                        description: Text("macOS 앱에서 할 일을 추가하세요")
                    )
                } else {
                    List(viewModel.nextWeekTasks) { task in
                        TaskRowView(task: task)
                    }
                }
            }
            .navigationTitle("다음 주")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        _Concurrency.Task { await viewModel.syncFromCloud() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isSyncing)
                }
            }
        }
    }
}
