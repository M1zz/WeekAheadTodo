# 다기기 동기화 시나리오 (2 Mac + iPhone)

> 작성일: 2026-03-04
> 대상: Mac A (주 작업), Mac B (보조), iPhone
> 동기화 방식: CloudKit Public Database, 앱 실행 시 자동 sync

---

## 아키텍처 개요

```
Mac A ──┐
Mac B ──┼──▶ CloudKit (TaskItem records + SyncMetadata tombstones)
iPhone ─┘
```

### 핵심 원칙

| 원칙 | 설명 |
|------|------|
| **Last-Write-Wins** | `modifiedAt` 기준, 1초 이상 차이일 때만 적용 |
| **1초 임계값** | 직렬화 오차(CloudKit NSDate ↔ UserDefaults JSON Double) 흡수 |
| **sessionEdited 보호** | 현재 세션에서 사용자가 직접 편집한 태스크는 클라우드 최신이어도 로컬 우선 (24h TTL, 앱 재시작 후에도 유지) |
| **Tombstone** | 삭제 정보를 클라우드에 보존 → 다른 기기에 삭제 전파 |

---

## 시나리오 1: 기본 생성 / 조회

| # | 행동 순서 | 기대 결과 | 비고 |
|---|-----------|-----------|------|
| 1-A | Mac A에서 태스크 생성 → Mac B sync | Mac B에 태스크 추가됨 | 정상 |
| 1-B | iPhone에서 태스크 생성 → Mac A sync | Mac A에 태스크 추가됨 | 정상 |
| 1-C | Mac B에서 태스크 생성 → iPhone sync | iPhone에 태스크 추가됨 | 정상 |
| 1-D | 세 기기 모두 sync | 전체 태스크 목록 완전 일치 | 정상 |

**MergeEngine 동작**: `cloudTasks`에만 있는 태스크 → `mergedTasks`에 append, `tasksToUpsert` 없음.

---

## 시나리오 2: 편집 충돌 (온라인 상태)

| # | 행동 순서 | 기대 결과 | 위험도 |
|---|-----------|-----------|--------|
| 2-A | Mac A 편집(t0) → Mac B sync | Mac B가 클라우드 최신 수신 | 없음 |
| 2-B | Mac A 편집(t0) → Mac B 편집(t0+3초) → 양쪽 sync | Mac B 버전 최신 → Mac A에 적용 | 없음 |
| 2-C | Mac A 편집 → 같은 세션에서 sync | sessionEdited 보호 → 로컬 유지, 클라우드 덮어씀 | 없음 |
| 2-D | Mac A 편집(t0) → 1초 내 Mac B도 편집(t0+0.3초) → 양쪽 sync | 1초 이내 차이 → 각자 로컬 유지, 재업로드 없음 | ⚠️ 낮음 |

> **2-D 주의**: 어느 버전이 클라우드에 마지막으로 올라갈지 비결정적. 두 편집이 서로를 모르는 채로 coexist함. 실용적으로는 무시해도 되는 수준.

---

## 시나리오 3: 편집 충돌 (오프라인 → 온라인)

| # | 행동 순서 | 기대 결과 | 위험도 |
|---|-----------|-----------|--------|
| 3-A | Mac A **오프라인** 편집 → Mac B **온라인** 편집 → Mac A 온라인 | `modifiedAt` 비교 → 더 최신이 승리 | ⚠️ 중간 |
| 3-B | Mac A 오프라인 편집 → 앱 **재시작** → sync | sessionEdited 24h TTL 유지 → 로컬 보호 | 없음 |
| 3-C | iPhone 오프라인 편집 → Mac A/B 온라인 동안 편집 → iPhone 온라인 | iPhone `modifiedAt` 기준 비교 → 더 최신 승리 | ⚠️ 중간 |
| 3-D | Mac A 오프라인 중 **Mac B + iPhone 둘 다** 편집 → Mac A 온라인 | 클라우드 최신(B vs iPhone 중 나중 것)이 Mac A에 적용 | 🔴 높음 |

> **3-A / 3-C 주의**: Mac A가 오랫동안 오프라인이었다면, 그 사이 Mac B/iPhone에서 한 편집이 클라우드에 반영되어 있고, Mac A가 온라인 되는 순간 Mac A의 로컬 편집 시각이 더 오래됐으면 덮어써진다.
> **해결책**: Mac A가 오프라인 중 편집했다면 sessionEdited가 보호해 줌. 단, 세션을 새로 시작했고 24h가 지났다면 보호 없음.

> **3-D 주의**: 3개 버전 중 클라우드에 마지막으로 올라간 1개만 살아남는다. 어떤 버전이 남을지 예측 불가.

---

## 시나리오 4: 삭제 전파 (정상 케이스)

| # | 행동 순서 | 기대 결과 | 위험도 |
|---|-----------|-----------|--------|
| 4-A | Mac A에서 삭제 → Mac B sync | Mac B에서도 삭제됨 (tombstone 전파) | 없음 |
| 4-B | iPhone에서 삭제 → Mac A sync | Mac A에서도 삭제됨 | 없음 |
| 4-C | Mac A **오프라인** 중 iPhone에서 삭제 → Mac A 온라인 | Mac A에서도 삭제 적용 | 없음 |
| 4-D | Mac A에서 삭제 → Mac B/iPhone에 tombstone 전파 → 전체 sync | 세 기기 모두 삭제됨 | 없음 |

**MergeEngine 동작**: `cloudTombstones[id]` 확인 → 로컬 `modifiedAt <= cloudDeletedAt` → 로컬에서 제거.

---

## 시나리오 5: 삭제 vs 편집 충돌 ⚠️

가장 복잡하고 예상과 다른 동작이 일어날 수 있는 케이스.

| # | 행동 순서 | 기대 결과 | 위험도 |
|---|-----------|-----------|--------|
| 5-A | Mac A 삭제(t0) → Mac B가 t1(>t0)에 편집 → Mac A sync | Mac B 수정이 최신 → **태스크 복원됨** | 🔴 높음 |
| 5-B | Mac A 삭제(t1) → Mac B가 t0(<t1)에 편집 후 sync | 삭제 tombstone이 최신 → Mac B에서도 삭제 | 없음 |
| 5-C | iPhone 삭제 → Mac A 오프라인 중 같은 태스크 편집 → Mac A 온라인 | Mac A 편집이 tombstone보다 최신 → **복원 + 재업로드** | 🔴 높음 |
| 5-D | Mac A 오프라인 중 삭제한 태스크를 Mac B가 편집 → Mac A 온라인 | Mac B 수정이 더 최신 → **Mac A에 복원됨** | 🔴 높음 |

> **정책 설명 (의도된 동작)**:
> 삭제보다 이후에 일어난 수정은 "의미 있는 변경"으로 간주하여 복원함.
> "삭제한 건데 왜 살아났지?"는 반드시 다른 기기에서 나중에 편집이 있었기 때문.
> 이 정책을 바꾸려면 MergeEngine의 tombstone 비교 로직 수정 필요.

---

## 시나리오 6: 앱 재시작 / 세션 경계

| # | 행동 순서 | 기대 결과 | 위험도 |
|---|-----------|-----------|--------|
| 6-A | Mac A 편집 → 앱 종료 → 재시작 → sync | sessionEdited 24h TTL 유지 → 로컬 보호 | 없음 |
| 6-B | Mac A 편집 → **25시간 후** 재시작 → sync | TTL 만료 → sessionEdited 보호 없음 → 클라우드 버전 적용 가능 | ⚠️ 낮음 |
| 6-C | restoreFromCloud 실행 | `modifiedAt` 필드 정상 fetch → 타임스탬프 인플레이션 없음 | 없음 |
| 6-D | 처음 앱 설치 (iPhone) → 기존 Mac A 데이터 sync | 클라우드 전체 태스크 로컬에 추가 | 없음 |

> **6-B 주의**: 25시간 이상 앱을 안 켰다가 켜면 보호 기간이 만료된다. 그 사이 다른 기기에서 편집이 있었다면 클라우드 버전이 로컬을 덮어씀.

---

## 시나리오 7: 엣지 케이스

| # | 행동 순서 | 기대 결과 | 위험도 |
|---|-----------|-----------|--------|
| 7-A | 세 기기 동시에 같은 태스크 편집 | 가장 마지막에 클라우드에 올라간 버전이 남음 | 🔴 높음 |
| 7-B | sync 전에 Mac A/Mac B 둘 다 새 태스크 생성 (같은 내용) | UUID가 달라 **중복 태스크 2개 생성** | ⚠️ 중간 |
| 7-C | iCloud 비로그인 상태 | 로컬 전용 동작, sync 없음, 에러 표시 | 없음 |
| 7-D | CloudKit rate limit 도달 | sync 실패, 다음 실행 시 재시도 | ⚠️ 낮음 |
| 7-E | 동일 태스크를 Mac A가 삭제하고 Mac B도 삭제 | 양쪽 tombstone → 정상 처리 | 없음 |

---

## 위험도별 요약

### 🔴 높음 (예상과 다른 동작 발생 가능)

1. **시나리오 3-D**: 세 기기 모두 오프라인 편집 → 클라우드 최신 1개만 살아남음
2. **시나리오 5-A/C/D**: 삭제 후 다른 기기의 편집으로 태스크 부활
3. **시나리오 7-A**: 동시 다기기 편집 → 비결정적 결과

### ⚠️ 중간 (상황에 따라 데이터 유실 가능)

4. **시나리오 3-A/C**: 오프라인 편집 후 온라인 시 클라우드에 덮어써짐
5. **시나리오 7-B**: sync 전 동일 내용 중복 생성

### ✅ 없음 (정상 동작)

- 기본 생성/조회 (시나리오 1)
- 순차적 편집 (시나리오 2-A/B)
- 정상 삭제 전파 (시나리오 4)
- restoreFromCloud 타임스탬프 처리 (시나리오 6-C)

---

## 구현 파일 참조

| 역할 | 파일 |
|------|------|
| 병합 로직 (테스트 가능) | `WeekAheadTodo/ViewModels/MergeEngine.swift` |
| 실제 sync 실행 | `WeekAheadTodo/ViewModels/TaskViewModel.swift` → `performMergeSync()` |
| 병합 단위 테스트 | `WeekAheadTodoTests/SyncMergeTests.swift` |

### 주요 상수

```swift
// 타임스탬프 비교 임계값 (직렬화 오차 흡수)
let threshold: TimeInterval = 1.0

// sessionEdited 보호 유효 기간
let ttl: TimeInterval = 24 * 3600  // 24시간

// UserDefaults 키
let sessionEditedKey = "SessionEditedTaskIds_v1"
let tombstonesKey    = "TaskTombstones"
let syncDateKey      = "LastSyncDate"
```

---

## 향후 개선 포인트

- [ ] **자동 sync**: 앱 실행 시 외에도 백그라운드 또는 포그라운드 전환 시 sync
- [ ] **충돌 알림**: 병합 결과 다른 기기 편집으로 덮어써졌을 때 사용자에게 알림
- [ ] **Conflict UI**: 양쪽 버전을 보여주고 사용자가 직접 선택 (Google Docs 방식)
- [ ] **시나리오 7-B 방지**: 태스크 생성 시 title+dueDate 기반 중복 감지
