import Foundation

/// The decisions of one review session. Pure state: saving kept screenshots and
/// deleting from Photos is done by the caller.
nonisolated struct SessionEngine: Equatable, Sendable {
    enum Decision: Equatable, Sendable {
        case delete
        case keep(Category)
        /// Kept like `keep`, with a reminder on top.
        case remind(Category, Date)
        /// Hidden in Photos: leaves the inbox without a record and without being deleted.
        case hide
        /// The image could not be loaded: left in the inbox without a decision.
        case skip
    }

    let assetIDs: [String]
    private(set) var decisions: [Decision] = []

    init(assetIDs: [String]) {
        self.assetIDs = assetIDs
    }

    /// Picks up to `size` random screenshots from the inbox. A screenshot tapped
    /// in the grid goes first; the rest are random.
    static func portion(from inbox: [String], size: Int, first: String? = nil) -> [String] {
        guard size > 0 else { return [] }
        guard let first, inbox.contains(first) else {
            return Array(inbox.shuffled().prefix(size))
        }
        let rest = inbox.filter { $0 != first }.shuffled().prefix(size - 1)
        return [first] + rest
    }

    var currentIndex: Int { decisions.count }
    var isFinished: Bool { currentIndex >= assetIDs.count }
    var canUndo: Bool { !decisions.isEmpty }

    var currentAssetID: String? {
        isFinished ? nil : assetIDs[currentIndex]
    }

    mutating func decide(_ decision: Decision) {
        guard !isFinished else { return }
        decisions.append(decision)
    }

    /// Reverts the last decision and returns it so the caller can undo its side effects.
    @discardableResult
    mutating func undo() -> (assetID: String, decision: Decision)? {
        guard let decision = decisions.popLast() else { return nil }
        return (assetIDs[decisions.count], decision)
    }

    /// Deletions are collected and sent to Photos as one batch, so the system asks once.
    var assetIDsMarkedForDeletion: [String] {
        zip(assetIDs, decisions).compactMap { $1 == .delete ? $0 : nil }
    }

    var keptCount: Int {
        decisions.count { decision in
            switch decision {
            case .keep, .remind: true
            case .delete, .hide, .skip: false
            }
        }
    }
}
