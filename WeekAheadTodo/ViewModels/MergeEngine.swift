import Foundation
import WeekAheadShared

// MARK: - MergeResult

/// 병합 연산의 결과
struct MergeResult {
    /// 최종 로컬에 적용할 태스크 목록
    let mergedTasks: [Task]
    /// 클라우드에 업로드(생성/갱신)해야 할 태스크 목록
    let tasksToUpsert: [Task]
    /// 클라우드에서 삭제해야 할 태스크 ID 목록
    let idsToDeleteFromCloud: [UUID]
    /// 정리 후 남은 로컬 tombstone (다음 saveTombstones에 쓸 값)
    let remainingTombstones: [UUID: Date]
}

// MARK: - MergeEngine

/// CloudKit ↔ 로컬 태스크 양방향 병합 로직 (CloudKit 의존성 없음 → 단위 테스트 가능)
///
/// 규칙:
/// 1. 클라우드 tombstone 적용 (다른 기기 삭제 전파)
/// 2. 양쪽에 있는 태스크: modifiedAt 비교 (1초 임계값)
///    - sessionEdited 태스크는 항상 로컬 우선
/// 3. 클라우드에만 있는 태스크: 로컬에 추가 (다른 기기 신규)
/// 4. 로컬에만 있는 태스크: 클라우드에 업로드
/// 5. 우리가 삭제한 태스크(tombstone)가 클라우드에 있으면:
///    - cloud.modifiedAt > tombstone → 삭제 후 수정됨 → 복원
///    - cloud.modifiedAt ≤ tombstone → 삭제 유효 → cloud에서도 삭제
enum MergeEngine {

    static func compute(
        localTasks: [Task],
        cloudTasks: [Task],
        cloudTombstones: [UUID: Date],
        localTombstones: [UUID: Date],
        sessionEditedIds: [UUID: Date]
    ) -> MergeResult {

        var mergedTasks = localTasks
        var tasksToUpsert: [Task] = []
        var idsToDeleteFromCloud: [UUID] = []
        var remainingTombstones = localTombstones
        let cloudDict = Dictionary(uniqueKeysWithValues: cloudTasks.map { ($0.id, $0) })

        // 1. 클라우드 tombstone을 로컬에 적용
        var cloudDeletedIds = Set<UUID>()
        for (deletedId, cloudDeletedAt) in cloudTombstones {
            if let localTask = mergedTasks.first(where: { $0.id == deletedId }) {
                if localTask.modifiedAt <= cloudDeletedAt {
                    // 클라우드에서 삭제됐고 로컬이 더 최신이 아님 → 로컬에서도 삭제
                    mergedTasks.removeAll { $0.id == deletedId }
                    cloudDeletedIds.insert(deletedId)
                }
                // 로컬이 더 최신(로컬 modifiedAt > cloudDeletedAt)이면 로컬 유지 → step 4에서 re-upload
            }
            // 클라우드가 이미 알고 있는 tombstone은 로컬에서 제거
            remainingTombstones.removeValue(forKey: deletedId)
        }

        // 2~3. 클라우드 태스크를 로컬에 병합
        for cloudTask in cloudTasks {
            let localIndex = mergedTasks.firstIndex(where: { $0.id == cloudTask.id })

            if let idx = localIndex {
                // 양쪽에 있음 → modifiedAt 비교
                let localTask = mergedTasks[idx]
                let isSessionEdited = sessionEditedIds[cloudTask.id] != nil

                if isSessionEdited {
                    // 이 세션에서 사용자가 직접 편집한 태스크 → 항상 로컬 우선
                    if cloudTask.dueDate != localTask.dueDate || cloudTask.modifiedAt != localTask.modifiedAt {
                        tasksToUpsert.append(localTask)
                    }
                } else if cloudTask.modifiedAt.timeIntervalSince(localTask.modifiedAt) > 1.0 {
                    // cloud가 1초 이상 최신 → cloud 우선
                    mergedTasks[idx] = cloudTask
                } else if localTask.modifiedAt.timeIntervalSince(cloudTask.modifiedAt) > 1.0 {
                    // local이 1초 이상 최신 → local 우선, cloud 업데이트
                    tasksToUpsert.append(localTask)
                }
                // 1초 이내 차이 → 동일하다고 간주 (직렬화 오차 흡수)

            } else if let tombstoneDate = remainingTombstones[cloudTask.id] {
                // 우리가 삭제한 태스크가 클라우드에 있음
                if cloudTask.modifiedAt > tombstoneDate {
                    // 삭제 후 클라우드에서 수정됨 → 클라우드 버전 복원
                    mergedTasks.append(cloudTask)
                    remainingTombstones.removeValue(forKey: cloudTask.id)
                } else {
                    // 우리 삭제가 유효 → 클라우드에서도 삭제 필요
                    idsToDeleteFromCloud.append(cloudTask.id)
                    remainingTombstones.removeValue(forKey: cloudTask.id)
                }
            } else {
                // 클라우드에만 있고 우리가 삭제하지 않음 → 로컬에 추가 (다른 기기에서 추가됨)
                mergedTasks.append(cloudTask)
            }
        }

        // 4. 로컬에만 있는 태스크 → 클라우드에 업로드
        // cloudDeletedIds 제외: step 1에서 클라우드 tombstone으로 삭제된 태스크는 재업로드 안 함
        for localTask in localTasks {
            if cloudDict[localTask.id] == nil
                && remainingTombstones[localTask.id] == nil
                && !cloudDeletedIds.contains(localTask.id) {
                tasksToUpsert.append(localTask)
            }
        }

        // 중복 제거
        let uniqueUpsert = Array(
            Dictionary(uniqueKeysWithValues: tasksToUpsert.map { ($0.id, $0) }).values
        )

        return MergeResult(
            mergedTasks: mergedTasks,
            tasksToUpsert: uniqueUpsert,
            idsToDeleteFromCloud: idsToDeleteFromCloud,
            remainingTombstones: remainingTombstones
        )
    }
}
