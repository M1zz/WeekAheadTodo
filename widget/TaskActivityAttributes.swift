//
//  TaskActivityAttributes.swift
//  widget
//
//  Live Activity (다이나믹 아일랜드) Attributes 정의
//

#if os(iOS)
import ActivityKit
import WidgetKit
import SwiftUI

/// Live Activity Attributes (오늘 할 일 타이머)
@available(iOS 16.1, *)
public struct TaskActivityAttributes: ActivityAttributes {
    /// 변경되지 않는 정적 데이터
    public struct ContentState: Codable, Hashable {
        /// 가장 긴급한 태스크 제목
        public var urgentTaskTitle: String
        /// 마감 시간
        public var dueDate: Date
        /// 남은 태스크 개수
        public var remainingTasksCount: Int

        public init(urgentTaskTitle: String, dueDate: Date, remainingTasksCount: Int) {
            self.urgentTaskTitle = urgentTaskTitle
            self.dueDate = dueDate
            self.remainingTasksCount = remainingTasksCount
        }

        /// 마감 시간이 지났는지 확인
        public var isPastDue: Bool {
            dueDate < Date()
        }

        /// 마감 시간 포맷 (M/d HH:mm)
        public var dueDateFormatted: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d HH:mm"
            formatter.locale = Locale(identifier: "ko_KR")
            return formatter.string(from: dueDate)
        }

        /// 경고 색상 (지났으면 빨간색, 아니면 오렌지)
        public var alertColor: Color {
            isPastDue ? .red : .orange
        }
    }

    /// Activity 식별자
    public var activityId: String

    public init(activityId: String) {
        self.activityId = activityId
    }
}

#endif // os(iOS)
