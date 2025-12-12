import SwiftUI
import AppKit
import EventKit

/// 설정 탭 내 캘린더 연동 섹션
struct CalendarIntegrationView: View {
    @EnvironmentObject var calendarViewModel: CalendarViewModel
    @EnvironmentObject var taskViewModel: TaskViewModel
    @State private var showingPatternReview = false
    @State private var showingPermissionGuide = false
    @State private var showingCalendarSelection = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 헤더
            HStack {
                Label("캘린더 패턴 감지", systemImage: "calendar.badge.clock")
                    .font(.headline)
                Spacer()
            }

            // 상태 표시
            statusView

            Divider()

            // 연동 안내 (비활성화 상태일 때)
            if shouldShowOnboardingGuide {
                onboardingGuide
            }

            // 버튼들
            actionButtons

            // 상태 메시지 (진행 중)
            if let statusMessage = calendarViewModel.statusMessage {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(statusMessage)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .padding(12)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
            }

            // 성공 메시지
            if let successMessage = calendarViewModel.successMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(successMessage)
                        .font(.subheadline)
                }
                .padding(12)
                .background(Color.green.opacity(0.05))
                .cornerRadius(8)
            }

            // 캘린더 선택 (연동 활성화 후)
            if calendarViewModel.isEnabled && !calendarViewModel.availableCalendars.isEmpty {
                Divider()
                calendarSelectionSection
            }

            // 권한 거부 시 안내 (우선 표시)
            if calendarViewModel.authorizationStatus == .denied ||
               (calendarViewModel.errorMessage?.contains("거부") == true) {
                permissionDeniedGuide
            }

            // 기타 에러 메시지
            else if let errorMessage = calendarViewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                .padding(12)
                .background(Color.red.opacity(0.05))
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .sheet(isPresented: $showingPatternReview) {
            PatternReviewView()
        }
    }

    // MARK: - Computed Properties

    private var shouldShowOnboardingGuide: Bool {
        !calendarViewModel.isEnabled &&
        calendarViewModel.authorizationStatus != .denied &&
        !calendarViewModel.isAnalyzing
    }

    // MARK: - Status View

    @ViewBuilder
    private var statusView: some View {
        HStack {
            statusIcon
            VStack(alignment: .leading, spacing: 4) {
                Text(calendarViewModel.statusString)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(statusDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private var statusIcon: some View {
        Group {
            if calendarViewModel.isAnalyzing {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 24, height: 24)
            } else if calendarViewModel.hasNewPatterns {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 24, height: 24)
                    Text("\(calendarViewModel.detectedPatterns.count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            } else {
                Image(systemName: statusIconName)
                    .font(.title2)
                    .foregroundColor(statusColor)
            }
        }
    }

    private var statusIconName: String {
        switch calendarViewModel.authorizationStatus {
        case .authorized, .fullAccess:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle"
        case .restricted:
            return "lock.circle.fill"
        default:
            return "circle"
        }
    }

    private var statusColor: Color {
        switch calendarViewModel.authorizationStatus {
        case .authorized, .fullAccess:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .gray
        case .restricted:
            return .orange
        default:
            return .gray
        }
    }

    private var statusDescription: String {
        if calendarViewModel.isAnalyzing {
            return "지난 3개월 일정을 분석하고 있습니다..."
        } else if calendarViewModel.hasNewPatterns {
            return "검토할 패턴이 있습니다"
        } else if calendarViewModel.authorizationStatus == .denied {
            return "시스템 설정에서 캘린더 권한을 허용해주세요"
        } else if calendarViewModel.authorizationStatus == .notDetermined {
            return "아래 버튼을 눌러 캘린더 패턴 감지를 시작하세요"
        } else if !calendarViewModel.isEnabled {
            return "연동 활성화 버튼을 눌러 패턴 분석을 시작하세요"
        } else {
            return "반복 패턴이 감지되지 않았습니다"
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // 연동 활성화/재분석 버튼
            if !calendarViewModel.isEnabled {
                Button {
                    _Concurrency.Task {
                        await calendarViewModel.enableIntegration()
                    }
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("연동 활성화")
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right.circle.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(calendarViewModel.isAnalyzing)
            } else {
                Button {
                    _Concurrency.Task {
                        await calendarViewModel.reanalyze()
                    }
                } label: {
                    Label("재분석", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(calendarViewModel.isAnalyzing)
            }

            // 패턴 검토 버튼
            if calendarViewModel.canReviewPatterns {
                Button(action: {
                    showingPatternReview = true
                }) {
                    HStack {
                        Label("패턴 검토하기", systemImage: "list.bullet.rectangle")
                        if calendarViewModel.hasNewPatterns {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }

            Spacer()
        }
    }

    // MARK: - Calendar Selection Section

    private var calendarSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("분석할 캘린더 선택", systemImage: "checklist")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Button(showingCalendarSelection ? "접기" : "펼치기") {
                    withAnimation {
                        showingCalendarSelection.toggle()
                    }
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.blue)
            }

            if showingCalendarSelection {
                VStack(alignment: .leading, spacing: 8) {
                    // 전체 선택/해제 버튼
                    HStack {
                        Button(action: {
                            if calendarViewModel.selectedCalendarIds.count == calendarViewModel.availableCalendars.count {
                                calendarViewModel.deselectAllCalendars()
                            } else {
                                calendarViewModel.selectAllCalendars()
                            }
                        }) {
                            Text(calendarViewModel.selectedCalendarIds.count == calendarViewModel.availableCalendars.count ? "전체 해제" : "전체 선택")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Text("\(calendarViewModel.selectedCalendarIds.count) / \(calendarViewModel.availableCalendars.count) 선택됨")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // 캘린더 목록
                    VStack(spacing: 6) {
                        ForEach(calendarViewModel.availableCalendars, id: \.calendarIdentifier) { calendar in
                            calendarRow(calendar: calendar)
                        }
                    }

                    // 재분석 버튼
                    if !calendarViewModel.selectedCalendarIds.isEmpty {
                        Button {
                            _Concurrency.Task {
                                await calendarViewModel.analyzeCalendar()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("선택된 캘린더로 재분석")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(calendarViewModel.isAnalyzing)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private func calendarRow(calendar: EKCalendar) -> some View {
        Button(action: {
            calendarViewModel.toggleCalendarSelection(calendar.calendarIdentifier)
        }) {
            HStack {
                Image(systemName: calendarViewModel.selectedCalendarIds.contains(calendar.calendarIdentifier) ? "checkmark.square.fill" : "square")
                    .foregroundColor(calendarViewModel.selectedCalendarIds.contains(calendar.calendarIdentifier) ? .blue : .gray)

                Circle()
                    .fill(Color(calendar.color))
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(calendar.title)
                        .font(.subheadline)
                    Text(calendar.source.title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(calendarViewModel.selectedCalendarIds.contains(calendar.calendarIdentifier) ? Color.blue.opacity(0.05) : Color.clear)
        )
    }

    // MARK: - Onboarding Guide

    private var onboardingGuide: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("캘린더 패턴 감지란?")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("캘린더의 반복 일정을 자동으로 분석하여 할 일을 제안합니다.")
                    .font(.subheadline)

                VStack(alignment: .leading, spacing: 6) {
                    featureItem(icon: "calendar.badge.clock", text: "지난 3개월 일정 분석")
                    featureItem(icon: "arrow.triangle.2.circlepath", text: "매주 회의, 격주 미팅 등 패턴 자동 감지")
                    featureItem(icon: "checkmark.circle", text: "할 일 자동 생성 (승인 후)")
                    featureItem(icon: "lock.shield", text: "읽기 전용 (일정을 수정하지 않음)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.blue)
                Text("아래 '연동 활성화' 버튼을 눌러 시작하세요")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }

    private func featureItem(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
        }
    }

    // MARK: - Permission Denied Guide

    private var permissionDeniedGuide: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "hand.raised.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                Text("캘린더 권한이 거부되었습니다")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("캘린더 패턴 감지를 사용하려면 권한이 필요합니다.")
                    .font(.subheadline)

                Text("다음 단계를 따라 권한을 허용해주세요:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 4) {
                    permissionStep(number: "1", text: "아래 버튼을 눌러 시스템 설정을 엽니다")
                    permissionStep(number: "2", text: "Privacy & Security → Calendars 선택")
                    permissionStep(number: "3", text: "WeekAheadTodo 앱의 권한을 켭니다")
                    permissionStep(number: "4", text: "이 앱으로 돌아와 '연동 활성화'를 다시 시도하세요")
                }
                .padding(.leading, 8)
            }
            .font(.caption)
            .foregroundColor(.secondary)

            HStack {
                Button {
                    openSystemSettings()
                } label: {
                    Label("시스템 설정 열기", systemImage: "gear")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                Button {
                    showingPermissionGuide = true
                } label: {
                    Label("자세한 안내", systemImage: "questionmark.circle")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .sheet(isPresented: $showingPermissionGuide) {
            PermissionGuideView()
        }
    }

    private func permissionStep(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.orange)
                .clipShape(Circle())
            Text(text)
                .font(.caption)
        }
    }

    // MARK: - Actions

    private func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        } else {
            // Fallback: 일반 설정 앱 열기
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        }
    }
}

// MARK: - Permission Guide View

struct PermissionGuideView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 소개
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.largeTitle)
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("캘린더 권한 안내")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("반복 패턴 감지를 위해 필요합니다")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Divider()

                    // 왜 필요한가
                    VStack(alignment: .leading, spacing: 12) {
                        Text("왜 캘린더 권한이 필요한가요?")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            featureItem(icon: "calendar.badge.clock", title: "지난 일정 분석", description: "지난 3개월 간의 일정을 읽어 반복 패턴을 찾습니다")
                            featureItem(icon: "arrow.triangle.2.circlepath", title: "자동 패턴 감지", description: "매주 회의, 격주 미팅 등 규칙적인 일정을 자동으로 찾아냅니다")
                            featureItem(icon: "checkmark.circle", title: "할 일 자동 생성", description: "감지된 패턴을 기반으로 준비 시간을 포함한 할 일을 생성합니다")
                        }
                    }

                    Divider()

                    // 단계별 안내
                    VStack(alignment: .leading, spacing: 12) {
                        Text("권한 허용 방법")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 16) {
                            guideStep(number: "1", title: "시스템 설정 열기", description: "아래 버튼을 눌러 시스템 설정 앱을 엽니다")

                            guideStep(number: "2", title: "Privacy & Security 선택", description: "왼쪽 사이드바에서 'Privacy & Security'를 찾아 클릭합니다")

                            guideStep(number: "3", title: "Calendars 항목 찾기", description: "오른쪽에서 스크롤하여 'Calendars' 항목을 찾아 클릭합니다")

                            guideStep(number: "4", title: "WeekAheadTodo 권한 켜기", description: "앱 목록에서 'WeekAheadTodo'를 찾아 체크박스를 활성화합니다")

                            guideStep(number: "5", title: "앱으로 돌아오기", description: "이 앱으로 돌아와 '연동 활성화'를 다시 시도하세요")
                        }
                    }

                    Divider()

                    // 안전성
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.green)
                            Text("개인정보 보호")
                                .font(.headline)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            privacyItem(text: "읽기 전용: 일정을 읽기만 하며, 수정하거나 삭제하지 않습니다")
                            privacyItem(text: "로컬 처리: 모든 분석은 기기 내에서만 이루어지며, 외부로 전송되지 않습니다")
                            privacyItem(text: "투명성: 감지된 모든 패턴을 확인 후 승인할 수 있습니다")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

                    // 시스템 설정 열기 버튼
                    Button {
                        openSystemSettings()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Label("시스템 설정 열기", systemImage: "gear")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(24)
            }
            .navigationTitle("캘린더 권한")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 700)
    }

    private func featureItem(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func guideStep(number: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.blue)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func privacyItem(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            Text(text)
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        }
    }
}
