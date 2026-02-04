//
//  TodoAlarmApp.swift
//  TodoAlarm
//
//  CloudKit 뷰어 앱
//

import SwiftUI
import Combine

@main
struct TodoAlarmApp: App {
    @StateObject private var taskViewModel = TaskViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(taskViewModel)
                .task {
                    print("🚀 [iOS TodoAlarmApp] 앱 시작 - 자동 동기화 시작")
                    // 앱 시작 시 자동 동기화
                    await taskViewModel.syncFromCloud()
                    print("✅ [iOS TodoAlarmApp] 자동 동기화 완료")
                }
        }
    }
}
