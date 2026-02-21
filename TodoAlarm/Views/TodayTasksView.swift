//
//  TodayTasksView.swift
//  TodoAlarm (iOS)
//
//  오늘 할 일 탭
//

import WeekAheadShared
import SwiftUI

struct TodayTasksView: View {
    @EnvironmentObject var viewModel: TaskViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isSyncing {
                    ProgressView("동기화 중...")
                } else if viewModel.todayTasks.isEmpty {
                    ContentUnavailableView(
                        "오늘 할 일이 없습니다",
                        systemImage: "checkmark.circle.fill",
                        description: Text("새로운 할 일을 macOS 앱에서 추가하세요")
                    )
                } else {
                    List(viewModel.todayTasks) { task in
                        TaskRowView(task: task)
                    }
                }
            }
            .navigationTitle("오늘")
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
            .alert("동기화 오류", isPresented: .constant(viewModel.syncError != nil)) {
                Button("확인") {
                    viewModel.syncError = nil
                }
            } message: {
                if let error = viewModel.syncError {
                    Text(error)
                }
            }
        }
    }
}
