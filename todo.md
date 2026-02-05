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

## 📋 향후 개선 사항

- [ ] 자동 iCloud 동기화 (현재는 앱 시작 시에만)
- [ ] 단축어 앱 통합 (App Intents - 현재 WIP)
- [ ] 태스크 태그 시스템
- [ ] 유닛 테스트 추가
