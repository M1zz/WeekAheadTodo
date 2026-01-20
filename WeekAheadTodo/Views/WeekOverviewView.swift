import SwiftUI

// MARK: - Week Overview View

struct DailyWorkload: Identifiable {
    let id = UUID()
    let date: Date
    let totalMinutes: Int
    let capacity: Int
    let taskCount: Int

    var isOverCapacity: Bool {
        totalMinutes > capacity
    }
}

struct WeekOverviewView: View {
    @EnvironmentObject var viewModel: TaskViewModel

    private var workloads: [DailyWorkload] {
        let weeklyData = viewModel.weeklyWorkload()
        return weeklyData.map { item in
            let count = viewModel.tasks(for: item.date).count
            return DailyWorkload(
                date: item.date,
                totalMinutes: item.minutes,
                capacity: item.capacity,
                taskCount: count
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("주간 개요")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(24)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    workloadChart

                    dailyBreakdown
                }
                .padding(24)
            }
        }
    }

    private var workloadChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("2주간 워크로드")
                .font(.headline)

            GeometryReader { geometry in
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(workloads) { workload in
                        VStack(spacing: 4) {
                            let maxMinutes = workloads.map { $0.totalMinutes }.max() ?? 480
                            let height = CGFloat(workload.totalMinutes) / CGFloat(max(maxMinutes, 480)) * (geometry.size.height - 40)

                            Rectangle()
                                .fill(workload.isOverCapacity ? Color.red : Color.blue)
                                .frame(width: (geometry.size.width - CGFloat(workloads.count - 1) * 4) / CGFloat(workloads.count), height: max(height, 4))
                                .cornerRadius(4)

                            Text(dayLabel(workload.date))
                                .font(.callout)
                                .foregroundColor(isToday(workload.date) ? .blue : .secondary)
                        }
                    }
                }
            }
            .frame(height: 200)

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 10, height: 10)
                    Text("정상")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                    Text("용량 초과")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private var dailyBreakdown: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("일별 상세")
                .font(.headline)

            ForEach(workloads) { workload in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dateLabel(workload.date))
                            .font(.body)
                            .fontWeight(isToday(workload.date) ? .bold : .regular)

                        Text("\(workload.taskCount)개 태스크")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatMinutes(workload.totalMinutes))
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(workload.isOverCapacity ? .red : .primary)

                        if workload.isOverCapacity {
                            Text("초과")
                                .font(.callout)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(12)
                .background(isToday(workload.date) ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    private func dateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d (E)"
        return formatter.string(from: date)
    }

    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)시간 \(mins)분"
        } else if hours > 0 {
            return "\(hours)시간"
        } else {
            return "\(mins)분"
        }
    }
}
