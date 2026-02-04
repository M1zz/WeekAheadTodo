//
//  LiveActivityManager.swift
//  TodoAlarm (iOS)
//
//  다이나믹 아일랜드 Live Activity 관리
//

#if os(iOS)
import ActivityKit
import SwiftUI
import Combine

@MainActor
@available(iOS 16.1, *)
class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    @Published var currentActivity: Activity<TaskActivityAttributes>?

    private init() {
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🎬 [LiveActivityManager] 초기화")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // 환경 정보
        #if targetEnvironment(simulator)
        print("📱 실행 환경: 시뮬레이터")
        #else
        print("📱 실행 환경: 실제 기기")
        #endif

        // iOS 버전
        let version = ProcessInfo.processInfo.operatingSystemVersion
        print("📱 iOS 버전: \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)")

        // 기기 모델
        #if os(iOS)
        let device = UIDevice.current
        print("📱 기기 모델: \(device.model)")
        print("📱 기기 이름: \(device.name)")
        #endif

        // Live Activity 지원 여부 확인
        let authInfo = ActivityAuthorizationInfo()
        print("\n🔐 ActivityKit 상태:")
        print("   areActivitiesEnabled: \(authInfo.areActivitiesEnabled)")

        if !authInfo.areActivitiesEnabled {
            print("\n⚠️ Live Activity가 비활성화되어 있습니다")
            print("   가능한 원인:")
            print("   1. iOS 16.1 미만 버전")
            print("   2. 시뮬레이터 제한")
            print("   3. 시스템 설정에서 비활성화")
            print("   4. Widget Extension 타겟 없음")
        } else {
            print("   ✅ Live Activity 사용 가능")
        }

        print("   frequentPushesEnabled: \(authInfo.frequentPushesEnabled)")

        // 현재 활성화된 Activity 확인
        let activities = Activity<TaskActivityAttributes>.activities
        print("\n📊 현재 활성 Activity: \(activities.count)개")
        for (index, activity) in activities.enumerated() {
            print("   [\(index)] ID: \(activity.id)")
            print("        State: \(activity.activityState)")
        }

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }

    // MARK: - Live Activity Management

    /// Live Activity 시작
    func startActivity(urgentTask: TaskModel, remainingCount: Int) {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🎬 [LiveActivityManager] Live Activity 시작 시도")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📋 태스크 정보:")
        print("   제목: \(urgentTask.title)")
        print("   마감: \(urgentTask.dueDate)")
        print("   남은 개수: \(remainingCount)")

        // 환경 확인
        print("\n🔍 환경 확인:")
        #if targetEnvironment(simulator)
        print("   실행 환경: 시뮬레이터")
        #else
        print("   실행 환경: 실제 기기")
        #endif

        // iOS 버전 확인
        let version = ProcessInfo.processInfo.operatingSystemVersion
        print("   iOS 버전: \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)")

        // ActivityKit 권한 확인
        let authInfo = ActivityAuthorizationInfo()
        print("\n🔐 ActivityKit 권한:")
        print("   areActivitiesEnabled: \(authInfo.areActivitiesEnabled)")
        print("   frequentPushesEnabled: \(authInfo.frequentPushesEnabled)")

        // 기존 활성 Activity 확인
        let existingActivities = Activity<TaskActivityAttributes>.activities
        print("\n📊 기존 활성 Activity:")
        print("   개수: \(existingActivities.count)")
        for (index, activity) in existingActivities.enumerated() {
            print("   [\(index)] ID: \(activity.id), State: \(activity.activityState)")
        }

        // iOS 16.1+ 확인
        guard authInfo.areActivitiesEnabled else {
            print("\n❌ [LiveActivityManager] Live Activity 지원 안 됨")
            print("   원인: areActivitiesEnabled = false")
            print("   가능한 이유:")
            print("   1. iOS 버전이 16.1 미만")
            print("   2. 시스템 설정에서 Live Activity 비활성화")
            print("   3. 기기가 Live Activity를 지원하지 않음")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
            return
        }

        // 기존 Activity 종료
        print("\n🧹 기존 Activity 정리 중...")
        endActivity()

        print("\n🚀 Activity.request() 호출...")
        do {
            let attributes = TaskActivityAttributes(activityId: "today-tasks")
            print("   Attributes 생성 완료: activityId = today-tasks")

            let contentState = TaskActivityAttributes.ContentState(
                urgentTaskTitle: urgentTask.title,
                dueDate: urgentTask.dueDate,
                remainingTasksCount: remainingCount
            )
            print("   ContentState 생성 완료")

            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil)
            )

            currentActivity = activity
            print("\n✅ [LiveActivityManager] Live Activity 시작 성공!")
            print("   Activity ID: \(activity.id)")
            print("   Activity State: \(activity.activityState)")
            print("   Push Token: \(activity.pushToken?.description ?? "없음")")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        } catch let error as NSError {
            print("\n❌ [LiveActivityManager] Live Activity 시작 실패")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("📛 에러 정보:")
            print("   Domain: \(error.domain)")
            print("   Code: \(error.code)")
            print("   Description: \(error.localizedDescription)")

            if let userInfo = error.userInfo as? [String: Any], !userInfo.isEmpty {
                print("\n   UserInfo:")
                for (key, value) in userInfo {
                    print("      \(key): \(value)")
                }
            }

            print("\n💡 에러 코드 분석:")
            switch error.code {
            case -1:
                print("   unsupportedTarget:")
                print("   → Widget Extension 타겟이 없거나 제대로 설정되지 않음")
                print("   → Xcode에서 Widget Extension 타겟을 추가해야 함")
                print("   → File → New → Target → Widget Extension")
                print("   → Include Live Activity 체크 필수!")
            case -2:
                print("   alreadyActive:")
                print("   → 동일한 Activity가 이미 활성화되어 있음")
            case -3:
                print("   tooManyActivities:")
                print("   → 최대 Activity 개수 초과")
            default:
                print("   알 수 없는 에러 코드: \(error.code)")
            }

            print("\n🔍 해결 방법:")
            print("   1. Xcode에서 Widget Extension 타겟 추가")
            print("   2. TodoAlarmWidget 생성")
            print("   3. Include Live Activity 옵션 활성화")
            print("   4. Task.swift를 Widget Extension과 공유")
            print("   5. App Groups 설정")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        } catch {
            print("\n❌ [LiveActivityManager] 일반 에러 발생")
            print("   에러: \(error)")
            print("   타입: \(type(of: error))")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        }
    }

    /// Live Activity 업데이트
    func updateActivity(urgentTask: TaskModel, remainingCount: Int) {
        print("🔄 [LiveActivityManager] Live Activity 업데이트")

        guard let activity = currentActivity else {
            print("   ⚠️ 활성화된 Activity 없음 - 새로 시작")
            startActivity(urgentTask: urgentTask, remainingCount: remainingCount)
            return
        }

        _Concurrency.Task {
            let contentState = TaskActivityAttributes.ContentState(
                urgentTaskTitle: urgentTask.title,
                dueDate: urgentTask.dueDate,
                remainingTasksCount: remainingCount
            )

            await activity.update(.init(state: contentState, staleDate: nil))
            print("✅ [LiveActivityManager] Live Activity 업데이트 완료")
        }
    }

    /// Live Activity 종료
    func endActivity() {
        guard let activity = currentActivity else {
            print("ℹ️ [LiveActivityManager] 종료할 Activity 없음")
            return
        }

        print("🛑 [LiveActivityManager] Live Activity 종료")

        _Concurrency.Task {
            await activity.end(
                .init(state: activity.content.state, staleDate: nil),
                dismissalPolicy: .immediate
            )
            currentActivity = nil
            print("✅ [LiveActivityManager] Live Activity 종료 완료")
        }
    }

    /// 모든 Live Activity 정리
    func endAllActivities() {
        print("🗑️ [LiveActivityManager] 모든 Live Activity 종료")

        _Concurrency.Task {
            for activity in Activity<TaskActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            currentActivity = nil
            print("✅ [LiveActivityManager] 모든 Live Activity 종료 완료")
        }
    }

    // MARK: - Helpers

    /// 오늘 할 일에 대한 Live Activity 관리
    func manageTodayTasksActivity(tasks: [TaskModel]) {
        print("📊 [LiveActivityManager] 오늘 할 일 Activity 관리: \(tasks.count)개")

        let incompleteTasks = tasks.filter { !$0.isCompleted }
        print("   📊 미완료 태스크: \(incompleteTasks.count)개")

        if incompleteTasks.isEmpty {
            print("   ✅ 모든 태스크 완료 - Activity 종료")
            endActivity()
            return
        }

        // 가장 긴급한 태스크
        guard let urgentTask = incompleteTasks.min(by: { $0.urgencyScore < $1.urgencyScore }) else {
            print("   ⚠️ 긴급 태스크 없음")
            return
        }

        print("   🔥 가장 긴급한 태스크: \(urgentTask.title)")
        print("   📅 마감 시간: \(urgentTask.dueDate)")
        print("   🎯 긴급도 점수: \(urgentTask.urgencyScore)")

        if currentActivity == nil {
            print("   ▶️ 새 Activity 시작")
            startActivity(urgentTask: urgentTask, remainingCount: incompleteTasks.count)
        } else {
            print("   🔄 기존 Activity 업데이트 (ID: \(currentActivity!.id))")
            updateActivity(urgentTask: urgentTask, remainingCount: incompleteTasks.count)
        }
    }
}

#endif // os(iOS)
