# Live Activity 설정 가이드

## 문제: Live Activity가 비활성화되는 이유

Live Activity가 "비활성화"로 표시되는 이유는 여러 가지가 있습니다:

### 1. ✅ Info.plist 설정 (완료)
- `TodoAlarm/Info.plist` 생성됨
- `NSSupportsLiveActivities = true` 추가됨

### 2. ⚠️ Widget Extension 타겟 필요 (수동 설정 필요)

**Live Activity UI를 표시하려면 Widget Extension이 필수입니다.**

#### Xcode에서 설정하는 방법:

1. **File → New → Target...**
2. **iOS → Widget Extension** 선택
3. **✅ "Include Live Activity" 체크** (중요!)
4. Product Name: `TodoAlarmWidget`
5. Finish

#### 생성 후 설정:

**A. App Groups 추가**
- TodoAlarmWidget 타겟 → Signing & Capabilities
- `+ Capability` → App Groups
- `group.com.leeo.TodoAlarm` 체크

**B. Task 모델 공유**
- `TodoAlarm/Models/Task.swift` 파일 선택
- Target Membership → `TodoAlarmWidget` 체크

**C. 생성된 파일 교체**
제가 이미 만든 파일들로 교체:
- `TodoAlarmWidget/TodoAlarmWidgetBundle.swift`
- `TodoAlarmWidget/TodoAlarmLiveActivity.swift`
- `TodoAlarmWidget/Info.plist`

### 3. 🔍 디버깅 체크리스트

앱을 실행하고 Xcode 콘솔에서 다음 로그를 확인:

```
🎬 [LiveActivityManager] 초기화
   📱 Live Activity 지원: true/false
   📱 Live Activity 권한 상태: 활성화됨/비활성화됨
   📱 시뮬레이터에서 실행 중 / 실제 기기에서 실행 중
```

**Live Activity 지원이 false라면:**
- iOS 16.1 미만 버전
- 시뮬레이터에서는 Live Activity가 제한적으로 지원됨
- **iPhone 14 Pro 이상 실제 기기**에서 테스트 권장

**오늘 할 일이 없다면:**
```
📊 [LiveActivityManager] 오늘 할 일 Activity 관리: 0개
   ✅ 모든 태스크 완료 - Activity 종료
```
→ 오늘 마감인 태스크를 추가하세요

**Activity 시작 실패:**
```
❌ [LiveActivityManager] Live Activity 시작 실패: ...
```
→ 에러 메시지 확인

### 4. 🧪 테스트 방법

1. **태스크 추가**
   - 오늘 마감인 태스크 1개 이상 생성
   - 예: "테스트 태스크" - 마감: 오늘 18:00

2. **앱 재시작**
   - 앱 종료 후 재실행
   - 콘솔 로그 확인

3. **확인 사항**
   - 설정 탭에서 "Live Activity 활성화됨" 표시
   - 다이나믹 아일랜드에 태스크 표시 (iPhone 14 Pro+)
   - 잠금 화면에 Live Activity 표시

### 5. 🚨 일반적인 문제 해결

#### "Live Activity 지원: false"
- iOS 버전 확인 (16.1+ 필요)
- 시뮬레이터가 아닌 실제 기기에서 테스트

#### "Live Activity 시작 실패"
- Widget Extension 타겟 확인
- App Groups 설정 확인
- Bundle Identifier 확인

#### "비활성화" 상태
- 오늘 할 일이 있는지 확인
- `currentActivity == nil`인지 로그 확인
- Activity.request() 실패 에러 확인

### 6. 📱 지원 기기

**다이나믹 아일랜드 (완전 지원):**
- iPhone 14 Pro
- iPhone 14 Pro Max
- iPhone 15 Pro
- iPhone 15 Pro Max
- iPhone 16 Pro
- iPhone 16 Pro Max
- iPhone 17 Pro (시뮬레이터)

**잠금 화면 Live Activity (모든 iOS 16.1+ 기기):**
- iPhone XS 이상
- iOS 16.1 이상

### 7. 🔧 다음 단계

1. Xcode에서 Widget Extension 타겟 추가
2. 앱 빌드 및 실행
3. 콘솔 로그 확인
4. 오늘 마감 태스크 추가
5. Live Activity 확인

---

## 빠른 문제 해결

**Q: "비활성화"로 계속 표시됨**
→ 콘솔에서 `[LiveActivityManager]` 로그 확인

**Q: Widget Extension 없이 테스트하고 싶음**
→ 불가능. Live Activity UI는 Widget Extension이 필수

**Q: 시뮬레이터에서 테스트 가능?**
→ 가능하지만 제한적. 실제 기기 권장

**Q: 다이나믹 아일랜드가 안 보임**
→ iPhone 14 Pro 이상 필요. 다른 기기는 잠금 화면에만 표시
