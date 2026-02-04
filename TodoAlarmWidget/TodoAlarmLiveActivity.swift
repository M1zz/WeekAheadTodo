//
//  TodoAlarmLiveActivity.swift
//  TodoAlarmWidget
//
//  Live Activity 위젯 (다이나믹 아일랜드)
//

import ActivityKit
import WidgetKit
import SwiftUI

// Swift Concurrency Task와 구분하기 위한 typealias
typealias TaskModel = Task

#if os(iOS)
import Foundation

/// Live Activity Attributes (오늘 할 일 타이머)
@available(iOS 16.1, *)
struct TaskActivityAttributes: ActivityAttributes {
    /// 변경되지 않는 정적 데이터
    public struct ContentState: Codable, Hashable {
        /// 가장 긴급한 태스크 제목
        var urgentTaskTitle: String
        /// 마감 시간
        var dueDate: Date
        /// 남은 태스크 개수
        var remainingTasksCount: Int

        /// 마감 시간이 지났는지 확인
        var isPastDue: Bool {
            dueDate < Date()
        }

        /// 마감 시간 포맷 (M/d HH:mm)
        var dueDateFormatted: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d HH:mm"
            formatter.locale = Locale(identifier: "ko_KR")
            return formatter.string(from: dueDate)
        }

        /// 경고 색상 (지났으면 빨간색, 아니면 오렌지)
        var alertColor: Color {
            isPastDue ? .red : .orange
        }
    }

    /// Activity 식별자
    var activityId: String
}

/// 오늘 할 일 Live Activity 위젯
@available(iOS 16.1, *)
struct TodoAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TaskActivityAttributes.self) { context in
            // 잠금 화면 뷰
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: context.state.isPastDue ? "exclamationmark.triangle.fill" : "clock.fill")
                        .foregroundColor(context.state.alertColor)
                    Text("오늘 할 일 \(context.state.remainingTasksCount)개")
                        .font(.headline)
                        .foregroundColor(context.state.isPastDue ? .red : .primary)
                }

                Text(context.state.urgentTaskTitle)
                    .font(.body)
                    .lineLimit(2)

                // 마감 시간 표시
                HStack(spacing: 4) {
                    Text("마감:")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Text(context.state.dueDateFormatted)
                        .font(.callout.bold())
                        .foregroundColor(context.state.alertColor)
                }

                // 타이머
                if context.state.isPastDue {
                    Text("\(context.state.dueDate, style: .timer) 지남")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.red)
                } else {
                    Text("\(context.state.dueDate, style: .timer) 남음")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(context.state.alertColor)
                }
            }
            .padding()
        } dynamicIsland: { context in
            // 다이나믹 아일랜드 구성
            DynamicIsland {
                // 확장 뷰
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.isPastDue ? "exclamationmark.triangle.fill" : "clock.badge.exclamationmark.fill")
                        .foregroundColor(context.state.alertColor)
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.remainingTasksCount)")
                        .font(.title2.bold())
                        .foregroundColor(context.state.alertColor)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    // 확장 뷰 내용
                    VStack(spacing: 12) {
                        // 헤더
                        HStack {
                            Image(systemName: context.state.isPastDue ? "exclamationmark.triangle.fill" : "clock.badge.exclamationmark.fill")
                                .foregroundColor(context.state.alertColor)
                                .font(.title2)
                            Text(context.state.isPastDue ? "마감 지남!" : "오늘 할 일")
                                .font(.headline)
                                .foregroundColor(context.state.isPastDue ? .red : .primary)
                            Spacer()
                        }

                        // 가장 긴급한 태스크
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(context.state.alertColor)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(context.state.urgentTaskTitle)
                                    .font(.body.bold())
                                    .lineLimit(2)

                                // 마감 시간 표시
                                HStack(spacing: 4) {
                                    Text("마감:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(context.state.dueDateFormatted)
                                        .font(.caption.bold())
                                        .foregroundColor(context.state.alertColor)
                                }

                                // 남은 시간 또는 지난 시간
                                if context.state.isPastDue {
                                    Text("\(context.state.dueDate, style: .relative) 지남")
                                        .font(.caption2)
                                        .foregroundColor(.red)
                                } else {
                                    Text("\(context.state.dueDate, style: .relative) 남음")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(context.state.isPastDue ? Color.red.opacity(0.1) : Color(.systemGray6))
                        .cornerRadius(12)

                        // 하단 정보
                        HStack {
                            Label("남은 할 일", systemImage: "checklist")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(context.state.remainingTasksCount)개")
                                .font(.caption.bold())
                                .foregroundColor(context.state.alertColor)
                        }
                    }
                    .padding()
                }
            } compactLeading: {
                // Compact Leading
                HStack(spacing: 4) {
                    Image(systemName: context.state.isPastDue ? "exclamationmark.triangle.fill" : "clock.fill")
                        .foregroundColor(context.state.alertColor)
                        .font(.caption2)
                    Text(timerText(for: context.state.dueDate))
                        .font(.caption2.bold())
                        .foregroundColor(context.state.alertColor)
                        .monospacedDigit()
                }
            } compactTrailing: {
                // Compact Trailing
                Text("\(context.state.remainingTasksCount)")
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(context.state.alertColor)
                    .clipShape(Capsule())
            } minimal: {
                // Minimal
                Image(systemName: context.state.isPastDue ? "exclamationmark.triangle.fill" : "clock.fill")
                    .foregroundColor(context.state.alertColor)
            }
            .keylineTint(context.state.alertColor)
        }
    }

    private func timerText(for dueDate: Date) -> String {
        let remaining = dueDate.timeIntervalSinceNow
        if remaining <= 0 {
            return "지남!"
        }

        let hours = Int(remaining) / 3600
        let minutes = Int(remaining) % 3600 / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

#endif
