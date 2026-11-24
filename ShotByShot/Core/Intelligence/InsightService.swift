import FoundationModels
import UIKit

/// What the on-device model says about one screenshot.
nonisolated struct ScreenshotInsight: Equatable, Sendable {
    /// `nil` when the model refused or failed.
    var category: Category?
    /// A playful guess, always a question. `nil` when the model is not sure.
    var guess: String?
    /// A refusal or an error also counts as personal: no jokes about such a screenshot.
    var isPersonal = false

    /// The model is asked for a question of up to eight words; anything else is dropped,
    /// so a wrong guess reads as "missed", not as a statement about the person.
    static func sanitizedGuess(_ raw: String?) -> String? {
        guard let guess = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              guess.hasSuffix("?"),
              (1...8).contains(guess.split(separator: " ").count)
        else { return nil }
        return guess
    }
}

@MainActor
protocol InsightService: AnyObject, Sendable {
    /// Without Apple Intelligence the app works the same, minus suggestions.
    var isAvailable: Bool { get }
    /// One request returns everything the session screen needs.
    func insight(for image: UIImage) async -> ScreenshotInsight
}

final class SystemInsightService: InsightService {
    var isAvailable: Bool {
        // The model accepts images only since iOS 27. Earlier systems take the same path
        // as a device without Apple Intelligence, so nothing outside this service checks the version.
        guard #available(iOS 27, *) else { return false }
        return if case .available = SystemLanguageModel.default.availability { true } else { false }
    }

    func insight(for image: UIImage) async -> ScreenshotInsight {
        // Not reached while `isAvailable` is false; an empty answer means "no suggestion",
        // unlike a refusal, which would mark the screenshot as personal.
        guard #available(iOS 27, *) else { return ScreenshotInsight() }
        return await modelInsight(for: image)
    }

    @available(iOS 27, *)
    private func modelInsight(for image: UIImage) async -> ScreenshotInsight {
        // The on-device context is small and images share it with text.
        let scale = min(1, 1280 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        guard let cgImage = image.preparingThumbnail(of: size)?.cgImage else {
            return ScreenshotInsight(isPersonal: true)
        }
        do {
            // A new session per screenshot keeps answers independent of each other.
            let session = LanguageModelSession(instructions: Self.instructions)
            let response = try await session.respond(generating: GeneratedInsight.self) {
                "Describe this screenshot."
                Attachment(cgImage)
            }
            let generated = response.content
            return ScreenshotInsight(
                category: Category(rawValue: generated.category.rawValue),
                guess: generated.isPersonal ? nil : ScreenshotInsight.sanitizedGuess(generated.guess),
                isPersonal: generated.isPersonal
            )
        } catch {
            return ScreenshotInsight(isPersonal: true)
        }
    }

    private static let instructions = """
    You look at a phone screenshot and answer three things.

    1. category: the action the person most likely intended when taking it. Choose exactly one.
    buy: products, prices, wishlists
    read: articles, posts, threads, books
    watch: films, series, videos
    listen: music, podcasts, audiobooks
    cook: recipes, food to make
    go: places, restaurants, routes, travel
    attend: events, tickets, schedules, dates to remember
    todo: tasks, instructions, things to get done
    tryOut: apps, tools, tips or settings to try
    contact: people to reach, phone numbers, profiles
    keep: documents, bookings, receipts, reference information to look up again
    inspire: design ideas, outfits, interiors, quotes
    other: memes, chats, anything without a clear purpose

    2. guess: one playful question of at most 8 words about why the person saved it, \
    for example "Planning a haircut?" or "Still thinking about this desk?". \
    Tease the habit of saving, never people, messages, health, money or looks. \
    No names, no quotes, no dates, addresses or amounts from the screenshot. \
    Leave it empty if you are not sure.

    3. isPersonal: true if the screenshot shows private messages, documents, passwords, \
    codes, banking, medical or intimate content. If true, leave guess empty.
    """
}

@Generable
private struct GeneratedInsight {
    let category: GeneratedCategory
    @Guide(description: "A playful question of at most 8 words, or empty")
    let guess: String?
    let isPersonal: Bool
}

/// Mirrors the selectable cases of `Category`, which stays free of model-specific types.
@Generable
private enum GeneratedCategory: String {
    case buy, read, watch, listen, cook, go, attend, todo, tryOut, contact, keep, inspire, other
}

#if DEBUG
/// Answers after a short pause, so the "model is thinking" state can be seen in Previews.
final class PreviewInsightService: InsightService {
    let isAvailable: Bool

    init(isAvailable: Bool = true) {
        self.isAvailable = isAvailable
    }

    func insight(for image: UIImage) async -> ScreenshotInsight {
        try? await Task.sleep(for: .seconds(1))
        return ScreenshotInsight(category: .buy, guess: "Still thinking about this desk?")
    }
}
#endif
