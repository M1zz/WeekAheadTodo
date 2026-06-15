import WeekAheadShared
import SwiftUI
import SwiftData

struct ApprovedPatternManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ApprovedPattern.approvedAt, order: .reverse) private var allPatterns: [ApprovedPattern]

    @State private var selectedPattern: ApprovedPattern?
    @State private var showingEditSheet = false
    @State private var showingAddSheet = false
    @State private var showingDeleteAlert = false
    @State private var patternToDelete: ApprovedPattern?
    @State private var filterCalendar: String?
    @State private var showActiveOnly = false
    @State private var flexiblePatternToSchedule: ApprovedPattern?
    @State private var flexibleNextDate: Date = Date()

    private var patternService: PatternManagementService {
        PatternManagementService(modelContext: modelContext)
    }

    // Filtered patterns
    private var filteredPatterns: [ApprovedPattern] {
        allPatterns.filter { pattern in
            let matchesActive = !showActiveOnly || pattern.isActive
            let matchesCalendar = filterCalendar == nil || pattern.primaryCalendar == filterCalendar
            return matchesActive && matchesCalendar
        }
    }

    // Unique calendars
    private var availableCalendars: [String] {
        Array(Set(allPatterns.map { $0.primaryCalendar })).sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Filters
            filterControls

            Divider()

            // Pattern list or empty state
            if allPatterns.isEmpty {
                emptyStateView
            } else if filteredPatterns.isEmpty {
                emptyFilterResultView
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredPatterns) { pattern in
                            ApprovedPatternRow(
                                pattern: pattern,
                                onToggleActive: {
                                    toggleActive(pattern)
                                },
                                onEdit: {
                                    selectedPattern = pattern
                                    showingEditSheet = true
                                },
                                onDelete: {
                                    patternToDelete = pattern
                                    showingDeleteAlert = true
                                },
                                onSetNextDate: {
                                    flexibleNextDate = Date()
                                    flexiblePatternToSchedule = pattern
                                }
                            )
                        }
                    }
                    .padding(24)
                }
            }
        }
        .sheet(item: $selectedPattern) { pattern in
            EditApprovedPatternView(pattern: pattern)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddApprovedPatternView()
        }
        .sheet(item: $flexiblePatternToSchedule) { pattern in
            FlexiblePatternScheduleView(
                pattern: pattern,
                selectedDate: $flexibleNextDate,
                onConfirm: { date in
                    setNextOccurrence(pattern: pattern, date: date)
                    flexiblePatternToSchedule = nil
                }
            )
        }
        .alert("패턴 삭제", isPresented: $showingDeleteAlert, presenting: patternToDelete) { pattern in
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) {
                deletePattern(pattern)
            }
        } message: { pattern in
            Text("'\(pattern.taskTitle)' 패턴을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.\n\n이미 생성된 할 일은 유지됩니다.")
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("패턴 관리")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("\(allPatterns.count)개 승인됨 • \(allPatterns.filter { $0.isActive }.count)개 활성")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: { showingAddSheet = true }) {
                Label("패턴 추가", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Filter Controls

    private var filterControls: some View {
        HStack(spacing: 12) {
            // Active only toggle
            Toggle("활성만 보기", isOn: $showActiveOnly)
                .toggleStyle(.switch)

            Spacer()

            // Calendar filter
            if !availableCalendars.isEmpty {
                Menu {
                    Button("전체 캘린더") {
                        filterCalendar = nil
                    }
                    Divider()
                    ForEach(availableCalendars, id: \.self) { calendar in
                        Button(calendar) {
                            filterCalendar = calendar
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(filterCalendar ?? "전체 캘린더")
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Empty States

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            Text("승인된 패턴이 없습니다")
                .font(.headline)
            Text("설정에서 캘린더를 분석하고 패턴을 승인하세요")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private var emptyFilterResultView: some View {
        VStack(spacing: 16) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            Text("필터 조건에 맞는 패턴이 없습니다")
                .font(.headline)
            Button("필터 초기화") {
                filterCalendar = nil
                showActiveOnly = false
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    // MARK: - Actions

    private func toggleActive(_ pattern: ApprovedPattern) {
        do {
            try patternService.togglePatternActive(pattern)
            // 활성화 시 즉시 태스크 생성되도록 알림
            NotificationCenter.default.post(name: .approvedPatternsDidChange, object: nil)
        } catch {
        }
    }

    private func deletePattern(_ pattern: ApprovedPattern) {
        do {
            try patternService.deletePattern(pattern)
        } catch {
        }
    }

    private func setNextOccurrence(pattern: ApprovedPattern, date: Date) {
        do {
            try patternService.setNextOccurrence(for: pattern, date: date)
            // 유동 일정 날짜 설정 후 즉시 태스크 생성되도록 알림
            NotificationCenter.default.post(name: .approvedPatternsDidChange, object: nil)
        } catch {
        }
    }
}

// MARK: - Approved Pattern Row

struct ApprovedPatternRow: View {
    let pattern: ApprovedPattern
    let onToggleActive: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onSetNextDate: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Active toggle
            Toggle("", isOn: Binding(
                get: { pattern.isActive },
                set: { _ in onToggleActive() }
            ))
            .toggleStyle(.switch)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 8) {
                // Title and calendar
                HStack {
                    Text(pattern.taskTitle)
                        .font(.headline)
                        .foregroundColor(pattern.isActive ? .primary : .secondary)

                    Spacer()

                    // Calendar badge
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

                // Pattern info
                HStack(spacing: 12) {
                    Label(pattern.patternTypeEnum.rawValue, systemImage: pattern.patternTypeEnum.icon)
                    Label(pattern.frequency.rawValue, systemImage: "arrow.triangle.2.circlepath")
                    Label(pattern.estimatedTimeFormatted, systemImage: "clock")
                }
                .font(.callout)
                .foregroundColor(.secondary)

                // Next occurrence
                HStack {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundColor(.blue)
                    Text("다음 발생: \(pattern.nextOccurrenceDate.formatted(date: .abbreviated, time: .omitted))")

                    if let lastGenerated = pattern.lastGeneratedTaskDate {
                        Text("• 마지막 생성: \(lastGenerated.formatted(date: .abbreviated, time: .omitted))")
                    }
                }
                .font(.callout)
                .foregroundColor(.secondary)

                // Status indicator
                if pattern.isFlexibleSchedule && !pattern.isActive {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .foregroundColor(.blue)
                        Text("다음 날짜 설정 필요")
                    }
                    .font(.callout)
                    .foregroundColor(.blue)
                } else if !pattern.isActive {
                    HStack(spacing: 4) {
                        Image(systemName: "pause.circle.fill")
                            .foregroundColor(.orange)
                        Text("비활성 - 자동 생성 중지됨")
                    }
                    .font(.callout)
                    .foregroundColor(.orange)
                }
            }

            Spacer()

            // Action buttons
            VStack(spacing: 8) {
                if pattern.isFlexibleSchedule && !pattern.isActive {
                    Button(action: onSetNextDate) {
                        Label("날짜 설정", systemImage: "calendar.badge.plus")
                            .font(.callout)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                Button(action: onEdit) {
                    Label("편집", systemImage: "pencil")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: onDelete) {
                    Label("삭제", systemImage: "trash")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.red)
            }
        }
        .padding(16)
        .background(pattern.isActive ? Color(NSColor.controlBackgroundColor) : Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(pattern.isActive ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}
