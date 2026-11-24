import Foundation
import SwiftData
import Testing
@testable import ShotByShot

@MainActor
struct SessionModelTests {
    @Test func reviewMoreLoadsASkippedScreenshotAgain() async throws {
        let library = PreviewPhotoLibrary(count: 1)
        library.unavailableIDs = ["preview-0"]
        let model = SessionModel(
            library: library, insight: PreviewInsightService(isAvailable: false),
            notifications: NotificationService(),
            context: ModelContext(ModelContainer.shotByShot(inMemory: true)),
            portionSize: 1, firstID: nil
        )
        model.start()
        try await wait { model.isUnavailable }
        await model.skip()
        #expect(model.phase == .summary)

        // The image can be loaded now, and the skipped screenshot is the only one left.
        library.unavailableIDs = []
        model.reviewMore()
        #expect(!model.isUnavailable)
        try await wait { model.isAssessed }
        #expect(!model.isUnavailable)
    }

    @Test func withoutModelTheSessionWorksOnTemplates() async throws {
        let context = ModelContext(ModelContainer.shotByShot(inMemory: true))
        // One sample only: the next two carry text the sensitivity rules react to.
        let model = SessionModel(
            library: PreviewPhotoLibrary(count: 1), insight: PreviewInsightService(isAvailable: false),
            notifications: NotificationService(),
            context: context, portionSize: 1, firstID: nil
        )
        model.start()
        try await wait { model.isAssessed }

        #expect(!model.isThinking)
        #expect(model.suggestedCategory == nil)
        let first = try #require(model.current)
        let captionContext = CaptionContext(takenAt: try #require(first.takenAt))
        let templates = CaptionTemplate.allCases.map { $0.text(captionContext) }
        #expect(templates.contains(try #require(model.caption)))

        await model.keep(in: .read)
        #expect(try context.screenshotItem(assetID: first.id)?.category == .read)
        #expect(model.phase == .summary)
    }

    private func wait(for condition: () -> Bool) async throws {
        for _ in 0..<100 where !condition() {
            try await Task.sleep(for: .milliseconds(50))
        }
        try #require(condition())
    }
}
