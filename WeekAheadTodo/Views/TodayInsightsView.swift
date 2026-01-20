import SwiftUI

// MARK: - Today Insights View

struct TodayInsightsView: View {
    @EnvironmentObject var viewModel: TaskViewModel

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d"
        return formatter.string(from: Date())
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("오늘 통계 \(todayDateString)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("오늘의 시간 블록과 미래 준비 현황을 확인하세요")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    timeBlockStatusView

                    futurePreparationGaugeView

                    if !viewModel.todayTasks.isEmpty {
                        futurePreparationSummary
                    }

                    let futurePreps = viewModel.futureTasksPreparedToday()
                    if !futurePreps.isEmpty {
                        futureFeedbackSection(futurePreps: futurePreps)
                    }
                }
                .padding(24)
            }
        }
    }

    private var timeBlockStatusView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("오늘의 시간 블록")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.formatMinutes(viewModel.todayUsedMinutes)) / \(viewModel.formatMinutes(viewModel.todayAvailableMinutes))")
                    .font(.subheadline)
                    .foregroundColor(viewModel.isTodayOverCapacity ? .red : .secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 8)
                        .fill(progressColor)
                        .frame(width: min(geometry.size.width * viewModel.todayUtilization, geometry.size.width))
                }
            }
            .frame(height: 12)

            HStack {
                if viewModel.isTodayOverCapacity {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("\(viewModel.formatMinutes(-viewModel.todayRemainingMinutes)) 초과")
                        .foregroundColor(.red)
                } else if viewModel.todayRemainingMinutes > 0 {
                    Image(systemName: "clock")
                        .foregroundColor(.green)
                    Text("\(viewModel.formatMinutes(viewModel.todayRemainingMinutes)) 여유")
                        .foregroundColor(.green)
                }
                Spacer()
            }
            .font(.callout)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private var progressColor: Color {
        if viewModel.todayUtilization > 1.0 {
            return .red
        } else if viewModel.todayUtilization > 0.8 {
            return .orange
        } else {
            return .blue
        }
    }

    private var futurePreparationGaugeView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("미래 준비 목표")
                        .font(.headline)
                    Text("얼마나 미리 준비하고 있나요?")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("현재")
                            .font(.callout)
                            .foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            Text("\(currentDaysAhead)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(gaugeColor)
                            Text("일 뒤")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("목표")
                            .font(.callout)
                            .foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            Text("\(viewModel.targetDaysAhead)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            Text("일 뒤")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.15))

                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: geometry.size.width)

                        RoundedRectangle(cornerRadius: 12)
                            .fill(gaugeColor)
                            .frame(width: min(
                                geometry.size.width * CGFloat(currentDaysAhead) / CGFloat(viewModel.targetDaysAhead),
                                geometry.size.width
                            ))
                    }
                }
                .frame(height: 24)

                HStack(spacing: 8) {
                    if currentDaysAhead >= viewModel.targetDaysAhead {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("목표 달성! 🎉")
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    } else {
                        let percentage = min(Int(Double(currentDaysAhead) / Double(viewModel.targetDaysAhead) * 100), 100)
                        Text("\(percentage)%")
                            .fontWeight(.semibold)
                            .foregroundColor(gaugeColor)
                        Text(gaugeMessage)
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private var currentDaysAhead: Int {
        guard !viewModel.todayTasks.isEmpty else { return 0 }

        var maxDays = 0
        for task in viewModel.todayTasks {
            if task.isPreparation {
                if let daysUntilTarget = task.daysUntilTarget, daysUntilTarget > maxDays {
                    maxDays = daysUntilTarget
                }
            } else if !task.isPreparation {
                if task.daysUntilDue > maxDays {
                    maxDays = task.daysUntilDue
                }
            }
        }
        return maxDays
    }

    private var gaugeColor: Color {
        let ratio = Double(currentDaysAhead) / Double(viewModel.targetDaysAhead)
        if ratio >= 1.0 {
            return .green
        } else if ratio >= 0.7 {
            return .blue
        } else if ratio >= 0.4 {
            return .orange
        } else {
            return .red
        }
    }

    private var gaugeMessage: String {
        let ratio = Double(currentDaysAhead) / Double(viewModel.targetDaysAhead)
        if ratio >= 0.7 {
            return "좋은 페이스예요! 👍"
        } else if ratio >= 0.4 {
            return "\(viewModel.targetDaysAhead)일 뒤를 살기 위해 노력해보세요! 🎯"
        } else {
            return "\(viewModel.targetDaysAhead)일 뒤를 살기 위해 노력해보세요! 🎯"
        }
    }

    private var futurePreparationSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.blue)
                    .font(.title3)
                Text("미래 준비 현황")
                    .font(.headline)
            }

            let todayDueTasks = viewModel.todayTasks.filter { !$0.isPreparation && $0.daysUntilDue == 0 }
            if !todayDueTasks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.circle.fill")
                            .foregroundColor(.red)
                        Text("오늘 마감")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                        Text("(\(todayDueTasks.count)개)")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    ForEach(todayDueTasks.prefix(3)) { task in
                        Text("⚡ \(task.title)")
                            .font(.callout)
                            .foregroundColor(.red)
                    }
                }
                .padding(12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }

            let preparationTasks = viewModel.todayTasks.filter { $0.isPreparation }
            if !preparationTasks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(.orange)
                        Text("미래 준비 중")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("(\(preparationTasks.count)개)")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }

                    ForEach(preparationTasks.prefix(5)) { task in
                        if let daysText = task.daysUntilTargetText {
                            HStack(spacing: 4) {
                                Text("•")
                                Text("\(daysText)")
                                    .fontWeight(.semibold)
                                Text("준비:")
                                Text(task.title)
                            }
                            .font(.callout)
                            .foregroundColor(.orange)
                        }
                    }
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func futureFeedbackSection(futurePreps: [(preparationTask: Task, mainTask: Task)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                Text("오늘 준비 완료!")
                    .font(.headline)
            }

            Text("오늘 완료한 준비로 미래가 준비되었어요 ✨")
                .font(.callout)
                .foregroundColor(.secondary)

            ForEach(futurePreps, id: \.preparationTask.id) { item in
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.green)
                        .font(.callout)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.preparationTask.title)
                            .font(.subheadline)
                            .strikethrough()

                        if let daysText = item.preparationTask.daysUntilTargetText {
                            HStack(spacing: 4) {
                                Text("\(daysText)")
                                    .fontWeight(.semibold)
                                Text("'\(item.mainTask.title)' 준비됨")
                            }
                            .font(.callout)
                            .foregroundColor(.green)
                        }
                    }
                }
                .padding(8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding(16)
        .background(Color.green.opacity(0.05))
        .cornerRadius(12)
    }
}
