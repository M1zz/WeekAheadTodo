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
                    // 앱 시작 시 자동 동기화
                    await taskViewModel.syncFromCloud()
                }
        }
    }
}
