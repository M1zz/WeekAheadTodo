import SwiftUI

/// 감지된 패턴 검토 뷰
struct PatternReviewView: View {
    @EnvironmentObject var calendarViewModel: CalendarViewModel
    @EnvironmentObject var taskViewModel: TaskViewModel
    @Environment(\.dismiss) var dismiss

    @State private var selectedPattern: RecurrencePattern?
    @State private var showingDetailView = false
    @State private var selectedCalendarFilter: String? = nil
    @State private var groupByCalendar: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 헤더
                headerView

                Divider()

                // 필터 및 그룹화 컨트롤
                filterControls

                Divider()

                // 패턴 목록
                if calendarViewModel.detectedPatterns.isEmpty {
                    emptyStateView
                } else if filteredPatterns.isEmpty {
                    emptyFilterResultView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if groupByCalendar {
                                // 캘린더별로 그룹화
                                ForEach(groupedPatterns.keys.sorted(), id: \.self) { calendar in
                                    calendarGroupSection(calendar: calendar, patterns: groupedPatterns[calendar] ?? [])
                                }
                            } else {
                                // 일반 목록
                                ForEach(filteredPatterns) { pattern in
                                    patternRow(pattern: pattern)
                                }
                            }
                        }
                        .padding(24)
                    }
                }

                Divider()

                // 하단 버튼들
                bottomBar
            }
            .navigationTitle("감지된 패턴")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedPattern) { pattern in
                PatternDetailView(pattern: pattern)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }

    // MARK: - Computed Properties

    /// 필터링된 패턴 목록
    private var filteredPatterns: [RecurrencePattern] {
        if let filter = selectedCalendarFilter {
            return calendarViewModel.detectedPatterns.filter { pattern in
                pattern.calendarTitles.contains(filter)
            }
        }
        return calendarViewModel.detectedPatterns
    }

    /// 캘린더별로 그룹화된 패턴
    private var groupedPatterns: [String: [RecurrencePattern]] {
        Dictionary(grouping: filteredPatterns) { $0.primaryCalendar }
    }

    /// 사용 가능한 캘린더 목록 (패턴에서 추출)
    private var availableCalendars: [String] {
        let allCalendars = calendarViewModel.detectedPatterns.flatMap { $0.calendarTitles }
        return Array(Set(allCalendars)).sorted()
    }

    // MARK: - Filter Controls

    private var filterControls: some View {
        VStack(spacing: 12) {
            HStack {
                // 캘린더 필터
                Menu {
                    Button(action: {
                        selectedCalendarFilter = nil
                    }) {
                        HStack {
                            Text("전체 캘린더")
                            if selectedCalendarFilter == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    Divider()

                    ForEach(availableCalendars, id: \.self) { calendar in
                        Button(action: {
                            selectedCalendarFilter = calendar
                        }) {
                            HStack {
                                Text(calendar)
                                if selectedCalendarFilter == calendar {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(selectedCalendarFilter ?? "전체 캘린더")
                    }
                }
                .buttonStyle(.bordered)

                Spacer()

                // 그룹화 토글
                Button(action: {
                    groupByCalendar.toggle()
                }) {
                    HStack {
                        Image(systemName: groupByCalendar ? "square.grid.2x2.fill" : "square.grid.2x2")
                        Text(groupByCalendar ? "그룹 해제" : "캘린더별 그룹")
                    }
                }
                .buttonStyle(.bordered)
            }

            // 필터 상태 표시
            if selectedCalendarFilter != nil || groupByCalendar {
                HStack(spacing: 8) {
                    if let filter = selectedCalendarFilter {
                        Label(filter, systemImage: "calendar")
                            .font(.callout)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                            .overlay(
                                Button(action: { selectedCalendarFilter = nil }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.callout)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.blue)
                                .offset(x: 8, y: -8),
                                alignment: .topTrailing
                            )
                    }

                    if groupByCalendar {
                        Label("캘린더별 그룹", systemImage: "square.grid.2x2")
                            .font(.callout)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(6)
                    }

                    Spacer()
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Calendar Group Section

    private func calendarGroupSection(calendar: String, patterns: [RecurrencePattern]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 그룹 헤더
            HStack {
                Label(calendar, systemImage: "calendar")
                    .font(.headline)
                    .foregroundColor(.blue)

                Spacer()

                Text("\(patterns.count)개 패턴")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.05))
            .cornerRadius(8)

            // 패턴 목록
            ForEach(patterns) { pattern in
                patternRow(pattern: pattern)
            }
        }
    }

    private func patternRow(pattern: RecurrencePattern) -> some View {
        PatternRowView(pattern: pattern, isSelected: calendarViewModel.selectedPatterns.contains(pattern.id))
            .onTapGesture {
                calendarViewModel.togglePatternSelection(pattern.id)
            }
            .contextMenu {
                Button {
                    selectedPattern = pattern
                    showingDetailView = true
                } label: {
                    Label("상세 보기", systemImage: "info.circle")
                }

                Button {
                    selectedPattern = pattern
                    showingDetailView = true
                } label: {
                    Label("수정", systemImage: "pencil")
                }

                Button {
                    calendarViewModel.selectPattern(pattern.id)
                } label: {
                    Label("승인", systemImage: "checkmark")
                }

                Button(role: .destructive) {
                    calendarViewModel.ignorePattern(pattern.id)
                } label: {
                    Label("무시", systemImage: "xmark")
                }
            }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(calendarViewModel.detectedPatterns.count)개 패턴 감지됨")
                    .font(.headline)
                Text("검토 후 승인하면 할 일이 자동으로 생성됩니다")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            Spacer()

            // 전체 선택/해제
            Button(calendarViewModel.selectedPatterns.isEmpty ? "전체 선택" : "전체 해제") {
                if calendarViewModel.selectedPatterns.isEmpty {
                    calendarViewModel.selectAllPatterns()
                } else {
                    calendarViewModel.deselectAllPatterns()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 64))
                .foregroundColor(.green)
            Text("검토할 패턴이 없습니다")
                .font(.headline)
            Text("패턴이 감지되면 여기에 표시됩니다")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyFilterResultView: some View {
        VStack(spacing: 16) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            Text("필터 조건에 맞는 패턴이 없습니다")
                .font(.headline)
            if let filter = selectedCalendarFilter {
                Text("'\(filter)' 캘린더의 패턴이 감지되지 않았습니다")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Button("필터 초기화") {
                selectedCalendarFilter = nil
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            Button("모두 무시") {
                calendarViewModel.ignoreAllPatterns()
                dismiss()
            }
            .buttonStyle(.bordered)
            .tint(.red)

            Spacer()

            HStack(spacing: 12) {
                if !calendarViewModel.selectedPatterns.isEmpty {
                    Text("\(calendarViewModel.selectedPatterns.count)개 선택됨")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Button {
                    approveSelectedPatterns()
                } label: {
                    Label("선택 항목 승인", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(calendarViewModel.selectedPatterns.isEmpty)
            }
        }
        .padding(24)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Actions

    private func approveSelectedPatterns() {
        let patternsToApprove = calendarViewModel.selectedPatternsList

        // Task 생성
        taskViewModel.createTasksFromPatterns(patternsToApprove)

        // 패턴 제거
        calendarViewModel.approvePatterns(calendarViewModel.selectedPatterns)

        // 완료 메시지

        // 모든 패턴이 처리되었으면 닫기
        if calendarViewModel.detectedPatterns.isEmpty {
            dismiss()
        }
    }
}

// MARK: - Pattern Row View

struct PatternRowView: View {
    let pattern: RecurrencePattern
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // 선택 체크박스
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundColor(isSelected ? .blue : .gray)

            VStack(alignment: .leading, spacing: 8) {
                // 패턴 정보
                HStack {
                    Image(systemName: pattern.type.icon)
                        .foregroundColor(.blue)
                    Text(pattern.type.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    // 캘린더 정보
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.callout)
                        Text(pattern.primaryCalendar)
                            .font(.callout)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(6)
                }

                // 빈도 및 시간
                Text(pattern.frequency)
                    .font(.headline)
                Text(pattern.timeRange)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // 여러 캘린더에 걸쳐 있는 경우 표시
                if pattern.calendarTitles.count > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.callout)
                            .foregroundColor(.secondary)
                        Text("\(pattern.calendarTitles.count)개 캘린더")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                }

                // 신뢰도
                HStack {
                    Text("신뢰도")
                        .font(.callout)
                        .foregroundColor(.secondary)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(confidenceColor)
                                .frame(width: geometry.size.width * pattern.confidenceScore, height: 8)
                        }
                    }
                    .frame(height: 8)

                    Text("\(pattern.confidencePercent)%")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(confidenceColor)
                        .frame(width: 35, alignment: .trailing)
                }

                // 최근 5개 날짜 표시
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.callout)
                        .foregroundColor(.blue)
                    Text("최근 5회:")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Text(pattern.recentEventDatesFormatted)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 2)

                // 감지 근거
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(pattern.detectedCharacteristics, id: \.self) { characteristic in
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.callout)
                                .foregroundColor(.green)
                            Text(characteristic)
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Divider()

                // Task 제안
                VStack(alignment: .leading, spacing: 4) {
                    Text("제안된 할 일:")
                        .font(.callout)
                        .foregroundColor(.secondary)

                    HStack {
                        Text(pattern.suggestedTask.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }

                    HStack(spacing: 12) {
                        Label(pattern.suggestedTask.estimatedTimeFormatted, systemImage: "clock")
                        Label("\(pattern.suggestedTask.leadTimeDays)일 전 시작", systemImage: "arrow.counterclockwise")
                        Label(pattern.suggestedTask.taskType.rawValue, systemImage: pattern.suggestedTask.taskType.icon)
                    }
                    .font(.callout)
                    .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(isSelected ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }

    private var confidenceColor: Color {
        if pattern.confidenceScore >= 0.8 {
            return .green
        } else if pattern.confidenceScore >= 0.6 {
            return .blue
        } else if pattern.confidenceScore >= 0.4 {
            return .orange
        } else {
            return .red
        }
    }
}
