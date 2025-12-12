import Foundation

/// 캘린더 이벤트의 반복 패턴 감지 서비스
class PatternDetectionService {

    // MARK: - Main Analysis

    /// 전체 패턴 분석 (4가지 유형 모두)
    func analyzePatterns(events: [CalendarEvent]) -> [RecurrencePattern] {
        print("\n[PatternDetectionService.analyzePatterns] 시작")
        print("📊 입력 이벤트: \(events.count)개")

        if events.isEmpty {
            print("  ⚠️ 이벤트가 없어서 패턴 분석 불가")
            return []
        }

        // 이벤트 날짜 범위 확인
        let sortedEvents = events.sorted { $0.startDate < $1.startDate }
        if let firstEvent = sortedEvents.first, let lastEvent = sortedEvents.last {
            print("  📅 이벤트 기간: \(firstEvent.startDate.formatted(date: .abbreviated, time: .omitted)) ~ \(lastEvent.startDate.formatted(date: .abbreviated, time: .omitted))")
        }

        var allPatterns: [RecurrencePattern] = []

        // 1. 매주 고정 요일 패턴
        print("\n  🔍 [1/4] 매주 고정 요일 패턴 감지 중...")
        let weeklyPatterns = detectWeeklyFixedDayPattern(events: events)
        allPatterns.append(contentsOf: weeklyPatterns)
        print("      ✓ 감지됨: \(weeklyPatterns.count)개")

        // 2. 격주/월간 패턴
        print("  🔍 [2/4] 격주/월간 패턴 감지 중...")
        let biweeklyMonthlyPatterns = detectBiweeklyMonthlyPattern(events: events)
        allPatterns.append(contentsOf: biweeklyMonthlyPatterns)
        print("      ✓ 감지됨: \(biweeklyMonthlyPatterns.count)개")

        // 3. 매일 같은 시간 패턴
        print("  🔍 [3/4] 매일 같은 시간 패턴 감지 중...")
        let dailyPatterns = detectDailySameTimePattern(events: events)
        allPatterns.append(contentsOf: dailyPatterns)
        print("      ✓ 감지됨: \(dailyPatterns.count)개")

        // 4. 제목 유사도 패턴
        print("  🔍 [4/4] 제목 유사도 패턴 감지 중...")
        let similarTitlePatterns = detectSimilarTitlePattern(events: events)
        allPatterns.append(contentsOf: similarTitlePatterns)
        print("      ✓ 감지됨: \(similarTitlePatterns.count)개")

        print("\n  🔄 중복 제거 및 순위 정렬 중...")
        print("     중복 제거 전: \(allPatterns.count)개")
        let uniquePatterns = removeDuplicatePatterns(allPatterns)
        print("     중복 제거 후: \(uniquePatterns.count)개")
        let rankedPatterns = rankPatterns(uniquePatterns)

        print("\n✅ [PatternDetectionService] 완료: \(rankedPatterns.count)개 패턴 반환\n")

        return rankedPatterns
    }

    // MARK: - Pattern 1: Weekly Fixed Day

    /// 패턴 1: 매주 고정 요일 반복
    func detectWeeklyFixedDayPattern(events: [CalendarEvent]) -> [RecurrencePattern] {
        var patterns: [RecurrencePattern] = []

        // 1. 요일별로 그룹화
        let eventsByDayOfWeek = Dictionary(grouping: events) { $0.dayOfWeek }

        for (dayOfWeek, dayEvents) in eventsByDayOfWeek {
            guard dayEvents.count >= 4 else { continue }

            // 2. 같은 시간대별로 그룹화 (±30분 허용)
            let timeGroups = groupByTimeRange(dayEvents, tolerance: 30)

            for timeGroup in timeGroups {
                guard timeGroup.count >= 4 else { continue }

                // 3. 간격 분석
                let intervals = calculateIntervals(timeGroup)
                let avgInterval = intervals.reduce(0, +) / Double(intervals.count)

                // 4. 7일 간격인지 확인 (±2일 허용)
                if abs(avgInterval - 7.0) <= 2.0 {
                    let confidence = calculateWeeklyConfidence(
                        eventCount: timeGroup.count,
                        intervalConsistency: standardDeviation(intervals)
                    )

                    if confidence >= 0.6 {
                        let pattern = createWeeklyPattern(
                            events: timeGroup,
                            dayOfWeek: dayOfWeek,
                            confidence: confidence
                        )
                        patterns.append(pattern)
                    }
                }
            }
        }

        return patterns
    }

    private func calculateWeeklyConfidence(eventCount: Int, intervalConsistency: Double) -> Double {
        // 이벤트 수 점수
        let countScore = min(Double(eventCount) / 12.0, 1.0)

        // 간격 일관성 점수 (표준편차 낮을수록 높음)
        let consistencyScore = max(0, 1.0 - (intervalConsistency / 3.0))

        return countScore * 0.6 + consistencyScore * 0.4
    }

    private func createWeeklyPattern(
        events: [CalendarEvent],
        dayOfWeek: Int,
        confidence: Double
    ) -> RecurrencePattern {
        let sortedEvents = events.sorted { $0.startDate < $1.startDate }
        guard let firstEvent = sortedEvents.first else {
            fatalError("이벤트가 비어있음")
        }

        let suggestedTask = createSuggestedTask(
            from: events,
            patternType: .weeklyFixedDay
        )

        return RecurrencePattern(
            type: .weeklyFixedDay,
            events: sortedEvents,
            confidenceScore: confidence,
            suggestedTask: suggestedTask
        )
    }

    // MARK: - Pattern 2: Biweekly/Monthly

    /// 패턴 2: 격주/월간 반복
    func detectBiweeklyMonthlyPattern(events: [CalendarEvent]) -> [RecurrencePattern] {
        var patterns: [RecurrencePattern] = []

        // 1. 제목 유사도로 그룹화
        let titleGroups = groupBySimilarTitle(events, threshold: 0.8)

        for titleGroup in titleGroups {
            guard titleGroup.count >= 3 else { continue }

            // 2. 간격 분석
            let sortedEvents = titleGroup.sorted { $0.startDate < $1.startDate }
            let intervals = calculateIntervals(sortedEvents)
            let avgInterval = intervals.reduce(0, +) / Double(intervals.count)

            var frequency: RecurrenceFrequency?
            var confidence: Double = 0

            // 3. 격주 (14일 ±3일)
            if abs(avgInterval - 14.0) <= 3.0 {
                frequency = .biweekly
                confidence = calculateRecurrenceConfidence(
                    eventCount: titleGroup.count,
                    intervalConsistency: standardDeviation(intervals),
                    targetInterval: 14.0
                )
            }
            // 4. 월간 (28-31일)
            else if avgInterval >= 28.0 && avgInterval <= 31.0 {
                frequency = .monthly
                confidence = calculateRecurrenceConfidence(
                    eventCount: titleGroup.count,
                    intervalConsistency: standardDeviation(intervals),
                    targetInterval: 30.0
                )
            }

            if let freq = frequency, confidence >= 0.5 {
                let pattern = createBiweeklyMonthlyPattern(
                    events: sortedEvents,
                    frequency: freq,
                    confidence: confidence
                )
                patterns.append(pattern)
            }
        }

        return patterns
    }

    private func calculateRecurrenceConfidence(
        eventCount: Int,
        intervalConsistency: Double,
        targetInterval: Double
    ) -> Double {
        let countScore = min(Double(eventCount) / 6.0, 1.0)
        let consistencyScore = max(0, 1.0 - (intervalConsistency / targetInterval * 0.3))

        return countScore * 0.5 + consistencyScore * 0.5
    }

    private func createBiweeklyMonthlyPattern(
        events: [CalendarEvent],
        frequency: RecurrenceFrequency,
        confidence: Double
    ) -> RecurrencePattern {
        let suggestedTask = createSuggestedTask(
            from: events,
            patternType: .biweeklyMonthly
        )

        return RecurrencePattern(
            type: .biweeklyMonthly,
            events: events,
            confidenceScore: confidence,
            suggestedTask: suggestedTask
        )
    }

    // MARK: - Pattern 3: Daily Same Time

    /// 패턴 3: 매일 같은 시간대 반복
    func detectDailySameTimePattern(events: [CalendarEvent]) -> [RecurrencePattern] {
        var patterns: [RecurrencePattern] = []

        // 1. 시간대별로 그룹화 (±15분 허용)
        let timeGroups = groupByTimeRange(events, tolerance: 15)

        for timeGroup in timeGroups {
            guard timeGroup.count >= 10 else { continue }

            // 2. 간격 분석
            let intervals = calculateIntervals(timeGroup)
            let avgInterval = intervals.reduce(0, +) / Double(intervals.count)

            // 3. 1일 간격 (±0.5일 허용, 주말 제외 고려로 최대 2일)
            if avgInterval >= 0.5 && avgInterval <= 2.0 {
                let confidence = calculateDailyConfidence(
                    eventCount: timeGroup.count,
                    totalDays: 90,
                    intervalConsistency: standardDeviation(intervals)
                )

                if confidence >= 0.6 {
                    let pattern = createDailyPattern(
                        events: timeGroup,
                        confidence: confidence
                    )
                    patterns.append(pattern)
                }
            }
        }

        return patterns
    }

    private func calculateDailyConfidence(
        eventCount: Int,
        totalDays: Int,
        intervalConsistency: Double
    ) -> Double {
        let frequencyScore = Double(eventCount) / Double(totalDays)
        let consistencyScore = max(0, 1.0 - intervalConsistency / 2.0)

        return min(1.0, frequencyScore * 0.7 + consistencyScore * 0.3)
    }

    private func createDailyPattern(
        events: [CalendarEvent],
        confidence: Double
    ) -> RecurrencePattern {
        let sortedEvents = events.sorted { $0.startDate < $1.startDate }

        let suggestedTask = createSuggestedTask(
            from: sortedEvents,
            patternType: .dailySameTime
        )

        return RecurrencePattern(
            type: .dailySameTime,
            events: sortedEvents,
            confidenceScore: confidence,
            suggestedTask: suggestedTask
        )
    }

    // MARK: - Pattern 4: Similar Title

    /// 패턴 4: 제목 유사도 기반 반복
    func detectSimilarTitlePattern(events: [CalendarEvent]) -> [RecurrencePattern] {
        var patterns: [RecurrencePattern] = []

        // 1. 제목 유사도로 그룹화 (임계값 낮춤)
        let titleGroups = groupBySimilarTitle(events, threshold: 0.75)

        for titleGroup in titleGroups {
            guard titleGroup.count >= 4 else { continue }

            // 2. 시간 일관성 분석
            let hasTimePattern = analyzeTimeConsistency(titleGroup)

            // 3. 간격 분석
            let intervals = calculateIntervals(titleGroup)
            let hasIntervalPattern = standardDeviation(intervals) < 7.0

            let confidence = calculateSimilarityConfidence(
                eventCount: titleGroup.count,
                titleSimilarity: calculateAverageSimilarity(titleGroup),
                hasTimePattern: hasTimePattern,
                hasIntervalPattern: hasIntervalPattern
            )

            if confidence >= 0.5 {
                let pattern = createSimilarityPattern(
                    events: titleGroup,
                    confidence: confidence
                )
                patterns.append(pattern)
            }
        }

        return patterns
    }

    private func calculateSimilarityConfidence(
        eventCount: Int,
        titleSimilarity: Double,
        hasTimePattern: Bool,
        hasIntervalPattern: Bool
    ) -> Double {
        let countScore = min(Double(eventCount) / 8.0, 1.0)
        let timeScore = hasTimePattern ? 1.0 : 0.5
        let intervalScore = hasIntervalPattern ? 1.0 : 0.5

        return countScore * 0.4 + titleSimilarity * 0.3 + timeScore * 0.15 + intervalScore * 0.15
    }

    private func createSimilarityPattern(
        events: [CalendarEvent],
        confidence: Double
    ) -> RecurrencePattern {
        let sortedEvents = events.sorted { $0.startDate < $1.startDate }

        let suggestedTask = createSuggestedTask(
            from: sortedEvents,
            patternType: .similarTitle
        )

        return RecurrencePattern(
            type: .similarTitle,
            events: sortedEvents,
            confidenceScore: confidence,
            suggestedTask: suggestedTask
        )
    }

    // MARK: - Pattern Ranking

    /// 패턴 우선순위 정렬
    func rankPatterns(_ patterns: [RecurrencePattern]) -> [RecurrencePattern] {
        return patterns.sorted { pattern1, pattern2 in
            // 1. 신뢰도 우선
            if abs(pattern1.confidenceScore - pattern2.confidenceScore) > 0.1 {
                return pattern1.confidenceScore > pattern2.confidenceScore
            }

            // 2. 이벤트 수
            if pattern1.events.count != pattern2.events.count {
                return pattern1.events.count > pattern2.events.count
            }

            // 3. 패턴 타입 우선순위
            return pattern1.type.sortOrder < pattern2.type.sortOrder
        }
    }

    // MARK: - Utility Functions

    /// 시간대별로 그룹화
    private func groupByTimeRange(_ events: [CalendarEvent], tolerance: Int) -> [[CalendarEvent]] {
        var groups: [[CalendarEvent]] = []
        var remaining = events

        while !remaining.isEmpty {
            let first = remaining.removeFirst()
            var group = [first]

            remaining = remaining.filter { event in
                if first.isSameTimeRange(as: event, tolerance: tolerance) {
                    group.append(event)
                    return false
                }
                return true
            }

            groups.append(group)
        }

        return groups
    }

    /// 제목 유사도로 그룹화
    private func groupBySimilarTitle(_ events: [CalendarEvent], threshold: Double) -> [[CalendarEvent]] {
        var groups: [[CalendarEvent]] = []
        var remaining = events

        while !remaining.isEmpty {
            let first = remaining.removeFirst()
            var group = [first]

            remaining = remaining.filter { event in
                let similarity = titleSimilarity(first.title, event.title)
                if similarity >= threshold {
                    group.append(event)
                    return false
                }
                return true
            }

            if group.count >= 2 {
                groups.append(group)
            }
        }

        return groups
    }

    /// 이벤트 간 간격 계산 (일 단위)
    private func calculateIntervals(_ events: [CalendarEvent]) -> [Double] {
        guard events.count >= 2 else { return [] }

        let sortedEvents = events.sorted { $0.startDate < $1.startDate }
        var intervals: [Double] = []

        for i in 0..<(sortedEvents.count - 1) {
            let interval = sortedEvents[i + 1].startDate.timeIntervalSince(sortedEvents[i].startDate)
            intervals.append(interval / 86400.0) // 초 → 일
        }

        return intervals
    }

    /// 시간 일관성 분석
    private func analyzeTimeConsistency(_ events: [CalendarEvent]) -> Bool {
        guard events.count >= 2 else { return true }

        let calendar = Calendar.current
        let hours = events.map { calendar.component(.hour, from: $0.startDate) }

        let stdDev = standardDeviation(hours.map { Double($0) })
        return stdDev < 2.0 // 2시간 이내 변동
    }

    /// 평균 제목 유사도 계산
    private func calculateAverageSimilarity(_ events: [CalendarEvent]) -> Double {
        guard events.count >= 2 else { return 1.0 }

        var similarities: [Double] = []
        let titles = events.map { $0.title }

        for i in 0..<titles.count {
            for j in (i + 1)..<titles.count {
                let similarity = titleSimilarity(titles[i], titles[j])
                similarities.append(similarity)
            }
        }

        return similarities.isEmpty ? 0 : similarities.reduce(0, +) / Double(similarities.count)
    }

    /// 중복 패턴 제거
    private func removeDuplicatePatterns(_ patterns: [RecurrencePattern]) -> [RecurrencePattern] {
        var uniquePatterns: [RecurrencePattern] = []
        var usedEventIds: Set<String> = []

        for pattern in patterns.sorted(by: { $0.confidenceScore > $1.confidenceScore }) {
            let eventIds = Set(pattern.events.map { $0.id })
            let overlap = eventIds.intersection(usedEventIds).count
            let overlapRatio = Double(overlap) / Double(eventIds.count)

            // 50% 이상 중복되지 않으면 추가
            if overlapRatio < 0.5 {
                uniquePatterns.append(pattern)
                usedEventIds.formUnion(eventIds)
            }
        }

        return uniquePatterns
    }

    // MARK: - Task Suggestion

    /// 패턴에서 Task 제안 생성
    private func createSuggestedTask(
        from events: [CalendarEvent],
        patternType: PatternType
    ) -> SuggestedTask {
        guard let firstEvent = events.first else {
            return SuggestedTask(
                title: "새 할 일",
                estimatedMinutes: 30,
                leadTimeDays: 0,
                taskType: .preparable
            )
        }

        // 제목 제안
        let title = suggestTitle(from: events, patternType: patternType)

        // 예상 시간
        let avgDuration = events.map { $0.durationMinutes }.reduce(0, +) / events.count
        let estimatedMinutes = max(15, avgDuration)

        // 선행 일수
        let leadTimeDays = suggestLeadTimeDays(
            for: avgDuration,
            patternType: patternType
        )

        // Task 타입
        let taskType = suggestTaskType(from: firstEvent)

        // 반복 규칙
        let recurrenceRule = createRecurrenceRule(
            from: events,
            patternType: patternType
        )

        return SuggestedTask(
            title: title,
            estimatedMinutes: estimatedMinutes,
            leadTimeDays: leadTimeDays,
            taskType: taskType,
            recurrenceRule: recurrenceRule
        )
    }

    private func suggestTitle(
        from events: [CalendarEvent],
        patternType: PatternType
    ) -> String {
        guard let firstEvent = events.first else {
            return "새 할 일"
        }

        let baseTitle = firstEvent.title

        // 키워드 분석
        let preparationKeywords = ["회의", "미팅", "meeting", "발표", "presentation"]

        for keyword in preparationKeywords {
            if baseTitle.lowercased().contains(keyword) {
                return "\(baseTitle) 준비"
            }
        }

        return baseTitle
    }

    private func suggestLeadTimeDays(
        for durationMinutes: Int,
        patternType: PatternType
    ) -> Int {
        switch patternType {
        case .weeklyFixedDay:
            return durationMinutes >= 60 ? 2 : 1
        case .biweeklyMonthly:
            return 3
        case .dailySameTime:
            return 0
        case .similarTitle:
            return durationMinutes >= 60 ? 2 : 1
        }
    }

    private func suggestTaskType(from event: CalendarEvent) -> TaskType {
        let title = event.title.lowercased()

        let dateSpecificKeywords = ["회의", "미팅", "meeting", "면접", "interview", "발표", "presentation"]
        let preparableKeywords = ["준비", "작성", "리뷰", "review", "계획", "planning"]

        if dateSpecificKeywords.contains(where: { title.contains($0) }) {
            return .dateSpecific
        } else if preparableKeywords.contains(where: { title.contains($0) }) {
            return .preparable
        }

        return event.durationMinutes >= 60 ? .preparable : .dateSpecific
    }

    private func createRecurrenceRule(
        from events: [CalendarEvent],
        patternType: PatternType
    ) -> RecurrenceRule? {
        guard events.count >= 2 else { return nil }

        let sortedEvents = events.sorted { $0.startDate < $1.startDate }
        let intervals = calculateIntervals(sortedEvents)
        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)

        let calendar = Calendar.current
        var frequency: RecurrenceFrequency
        var interval: Int = 1
        var daysOfWeek: [Int]? = nil

        switch patternType {
        case .weeklyFixedDay:
            frequency = .weekly
            if let firstEvent = sortedEvents.first {
                daysOfWeek = [firstEvent.dayOfWeek]
            }

        case .biweeklyMonthly:
            if avgInterval >= 28 {
                frequency = .monthly
            } else {
                frequency = .biweekly
                interval = 2
            }

        case .dailySameTime:
            frequency = .daily

        case .similarTitle:
            if abs(avgInterval - 7.0) <= 2.0 {
                frequency = .weekly
            } else if avgInterval >= 28 {
                frequency = .monthly
            } else {
                frequency = .weekly
            }
        }

        // 다음 발생 날짜 계산
        guard let lastEvent = sortedEvents.last else { return nil }
        let nextOccurrence = calendar.date(byAdding: .day, value: Int(avgInterval), to: lastEvent.startDate) ?? Date()

        return RecurrenceRule(
            frequency: frequency,
            interval: interval,
            daysOfWeek: daysOfWeek,
            nextOccurrenceDate: nextOccurrence
        )
    }
}

// MARK: - Helper Functions

/// 표준편차 계산
private func standardDeviation(_ values: [Double]) -> Double {
    guard values.count > 1 else { return 0 }

    let mean = values.reduce(0, +) / Double(values.count)
    let squaredDiffs = values.map { pow($0 - mean, 2) }
    let variance = squaredDiffs.reduce(0, +) / Double(values.count)

    return sqrt(variance)
}
