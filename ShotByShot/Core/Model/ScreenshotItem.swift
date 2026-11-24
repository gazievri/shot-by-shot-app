import Foundation
import SwiftData

/// A kept screenshot. Holds a reference to the Photos asset, never the image itself.
@Model
final class ScreenshotItem {
    @Attribute(.unique) var assetID: String
    var categoryRaw: String
    var note: String
    var addedAt: Date
    var takenAt: Date?
    var isDone: Bool
    var reminderAt: Date?
    var reminderNotificationID: String?
    var sensitivityRaw: String
    var markedNotSensitive: Bool
    /// First line of the text recognized in the screenshot; the title of its row when there
    /// is no note. Only set in a session, and never for a screenshot that looks private.
    var recognizedTitle: String?

    init(assetID: String, category: Category, takenAt: Date?, addedAt: Date = .now) {
        self.assetID = assetID
        self.categoryRaw = category.rawValue
        self.note = ""
        self.addedAt = addedAt
        self.takenAt = takenAt
        self.isDone = false
        self.sensitivityRaw = "none"
        self.markedNotSensitive = false
    }

    var category: Category {
        get { Category(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    /// The first line with anything in it, cut to a length a list row can make use of.
    nonisolated static func title(fromRecognizedText text: String) -> String? {
        let line = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        return line.map { String($0.prefix(200)) }
    }
}

@Model
final class CategoryTitle {
    @Attribute(.unique) var categoryRaw: String
    var title: String

    init(category: Category, title: String) {
        self.categoryRaw = category.rawValue
        self.title = title
    }
}

extension ModelContext {
    func screenshotItem(assetID: String) throws -> ScreenshotItem? {
        var descriptor = FetchDescriptor<ScreenshotItem>(predicate: #Predicate { $0.assetID == assetID })
        descriptor.fetchLimit = 1
        return try fetch(descriptor).first
    }
}
