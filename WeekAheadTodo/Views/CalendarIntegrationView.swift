import WeekAheadShared
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
    @State private var showingCalendarImport = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더 & 상태
            HStack {
                Label("캘린더 패턴 감지", systemImage: "calendar.badge.clock")
                    .font(.headline)
                Spacer()
                statusBadge
            }

            // 버튼들
            actionButtons

            // 진행 상태 메시지
            if let statusMessage = calendarViewModel.statusMessage {
                compactMessage(icon: "gearshape", text: statusMessage, color: .blue, showProgress: true)
            }

            // 성공 메시지
            if let successMessage = calendarViewModel.successMessage {
                compactMessage(icon: "checkmark.circle.fill", text: successMessage, color: .green)
            }

            // 권한 거부 안내
            if calendarViewModel.authorizationStatus == .denied {
                permissionDeniedGuide
            }
            // 기타 에러
            else if let errorMessage = calendarViewModel.errorMessage {
                compactMessage(icon: "exclamationmark.triangle.fill", text: errorMessage, color: .red)
            }

            // 캘린더 선택 (패턴 감지용)
            if calendarViewModel.isEnabled && !calendarViewModel.availableCalendars.isEmpty {
                Divider()
                calendarSelectionSection
            }

            // 캘린더 전체 가져오기
            if calendarViewModel.isEnabled && !calendarViewModel.availableCalendars.isEmpty {
                Divider()
                calendarImportSection
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .sheet(isPresented: $showingPatternReview) {
            PatternReviewView()
        }
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        HStack(spacing: 6) {
            if calendarViewModel.isAnalyzing {
                ProgressView()
                    .scaleEffect(0.6)
            } else if calendarViewModel.hasNewPatterns {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 20, height: 20)
                    Text("\(calendarViewModel.detectedPatterns.count)")
                        .font(.callout)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            } else {
                Image(systemName: statusIconName)
                    .foregroundColor(statusColor)
            }
            Text(calendarViewModel.statusString)
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .cornerRadius(8)
    }

    private var statusIconName: String {
        switch calendarViewModel.authorizationStatus {
        case .authorized, .fullAccess: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .notDetermined: return "questionmark.circle"
        case .restricted: return "lock.circle.fill"
        default: return "circle"
        }
    }

    private var statusColor: Color {
        switch calendarViewModel.authorizationStatus {
        case .authorized, .fullAccess: return .green
        case .denied: return .red
        case .notDetermined: return .gray
        case .restricted: return .orange
        default: return .gray
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 8) {
            if !calendarViewModel.isEnabled {
                Button {
                    _Concurrency.Task {
                        await calendarViewModel.enableIntegration()
                    }
                } label: {
                    Label("연동 활성화", systemImage: "sparkles")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
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

            if calendarViewModel.canReviewPatterns {
                Button {
                    showingPatternReview = true
                } label: {
                    HStack(spacing: 4) {
                        Text("패턴 검토")
                        if calendarViewModel.hasNewPatterns {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
    }

    // MARK: - Compact Message

    private func compactMessage(icon: String, text: String, color: Color, showProgress: Bool = false) -> some View {
        HStack(spacing: 8) {
            if showProgress {
                ProgressView()
                    .scaleEffect(0.6)
            } else {
                Image(systemName: icon)
            }
            Text(text)
                .font(.callout)
        }
        .foregroundColor(color)
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.05))
        .cornerRadius(6)
    }

    // MARK: - Calendar Selection

    private var calendarSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("패턴 감지용 캘린더", systemImage: "list.bullet")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(calendarViewModel.selectedCalendarIds.count)/\(calendarViewModel.availableCalendars.count)")
                    .font(.callout)
                    .foregroundColor(.secondary)
                Button(showingCalendarSelection ? "접기" : "펼치기") {
                    withAnimation {
                        showingCalendarSelection.toggle()
                    }
                }
                .buttonStyle(.plain)
                .font(.callout)
                .foregroundColor(.blue)
            }

            if showingCalendarSelection {
                VStack(spacing: 4) {
                    ForEach(calendarViewModel.availableCalendars, id: \.calendarIdentifier) { calendar in
                        calendarRow(calendar: calendar)
                    }
                }

                HStack(spacing: 8) {
                    Button(calendarViewModel.selectedCalendarIds.count == calendarViewModel.availableCalendars.count ? "전체 해제" : "전체 선택") {
                        if calendarViewModel.selectedCalendarIds.count == calendarViewModel.availableCalendars.count {
                            calendarViewModel.deselectAllCalendars()
                        } else {
                            calendarViewModel.selectAllCalendars()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    if !calendarViewModel.selectedCalendarIds.isEmpty {
                        Button {
                            _Concurrency.Task {
                                await calendarViewModel.analyzeCalendar()
                            }
                        } label: {
                            Label("재분석", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(calendarViewModel.isAnalyzing)
                    }
                }
            }
        }
    }

    private func calendarRow(calendar: EKCalendar) -> some View {
        Button {
            calendarViewModel.toggleCalendarSelection(calendar.calendarIdentifier)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: calendarViewModel.selectedCalendarIds.contains(calendar.calendarIdentifier) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(calendarViewModel.selectedCalendarIds.contains(calendar.calendarIdentifier) ? .blue : .gray)
                    .font(.callout)

                Circle()
                    .fill(Color(calendar.color))
                    .frame(width: 10, height: 10)

                Text(calendar.title)
                    .font(.callout)
                    .lineLimit(1)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(calendarViewModel.selectedCalendarIds.contains(calendar.calendarIdentifier) ? Color.blue.opacity(0.05) : Color.clear)
        )
    }

    // MARK: - Calendar Import Section

    private var calendarImportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("캘린더 전체 가져오기", systemImage: "arrow.down.circle")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(calendarViewModel.importCalendarIds.count)/\(calendarViewModel.availableCalendars.count)")
                    .font(.callout)
                    .foregroundColor(.secondary)
                Button(showingCalendarImport ? "접기" : "펼치기") {
                    withAnimation {
                        showingCalendarImport.toggle()
                    }
                }
                .buttonStyle(.plain)
                .font(.callout)
                .foregroundColor(.blue)
            }

            Text("선택한 캘린더의 모든 일정을 태스크로 가져옵니다 (패턴 감지가 아닌 전체 가져오기)")
                .font(.caption)
                .foregroundColor(.secondary)

            if showingCalendarImport {
                VStack(spacing: 4) {
                    ForEach(calendarViewModel.availableCalendars, id: \.calendarIdentifier) { calendar in
                        calendarImportRow(calendar: calendar)
                    }
                }

                // 기간 설정
                HStack {
                    Text("가져올 기간:")
                        .font(.callout)
                    Picker("", selection: $calendarViewModel.importWeeksAhead) {
                        Text("1주").tag(1)
                        Text("2주").tag(2)
                        Text("4주").tag(4)
                        Text("8주").tag(8)
                        Text("12주").tag(12)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 250)
                }
                .padding(.vertical, 4)

                HStack(spacing: 8) {
                    if !calendarViewModel.importCalendarIds.isEmpty {
                        Button {
                            _Concurrency.Task {
                                await calendarViewModel.importAllEventsFromCalendars(to: taskViewModel)
                            }
                        } label: {
                            Label("가져오기", systemImage: "arrow.down.circle.fill")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(calendarViewModel.isImporting)
                    }

                    Button(calendarViewModel.importCalendarIds.count == calendarViewModel.availableCalendars.count ? "전체 해제" : "전체 선택") {
                        if calendarViewModel.importCalendarIds.count == calendarViewModel.availableCalendars.count {
                            calendarViewModel.importCalendarIds = []
                        } else {
                            calendarViewModel.importCalendarIds = Set(calendarViewModel.availableCalendars.map { $0.calendarIdentifier })
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private func calendarImportRow(calendar: EKCalendar) -> some View {
        Button {
            calendarViewModel.toggleCalendarImport(calendar.calendarIdentifier)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: calendarViewModel.importCalendarIds.contains(calendar.calendarIdentifier) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(calendarViewModel.importCalendarIds.contains(calendar.calendarIdentifier) ? .green : .gray)
                    .font(.callout)

                Circle()
                    .fill(Color(calendar.color))
                    .frame(width: 10, height: 10)

                Text(calendar.title)
                    .font(.callout)
                    .lineLimit(1)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(calendarViewModel.importCalendarIds.contains(calendar.calendarIdentifier) ? Color.green.opacity(0.05) : Color.clear)
        )
    }

    // MARK: - Permission Denied Guide

    private var permissionDeniedGuide: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(.orange)
                Text("캘린더 권한 필요")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Text("시스템 설정 → Privacy & Security → Calendars → WeekAheadTodo 권한 활성화")
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
            } label: {
                Label("시스템 설정 열기", systemImage: "gear")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.05))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}
