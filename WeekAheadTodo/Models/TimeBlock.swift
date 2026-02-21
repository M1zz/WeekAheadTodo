import WeekAheadShared
import Foundation

/// 하루의 시간 블록 관리
struct DayTimeBlock: Identifiable, Codable {
    let id: UUID
    let date: Date
    var availableMinutes: Int           // 하루 가용 시간 (분)
    var allocatedTasks: [UUID]          // 배정된 태스크 ID들
    
    init(date: Date, availableMinutes: Int = 360) { // 기본 6시간
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.availableMinutes = availableMinutes
        self.allocatedTasks = []
    }
    
    /// 사용된 시간 계산 (태스크 목록 필요)
    func usedMinutes(tasks: [Task]) -> Int {
        tasks
            .filter { allocatedTasks.contains($0.id) && !$0.isCompleted }
            .reduce(0) { $0 + $1.estimatedMinutes }
    }
    
    /// 남은 용량
    func remainingMinutes(tasks: [Task]) -> Int {
        availableMinutes - usedMinutes(tasks: tasks)
    }
    
    /// 용량 초과 여부
    func isOverCapacity(tasks: [Task]) -> Bool {
        remainingMinutes(tasks: tasks) < 0
    }
    
    /// 특정 태스크를 추가할 수 있는지
    func canFit(task: Task, allTasks: [Task]) -> Bool {
        remainingMinutes(tasks: allTasks) >= task.estimatedMinutes
    }
    
    /// 용량 사용률 (0.0 ~ 1.0+)
    func utilizationRate(tasks: [Task]) -> Double {
        guard availableMinutes > 0 else { return 0 }
        return Double(usedMinutes(tasks: tasks)) / Double(availableMinutes)
    }
    
    /// 날짜 포맷팅
    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 (E)"
        return formatter.string(from: date)
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}

/// 주간 시간 블록 관리자
struct WeeklyTimeBlockManager {
    var blocks: [DayTimeBlock]
    
    init(startingFrom date: Date = Date(), defaultDailyMinutes: Int = 360) {
        let calendar = Calendar.current
        let startOfWeek = calendar.startOfDay(for: date)
        
        blocks = (0..<14).map { dayOffset in
            let blockDate = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek)!
            return DayTimeBlock(date: blockDate, availableMinutes: defaultDailyMinutes)
        }
    }
    
    /// 특정 날짜의 블록 찾기
    func block(for date: Date) -> DayTimeBlock? {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        return blocks.first { calendar.isDate($0.date, inSameDayAs: targetDay) }
    }
    
    /// 특정 날짜의 블록 인덱스
    func blockIndex(for date: Date) -> Int? {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        return blocks.firstIndex { calendar.isDate($0.date, inSameDayAs: targetDay) }
    }
    
    /// 태스크를 배치할 수 있는 가장 빠른 날짜 찾기
    func earliestAvailableDate(for task: Task, allTasks: [Task], startingFrom: Date = Date()) -> Date? {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: startingFrom)
        
        for block in blocks {
            if block.date >= startDay && block.canFit(task: task, allTasks: allTasks) {
                return block.date
            }
        }
        return nil
    }
    
    /// 이번 주 총 가용 시간
    func thisWeekTotalMinutes() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: today)!
        
        return blocks
            .filter { $0.date >= today && $0.date < weekEnd }
            .reduce(0) { $0 + $1.availableMinutes }
    }
    
    /// 이번 주 사용된 시간
    func thisWeekUsedMinutes(tasks: [Task]) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: today)!
        
        return blocks
            .filter { $0.date >= today && $0.date < weekEnd }
            .reduce(0) { $0 + $1.usedMinutes(tasks: tasks) }
    }
}

/// 시간 블록 배정 결과
struct AllocationResult {
    let task: Task
    let suggestedDate: Date?
    let reason: AllocationReason
    
    enum AllocationReason {
        case fitsToday              // 오늘 용량 안에 들어감
        case pushedToFuture(Date)   // 오늘 용량 초과로 미래로 밀림
        case noCapacity             // 2주 내 용량 없음
        case alreadyAllocated       // 이미 배정됨
    }
}
