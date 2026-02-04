//
//  ContentView.swift
//  TodoAlarm
//
//  TabView 기반 메인 UI
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: TaskViewModel

    var body: some View {
        TabView {
            TodayTasksView()
                .tabItem {
                    Label("오늘", systemImage: "star.fill")
                }

            ThisWeekTasksView()
                .tabItem {
                    Label("이번 주", systemImage: "calendar")
                }

            NextWeekTasksView()
                .tabItem {
                    Label("다음 주", systemImage: "calendar.badge.clock")
                }

            SettingsView()
                .tabItem {
                    Label("더보기", systemImage: "ellipsis")
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(TaskViewModel())
}
