//
//  SettingsView.swift
//  TodoAlarm (iOS)
//
//  설정 및 통계 탭
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: TaskViewModel

    var body: some View {
        NavigationStack {
            List {
                // 동기화 섹션
                Section("동기화") {
                    if let lastSync = viewModel.lastSyncDate {
                        LabeledContent("마지막 동기화") {
                            Text(lastSync, style: .relative)
                        }
                    }

                    Button {
                        print("🔘 [iOS SettingsView] 지금 동기화 버튼 클릭")
                        _Concurrency.Task {
                            print("🚀 [iOS SettingsView] Task 시작 - syncFromCloud() 호출")
                            await viewModel.syncFromCloud()
                            print("✅ [iOS SettingsView] syncFromCloud() 완료")
                        }
                    } label: {
                        HStack {
                            if viewModel.isSyncing {
                                ProgressView()
                                    .padding(.trailing, 4)
                            }
                            Text("지금 동기화")
                        }
                    }
                    .disabled(viewModel.isSyncing)

                    if let error = viewModel.syncError {
                        Text("오류: \(error)")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                // 통계 섹션
                Section("통계") {
                    LabeledContent("총 태스크") {
                        Text("\(viewModel.tasks.count)개")
                    }
                    LabeledContent("오늘") {
                        Text("\(viewModel.todayTasks.count)개")
                    }
                    LabeledContent("이번 주") {
                        Text("\(viewModel.thisWeekTasks.count)개")
                    }
                    LabeledContent("다음 주") {
                        Text("\(viewModel.nextWeekTasks.count)개")
                    }
                    LabeledContent("프로젝트") {
                        Text("\(viewModel.projects.count)개")
                    }
                }

                // 앱 정보 섹션
                Section("정보") {
                    LabeledContent("버전") {
                        Text("1.0.0")
                    }
                    Text("macOS WeekAheadTodo 데이터를 읽기 전용으로 표시합니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("더보기")
        }
    }
}
