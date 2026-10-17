import Foundation
import Testing
@testable import MorseCore

private func decodeProgress(_ json: String) throws -> LearnerProgress {
    try JSONDecoder().decode(LearnerProgress.self, from: Data(json.utf8))
}

@Test func decodingClampsUnlockedCountIntoRange() throws {
    let high = try decodeProgress(#"{"version":1,"unlockedCount":37,"pendingUnlock":false,"records":{},"recentAcrossSet":[]}"#)
    #expect(high.unlockedCount == 36)
    #expect(high.isComplete && high.next == nil && high.newest == "4")
    let low = try decodeProgress(#"{"version":1,"unlockedCount":0,"pendingUnlock":false,"records":{},"recentAcrossSet":[]}"#)
    #expect(low.unlockedCount == 2)
    #expect(low.newest == "M")
    #expect(HomeSummary(progress: low).kind == .firstRun)
}

@Test func decodingToleratesMissingFields() throws {
    let p = try decodeProgress(#"{"unlockedCount":3}"#)
    #expect(p.unlocked == ["K", "M", "R"])
    #expect(!p.pendingUnlock)
    #expect(p.record("K", .keying) == SkillRecord())
}

@Test func decodingTrimsOversizedWindows() throws {
    let recent = Array(repeating: "true", count: 25).joined(separator: ",")
    let across = Array(repeating: "false", count: 60).joined(separator: ",")
    let p = try decodeProgress(#"{"unlockedCount":2,"records":{"K/keying":{"recent":[\#(recent)],"total":25}},"recentAcrossSet":[\#(across)]}"#)
    #expect(p.record("K", .keying).recent.count == 20)
    #expect(p.record("K", .keying).total == 25)
    #expect(!p.isSetSolid)
}

@Test func decodingDropsRecordsForUnknownCharacters() throws {
    let p = try decodeProgress(#"{"unlockedCount":2,"records":{"k/keying":{"recent":[true],"total":1},"K/typing":{"recent":[true],"total":1}}}"#)
    #expect(!p.hasLoggedAttempts)
}

@Test func encodedKeysAreStable() throws {
    let data = try JSONEncoder().encode(LearnerProgress.initial)
    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    #expect(Set(object?.keys.map { $0 } ?? []) == ["version", "unlockedCount", "pendingUnlock", "records", "recentAcrossSet"])
    #expect(object?["version"] as? Int == 1)
}

@Test func skillRecordInitTrimsToWindow() {
    let r = SkillRecord(recent: Array(repeating: false, count: 30), total: 30)
    #expect(r.recent.count == 20)
}

@Test func ditEstimatorClampsOnInitAndDecode() throws {
    #expect(DitEstimator(dit: 0).dit == DitEstimator.minimum)
    #expect(DitEstimator(dit: 5).dit == DitEstimator.maximum)
    let decoded = try JSONDecoder().decode(DitEstimator.self, from: Data(#"{"dit":0}"#.utf8))
    #expect(decoded.dit == DitEstimator.minimum)
    #expect(DitEstimator(dit: .nan).dit == DitEstimator.initial)
    #expect(DitEstimator(dit: .infinity).dit == DitEstimator.initial)
    let missing = try JSONDecoder().decode(DitEstimator.self, from: Data("{}".utf8))
    #expect(missing.dit == DitEstimator.initial)
}
