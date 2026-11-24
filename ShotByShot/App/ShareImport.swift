import Foundation
import SwiftData

/// Screenshots sent through the Share Extension wait in the App Group as file names.
/// Here they are matched to assets and become ordinary records. The keys mirror
/// `ShareModel.save` in the extension; the two targets share no code.
enum ShareImport {
    static let pendingKey = "share.pending"

    static func run(defaults: UserDefaults, library: any PhotoLibrary, context: ModelContext) async {
        guard !library.isLoading, library.access == .full || library.access == .limited,
              let pending = defaults.array(forKey: pendingKey) as? [[String: String]], !pending.isEmpty
        else { return }
        // Taken before the first suspension, so a second run started meanwhile finds nothing.
        defaults.removeObject(forKey: pendingKey)
        var unmatched: [[String: String]] = []
        for entry in pending {
            guard let filename = entry["filename"] else { continue }
            guard let assetID = await library.assetID(forFilename: filename) else {
                // With limited access the original may just not be selected yet, so the item
                // waits for the next attempt. With full access there is nothing to refer to.
                if library.access == .limited { unmatched.append(entry) }
                continue
            }
            let category = Category(rawValue: entry["category"] ?? "") ?? .other
            let takenAt = library.screenshots.first { $0.id == assetID }?.takenAt
            // A screenshot already in Library is updated, not saved twice.
            let item = (try? context.screenshotItem(assetID: assetID))
                ?? ScreenshotItem(assetID: assetID, category: category, takenAt: takenAt)
            item.category = category
            if let note = entry["note"], !note.isEmpty { item.note = note }
            if item.modelContext == nil { context.insert(item) }
        }
        if !unmatched.isEmpty {
            // The extension may have added items while this ran; they stay after the old ones.
            let added = defaults.array(forKey: pendingKey) as? [[String: String]] ?? []
            defaults.set(unmatched + added, forKey: pendingKey)
        }
    }
}
