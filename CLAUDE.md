# WeekAheadTodo 프로젝트 컨텍스트

## 프로젝트 개요
- **프로젝트명**: WeekAheadTodo
- **설명**: 캘린더 통합 기반 지능형 할 일 관리 macOS 앱
- **언어**: Swift, SwiftUI
- **최소 지원**: macOS 14.0+
- **아키텍처**: MVVM + SwiftData + EventKit
- **주요 특징**:
  - 선행 작업 역산 기능 (Lead Time Days)
  - 캘린더 패턴 자동 감지 및 태스크 생성
  - 워크로드 시각화 (2주간 일정 용량 분석)
  - iCloud 동기화

## 기술 스택
### 프레임워크
- **SwiftUI**: 모든 UI 구성
- **SwiftData**: 승인된 패턴(ApprovedPattern) 영구 저장
- **EventKit**: 캘린더 일정 읽기 (Full Access 권한 사용, 읽기 전용)
- **CloudKit**: 태스크 데이터 iCloud 백업/복원
- **UserNotifications**: 할 일 알림

### 데이터 저장
- **태스크**: UserDefaults (JSON 인코딩) + CloudKit 백업
- **승인된 패턴**: SwiftData (ModelContainer)
- **설정**: @AppStorage (UserDefaults)

## 아키텍처 패턴

### MVVM 구조
```
View (ContentView, ImportView 등)
  ↓ @EnvironmentObject
ViewModel (TaskViewModel, CalendarViewModel)
  ↓
Service (CalendarService, PatternDetectionService, NotificationService)
  ↓
Model (Task, RecurrencePattern, ApprovedPattern)
```

### 주요 ViewModel
- **TaskViewModel**: 태스크 CRUD, iCloud 동기화, 워크로드 계산
- **CalendarViewModel**: 캘린더 권한, 이벤트 가져오기, 선택된 캘린더 관리

### 주요 Service
- **CalendarService**: EventKit 캘린더 접근, 이벤트 읽기, 시간 계산
- **PatternDetectionService**: 반복 패턴 감지 (주간, 격주, 월간 등)
- **PatternManagementService**: 승인된 패턴으로부터 자동 태스크 생성
- **NotificationService**: 로컬 알림 스케줄링
- **TaskInputParser**: 자연어 입력 파싱 ("내일 3시간 회의 준비")
- **MarkdownParser**: 마크다운 체크리스트 임포트

## 핵심 데이터 모델

### Task
```swift
struct Task: Identifiable, Codable {
    let id: UUID
    var title: String
    var dueDate: Date                    // 최종 마감일
    var estimatedMinutes: Int            // 예상 소요 시간 (분)
    var leadTimeDays: Int                // 선행 소요 일수 (역산용)
    var taskType: TaskType               // preparable(미리 가능), dateSpecific(당일만 가능)
    var taskRole: TaskRole               // 메인, 준비, 루틴, 후속, 검토, 학습, 아이디어
    var status: TaskStatus               // notStarted, inProgress, completed
    var priority: TaskPriority           // low, normal, high, urgent

    // 캘린더 연동
    var calendarEventId: String?
    var isFromCalendarPattern: Bool
    var patternId: UUID?
    var autoRecurring: Bool
}
```

### ApprovedPattern (SwiftData)
```swift
@Model
class ApprovedPattern {
    var id: UUID
    var title: String
    var pattern: RecurrencePattern
    var estimatedMinutes: Int
    var leadTimeDays: Int
    var taskType: TaskType
    var createdAt: Date
}
```

### RecurrencePattern
- **주간 패턴**: 매주 특정 요일 (예: 매주 월요일)
- **격주 패턴**: 2주마다 특정 요일
- **월간 패턴**: 매월 특정 날짜 또는 N번째 요일
- **일간 패턴**: 매일 반복

## 코딩 컨벤션

### 1. UI 텍스트
- **모든 UI 텍스트는 한글 사용**
- enum rawValue도 한글: `case main = "메인"`, `case today = "오늘"`
- 주석은 한글/영어 혼용 가능

### 2. 폰트 시스템
- **최소 폰트 크기**: `.callout` (절대 `.caption`, `.caption2` 사용 금지)
- **6단계 폰트 레벨**: 1~6, 각 단계마다 2pt 증가
- **기본 레벨**: 1
- 기본 크기 정의:
  ```swift
  .title: 28pt
  .title2: 22pt
  .title3: 20pt
  .headline: 17pt
  .body: 17pt
  .callout: 16pt
  ```

### 3. 문서화
- public/internal 함수는 `///` 문서화 주석 권장
- 복잡한 로직은 한글 주석으로 설명
- 예시:
  ```swift
  /// 특정 날짜의 캘린더 이벤트 총 시간 계산 (분 단위)
  /// - Parameters:
  ///   - date: 계산할 날짜
  ///   - calendarIdentifiers: 포함할 캘린더 ID 목록
  /// - Returns: 해당 날짜의 이벤트 총 시간 (분)
  func calculateEventDuration(for date: Date, calendarIdentifiers: Set<String>) -> Int
  ```

### 4. 코드 구조
- View는 가능한 500줄 이하로 유지 (현재 ContentView는 5000줄+ 예외)
- `// MARK: -` 섹션 구분 적극 활용
- 복잡한 View는 별도 파일로 분리 (ImportView, PatternReviewView 등)

### 5. 에러 핸들링
- async 함수는 `throws` 선언
- do-catch 블록에서 에러 로깅: `print("❌ [Service] 에러 메시지: \(error)")`
- 이모지 로깅 컨벤션:
  - ✅ 성공
  - ❌ 실패/에러
  - ⚠️ 경고
  - 📊 통계/결과
  - 🔍 검색/분석
  - ℹ️ 정보

## 주요 기능

### 1. 선행 작업 역산 (Lead Time Days)
- `leadTimeDays`: 마감일로부터 며칠 전에 시작해야 하는지
- `effectiveStartDate`: 실제 시작 날짜 = dueDate - leadTimeDays
- `currentHorizon`: 오늘, 이번 주, 다음 주, 나중에

### 2. 캘린더 패턴 감지
1. 최근 3개월 캘린더 이벤트 가져오기
2. 반복 패턴 자동 감지 (PatternDetectionService)
3. 사용자 승인 후 ApprovedPattern으로 저장
4. 다음 발생 예정일에 자동으로 Task 생성

### 3. 워크로드 계산
- 2주간 일별 워크로드 계산
- 캘린더 일정 시간 + 태스크 예상 시간
- 용량 초과 시 빨간색 경고
- 바 차트 + 일별 상세 뷰

### 4. iCloud 동기화
- CloudKit Public Database 사용
- Record Type: "TaskItem"
- 수동 백업/복원 (자동 동기화 아님)
- `desiredKeys: ["title"]` 필수 (빈 배열 시 "recordName is not marked queryable" 에러)

### 5. 자연어 태스크 입력
- "내일 3시간 회의 준비" → dueDate: 내일, estimatedMinutes: 180, title: "회의 준비"
- "다음주 금요일까지 보고서" → dueDate: 다음주 금요일, title: "보고서"
- "2시간" / "30분" → estimatedMinutes 자동 파싱

### 6. 마크다운 임포트
- GitHub-style 체크리스트 지원
- `- [ ] 할 일` → Task 생성
- 날짜, 시간, 우선순위 자동 파싱

## 파일 구조

```
WeekAheadTodo/
├── WeekAheadTodoApp.swift          # 앱 진입점, ModelContainer 설정
├── ContentView.swift                # 메인 UI (5000+ 줄, 모든 View 포함)
├── Models/
│   ├── Task.swift                   # 태스크 모델, TimeHorizon, TaskType, TaskRole, TaskStatus, TaskPriority
│   ├── ApprovedPattern.swift        # SwiftData 모델
│   ├── RecurrencePattern.swift      # 반복 패턴 enum
│   ├── CalendarEvent.swift          # EKEvent 래퍼
│   └── TimeBlock.swift              # 시간 블록
├── ViewModels/
│   ├── TaskViewModel.swift          # 태스크 관리, iCloud 동기화
│   └── CalendarViewModel.swift      # 캘린더 권한, 이벤트 관리
├── Services/
│   ├── CalendarService.swift        # EventKit 캘린더 접근
│   ├── PatternDetectionService.swift # 패턴 감지 알고리즘
│   ├── PatternManagementService.swift # 승인된 패턴 → 태스크 자동 생성
│   ├── NotificationService.swift     # 로컬 알림
│   ├── TaskInputParser.swift        # 자연어 파싱
│   └── MarkdownParser.swift         # 마크다운 임포트
└── Views/
    ├── ImportView.swift             # 마크다운 임포트 UI
    ├── PatternReviewView.swift      # 패턴 승인 UI
    ├── PatternDetailView.swift      # 패턴 상세 정보
    ├── ApprovedPatternManagementView.swift # 승인된 패턴 관리
    ├── EditApprovedPatternView.swift # 패턴 편집
    ├── CalendarIntegrationView.swift # 캘린더 설정
    └── NotificationPreviewView.swift # 알림 미리보기
```

## 자주 하는 실수 (Claude 학습용)

### 1. SwiftData 관련
- ❌ **잘못**: SwiftData @Query를 ViewModel에서 사용
  ```swift
  class TaskViewModel {
      @Query var patterns: [ApprovedPattern] // 컴파일 에러!
  }
  ```
- ✅ **올바름**: @Query는 View에서만 사용, ViewModel은 ModelContext 직접 사용
  ```swift
  struct PatternListView: View {
      @Query var patterns: [ApprovedPattern]
  }
  ```

### 2. EventKit 권한
- ❌ **잘못**: Write-Only Access 요청 시도
- ✅ **올바름**: 읽기를 위해서도 Full Access 필요
  ```swift
  // macOS 14.0+
  try await eventStore.requestFullAccessToEvents()
  ```

### 3. iCloud CloudKit 쿼리
- ❌ **잘못**: `desiredKeys: []` 사용
  ```swift
  database.records(matching: query, desiredKeys: []) // "recordName is not marked queryable" 에러
  ```
- ✅ **올바름**: 최소 하나 이상의 필드 지정
  ```swift
  database.records(matching: query, desiredKeys: ["title"])
  ```

### 4. Sheet에서 EnvironmentObject
- ❌ **잘못**: Sheet에 environmentObject 전달 안 함
  ```swift
  .sheet(isPresented: $showingSheet) {
      AddProjectView() // TaskViewModel 찾을 수 없음!
  }
  ```
- ✅ **올바름**: Sheet에도 명시적으로 전달
  ```swift
  .sheet(isPresented: $showingSheet) {
      AddProjectView()
          .environmentObject(viewModel)
  }
  ```

### 5. 폰트 크기
- ❌ **잘못**: `.caption`, `.caption2` 사용 (너무 작아서 가독성 나쁨)
- ✅ **올바름**: 최소 `.callout` 사용
  ```swift
  Text("설명").font(.callout) // ✅
  Text("설명").font(.caption)  // ❌
  ```

### 6. TaskRole enum exhaustive switch
- ❌ **잘못**: 새 case 추가 후 switch 업데이트 안 함
- ✅ **올바름**: TaskRole에 case 추가 시, 모든 switch문 업데이트 필요
  ```swift
  // TaskRole에 .routine 추가 시
  switch task.taskRole {
  case .main: return .blue
  case .preparation: return .orange
  case .routine: return .purple  // 추가 필수!
  // ... 나머지 case들
  }
  ```

## 중요 규칙

### 1. 파일 수정 전 반드시 Read
- 기존 파일 수정 시 반드시 Read tool로 먼저 읽기
- 추측으로 코드 작성 금지

### 2. UI 텍스트는 무조건 한글
- enum rawValue, 버튼 라벨, placeholder 등 모두 한글
- 예외: 코드 내부 변수명은 영어

### 3. 폰트는 최소 .callout
- 절대 `.caption`, `.caption2` 사용 금지
- 작은 텍스트도 `.callout` 사용

### 4. 이모지 로깅 일관성
- print 문에 이모지로 로그 레벨 표시
- 성공(✅), 에러(❌), 경고(⚠️), 정보(ℹ️), 검색(🔍), 통계(📊)

### 5. @MainActor 사용
- CalendarService, NotificationService는 @MainActor
- UI 업데이트하는 ViewModel 메서드도 @MainActor

### 6. 캘린더 읽기는 읽기 전용
- CalendarService는 Full Access 권한을 가지지만 **절대 일정 수정/삭제 안 함**
- 읽기 전용으로만 사용

## 테스트 가이드

### 현재 테스트 상태
- 유닛 테스트 없음 (추후 추가 예정)

### 추천 테스트 영역
1. **TaskInputParser**: 자연어 파싱 정확도
2. **PatternDetectionService**: 패턴 감지 알고리즘
3. **Task 모델**: effectiveStartDate, currentHorizon 계산
4. **MarkdownParser**: 마크다운 파싱

### 테스트 네이밍 컨벤션
```swift
func test_TaskInputParser_내일3시간입력_내일날짜와180분반환()
func test_PatternDetection_매주월요일이벤트_주간패턴감지()
```

## 빌드 및 실행

### 요구사항
- Xcode 15.0+
- macOS 14.0+
- Swift 5.9+

### 권한 설정
- Info.plist에 캘린더 권한 설명 필요:
  - `NSCalendarsFullAccessUsageDescription`
- 알림 권한:
  - `NSUserNotificationsUsageDescription`

### 빌드 명령어
```bash
xcodebuild -scheme WeekAheadTodo -configuration Debug -destination 'platform=macOS' build
```

## 디버깅 팁

### 1. SwiftData 초기화 실패
- 문제: "Model container creation failed"
- 해결: `WeekAheadTodoApp.deleteSwiftDataStore()` 실행
- 위치: Application Support/default.store 삭제

### 2. 캘린더 이벤트 안 보임
- 문제: `fetchEvents()` 빈 배열 반환
- 체크리스트:
  1. 권한 승인되었는지 확인
  2. 선택된 캘린더 있는지 확인
  3. 해당 기간에 실제 일정 있는지 확인
  4. 로그 확인: `[CalendarService.fetchEvents]`

### 3. iCloud 동기화 실패
- "recordName is not marked queryable": `desiredKeys` 빈 배열
- "CloudKit database not available": iCloud 로그인 확인
- Rate limit: CloudKit 요청 제한 (너무 빠른 요청)

## 버전 히스토리

### v1.0.0 (현재)
- 기본 태스크 CRUD
- 캘린더 통합 및 패턴 감지
- 워크로드 시각화
- iCloud 백업/복원
- 마크다운 임포트
- 자연어 태스크 입력
- 6단계 폰트 시스템
- 탭 순서 커스터마이징

## 향후 계획
- [ ] 유닛 테스트 추가
- [ ] 자동 iCloud 동기화 (현재는 수동)
- [ ] 위젯 지원
- [ ] 단축어 앱 통합
- [ ] 태스크 태그 시스템
- [ ] 프로젝트별 필터링 강화
