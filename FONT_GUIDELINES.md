# WeekAheadTodo 폰트 크기 가이드라인

## 폰트 크기 원칙

**핵심 규칙: `.body` (17pt)보다 작은 폰트를 사용하지 않는다.**

가독성과 접근성을 위해 최소 폰트 크기를 17pt로 유지합니다.

---

## SwiftUI 기본 폰트 크기 참고

| 폰트 스타일 | 크기 | 사용 가능 여부 |
|------------|------|--------------|
| `.largeTitle` | 34pt | ✅ 사용 가능 |
| `.title` | 28pt | ✅ 사용 가능 |
| `.title2` | 22pt | ✅ 사용 가능 |
| `.title3` | 20pt | ✅ 사용 가능 |
| `.headline` | 17pt (bold) | ✅ 사용 가능 |
| **`.body`** | **17pt** | **✅ 최소 크기** |
| `.callout` | 16pt | ❌ 사용 금지 |
| `.subheadline` | 15pt | ❌ 사용 금지 |
| `.footnote` | 13pt | ❌ 사용 금지 |
| `.caption` | 12pt | ❌ 사용 금지 |
| `.caption2` | 11pt | ❌ 사용 금지 |

---

## 프로젝트 폰트 크기 체계

### 1. 대형 폰트 (40pt 이상)
**용도**: 엠티 스테이트, 큰 아이콘, 특별한 강조

```swift
.font(.system(size: 64))  // 엠티 스테이트 아이콘
.font(.system(size: 52))  // 엠티 스테이트 이모지
.font(.system(size: 40))  // 미리보기 큰 텍스트
```

### 2. 타이틀 폰트 (20pt ~ 28pt)
**용도**: 섹션 제목, 페이지 헤더

```swift
.font(.system(size: 28, weight: .bold))    // 메인 타이틀
.font(.system(size: 24, weight: .semibold)) // 캘린더 헤더
.font(.system(size: 20))                    // 서브 타이틀
```

### 3. 본문 폰트 (17pt ~ 19pt)
**용도**: 일반 텍스트, 태스크 제목, 설명

```swift
.font(.body)                              // 기본 텍스트 (17pt)
.font(.system(size: 18))                  // 강조 본문
.font(.system(size: 17))                  // 본문
```

### 4. 보조 텍스트 (17pt)
**용도**: 메타 정보, 라벨 - ⚠️ 17pt 미만 사용 금지

```swift
.font(.body)                              // 라벨, 보조 텍스트
.font(.system(size: 17))                  // 시간, 날짜, 상태
```

---

## 과거 사용했던 작은 폰트 (사용 금지)

### ❌ 제거된 폰트 크기

| 이전 크기 | 새 크기 | 변경 이유 |
|----------|---------|----------|
| `.caption2` (11pt) | `.body` (17pt) | 가독성 개선 |
| `.caption` (12pt) | `.body` (17pt) | 가독성 개선 |
| `.footnote` (13pt) | `.body` (17pt) | 가독성 개선 |
| `.system(size: 13)` | `.system(size: 17)` | 최소 크기 준수 |
| `.system(size: 14)` | `.system(size: 17)` | 최소 크기 준수 |
| `.system(size: 15)` | `.system(size: 17)` | 최소 크기 준수 |
| `.system(size: 16)` | `.system(size: 17)` | 최소 크기 준수 |

---

## 컴포넌트별 폰트 사용 가이드

### 태스크 리스트
```swift
// 태스크 제목
.font(.body)                // 17pt

// 태스크 메타 정보 (시간, D-day 등)
.font(.body)                // 17pt

// 프로젝트 태그
.font(.body)                // 17pt
```

### 캘린더 뷰
```swift
// 헤더 (월/주)
.font(.system(size: 24, weight: .semibold))  // 24pt

// 요일
.font(.system(size: 18, weight: .medium))    // 18pt

// 날짜
.font(.system(size: 17))                     // 17pt

// 시간 레이블
.font(.system(size: 17))                     // 17pt
```

### 통계 및 대시보드
```swift
// 큰 숫자
.font(.system(size: 52))                     // 52pt

// 라벨
.font(.body)                                 // 17pt

// 달성률 텍스트
.font(.body)                                 // 17pt
```

### 버튼
```swift
// 주요 버튼
.font(.system(size: 17))                     // 17pt

// 작은 버튼 (탭 바, 툴바)
.font(.system(size: 17))                     // 17pt (최소 크기)
```

### 엠티 스테이트
```swift
// 아이콘/이모지
.font(.system(size: 64))                     // 64pt

// 메시지
.font(.system(size: 18))                     // 18pt

// 설명
.font(.body)                                 // 17pt
```

---

## 체크리스트: 새 화면 개발 시

- [ ] 모든 텍스트가 최소 17pt 이상인가?
- [ ] `.caption`, `.caption2`, `.footnote` 사용하지 않았는가?
- [ ] `.system(size: 16)` 이하 크기 사용하지 않았는가?
- [ ] 보조 텍스트도 `.body` (17pt) 이상인가?
- [ ] 시각적 위계는 폰트 크기가 아닌 weight, color로 표현했는가?

---

## 폰트 크기 검색 명령어

```bash
# 작은 폰트 찾기 (17pt 미만)
grep -rn "\.font(" WeekAheadTodo --include="*.swift" | grep -E "(\.caption|\.caption2|\.footnote|size: 1[0-6])"

# 특정 크기 찾기
grep -rn "\.system(size: 13" WeekAheadTodo --include="*.swift"
```

---

## 예외 사항

**없음.** 모든 텍스트는 17pt 이상을 유지합니다.

작은 폰트가 필요해 보이는 경우:
- 폰트 크기 대신 **color opacity** 사용 (`.foregroundColor(.secondary)`)
- 폰트 크기 대신 **font weight** 사용 (`.fontWeight(.regular)` vs `.fontWeight(.medium)`)
- 레이아웃으로 시각적 위계 표현

---

## 변경 이력

- **2026-01-19**: 초기 가이드라인 작성
  - 최소 폰트 크기 17pt 규칙 수립
  - 모든 `.caption`, `.caption2`, `.footnote` 제거
  - 모든 17pt 미만 `.system(size:)` 제거

---

## 참고 자료

- [Apple Human Interface Guidelines - Typography](https://developer.apple.com/design/human-interface-guidelines/typography)
- [SwiftUI Font Documentation](https://developer.apple.com/documentation/swiftui/font)
- [Accessibility - Text Size](https://developer.apple.com/accessibility/macos/)
