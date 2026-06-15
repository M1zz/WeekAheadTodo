# WeekAheadTodo 작업 목록

## ✅ 완료된 작업

### AI 통합 기능 (2026-02-05)
- [x] URL Schemes 구현 (URLHandler.swift) - 파일 생성됨, Xcode 프로젝트 추가 필요
- [x] 홈 화면 위젯 구현 (TodayWidget.swift) - 파일 생성됨, Widget Extension 생성 필요
- [x] 고급 자연어 처리 구현 (AdvancedTaskParser.swift) - 파일 생성됨, Xcode 프로젝트 추가 필요
- [x] URLHandler 호출 임시 주석 처리 (빌드 에러 방지)

### iCloud 동기화 (2026-02-05)
- [x] 앱 시작 시 자동 동기화 (최신 데이터 비교)
- [x] CloudKit 쿼리 버그 수정 (desiredKeys 22개 필드 명시)

### 캘린더 통합 (2026-02-05)
- [x] 특정 캘린더 전체 가져오기 기능

### 메일 통합 (2026-02-05)
- [x] Mail.app 연동 (AppleScript)
- [x] 일정 감지 및 태스크 변환

## 🔧 수동 설정 필요 (Xcode)

### 🚨 중요: 현재 빌드 불가 상태
다음 작업을 완료해야 앱이 정상 빌드됩니다:

### 1. 새 파일을 Xcode 프로젝트에 추가 ⚠️ **필수**
다음 3개 파일이 파일 시스템에는 존재하지만 Xcode 프로젝트에 추가되지 않았습니다:

**방법 1: Xcode에서 직접 추가 (권장)**
1. Xcode에서 프로젝트 열기
2. 프로젝트 네비게이터에서 `Services` 폴더 우클릭
3. "Add Files to WeekAheadTodo..." 선택
4. 다음 파일들 선택:
   - `WeekAheadTodo/Services/AdvancedTaskParser.swift`
   - `WeekAheadTodo/Services/URLHandler.swift`
5. "Copy items if needed" 체크 해제 (이미 올바른 위치에 있음)
6. "Add to targets" → WeekAheadTodo 체크
7. Add 버튼 클릭

**방법 2: 프로젝트 파일 직접 수정 (고급)**
- `WeekAheadTodo.xcodeproj/project.pbxproj` 파일에 수동으로 파일 참조 추가
- ⚠️ 백업 후 시도 권장

**파일 목록:**
- [ ] **AdvancedTaskParser.swift** - 경로: `WeekAheadTodo/Services/AdvancedTaskParser.swift`
- [ ] **URLHandler.swift** - 경로: `WeekAheadTodo/Services/URLHandler.swift`
- [ ] **TodayWidget.swift** - 경로: `WeekAheadTodoWidget/TodayWidget.swift` (Widget Extension 생성 후)

### 2. URL Schemes 설정
- [ ] Xcode에서 프로젝트 선택 → Targets → WeekAheadTodo → Info
- [ ] URL Types 섹션에 추가:
  - **Identifier**: `com.weekaheadtodo.urlscheme`
  - **URL Schemes**: `weekaheadtodo`
- [ ] 테스트: 터미널에서 `open "weekaheadtodo://addTask?title=테스트"`

### 3. Widget Extension 생성
- [ ] File → New → Target → Widget Extension
- [ ] Product Name: `WeekAheadTodoWidget`
- [ ] Include Configuration Intent: No (체크 해제)
- [ ] TodayWidget.swift 파일을 위젯 타겟에 추가
- [ ] App Groups 설정:
  1. Main App 타겟 → Signing & Capabilities → + Capability → App Groups
  2. App Group ID 생성: `group.com.weekaheadtodo.shared`
  3. Widget 타겟에도 동일한 App Group 추가
- [ ] UserDefaults를 App Group suite로 변경:
  ```swift
  let sharedDefaults = UserDefaults(suiteName: "group.com.weekaheadtodo.shared")
  ```

### 4. ContentView에서 URLHandler 주석 해제
URLHandler.swift가 프로젝트에 추가된 후:

- [ ] `ContentView.swift` 파일 열기 (142-144번 줄 근처)
- [ ] 다음 주석 해제:
  ```swift
  .onOpenURL { url in
      _ = URLHandler.handle(url: url, taskViewModel: viewModel)
  }
  ```

### 5. AdvancedTaskParser 통합
AdvancedTaskParser.swift가 프로젝트에 추가된 후:

- [ ] `TaskInputParser.swift` 파일 열기
- [ ] `parse()` 메서드의 return 직전에 추가:
  ```swift
  // 고급 파싱으로 강화 (시간대, 복잡한 날짜, 컨텍스트 기반 예상 시간)
  result = AdvancedTaskParser.enhanceParsedInfo(result, from: input)
  ```

### 6. 빌드 및 테스트
- [ ] Xcode에서 Clean Build Folder (⌘⇧K)
- [ ] 빌드 테스트 (⌘B)
- [ ] URL Schemes 테스트: 터미널에서 `open "weekaheadtodo://addTask?title=테스트"`
- [ ] 고급 자연어 파싱 테스트:
  - "내일 오후 2시 회의" → 내일 14:00, 60분
  - "다다음주 보고서 작성" → 2주 후, 120분
  - "이번달말까지 프로젝트 #긴급" → 이번 달 마지막 날

## ✅ iOS/macOS 코드 공유 구조 리팩토링 (2026-02-21)
- [x] `Packages/WeekAheadShared/` 로컬 Swift Package 생성 (swift-tools-version: 6.0)
- [x] `Task`, `Subtask`, `Project`, `TaskTemplate`, 6개 enum을 패키지로 이전 (public 선언)
- [x] `project.pbxproj` 수정: XCLocalSwiftPackageReference, XCSwiftPackageProductDependency 추가
- [x] WeekAheadTodo(macOS) 타깃에 WeekAheadShared 패키지 연결
- [x] TodoAlarm(iOS) 타깃에 WeekAheadShared 패키지 연결
- [x] `WeekAheadTodo/Models/Task.swift` 삭제 (패키지로 이전)
- [x] `TodoAlarm/Models/Task.swift` 삭제 (패키지로 이전)
- [x] 57개 파일에 `import WeekAheadShared` 추가
- [x] macOS 빌드 성공 확인
- [x] iOS(TodoAlarm) 파일 컴파일 에러 없음 확인
  - ⚠️ widgetExtension 타깃의 Recovered References 에러는 기존 문제 (CalendarService.swift 등이 프로젝트 루트에 없음)

## ✅ 보고 습관 장치 추가 (2026-03-19)
- [x] `ReportingHabitsView.swift` 생성 — 사이드바 "성장 > 보고 습관" 섹션
  - 7가지 오늘의 실천 체크리스트 (매일 자정 자동 초기화)
  - 4종 보고 템플릿 복사 (착수 보고, 중간 보고, 완료 보고, 이슈 PSAR 보고)
  - PSAR 문제 메모 입력 + 보고문 즉시 복사
- [x] `NotificationService.swift` — 보고 습관 알림 3종 추가
  - `scheduleStartReportReminder()` — 착수 보고 1시간 리마인더
  - `scheduleEightyPercentReminder()` — 80% 완료 시점 공유 알림
  - `scheduleWeeklyRoutineReminders()` — 주간 루틴 (월/수/금) 알림
- [x] `AddTaskView.swift` — 보고 습관 알림 섹션 추가 (착수 보고 + 80% 공유 토글)
- [x] `SettingsView.swift` — 주간 루틴 보고 알림 설정 섹션 추가
- [x] `ContentView.swift` — SidebarSection에 `reportingHabits` 추가, "성장" 섹션으로 표시

## ✅ 패턴 즉시 반영 + 완료 항목 정렬 (2026-06-15)
- [x] 패턴 추가/수정/활성화 직후 앱 재시작 없이 태스크 즉시 생성
  - `Notification.Name.approvedPatternsDidChange` 추가 (WeekAheadTodoApp.swift)
  - AddApprovedPatternView, EditApprovedPatternView, ApprovedPatternManagementView(toggleActive/setNextOccurrence)에서 변경 시 알림 발송
  - ContentView가 알림 수신 시 `generateTasksIfNeeded()` 호출
- [x] 완료된 항목 기본적으로 맨 아래로 정렬 (오늘/이번주/다음주/언젠가 목록)
  - TaskViewModel의 todayTasks/thisWeekTasks/nextWeekTasks/somedayTasks 정렬에 "미완료 우선" 1차 기준 추가
- [x] macOS 빌드 성공 확인

## 📋 향후 개선 사항

- [ ] 자동 iCloud 동기화 (현재는 앱 시작 시에만)
- [ ] 단축어 앱 통합 (App Intents - 현재 WIP)
- [ ] 태스크 태그 시스템
- [ ] 유닛 테스트 추가
