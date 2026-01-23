import SwiftUI

/// 체크인 팝오버/시트 뷰
struct CheckinView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    let task: Task
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 16) {
            // 헤더
            HStack {
                Image(systemName: "clock.badge.questionmark")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("진행 상황 확인")
                    .font(.headline)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // 태스크 정보
            VStack(alignment: .leading, spacing: 8) {
                Text(task.title)
                    .font(.title3)
                    .fontWeight(.semibold)

                HStack(spacing: 12) {
                    Label(task.estimatedTimeFormatted, systemImage: "clock")
                    Label(task.dueDateWithWeekday, systemImage: "calendar")
                    if task.daysUntilDue <= 2 {
                        Text(task.dDayText)
                            .foregroundColor(.red)
                            .fontWeight(.bold)
                    }
                }
                .font(.callout)
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // 응답 버튼들
            VStack(spacing: 10) {
                CheckinResponseButton(
                    response: .onTrack,
                    action: { submitCheckin(.onTrack) }
                )

                CheckinResponseButton(
                    response: .completed,
                    action: { submitCheckin(.completed) }
                )

                CheckinResponseButton(
                    response: .needHelp,
                    action: { submitCheckin(.needHelp) }
                )

                CheckinResponseButton(
                    response: .postponed,
                    action: { submitCheckin(.postponed) }
                )
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    private func submitCheckin(_ response: CheckinResponse) {
        viewModel.handleCheckinResponse(taskId: task.id, response: response)
        isPresented = false
    }
}

/// 체크인 응답 버튼
struct CheckinResponseButton: View {
    let response: CheckinResponse
    let action: () -> Void

    private var responseColor: Color {
        switch response {
        case .onTrack: return .green
        case .completed: return .blue
        case .needHelp: return .red
        case .postponed: return .orange
        }
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: response.icon)
                    .font(.body)
                Text(response.rawValue)
                    .font(.callout)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(responseColor.opacity(0.1))
            .foregroundColor(responseColor)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

/// 미체크인 경고 배너
struct MissedCheckinBanner: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @Binding var showingCheckinSheet: Bool
    @Binding var selectedCheckinTask: Task?

    var body: some View {
        if !viewModel.tasksWithMissedCheckins.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("확인이 필요한 태스크")
                        .font(.headline)
                    Spacer()
                }

                Text("\(viewModel.tasksWithMissedCheckins.count)개의 진행 중인 태스크가 체크인되지 않았습니다")
                    .font(.callout)
                    .foregroundColor(.secondary)

                ForEach(viewModel.tasksWithMissedCheckins.prefix(3)) { task in
                    Button(action: {
                        selectedCheckinTask = task
                        showingCheckinSheet = true
                    }) {
                        HStack {
                            Text(task.title)
                                .lineLimit(1)
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(task.consecutiveMissedCheckins)일 미확인")
                                .font(.callout)
                                .foregroundColor(.orange)
                        }
                        .padding(10)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(Color.orange.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

/// 체크인 필요 태스크 목록 뷰
struct CheckinNeededListView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @Binding var showingCheckinSheet: Bool
    @Binding var selectedCheckinTask: Task?

    var body: some View {
        if !viewModel.tasksNeedingCheckin.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "clock.badge.questionmark")
                        .foregroundColor(.blue)
                    Text("체크인 필요")
                        .font(.headline)
                    Spacer()
                    Text("\(viewModel.tasksNeedingCheckin.count)개")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }

                ForEach(viewModel.tasksNeedingCheckin) { task in
                    Button(action: {
                        selectedCheckinTask = task
                        showingCheckinSheet = true
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                    .lineLimit(1)
                                    .foregroundColor(.primary)
                                Text(task.dDayWithDate)
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(Color(.windowBackgroundColor).opacity(0.5))
            .cornerRadius(12)
        }
    }
}
