import SwiftUI

// MARK: - Drag Preview Info

/// 드래그 프리뷰 정보
struct DragPreviewInfo {
    let taskId: UUID
    let targetDate: Date
    let estimatedMinutes: Int
}

// MARK: - Shared Enums

enum WeekViewMode: String, CaseIterable {
    case calendar = "캘린더"
    case list = "리스트"
}

enum TaskFilterMode: String, CaseIterable {
    case byStartDate = "시작일 기준"
    case byDueDate = "마감일 기준"
}

enum CalendarViewMode: String, CaseIterable, Codable {
    case week = "주간"
    case month = "월간"
}
