import WidgetKit
import SwiftUI

/// 오늘 할 일 위젯
struct TodayWidget: Widget {
    let kind: String = "TodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayWidgetProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("오늘 할 일")
        .description("오늘 해야 할 태스크를 한눈에 확인하세요")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// 위젯 데이터 제공자
struct TodayWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayWidgetEntry {
        TodayWidgetEntry(date: Date(), tasks: sampleTasks())
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayWidgetEntry) -> Void) {
        let entry = TodayWidgetEntry(date: Date(), tasks: loadTodayTasks())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayWidgetEntry>) -> Void) {
        let currentDate = Date()
        let tasks = loadTodayTasks()

        // 다음 업데이트: 1시간 후
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!

        let entry = TodayWidgetEntry(date: currentDate, tasks: tasks)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))

        completion(timeline)
    }

    /// UserDefaults에서 오늘 할 일 로드
    private func loadTodayTasks() -> [WidgetTask] {
        guard let data = UserDefaults.standard.data(forKey: "SavedTasks"),
              let tasks = try? JSONDecoder().decode([Task].self, from: data) else {
            return []
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        return tasks
            .filter { task in
                let effectiveStart = task.effectiveStartDate
                return effectiveStart >= today && effectiveStart < tomorrow && !task.isCompleted
            }
            .prefix(10)
            .map { WidgetTask(from: $0) }
    }

    private func sampleTasks() -> [WidgetTask] {
        [
            WidgetTask(title: "회의 준비", dueDate: Date(), estimatedMinutes: 60, priority: "보통"),
            WidgetTask(title: "보고서 작성", dueDate: Date(), estimatedMinutes: 120, priority: "높음"),
            WidgetTask(title: "이메일 확인", dueDate: Date(), estimatedMinutes: 30, priority: "낮음")
        ]
    }
}

/// 위젯 엔트리
struct TodayWidgetEntry: TimelineEntry {
    let date: Date
    let tasks: [WidgetTask]
}

/// 위젯용 간단한 Task 모델
struct WidgetTask: Codable {
    let title: String
    let dueDate: Date
    let estimatedMinutes: Int
    let priority: String

    init(title: String, dueDate: Date, estimatedMinutes: Int, priority: String) {
        self.title = title
        self.dueDate = dueDate
        self.estimatedMinutes = estimatedMinutes
        self.priority = priority
    }

    init(from task: Task) {
        self.title = task.title
        self.dueDate = task.dueDate
        self.estimatedMinutes = task.estimatedMinutes
        self.priority = task.priority.rawValue
    }
}

/// 위젯 뷰
struct TodayWidgetView: View {
    var entry: TodayWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

/// Small 위젯
struct SmallWidgetView: View {
    let entry: TodayWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                Text("오늘 할 일")
                    .font(.headline)
                    .fontWeight(.bold)
            }

            if entry.tasks.isEmpty {
                Text("할 일 없음")
                    .font(.callout)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(entry.tasks.prefix(3), id: \.title) { task in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(priorityColor(task.priority))
                                .frame(width: 6, height: 6)
                            Text(task.title)
                                .font(.callout)
                                .lineLimit(1)
                        }
                    }
                }

                if entry.tasks.count > 3 {
                    Text("+\(entry.tasks.count - 3)개 더")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }

    private func priorityColor(_ priority: String) -> Color {
        switch priority {
        case "긴급": return .red
        case "높음": return .orange
        case "낮음": return .gray
        default: return .blue
        }
    }
}

/// Medium 위젯
struct MediumWidgetView: View {
    let entry: TodayWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                VStack(alignment: .leading) {
                    Text("오늘 할 일")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("\(entry.tasks.count)개 태스크")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            if entry.tasks.isEmpty {
                Text("할 일이 없습니다")
                    .font(.callout)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.tasks.prefix(5), id: \.title) { task in
                        HStack {
                            Circle()
                                .fill(priorityColor(task.priority))
                                .frame(width: 8, height: 8)
                            Text(task.title)
                                .font(.callout)
                                .lineLimit(1)
                            Spacer()
                            Text("\(task.estimatedMinutes)분")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func priorityColor(_ priority: String) -> Color {
        switch priority {
        case "긴급": return .red
        case "높음": return .orange
        case "낮음": return .gray
        default: return .blue
        }
    }
}

/// Large 위젯
struct LargeWidgetView: View {
    let entry: TodayWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title)
                VStack(alignment: .leading) {
                    Text("오늘 할 일")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("\(entry.tasks.count)개 태스크 · \(totalMinutes())분")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            if entry.tasks.isEmpty {
                Spacer()
                Text("할 일이 없습니다")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(entry.tasks, id: \.title) { task in
                            HStack(alignment: .top) {
                                Circle()
                                    .fill(priorityColor(task.priority))
                                    .frame(width: 10, height: 10)
                                    .padding(.top, 4)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.title)
                                        .font(.callout)
                                        .fontWeight(.medium)
                                    Text("\(task.estimatedMinutes)분 · \(task.priority)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func totalMinutes() -> Int {
        entry.tasks.reduce(0) { $0 + $1.estimatedMinutes }
    }

    private func priorityColor(_ priority: String) -> Color {
        switch priority {
        case "긴급": return .red
        case "높음": return .orange
        case "낮음": return .gray
        default: return .blue
        }
    }
}
