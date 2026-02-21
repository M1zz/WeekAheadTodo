//
//  SettingsView.swift
//  TodoAlarm (iOS)
//
//  설정 및 통계 탭
//

import WeekAheadShared
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @StateObject private var notificationManager = NotificationManager.shared

    var body: some View {
        NavigationStack {
            List {
                // 알림 섹션
                Section("알림 설정") {
                    HStack {
                        Image(systemName: authStatusIcon)
                            .foregroundColor(authStatusColor)
                        Text(authStatusText)
                            .font(.callout)
                    }

                    if notificationManager.authorizationStatus != .authorized {
                        Button("알림 권한 요청") {
                            _Concurrency.Task {
                                await viewModel.requestNotificationPermission()
                            }
                        }
                    }

                    Button("알림 즉시 업데이트") {
                        _Concurrency.Task {
                            await viewModel.refreshNotificationsAndActivity()
                        }
                    }
                }

                // 동기화 섹션
                Section("동기화") {
                    // 자동 동기화 토글
                    Toggle(isOn: $viewModel.isAutoSyncEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("자동 동기화")
                                .font(.callout)
                            Text("1시간마다 자동으로 클라우드에서 데이터 가져오기")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

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

    // MARK: - Computed Properties

    private var authStatusIcon: String {
        switch notificationManager.authorizationStatus {
        case .authorized:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle"
        default:
            return "exclamationmark.circle"
        }
    }

    private var authStatusColor: Color {
        switch notificationManager.authorizationStatus {
        case .authorized:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        default:
            return .gray
        }
    }

    private var authStatusText: String {
        switch notificationManager.authorizationStatus {
        case .authorized:
            return "알림 권한 승인됨"
        case .denied:
            return "알림 권한 거부됨 (설정에서 변경)"
        case .notDetermined:
            return "알림 권한 미요청"
        default:
            return "알림 권한 상태 불명"
        }
    }
}
