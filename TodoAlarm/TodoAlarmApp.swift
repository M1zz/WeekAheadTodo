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
                    print("🚀 [iOS TodoAlarmApp] 앱 시작")

                    // 1. 알림 권한 요청
                    print("   1️⃣ 알림 권한 요청...")
                    await taskViewModel.requestNotificationPermission()

                    // 2. 자동 동기화
                    print("   2️⃣ 자동 동기화 시작...")
                    await taskViewModel.syncFromCloud()

                    // 3. 알림 및 Live Activity 설정
                    print("   3️⃣ 알림 및 Live Activity 업데이트...")
                    await taskViewModel.refreshNotificationsAndActivity()

                    print("✅ [iOS TodoAlarmApp] 앱 시작 완료")
                }
        }
    }
}
