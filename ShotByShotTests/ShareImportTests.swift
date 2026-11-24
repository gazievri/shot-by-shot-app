import Foundation
import SwiftData
import Testing
@testable import ShotByShot

@MainActor
struct ShareImportTests {
    let context = ModelContext(ModelContainer.shotByShot(inMemory: true))
    let defaults: UserDefaults
    let entry = ["filename": "IMG_0001.PNG", "category": Category.read.rawValue, "note": "Later"]

    init() {
        let suite = "share-import-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set([entry], forKey: ShareImport.pendingKey)
    }

    var pending: [[String: String]] {
        defaults.array(forKey: ShareImport.pendingKey) as? [[String: String]] ?? []
    }

    @Test func limitedAccessKeepsAnItemWhoseOriginalIsNotSelected() async throws {
        let library = PreviewPhotoLibrary(access: .limited)
        await ShareImport.run(defaults: defaults, library: library, context: context)
        #expect(pending == [entry])
        #expect(try context.fetchCount(FetchDescriptor<ScreenshotItem>()) == 0)
    }

    @Test func keptItemIsSavedOnceItsOriginalIsSelected() async throws {
        let library = PreviewPhotoLibrary(access: .limited)
        await ShareImport.run(defaults: defaults, library: library, context: context)
        library.assetIDsByFilename = ["IMG_0001.PNG": "preview-3"]
        await ShareImport.run(defaults: defaults, library: library, context: context)
        #expect(pending.isEmpty)
        let item = try #require(try context.screenshotItem(assetID: "preview-3"))
        #expect(item.category == .read)
        #expect(item.note == "Later")
    }

    @Test func fullAccessDropsAnItemWithoutAnOriginal() async throws {
        let library = PreviewPhotoLibrary(access: .full)
        await ShareImport.run(defaults: defaults, library: library, context: context)
        #expect(pending.isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<ScreenshotItem>()) == 0)
    }

    @Test func queueWaitsWhileThereIsNoAccess() async {
        let library = PreviewPhotoLibrary(access: .denied)
        await ShareImport.run(defaults: defaults, library: library, context: context)
        #expect(pending == [entry])
    }
}
