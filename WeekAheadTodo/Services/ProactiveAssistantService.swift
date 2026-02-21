import WeekAheadShared
import Foundation

/// 선제적 제안 서비스 - "비서처럼" 먼저 알려주는 기능
@MainActor
class ProactiveAssistantService: ObservableObject {

    static let shared = ProactiveAssistantService()

    @Published var activeSuggestions: [AssistantSuggestion] = []
    @Published var suggestionHistory: [AssistantSuggestion] = []

    // UserDefaults 키
    private let dismissedSuggestionsKey = "dismissedSuggestions"
    private let suggestionHistoryKey = "suggestionHistory"

    private init() {
        loadHistory()
    }

    // MARK: - Public Methods

    /// 모든 태스크를 분석하여 제안 생성
    func analyzeTasks(_ tasks: [Task]) {
        var suggestions: [AssistantSuggestion] = []

        // 1. 회의 준비 누락 감지
        if let meetingPreparationSuggestion = detectMeetingPreparationMissing(tasks) {
            suggestions.append(meetingPreparationSuggestion)
        }

        // 2. 용량 초과 감지
        if let capacityOverloadSuggestion = detectCapacityOverload(tasks) {
            suggestions.append(capacityOverloadSuggestion)
        }

        // 3. 후속 조치 필요 감지
        if let followUpSuggestion = detectFollowUpNeeded(tasks) {
            suggestions.append(followUpSuggestion)
        }

        // 4. 마감 위험 감지
        if let deadlineRiskSuggestion = detectDeadlineRisk(tasks) {
            suggestions.append(deadlineRiskSuggestion)
        }

        // 5. 여유 시간 활용 제안
        if let idleTimeSuggestion = detectIdleTime(tasks) {
            suggestions.append(idleTimeSuggestion)
        }

        // 우선순위 순으로 정렬 (긴급도 높은 순)
        suggestions.sort { $0.priority.rawValue > $1.priority.rawValue }

        // 최대 3개까지만 표시
        let filteredSuggestions = suggestions.prefix(3)

        // 새로운 제안을 히스토리에 추가 (중복 방지)
        for suggestion in filteredSuggestions {
            if !suggestionHistory.contains(where: { $0.uniqueKey == suggestion.uniqueKey }) {
                suggestionHistory.insert(suggestion, at: 0)  // 최신 항목을 맨 위에
            }
        }

        // 히스토리는 최대 50개까지 유지
        if suggestionHistory.count > 50 {
            suggestionHistory = Array(suggestionHistory.prefix(50))
        }

        // 히스토리 저장
        saveHistory()

        // Dismiss된 제안 필터링
        activeSuggestions = Array(filteredSuggestions).filter { !isDismissed($0) }
    }

    /// 제안 무시하기
    func dismissSuggestion(_ suggestion: AssistantSuggestion) {
        // UserDefaults에 저장 (24시간 동안 재표시 안 함)
        var dismissed = getDismissedSuggestions()
        dismissed[suggestion.uniqueKey] = Date()
        saveDismissedSuggestions(dismissed)

        // 활성 제안에서 제거
        activeSuggestions.removeAll { $0.id == suggestion.id }
    }

    // MARK: - Detection Logic

    /// 1. 회의 준비 누락 감지
    /// 내일 메인 태스크 (회의, 발표) 확인 → 준비 태스크 완료도 < 50% → 경고
    private func detectMeetingPreparationMissing(_ tasks: [Task]) -> AssistantSuggestion? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        // 내일 있는 메인 태스크 찾기
        let tomorrowMainTasks = tasks.filter {
            !$0.isPreparation &&
            !$0.isCompleted &&
            calendar.isDate($0.dueDate, inSameDayAs: tomorrow)
        }

        guard !tomorrowMainTasks.isEmpty else { return nil }

        for mainTask in tomorrowMainTasks {
            // 이 메인 태스크를 위한 준비 태스크들
            let preparationTasks = tasks.filter {
                $0.isPreparation &&
                $0.mainTaskId == mainTask.id
            }

            guard !preparationTasks.isEmpty else { continue }

            // 준비 태스크 완료율
            let completedCount = preparationTasks.filter { $0.isCompleted }.count
            let completionRate = Double(completedCount) / Double(preparationTasks.count)

            // 완료율이 50% 미만이면 경고
            if completionRate < 0.5 {
                let remainingTasks = preparationTasks.filter { !$0.isCompleted }
                let taskTitles = remainingTasks.prefix(3).map { "• \($0.title)" }.joined(separator: "\n")

                return AssistantSuggestion(
                    type: .meetingPreparationMissing,
                    title: "⚠️ 준비 부족",
                    message: "내일 '\(mainTask.title)'이(가) 있는데 준비가 \(Int(completionRate * 100))%만 완료됐어요.\n\n남은 준비:\n\(taskTitles)",
                    priority: .high,
                    relatedTaskIds: [mainTask.id] + remainingTasks.map { $0.id },
                    actionButtons: [
                        SuggestionAction(title: "준비 태스크 보기", actionType: .viewTasks),
                        SuggestionAction(title: "나중에", actionType: .dismiss)
                    ]
                )
            }
        }

        return nil
    }

    /// 2. 용량 초과 감지
    /// todayRemainingMinutes < 0 → 긴급 경고 + 재배치 제안
    private func detectCapacityOverload(_ tasks: [Task]) -> AssistantSuggestion? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // 오늘 해야 할 일들
        let todayTasks = tasks.filter {
            $0.currentHorizon == .today && !$0.isCompleted
        }

        guard !todayTasks.isEmpty else { return nil }

        // 총 예상 시간
        let totalMinutes = todayTasks.reduce(0) { $0 + $1.estimatedMinutes }

        // 하루 작업 가능 시간 (8시간 = 480분)
        let availableMinutes = 480

        // 초과 시간
        let overloadMinutes = totalMinutes - availableMinutes

        if overloadMinutes > 0 {
            let overloadHours = overloadMinutes / 60
            let overloadMins = overloadMinutes % 60

            return AssistantSuggestion(
                type: .capacityOverload,
                title: "🚨 오늘 할 일 과부하",
                message: "오늘 할 일이 \(overloadHours)시간 \(overloadMins)분 초과됐어요.\n일부 태스크를 내일로 미루거나 시간을 조정해보세요.",
                priority: .urgent,
                relatedTaskIds: todayTasks.map { $0.id },
                actionButtons: [
                    SuggestionAction(title: "태스크 재배치", actionType: .reschedule),
                    SuggestionAction(title: "무시", actionType: .dismiss)
                ]
            )
        }

        return nil
    }

    /// 3. 후속 조치 필요 감지
    /// 오늘 완료된 메인 태스크 확인 → 후속 조치 태스크 없으면 제안
    private func detectFollowUpNeeded(_ tasks: [Task]) -> AssistantSuggestion? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // 오늘 완료된 메인 태스크
        let completedMainTasks = tasks.filter {
            !$0.isPreparation &&
            $0.isCompleted &&
            calendar.isDate($0.createdAt, inSameDayAs: today)
        }

        guard !completedMainTasks.isEmpty else { return nil }

        for mainTask in completedMainTasks {
            // 후속 조치 태스크가 있는지 확인
            let hasFollowUp = tasks.contains {
                $0.taskRole == .followUp && $0.mainTaskId == mainTask.id
            }

            if !hasFollowUp {
                return AssistantSuggestion(
                    type: .followUpNeeded,
                    title: "📝 후속 조치",
                    message: "'\(mainTask.title)'을(를) 완료했어요!\n후속 조치가 필요한가요?",
                    priority: .medium,
                    relatedTaskIds: [mainTask.id],
                    actionButtons: [
                        SuggestionAction(title: "후속 조치 추가", actionType: .addTask),
                        SuggestionAction(title: "필요 없음", actionType: .dismiss)
                    ]
                )
            }
        }

        return nil
    }

    /// 4. 마감 위험 감지
    /// effectiveStartDate < today && isNotStarted → 경고
    private func detectDeadlineRisk(_ tasks: [Task]) -> AssistantSuggestion? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // 시작일이 지났는데 시작 안한 태스크
        let overdueTasks = tasks.filter {
            $0.effectiveStartDate < today &&
            $0.isNotStarted &&
            !$0.isCompleted
        }

        guard !overdueTasks.isEmpty else { return nil }

        // 가장 오래된 것
        if let oldestTask = overdueTasks.max(by: { $0.daysUntilStart > $1.daysUntilStart }) {
            let daysOverdue = abs(oldestTask.daysUntilStart)

            return AssistantSuggestion(
                type: .deadlineRisk,
                title: "❗ 시작일 지남",
                message: "'\(oldestTask.title)'은(는) 시작일이 \(daysOverdue)일 지났어요.\n마감: \(oldestTask.dDayText)",
                priority: .high,
                relatedTaskIds: [oldestTask.id],
                actionButtons: [
                    SuggestionAction(title: "지금 시작", actionType: .viewTasks),
                    SuggestionAction(title: "마감일 연장", actionType: .reschedule)
                ]
            )
        }

        return nil
    }

    /// 5. 여유 시간 활용 제안
    /// 오늘 여유 시간에 미리 할 수 있는 일이 있으면 제안
    private func detectIdleTime(_ tasks: [Task]) -> AssistantSuggestion? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // 오늘 해야 할 일들
        let todayTasks = tasks.filter {
            $0.currentHorizon == .today && !$0.isCompleted
        }

        // 총 예상 시간
        let totalMinutes = todayTasks.reduce(0) { $0 + $1.estimatedMinutes }

        // 하루 작업 가능 시간 (8시간 = 480분)
        let availableMinutes = 480

        // 여유 시간
        let idleMinutes = availableMinutes - totalMinutes

        // 여유 시간이 1시간 이상 있으면
        if idleMinutes >= 60 {
            // 미리 할 수 있는 일 (내일 이후의 preparable 태스크)
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
            let preparableTasks = tasks.filter {
                $0.dueDate >= tomorrow &&
                $0.taskType == .preparable &&
                !$0.isCompleted &&
                $0.estimatedMinutes <= idleMinutes
            }

            guard !preparableTasks.isEmpty else { return nil }

            let idleHours = idleMinutes / 60
            let taskTitles = preparableTasks.prefix(3).map { "• \($0.title) (\($0.estimatedTimeFormatted))" }.joined(separator: "\n")

            return AssistantSuggestion(
                type: .idleTime,
                title: "💡 여유 시간 활용",
                message: "오늘 \(idleHours)시간 정도 여유가 있어요.\n미리 할 수 있는 일:\n\n\(taskTitles)",
                priority: .low,
                relatedTaskIds: preparableTasks.map { $0.id },
                actionButtons: [
                    SuggestionAction(title: "미리 하기", actionType: .viewTasks),
                    SuggestionAction(title: "나중에", actionType: .dismiss)
                ]
            )
        }

        return nil
    }

    // MARK: - Dismissed Suggestions Management

    /// 제안이 dismiss되었는지 확인 (24시간 이내)
    private func isDismissed(_ suggestion: AssistantSuggestion) -> Bool {
        let dismissed = getDismissedSuggestions()
        guard let dismissedDate = dismissed[suggestion.uniqueKey] else {
            return false
        }

        // 24시간이 지났으면 다시 표시
        let hoursSinceDismissed = Date().timeIntervalSince(dismissedDate) / 3600
        return hoursSinceDismissed < 24
    }

    /// UserDefaults에서 dismiss된 제안 로드
    private func getDismissedSuggestions() -> [String: Date] {
        guard let data = UserDefaults.standard.data(forKey: dismissedSuggestionsKey),
              let dismissed = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return [:]
        }
        return dismissed
    }

    /// UserDefaults에 dismiss된 제안 저장
    private func saveDismissedSuggestions(_ dismissed: [String: Date]) {
        if let data = try? JSONEncoder().encode(dismissed) {
            UserDefaults.standard.set(data, forKey: dismissedSuggestionsKey)
        }
    }

    /// 모든 dismiss 기록 초기화 (디버깅용)
    func clearDismissedSuggestions() {
        UserDefaults.standard.removeObject(forKey: dismissedSuggestionsKey)
    }

    // MARK: - History Persistence

    /// UserDefaults에서 제안 히스토리 로드
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: suggestionHistoryKey),
              let history = try? JSONDecoder().decode([AssistantSuggestion].self, from: data) else {
            return
        }
        suggestionHistory = history
    }

    /// UserDefaults에 제안 히스토리 저장
    private func saveHistory() {
        if let data = try? JSONEncoder().encode(suggestionHistory) {
            UserDefaults.standard.set(data, forKey: suggestionHistoryKey)
        }
    }

    /// 히스토리에서 제안 삭제
    func removeFromHistory(_ suggestion: AssistantSuggestion) {
        suggestionHistory.removeAll { $0.id == suggestion.id }
        saveHistory()
    }

    /// 모든 히스토리 삭제
    func clearHistory() {
        suggestionHistory.removeAll()
        UserDefaults.standard.removeObject(forKey: suggestionHistoryKey)
    }
}
