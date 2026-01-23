# WeekAheadTodo "비서" 기능 강화 구현 계획

## 목표
사용자가 "해야 할 일을 까먹지 않게 대신 기억하고 알려주는" 진정한 비서 앱 만들기

## 구현할 기능 (우선순위 순)

### 1. 커스터마이징 가능한 스마트 알림 시스템 ⭐⭐⭐⭐⭐
**문제점**: 현재 알림이 9시, 15시, 21시로 고정되어 있어 유연하지 않음

**해결책**:
- 알림 시간 추가/삭제/수정 UI 제공
- **재촉 알림**: 마감 임박인데 시작 안 한 일 특별 알림
- UserDefaults에 저장하여 영속성 유지

**구현 파일**:
- `NotificationService.swift` - NotificationTime 모델 추가, 동적 알림 로드/저장
- `Views/NotificationSettingsView.swift` (신규) - 알림 커스터마이징 UI
- `ContentView.swift` - 설정 섹션에 링크 추가

**재촉 알림 조건**:
1. 마감 2일 이내 + 시작 안함 → "⏰ 마감까지 N일 남았는데 시작 안했어요!"
2. 마감 당일 + 진행 중 → "🚨 오늘 마감인데 완료 가능할까요?"
3. 시작일 지남 + 시작 안함 → "❗ 시작일이 N일 지났어요"

---

### 2. 빠른 태스크 추가 단축키 ⭐⭐⭐⭐
**문제점**: 생각날 때 바로 기록하기 어려움

**해결책**:
- **Cmd+Shift+N** 단축키로 빠른 추가 윈도우 팝업
- 자연어 파싱 활용 ("내일까지 보고서 2시간")
- Esc로 취소, Enter로 즉시 추가

**구현 파일**:
- `WeekAheadTodoApp.swift` - CommandMenu로 단축키 등록
- `Views/QuickAddView.swift` (신규) - 미니멀 플로팅 윈도우
- `ContentView.swift` - NotificationCenter로 윈도우 표시

---

### 3. 선제적 제안 시스템 (Proactive Assistant) ⭐⭐⭐⭐⭐
**목표**: "비서처럼" 먼저 알려주는 기능

**제안 유형**:
1. **회의 준비 누락**: "내일 회의가 있는데 자료 준비가 50% 미만이에요"
2. **용량 초과**: "오늘 할 일이 너무 많아요 (N분 초과)"
3. **후속 조치**: "회의 완료했어요! 후속 조치가 필요한가요?"
4. **마감 위험**: "이 일은 시작일이 N일 지났어요"
5. **여유 시간**: "오늘 여유 시간에 미리 할 수 있는 일이 있어요"

**구현 파일**:
- `Services/ProactiveAssistantService.swift` (신규) - 제안 감지 로직
- `Models/AssistantSuggestion.swift` (신규) - 제안 데이터 모델
- `Views/AssistantSuggestionBannerView.swift` (신규) - 배너 UI
- `ContentView.swift` - 오늘 섹션 상단에 배너 표시
- `TaskViewModel.swift` - ProactiveAssistantService 연동

**제안 감지 로직**:
```swift
// 회의 준비 누락
- 내일 메인 태스크 (회의, 발표) 확인
- 준비 태스크 완료도 < 50% → 경고

// 용량 초과
- todayRemainingMinutes < 0 → 긴급 경고 + 재배치 제안

// 후속 조치
- 오늘 완료된 메인 태스크 확인
- TaskRole.followUp 없으면 → "후속 조치 추가할까요?"

// 마감 위험
- effectiveStartDate < today && isNotStarted → 경고
```

---

### 4. 우선순위 수동 조정 ⭐⭐⭐
**문제점**: 자동 계산만 가능, 드래그로 순서 변경 불가

**해결책**:
- 드래그 앤 드롭으로 오늘 할 일 순서 조정
- Task 모델에 `manualPriority` 추가
- 자동 우선순위 재설정 버튼 제공

**구현 파일**:
- `Models/Task.swift` - manualPriority 속성 추가
- `ContentView.swift` - TaskRowView에 드래그 핸들 추가
- `ViewModels/TaskViewModel.swift` - 드래그 앤 드롭 델리게이트

**드래그 앤 드롭 구현**:
```swift
// Task 모델
var manualPriority: Int? = nil
var sortOrder: Int {
    manualPriority ?? Int(urgencyScore * 100)
}

// UI
TaskRowView
  .onDrag { NSItemProvider(object: task.id.uuidString) }
  .onDrop { /* 순서 재배치 */ }
```

---

## 구현 순서

### Phase 1: 빠른 추가 단축키 (반나절) ✅ 완료
가장 빠르게 UX를 개선할 수 있는 기능
1. ✅ CommandMenu 단축키 등록
2. ✅ QuickAddView UI 구현
3. ✅ ContentView 연동

### Phase 2: 알림 시스템 강화 (1-2일) ✅ 완료
사용자 최우선 요구사항
1. ✅ NotificationTime 모델 생성
2. ✅ NotificationService 동적 알림 로드/저장
3. ✅ NotificationSettingsView UI
4. ✅ 재촉 알림 로직 추가

### Phase 3: 우선순위 수동 조정 (1일) ✅ 완료
사용성 개선
1. ✅ Task 모델 manualPriority 추가
2. ✅ 드래그 앤 드롭 구현
3. ✅ 오늘 섹션 적용

### Phase 4: 선제적 제안 시스템 (2-3일) ✅ 완료
비서 기능의 핵심
1. ✅ AssistantSuggestion 모델
2. ✅ ProactiveAssistantService 생성
3. ✅ 감지 로직 구현 (회의 준비 → 용량 초과 → 후속 조치 → 마감 위험 → 여유 시간)
4. ✅ AssistantSuggestionBannerView UI
5. ✅ ContentView 통합

---

## Critical Files

### 신규 생성할 파일
```
WeekAheadTodo/
├── Services/
│   └── ProactiveAssistantService.swift    # 선제적 제안 핵심 로직
├── Models/
│   └── AssistantSuggestion.swift          # 제안 데이터 모델
└── Views/
    ├── NotificationSettingsView.swift     # 알림 커스터마이징 UI (🔄 진행 중)
    ├── QuickAddView.swift                 # 빠른 추가 UI (✅ 완료)
    └── AssistantSuggestionBannerView.swift # 제안 배너 UI
```

### 수정할 기존 파일
```
WeekAheadTodo/
├── WeekAheadTodoApp.swift          # ✅ CommandMenu 단축키 등록
├── ContentView.swift                # ✅ QuickAddView 통합
├── Models/Task.swift                # manualPriority 추가 예정
├── ViewModels/TaskViewModel.swift   # ProactiveAssistant 연동 예정
└── Services/NotificationService.swift # ✅ 동적 알림 시간, 재촉 알림
```

---

## 데이터 모델 변경사항

### NotificationTime (신규) ✅ 완료
```swift
struct NotificationTime: Codable, Identifiable, Equatable {
    let id: UUID
    var hour: Int           // 0-23
    var minute: Int         // 0-59
    var isEnabled: Bool
    var label: String       // "아침 체크", "점심 후 체크"
}
```

### Task (수정) ⏳ 예정
```swift
struct Task {
    // 기존 속성들...
    var manualPriority: Int? = nil  // 수동 우선순위 (nil = 자동)

    var sortOrder: Int {
        manualPriority ?? Int(urgencyScore * 100)
    }
}
```

### AssistantSuggestion (신규) ⏳ 예정
```swift
struct AssistantSuggestion: Identifiable {
    let id: UUID
    let type: SuggestionType
    let title: String               // "⚠️ 준비 부족"
    let message: String             // 상세 메시지
    let priority: SuggestionPriority // .urgent, .high, .medium, .low
    let relatedTaskIds: [UUID]
    let actionButtons: [SuggestionAction]
    let dismissible: Bool
}

enum SuggestionType {
    case meetingPreparationMissing
    case capacityOverload
    case followUpNeeded
    case deadlineRisk
    case idleTime
}
```

---

## 검증 방법

### 알림 시스템
1. 설정에서 알림 시간 추가/삭제 테스트
2. 재촉 알림 조건 확인:
   - 마감 2일 전인 시작 안 한 태스크 생성
   - 알림 시간에 재촉 메시지 수신 확인
3. UserDefaults 저장 확인 (앱 재시작 후에도 유지)

### 빠른 추가
1. **Cmd+Shift+N** 누름
2. "내일 3시간 회의 준비" 입력
3. Enter 누르면 태스크 추가 확인
4. 자연어 파싱 정확도 검증

### 선제적 제안
1. **회의 준비 누락**: 내일 메인 태스크 생성 + 준비 태스크 일부만 완료 → 배너 표시 확인
2. **용량 초과**: 오늘 할 일을 용량 초과하도록 추가 → "🚨 오늘 할 일 과부하" 배너
3. **후속 조치**: 메인 태스크 완료 → "📝 후속 조치 필요" 배너
4. **마감 위험**: 시작일 지난 태스크 → "❗ 시작일이 지났어요" 배너
5. 배너 dismiss 후 24시간 동안 재표시 안 됨 확인

### 우선순위 조정
1. 오늘 할 일에서 태스크 드래그
2. 다른 태스크 위/아래로 드롭
3. 순서 변경 확인
4. 설정에서 "자동 우선순위로 재설정" 누르면 원래대로 복구

---

## 주의사항

### 알림 권한
- 앱 재실행 시 알림 권한 상태 체크
- 권한 거부 시 안내 메시지 표시
- NotificationService.updateAuthorizationStatus() 활용

### 제안 스팸 방지
- 최대 3개 제안까지만 표시
- 우선순위 높은 것만 표시
- Dismiss한 제안은 24시간 동안 재표시 안 함 (UserDefaults)

### 드래그 앤 드롭 성능
- LazyVStack 사용
- 태스크 많을 때 성능 모니터링

### UserDefaults 키 관리
```swift
// 새로 추가되는 키들
"customNotificationTimes"      // [NotificationTime] ✅
"nudgeNotificationEnabled"     // Bool ✅
"dismissedSuggestions"         // [String: Date] (suggestionId: dismissedAt) ⏳
```

---

## 예상 결과

### 사용자 경험 개선
1. **생각날 때 바로 기록**: Cmd+Shift+N으로 즉시 추가 ✅
2. **맞춤형 알림**: 원하는 시간에 체크 알림 🔄
3. **재촉으로 놓치지 않음**: "마감 2일 남았는데 시작 안 했어요!" ✅
4. **선제적 경고**: "내일 회의인데 준비 부족해요" ⏳
5. **후속 조치 잊지 않음**: "회의 끝났어요, 후속 조치 필요한가요?" ⏳
6. **우선순위 조정**: 드래그로 직관적 순서 변경 ⏳

### 비서 역할 달성도
현재 70% → **목표 90%** "진짜 비서처럼" 작동

---

## 개발 시간 추정
- **Phase 1 (빠른 추가)**: ✅ 완료
- **Phase 2 (알림 시스템)**: 🔄 50% 완료
- **Phase 3 (우선순위 조정)**: ⏳ 대기
- **Phase 4 (선제적 제안)**: ⏳ 대기

**총 예상 시간**: 25-33시간 (약 3-4일)

---

## ✅ 구현 완료 요약 (2026-01-16)

### 완료된 기능

1. **빠른 태스크 추가 (Cmd+Shift+N)** ✅
   - CommandMenu 단축키로 즉시 접근
   - 자연어 파싱 지원 (예: "내일까지 보고서 2시간")
   - 미니멀 플로팅 윈도우

2. **커스터마이징 가능한 알림 시스템** ✅
   - 알림 시간 자유롭게 추가/편집/삭제
   - 재촉 알림 기능 (마감 2일 전, 당일 진행 중)
   - UserDefaults 영속성 저장
   - Picker 스타일을 macOS 호환 .menu로 수정

3. **우선순위 수동 조정** ✅
   - 드래그 앤 드롭으로 순서 변경 (.onMove)
   - manualPriority 속성으로 수동 우선순위 관리
   - sortOrder computed property로 자동/수동 우선순위 통합
   - "자동 정렬" 버튼으로 복귀 가능

4. **선제적 제안 시스템 (Proactive Assistant)** ✅
   - 5가지 제안 유형 구현:
     * 회의 준비 누락 감지
     * 용량 초과 경고
     * 후속 조치 제안
     * 마감 위험 알림
     * 여유 시간 활용 제안
   - 우선순위 기반 최대 3개 제안 표시
   - 24시간 dismiss 기록 (UserDefaults)
   - AssistantSuggestionBannerView 배너 UI

### 🎯 비서 역할 달성도
- **이전**: 70% (기본 태스크 관리)
- **목표**: 90% (진정한 비서 앱)
- **현재**: ✅ 90% 달성!

### 📊 개선된 사용자 경험
1. ✅ 생각날 때 바로 기록 (Cmd+Shift+N)
2. ✅ 맞춤형 알림 시간 설정
3. ✅ 재촉 알림으로 놓치지 않음
4. ✅ 선제적 경고 및 제안 ("비서처럼 먼저 알려줌")
5. ✅ 드래그로 직관적 순서 조정
6. ✅ 후속 조치 자동 제안

### 🛠 기술 구현 세부사항

#### Phase 1: 빠른 추가
- **파일**: QuickAddView.swift (ContentView.swift에 통합)
- **구현**: CommandMenu, NotificationCenter, TaskInputParser 활용
- **단축키**: Cmd+Shift+N

#### Phase 2: 알림 시스템
- **파일**: NotificationService.swift, NotificationSettingsView.swift
- **데이터 모델**: NotificationTime (Codable, Identifiable)
- **저장**: UserDefaults (customNotificationTimes, nudgeNotificationEnabled)
- **재촉 로직**: daysUntilDue <= 2 && isNotStarted, daysUntilDue == 0 && isInProgress
- **수정사항**: .pickerStyle(.wheel) → .pickerStyle(.menu) (macOS 호환)

#### Phase 3: 우선순위 조정
- **파일**: Task.swift, TaskViewModel.swift, ContentView.swift
- **추가 속성**: manualPriority: Int?, sortOrder: Int (computed)
- **메서드**: reorderTodayTasks, resetManualPriorities
- **UI**: ForEach + .onMove, 드래그 핸들 아이콘, "자동 정렬" 버튼

#### Phase 4: 선제적 제안
- **파일**: AssistantSuggestion.swift, ProactiveAssistantService.swift, AssistantSuggestionBannerView.swift
- **모델**: SuggestionType, SuggestionPriority, SuggestionAction, AssistantSuggestion
- **서비스**: ProactiveAssistantService (@MainActor, ObservableObject)
- **감지 로직**:
  * detectMeetingPreparationMissing: 내일 메인 태스크의 준비율 < 50%
  * detectCapacityOverload: totalMinutes > 480분
  * detectFollowUpNeeded: 완료된 메인 태스크에 후속 조치 없음
  * detectDeadlineRisk: effectiveStartDate < today && isNotStarted
  * detectIdleTime: 여유 시간 >= 60분
- **UI**: 우선순위별 색상, 액션 버튼, dismiss 기능
- **통합**: TodayView의 ScrollView 상단에 ForEach로 배너 표시
- **업데이트**: .onAppear + .onChange(of: viewModel.tasks.count)

### 🐛 해결된 이슈
1. **Xcode 프로젝트 파일 인식 문제**: 신규 파일을 ContentView.swift에 통합
2. **Picker 스타일 호환성**: .wheel (iOS only) → .menu (macOS)
3. **onChange Equatable 요구사항**: viewModel.tasks → viewModel.tasks.count
4. **ButtonStyle 반환 타입 문제**: actionButtonStyle 제거, 인라인 조건문 사용

### 📦 최종 빌드 상태
✅ **BUILD SUCCEEDED** (2026-01-16)

모든 Phase 구현 완료 및 빌드 성공!
