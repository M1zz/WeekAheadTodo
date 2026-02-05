# WeekAheadTodo 작업 목록

## ✅ 완료된 작업

### AI 통합 기능 (2026-02-05)
- [x] URL Schemes 구현 (URLHandler.swift)
- [x] 홈 화면 위젯 구현 (TodayWidget.swift)
- [x] 고급 자연어 처리 구현 (AdvancedTaskParser.swift)

### iCloud 동기화 (2026-02-05)
- [x] 앱 시작 시 자동 동기화 (최신 데이터 비교)
- [x] CloudKit 쿼리 버그 수정 (desiredKeys 22개 필드 명시)

### 캘린더 통합 (2026-02-05)
- [x] 특정 캘린더 전체 가져오기 기능

### 메일 통합 (2026-02-05)
- [x] Mail.app 연동 (AppleScript)
- [x] 일정 감지 및 태스크 변환

## 🔧 수동 설정 필요 (Xcode)

### 1. 새 파일을 Xcode 프로젝트에 추가
다음 3개 파일이 파일 시스템에는 존재하지만 Xcode 프로젝트에 추가되지 않았습니다:

- [ ] **AdvancedTaskParser.swift** → WeekAheadTodo 타겟에 추가
  - 경로: `WeekAheadTodo/Services/AdvancedTaskParser.swift`
  - Xcode에서: 프로젝트 네비게이터에서 Services 폴더 우클릭 → Add Files to "WeekAheadTodo" → 해당 파일 선택

- [ ] **URLHandler.swift** → WeekAheadTodo 타겟에 추가
  - 경로: `WeekAheadTodo/Services/URLHandler.swift`

- [ ] **TodayWidget.swift** → WeekAheadTodoWidget 타겟에 추가 (Widget Extension 생성 후)
  - 경로: `WeekAheadTodoWidget/TodayWidget.swift`

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

### 4. AdvancedTaskParser 통합
AdvancedTaskParser.swift가 프로젝트에 추가된 후:

- [ ] `TaskInputParser.swift` 파일 열기
- [ ] `parse()` 메서드의 return 직전에 추가:
  ```swift
  // 고급 파싱으로 강화 (시간대, 복잡한 날짜, 컨텍스트 기반 예상 시간)
  result = AdvancedTaskParser.enhanceParsedInfo(result, from: input)
  ```
- [ ] 빌드 테스트: ⌘B
- [ ] 기능 테스트:
  - "내일 오후 2시 회의" → 내일 14:00, 60분
  - "다다음주 보고서 작성" → 2주 후, 120분
  - "이번달말까지 프로젝트 #긴급" → 이번 달 마지막 날

## 📋 향후 개선 사항

- [ ] 자동 iCloud 동기화 (현재는 앱 시작 시에만)
- [ ] 단축어 앱 통합 (App Intents - 현재 WIP)
- [ ] 태스크 태그 시스템
- [ ] 유닛 테스트 추가
