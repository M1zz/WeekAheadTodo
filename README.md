# WeekAhead Todo

**일주일 앞을 내다보는 전략적 할 일 관리 앱**

기존 Todo 앱의 한계를 넘어, 미래 일정에서 역산해 오늘 해야 할 일을 자동으로 도출하고, 하루의 시간 용량을 관리하는 새로운 접근법을 구현했습니다.

---

## 핵심 메커니즘

### 1. 선행 작업 역산 로직 (Backward Planning)

```
[발표 D-day: 12월 20일]
        ↑
[슬라이드 완성: D-2]  ← leadTimeDays = 2
        ↑
[초안 작성: D-4]      ← leadTimeDays = 4
        ↑
[자료 수집: D-6]      ← leadTimeDays = 6 → 오늘이 14일이면 "오늘 할 일"에 표시
```

**작동 원리:**
- 각 태스크에 `leadTimeDays` (선행 소요 일수) 설정
- `effectiveStartDate = dueDate - leadTimeDays`로 실제 시작일 계산
- 시작일 기준으로 시간 지평선 자동 분류 (오늘/이번 주/다음 주/나중에)

**코드 위치:** `Models/Task.swift` - `effectiveStartDate`, `currentHorizon` 프로퍼티

### 2. 시간 블록 관리 (Time Capacity)

```
오늘 가용 시간: 6시간 (360분)
────────────────────────────────────────
[회의 준비 2h][코드 리뷰 1.5h][이메일 0.5h] = 4h
────────────────────────────────────────
남은 용량: 2h → "미리 할 수 있는 일" 추천
```

**작동 원리:**
- 하루 가용 시간을 분 단위로 관리
- 태스크 배정 시 용량 체크
- 초과 시 재배치 제안 (긴급도 낮은 것부터)

**코드 위치:** `Models/TimeBlock.swift` - `DayTimeBlock`, `WeeklyTimeBlockManager`

---

## 주요 기능

| 기능 | 설명 |
|------|------|
| **역산 기반 할 일 표시** | 마감일이 아닌 "시작해야 할 날" 기준으로 분류 |
| **시간 블록 용량 관리** | 하루 가용 시간 대비 사용량 시각화 |
| **미리 가능한 일 추천** | 여유 시간에 다음 주 일을 미리 처리 제안 |
| **용량 초과 시 재배치** | 오버된 태스크를 다른 날로 밀어내기 제안 |
| **주간 워크로드 차트** | 2주간 일별 부하를 한눈에 확인 |
| **템플릿 지원** | 회의 준비, 발표 준비 등 반복 패턴 자동 생성 |

---

## 태스크 유형

### Preparable (미리 가능)
- 회의 아젠다 정리, 자료 준비, 보고서 초안 등
- 시간 여유가 있을 때 미리 처리 가능
- 용량 초과 시 다른 날로 재배치 가능

### Date-Specific (당일만 가능)
- 실제 회의 참석, 발표 진행, 면접 등
- 해당 날짜에만 수행 가능
- 재배치 불가

---

## 프로젝트 구조

```
WeekAheadTodo/
├── WeekAheadTodo.xcodeproj/
├── WeekAheadTodo/
│   ├── WeekAheadTodoApp.swift      # 앱 엔트리포인트
│   ├── ContentView.swift           # 메인 UI (사이드바 + 뷰들)
│   ├── Models/
│   │   ├── Task.swift              # 태스크 모델 + 역산 로직
│   │   └── TimeBlock.swift         # 시간 블록 모델
│   ├── ViewModels/
│   │   └── TaskViewModel.swift     # 비즈니스 로직
│   └── Assets.xcassets/
└── README.md
```

---

## 빌드 방법

1. Xcode 15.0 이상 필요
2. `WeekAheadTodo.xcodeproj` 열기
3. macOS 14.0+ 타겟으로 빌드
4. ⌘+R 실행

---

## 다음 단계 (프로토타입 확장 아이디어)

- [ ] 캘린더 앱 연동 (EventKit)
- [ ] 데이터 영속성 (SwiftData/CoreData)
- [ ] 알림 기능 (UserNotifications)
- [ ] 위젯 지원
- [ ] 반복 태스크
- [ ] 드래그 앤 드롭으로 날짜 이동

---

## 라이선스

프로토타입 - 자유롭게 수정 및 확장 가능
