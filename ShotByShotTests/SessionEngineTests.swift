import Testing
@testable import ShotByShot

struct SessionEngineTests {
    let inbox = (1...20).map { "asset-\($0)" }

    // MARK: Portion

    @Test func portionHasRequestedSizeAndNoDuplicates() {
        let portion = SessionEngine.portion(from: inbox, size: 3)
        #expect(portion.count == 3)
        #expect(Set(portion).count == 3)
        #expect(Set(portion).isSubset(of: Set(inbox)))
    }

    @Test func portionIsWholeInboxWhenInboxIsSmaller() {
        let portion = SessionEngine.portion(from: ["a", "b"], size: 5)
        #expect(Set(portion) == ["a", "b"])
    }

    @Test func tappedScreenshotGoesFirst() {
        let portion = SessionEngine.portion(from: inbox, size: 3, first: "asset-7")
        #expect(portion.first == "asset-7")
        #expect(portion.count == 3)
        #expect(Set(portion).count == 3)
    }

    @Test func unknownFirstScreenshotIsIgnored() {
        let portion = SessionEngine.portion(from: inbox, size: 3, first: "missing")
        #expect(portion.count == 3)
        #expect(!portion.contains("missing"))
    }

    @Test func emptyInboxGivesEmptyPortion() {
        #expect(SessionEngine.portion(from: [], size: 3).isEmpty)
    }

    // MARK: Decisions

    @Test func decisionsAdvanceThroughThePortion() {
        var engine = SessionEngine(assetIDs: ["a", "b", "c"])
        #expect(engine.currentAssetID == "a")
        #expect(!engine.canUndo)

        engine.decide(.delete)
        #expect(engine.currentAssetID == "b")
        #expect(engine.currentIndex == 1)
        #expect(engine.canUndo)

        engine.decide(.keep(.buy))
        engine.decide(.delete)
        #expect(engine.isFinished)
        #expect(engine.currentAssetID == nil)
    }

    @Test func deletionsAreCollectedAndKeepsAreCounted() {
        var engine = SessionEngine(assetIDs: ["a", "b", "c"])
        engine.decide(.delete)
        engine.decide(.keep(.read))
        engine.decide(.delete)
        #expect(engine.assetIDsMarkedForDeletion == ["a", "c"])
        #expect(engine.keptCount == 1)
    }

    @Test func undoRevertsTheLastDecision() {
        var engine = SessionEngine(assetIDs: ["a", "b"])
        engine.decide(.keep(.cook))
        engine.decide(.delete)

        let undone = engine.undo()
        #expect(undone?.assetID == "b")
        #expect(undone?.decision == .delete)
        #expect(engine.currentAssetID == "b")
        #expect(!engine.isFinished)
        #expect(engine.assetIDsMarkedForDeletion.isEmpty)

        #expect(engine.undo()?.decision == .keep(.cook))
        #expect(engine.undo() == nil)
        #expect(!engine.canUndo)
    }

    @Test func decisionsAfterTheEndAreIgnored() {
        var engine = SessionEngine(assetIDs: ["a"])
        engine.decide(.delete)
        engine.decide(.keep(.buy))
        #expect(engine.decisions == [.delete])
    }

    @Test func aSkippedScreenshotIsNeitherKeptNorDeleted() {
        var engine = SessionEngine(assetIDs: ["a", "b"])
        engine.decide(.skip)
        engine.decide(.keep(.read))
        #expect(engine.isFinished)
        #expect(engine.assetIDsMarkedForDeletion.isEmpty)
        #expect(engine.keptCount == 1)
    }

    @Test func closingEarlyLeavesTheRestUndecided() {
        var engine = SessionEngine(assetIDs: ["a", "b", "c"])
        engine.decide(.delete)
        #expect(!engine.isFinished)
        #expect(engine.assetIDsMarkedForDeletion == ["a"])
        #expect(engine.keptCount == 0)
    }
}
