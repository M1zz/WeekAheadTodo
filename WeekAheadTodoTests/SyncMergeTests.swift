import XCTest
import WeekAheadShared
@testable import WeekAheadTodo

/// MergeEngine 단위 테스트 - 2Mac + 1iPhone 다기기 동기화 시나리오 검증
final class SyncMergeTests: XCTestCase {

    // MARK: - 헬퍼

    /// 특정 modifiedAt 타임스탬프를 가진 테스트용 태스크 생성
    private func task(id: UUID = UUID(), title: String, modifiedAt: Date, dueDate: Date = Date()) -> Task {
        var t = Task(id: id, title: title, dueDate: dueDate)
        t.modifiedAt = modifiedAt
        return t
    }

    // 기준 시각
    private let base = Date(timeIntervalSinceReferenceDate: 1_000_000)

    /// base + 2초 (확실히 최신)
    private var newer: Date { base.addingTimeInterval(2) }

    /// base + 0.3초 (1초 이내 → 동일 간주)
    private var almostSame: Date { base.addingTimeInterval(0.3) }

    // MARK: - 시나리오 1: 클라우드에만 있는 태스크 → 로컬에 추가

    func test_클라우드전용태스크_로컬에추가() {
        let cloudTask = task(title: "클라우드 신규", modifiedAt: base)

        let result = MergeEngine.compute(
            localTasks: [],
            cloudTasks: [cloudTask],
            cloudTombstones: [:],
            localTombstones: [:],
            sessionEditedIds: [:]
        )

        XCTAssertEqual(result.mergedTasks.count, 1)
        XCTAssertEqual(result.mergedTasks[0].id, cloudTask.id)
        XCTAssertTrue(result.tasksToUpsert.isEmpty, "클라우드→로컬 추가는 업로드 불필요")
    }

    // MARK: - 시나리오 2: 로컬에만 있는 태스크 → 클라우드 업로드 목록에 포함

    func test_로컬전용태스크_업로드목록에추가() {
        let localTask = task(title: "로컬 신규", modifiedAt: base)

        let result = MergeEngine.compute(
            localTasks: [localTask],
            cloudTasks: [],
            cloudTombstones: [:],
            localTombstones: [:],
            sessionEditedIds: [:]
        )

        XCTAssertEqual(result.mergedTasks.count, 1)
        XCTAssertTrue(result.tasksToUpsert.contains { $0.id == localTask.id }, "로컬 전용 태스크는 클라우드에 업로드 필요")
    }

    // MARK: - 시나리오 3: 클라우드가 1초 이상 최신 → 클라우드 버전으로 덮어씀

    func test_클라우드최신_클라우드우선() {
        let id = UUID()
        let localTask = task(id: id, title: "로컬 구버전", modifiedAt: base)
        let cloudTask = task(id: id, title: "클라우드 최신", modifiedAt: newer)

        let result = MergeEngine.compute(
            localTasks: [localTask],
            cloudTasks: [cloudTask],
            cloudTombstones: [:],
            localTombstones: [:],
            sessionEditedIds: [:]
        )

        XCTAssertEqual(result.mergedTasks.count, 1)
        XCTAssertEqual(result.mergedTasks[0].title, "클라우드 최신", "클라우드가 1초 이상 최신이면 클라우드 버전 사용")
        XCTAssertTrue(result.tasksToUpsert.isEmpty, "클라우드→로컬 덮어쓸 때 re-upload 불필요")
    }

    // MARK: - 시나리오 4: 로컬이 1초 이상 최신 → 로컬 유지, 클라우드 업로드

    func test_로컬최신_로컬우선_클라우드업로드() {
        let id = UUID()
        let localTask = task(id: id, title: "로컬 최신", modifiedAt: newer)
        let cloudTask = task(id: id, title: "클라우드 구버전", modifiedAt: base)

        let result = MergeEngine.compute(
            localTasks: [localTask],
            cloudTasks: [cloudTask],
            cloudTombstones: [:],
            localTombstones: [:],
            sessionEditedIds: [:]
        )

        XCTAssertEqual(result.mergedTasks.count, 1)
        XCTAssertEqual(result.mergedTasks[0].title, "로컬 최신", "로컬이 1초 이상 최신이면 로컬 버전 유지")
        XCTAssertTrue(result.tasksToUpsert.contains { $0.id == id }, "로컬 최신이면 클라우드에 업로드 필요")
    }

    // MARK: - 시나리오 5: modifiedAt 차이 1초 미만 → 동일 간주 (직렬화 오차 흡수)

    func test_타임스탬프1초이내차이_동일간주_업로드없음() {
        let id = UUID()
        let localTask = task(id: id, title: "로컬", modifiedAt: base)
        let cloudTask = task(id: id, title: "클라우드", modifiedAt: almostSame) // +0.3초

        let result = MergeEngine.compute(
            localTasks: [localTask],
            cloudTasks: [cloudTask],
            cloudTombstones: [:],
            localTombstones: [:],
            sessionEditedIds: [:]
        )

        XCTAssertEqual(result.mergedTasks.count, 1)
        XCTAssertTrue(result.tasksToUpsert.isEmpty, "1초 이내 차이는 동일 간주 → 업로드 없음 (무한 sync 방지)")
    }

    // MARK: - 시나리오 6: 세션 편집 태스크 → 클라우드가 더 최신이어도 로컬 유지

    func test_세션편집태스크_클라우드최신이어도로컬유지() {
        let id = UUID()
        let localTask = task(id: id, title: "로컬 편집", modifiedAt: base)
        let cloudTask = task(id: id, title: "클라우드 최신", modifiedAt: newer)
        let editedAt = base.addingTimeInterval(1)

        let result = MergeEngine.compute(
            localTasks: [localTask],
            cloudTasks: [cloudTask],
            cloudTombstones: [:],
            localTombstones: [:],
            sessionEditedIds: [id: editedAt]
        )

        XCTAssertEqual(result.mergedTasks[0].title, "로컬 편집", "세션 편집 태스크는 클라우드 최신이어도 로컬 유지")
        XCTAssertTrue(result.tasksToUpsert.contains { $0.id == id }, "세션 편집 태스크는 클라우드에 덮어써야 함")
    }

    // MARK: - 시나리오 7: 세션 편집 태스크, 내용이 동일 → 불필요한 업로드 없음

    func test_세션편집태스크_내용동일_업로드없음() {
        let id = UUID()
        let sameDate = Date(timeIntervalSinceReferenceDate: 500_000)
        let localTask = task(id: id, title: "동일 내용", modifiedAt: base, dueDate: sameDate)
        let cloudTask = task(id: id, title: "동일 내용", modifiedAt: base, dueDate: sameDate)

        let result = MergeEngine.compute(
            localTasks: [localTask],
            cloudTasks: [cloudTask],
            cloudTombstones: [:],
            localTombstones: [:],
            sessionEditedIds: [id: base]
        )

        XCTAssertTrue(result.tasksToUpsert.isEmpty, "세션 편집이지만 dueDate·modifiedAt이 동일하면 업로드 안 함")
    }

    // MARK: - 시나리오 8: 클라우드 툼스톤 → 로컬 태스크 삭제 (다른 기기에서 삭제)

    func test_클라우드툼스톤_로컬에서삭제() {
        let id = UUID()
        let localTask = task(id: id, title: "삭제될 태스크", modifiedAt: base)
        let cloudTombstones: [UUID: Date] = [id: newer] // 클라우드에서 newer 시각에 삭제

        let result = MergeEngine.compute(
            localTasks: [localTask],
            cloudTasks: [],
            cloudTombstones: cloudTombstones,
            localTombstones: [:],
            sessionEditedIds: [:]
        )

        XCTAssertTrue(result.mergedTasks.isEmpty, "클라우드 툼스톤이 있으면 로컬에서도 삭제")
    }

    // MARK: - 시나리오 9: 클라우드 툼스톤이지만 로컬이 더 최신 → 로컬 유지

    func test_클라우드툼스톤_로컬이최신_로컬유지() {
        let id = UUID()
        let localTask = task(id: id, title: "로컬에서 재수정됨", modifiedAt: newer)
        let cloudTombstones: [UUID: Date] = [id: base] // 클라우드는 base 시각에 삭제 (로컬보다 오래됨)

        let result = MergeEngine.compute(
            localTasks: [localTask],
            cloudTasks: [],
            cloudTombstones: cloudTombstones,
            localTombstones: [:],
            sessionEditedIds: [:]
        )

        XCTAssertEqual(result.mergedTasks.count, 1, "로컬이 더 최신이면 클라우드 툼스톤 무시")
        XCTAssertTrue(result.tasksToUpsert.contains { $0.id == id }, "로컬 유지 후 클라우드에 재업로드")
    }

    // MARK: - 시나리오 10: 로컬 툼스톤 → 클라우드 삭제 요청

    func test_로컬툼스톤_클라우드삭제요청() {
        let id = UUID()
        let cloudTask = task(id: id, title: "이미 삭제한 태스크", modifiedAt: base)
        let localTombstones: [UUID: Date] = [id: newer] // 로컬에서 newer 시각에 삭제

        let result = MergeEngine.compute(
            localTasks: [],
            cloudTasks: [cloudTask],
            cloudTombstones: [:],
            localTombstones: localTombstones,
            sessionEditedIds: [:]
        )

        XCTAssertTrue(result.mergedTasks.isEmpty, "이미 삭제한 태스크는 로컬에 복원 안 함")
        XCTAssertTrue(result.idsToDeleteFromCloud.contains(id), "클라우드에서도 삭제 요청")
        XCTAssertTrue(result.remainingTombstones.isEmpty, "처리된 툼스톤은 remainingTombstones에 남기지 않음")
    }

    // MARK: - 시나리오 11: 로컬 툼스톤이지만 클라우드가 이후에 재수정됨 → 복원

    func test_로컬툼스톤_클라우드재수정_복원() {
        let id = UUID()
        // 로컬에서 base 시각에 삭제, 그 이후 다른 기기가 클라우드에서 newer에 수정
        let cloudTask = task(id: id, title: "다른 기기가 재수정", modifiedAt: newer)
        let localTombstones: [UUID: Date] = [id: base]

        let result = MergeEngine.compute(
            localTasks: [],
            cloudTasks: [cloudTask],
            cloudTombstones: [:],
            localTombstones: localTombstones,
            sessionEditedIds: [:]
        )

        XCTAssertEqual(result.mergedTasks.count, 1, "삭제 후 재수정된 태스크는 복원")
        XCTAssertEqual(result.mergedTasks[0].title, "다른 기기가 재수정")
        XCTAssertTrue(result.idsToDeleteFromCloud.isEmpty, "복원됐으므로 클라우드 삭제 안 함")
        XCTAssertTrue(result.remainingTombstones.isEmpty, "복원된 태스크의 툼스톤 제거")
    }

    // MARK: - 시나리오 12: 클라우드 툼스톤 → 로컬 툼스톤에서도 제거

    func test_클라우드툼스톤_로컬툼스톤에서제거() {
        let id = UUID()
        // 클라우드가 이미 처리한 삭제 → 로컬 툼스톤 불필요
        let cloudTombstones: [UUID: Date] = [id: base]
        let localTombstones: [UUID: Date] = [id: base]

        let result = MergeEngine.compute(
            localTasks: [],
            cloudTasks: [],
            cloudTombstones: cloudTombstones,
            localTombstones: localTombstones,
            sessionEditedIds: [:]
        )

        XCTAssertFalse(result.remainingTombstones.keys.contains(id), "클라우드가 이미 아는 툼스톤은 로컬에서 제거")
    }

    // MARK: - 시나리오 13: Mac A 생성 → Mac B 수정 → Mac A sync 시 클라우드 최신 승리

    func test_맥A생성후맥B수정_클라우드최신승리() {
        let id = UUID()
        let macALocal = task(id: id, title: "Mac A 원본", modifiedAt: base)
        let macBCloud = task(id: id, title: "Mac B 수정", modifiedAt: newer)

        let result = MergeEngine.compute(
            localTasks: [macALocal],
            cloudTasks: [macBCloud],
            cloudTombstones: [:],
            localTombstones: [:],
            sessionEditedIds: [:]
        )

        XCTAssertEqual(result.mergedTasks[0].title, "Mac B 수정", "Mac B가 더 최신 → 클라우드 버전 적용")
    }

    // MARK: - 시나리오 14: iPhone 삭제 → Mac A 오프라인 기간 → 온라인 시 삭제 전파

    func test_아이폰삭제후맥A온라인_삭제전파() {
        let id = UUID()
        let macALocal = task(id: id, title: "오프라인 중 남아있던 태스크", modifiedAt: base)
        let cloudTombstones: [UUID: Date] = [id: newer] // iPhone이 newer에 삭제

        let result = MergeEngine.compute(
            localTasks: [macALocal],
            cloudTasks: [],
            cloudTombstones: cloudTombstones,
            localTombstones: [:],
            sessionEditedIds: [:]
        )

        XCTAssertTrue(result.mergedTasks.isEmpty, "iPhone 삭제가 Mac A 오프라인 기간 로컬에 전파")
    }

    // MARK: - 시나리오 15: 두 기기가 동시 편집 (1초 이내) → 로컬 유지, 업로드 없음

    func test_동시편집1초이내_로컬유지_업로드없음() {
        let id = UUID()
        let localTask = task(id: id, title: "로컬 편집", modifiedAt: base)
        let cloudTask = task(id: id, title: "클라우드 편집", modifiedAt: almostSame) // +0.3초

        let result = MergeEngine.compute(
            localTasks: [localTask],
            cloudTasks: [cloudTask],
            cloudTombstones: [:],
            localTombstones: [:],
            sessionEditedIds: [:]
        )

        XCTAssertEqual(result.mergedTasks[0].title, "로컬 편집", "1초 이내 동시 편집은 로컬 유지")
        XCTAssertTrue(result.tasksToUpsert.isEmpty, "1초 이내 동시 편집 → 업로드 없음 (무한 sync 방지)")
    }

    // MARK: - 시나리오 16: 빈 상태 → 아무것도 안 함

    func test_빈상태_아무것도안함() {
        let result = MergeEngine.compute(
            localTasks: [],
            cloudTasks: [],
            cloudTombstones: [:],
            localTombstones: [:],
            sessionEditedIds: [:]
        )

        XCTAssertTrue(result.mergedTasks.isEmpty)
        XCTAssertTrue(result.tasksToUpsert.isEmpty)
        XCTAssertTrue(result.idsToDeleteFromCloud.isEmpty)
        XCTAssertTrue(result.remainingTombstones.isEmpty)
    }

    // MARK: - 시나리오 17: 클라우드에 없는 로컬 툼스톤 → 클라우드 삭제 요청 안 함, 툼스톤 보존

    func test_로컬툼스톤_클라우드에없음_툼스톤보존() {
        let id = UUID()
        let localTombstones: [UUID: Date] = [id: base]

        let result = MergeEngine.compute(
            localTasks: [],
            cloudTasks: [],
            cloudTombstones: [:],
            localTombstones: localTombstones,
            sessionEditedIds: [:]
        )

        XCTAssertTrue(result.idsToDeleteFromCloud.isEmpty, "클라우드에 없는 태스크는 삭제 요청 안 함")
        XCTAssertTrue(result.remainingTombstones.keys.contains(id), "처리 안 된 툼스톤은 다음 sync까지 유지")
    }

    // MARK: - 시나리오 18: 업로드 목록 중복 없음 보장

    func test_업로드목록_중복없음() {
        let id = UUID()
        let sameDate = Date(timeIntervalSinceReferenceDate: 500_000)
        // sessionEdited인 동시에, dueDate가 달라서 upsert 유발
        let localTask = task(id: id, title: "태스크", modifiedAt: base, dueDate: sameDate)
        let cloudTask = task(id: id, title: "태스크", modifiedAt: base,
                             dueDate: sameDate.addingTimeInterval(86400))

        let result = MergeEngine.compute(
            localTasks: [localTask],
            cloudTasks: [cloudTask],
            cloudTombstones: [:],
            localTombstones: [:],
            sessionEditedIds: [id: base]
        )

        let upsertCount = result.tasksToUpsert.filter { $0.id == id }.count
        XCTAssertEqual(upsertCount, 1, "같은 태스크가 업로드 목록에 중복 포함되면 안 됨")
    }
}
