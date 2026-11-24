import Foundation
import SwiftData

/// One row of the Library list.
nonisolated struct LibraryGroup: Hashable, Identifiable, Sendable {
    let category: Category
    let count: Int

    var id: Category { category }

    /// Groups kept screenshots by category. Empty categories are left out, the most
    /// recently used category comes first, and Private is always last.
    static func groups(from entries: [(category: Category, addedAt: Date)]) -> [LibraryGroup] {
        var counts: [Category: Int] = [:]
        var latest: [Category: Date] = [:]
        for entry in entries {
            counts[entry.category, default: 0] += 1
            latest[entry.category] = max(latest[entry.category] ?? .distantPast, entry.addedAt)
        }
        return counts.keys
            .sorted { lhs, rhs in
                if (lhs == .private) != (rhs == .private) { return rhs == .private }
                return latest[lhs, default: .distantPast] > latest[rhs, default: .distantPast]
            }
            .map { LibraryGroup(category: $0, count: counts[$0, default: 0]) }
    }
}

/// Delete removes the original from Photos, after the system confirmation, and the record with it.
/// Returns `false` when the person declines.
func deleteFromPhotos(_ item: ScreenshotItem, library: any PhotoLibrary, context: ModelContext) async -> Bool {
    let assetID = item.assetID
    let size = await library.byteSize(of: [assetID])
    guard await library.delete([assetID]) else { return false }
    context.removeRecord(item, freedBytes: size)
    return true
}

extension ModelContext {
    /// For a screenshot whose original has just been deleted from Photos.
    func removeRecord(_ item: ScreenshotItem, freedBytes: Int64) {
        delete(item)
        if let log = try? dayLog() {
            log.deleted += 1
            log.freedBytes += freedBytes
        }
    }
}
