import Foundation
import AppIntents

/// 앱의 기본 단축어 제공
struct WeekAheadTodoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ListTasksIntent(),
            phrases: [
                "오늘 할 일 확인해줘 in \(.applicationName)",
                "오늘 뭐 해야 돼? in \(.applicationName)",
                "남은 할 일 뭐야? in \(.applicationName)"
            ],
            shortTitle: "오늘 할 일",
            systemImageName: "checklist"
        )

        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "태스크 추가해줘 in \(.applicationName)",
                "할 일 추가 in \(.applicationName)"
            ],
            shortTitle: "태스크 추가",
            systemImageName: "plus.circle"
        )
    }

    static var shortcutTileColor: ShortcutTileColor {
        .blue
    }
}
