import Foundation
import Observation
import SwiftData
import UIKit

/// Drives one review session: applies the engine's decisions to the library and the store.
@Observable
final class SessionModel {
    enum Phase {
        case reviewing, finishing, summary
    }

    private(set) var portion: [Screenshot]
    private(set) var engine: SessionEngine
    private(set) var phase = Phase.reviewing
    private(set) var stats = ReviewStats()
    private(set) var doneToday = 0
    private(set) var progress = RitualProgress()
    /// Whether this portion lit a star; `RitualRules.starPerSession` decides how often that happens.
    private(set) var earnedStar = false
    /// Size of the next portion; zero when the inbox is empty.
    private(set) var nextPortionCount = 0

    // Answers are keyed by asset, so a late one never lands on another screenshot.
    private var insights: [String: ScreenshotInsight] = [:]
    private var captions: [String: String] = [:]
    private var actions: [String: [ContextAction]] = [:]
    private var sensitivities: [String: Sensitivity] = [:]
    private var texts: [String: String] = [:]
    /// Blur lifted with Show; lasts only while this screenshot is on screen in this session.
    private var revealed: Set<String> = []
    /// "Not sensitive": remembered for the session and saved with the screenshot if it is kept.
    private var cleared: Set<String> = []
    /// Deleted or hidden right away rather than at the end; such decisions cannot be undone.
    private var deletedNow: Set<String> = []
    private var hiddenNow: Set<String> = []
    /// The image could not be loaded: there is nothing to decide on, only to skip.
    private var unavailable: Set<String> = []
    /// The sensitivity check took too long; such a screenshot is shown as an ordinary one.
    private var assessmentTimedOut: Set<String> = []
    /// The model took too long; such a screenshot gets no suggestion, as without a model.
    private var insightTimedOut: Set<String> = []

    @ObservationIgnored private let library: any PhotoLibrary
    @ObservationIgnored private let insight: any InsightService
    @ObservationIgnored private let notifications: NotificationService
    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let portionSize: Int
    @ObservationIgnored private var rotation = CaptionRotation()
    @ObservationIgnored private var prepared: Set<String> = []
    @ObservationIgnored private var freedNow: Int64 = 0
    @ObservationIgnored private var hasStarted = false
    /// The model is asked about one screenshot at a time, in the order they are shown.
    @ObservationIgnored private var lastInsightTask: Task<Void, Never>?

    init(
        library: any PhotoLibrary, insight: any InsightService, notifications: NotificationService,
        context: ModelContext, portionSize: Int, firstID: String?
    ) {
        self.library = library
        self.insight = insight
        self.notifications = notifications
        self.context = context
        self.portionSize = portionSize
        let portion = Self.makePortion(library: library, context: context, size: portionSize, firstID: firstID)
        self.portion = portion
        self.engine = SessionEngine(assetIDs: portion.map(\.id))
    }

    /// Starts loading the first screenshots. Not part of `init`: SwiftUI may create this
    /// model again whenever the parent view updates and throw the copy away, and every
    /// such copy used to load, recognize and ask the model about screenshots of its own.
    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        prepareUpcoming()
    }

    var current: Screenshot? {
        engine.isFinished ? nil : portion[engine.currentIndex]
    }

    // MARK: What the model and the detectors say about the current screenshot

    /// The model has been asked and has not answered yet. Buttons stay active meanwhile.
    var isThinking: Bool {
        guard let current else { return false }
        return insight.isAvailable && insights[current.id] == nil
            && !insightTimedOut.contains(current.id) && !unavailable.contains(current.id)
    }

    /// Nothing is shown until the screenshot has been checked, so private content never flashes by.
    var isAssessed: Bool {
        guard let current else { return false }
        return sensitivities[current.id] != nil || assessmentTimedOut.contains(current.id)
    }

    var isUnavailable: Bool {
        current.map { unavailable.contains($0.id) } ?? false
    }

    /// Called when a screenshot comes up. Neither the sensitivity check nor the model is
    /// waited for longer than three seconds: after that the screenshot is shown as an
    /// ordinary one and handled as if there were no model. Late results are not applied
    /// to a screenshot the person is already looking at.
    func limitWaiting(for screenshot: Screenshot) async {
        try? await Task.sleep(for: .seconds(3))
        guard !Task.isCancelled else { return }
        if sensitivities[screenshot.id] == nil {
            assessmentTimedOut.insert(screenshot.id)
        }
        if insight.isAvailable, insights[screenshot.id] == nil {
            insightTimedOut.insert(screenshot.id)
            captions[screenshot.id] = templateCaption(for: screenshot)
        }
    }

    /// Text rules and the system analyzer first; the model's "personal" flag on top.
    var sensitivity: Sensitivity {
        guard let current, !cleared.contains(current.id), !assessmentTimedOut.contains(current.id) else { return .none }
        let assessed = sensitivities[current.id] ?? .none
        if assessed == .none, insights[current.id]?.isPersonal == true { return .personal }
        return assessed
    }

    var isBlurred: Bool {
        guard let current else { return false }
        return sensitivity != .none && !revealed.contains(current.id)
    }

    var suggestedCategory: Category? {
        sensitivity != .none ? .private : current.flatMap { insights[$0.id]?.category }
    }

    /// Any signal turns the jokes off; a secret gets a warning card instead of a caption.
    var caption: String? {
        switch sensitivity {
        case .none: current.flatMap { captions[$0.id] }
        case .secret: nil
        case .personal, .explicit: String(localized: "Looks private")
        }
    }

    var contextActions: [ContextAction] {
        sensitivity == .none ? current.flatMap { actions[$0.id] } ?? [] : []
    }

    var recognizedText: String {
        current.flatMap { texts[$0.id] } ?? ""
    }

    var canUndo: Bool {
        guard engine.canUndo else { return false }
        let last = engine.assetIDs[engine.currentIndex - 1]
        return !deletedNow.contains(last) && !hiddenNow.contains(last)
    }

    func reveal() {
        if let current { revealed.insert(current.id) }
    }

    func markNotSensitive() {
        if let current { cleared.insert(current.id) }
    }

    // MARK: Decisions

    func keep(in category: Category) async {
        guard phase == .reviewing, let current else { return }
        // Kept screenshots are saved right away; only deletions wait for the end of the session.
        context.insert(makeItem(for: current, in: category))
        engine.decide(.keep(category))
        await advance()
    }

    /// For personal screenshots: moves the original to Hidden in Photos, with no record here.
    func hideInPhotos() async {
        guard phase == .reviewing, let current, await library.hide([current.id]) else { return }
        hiddenNow.insert(current.id)
        engine.decide(.hide)
        await advance()
    }

    /// S3: a secret should not wait for the end of the session, so it is deleted right away.
    /// Returns `false` when the person declines the system confirmation.
    func deleteNow() async -> Bool {
        guard phase == .reviewing, let current else { return false }
        let size = await library.byteSize(of: [current.id])
        guard await library.delete([current.id]) else { return false }
        deletedNow.insert(current.id)
        freedNow += size
        engine.decide(.delete)
        await advance()
        return true
    }

    /// Keeps the screenshot in the suggested category, or in Other without a suggestion,
    /// and adds a reminder. Without notification permission it is kept without one.
    func remind(at date: Date, categoryTitles: [String: String]) async {
        guard phase == .reviewing, let current else { return }
        let category = suggestedCategory ?? .other
        let item = makeItem(for: current, in: category)
        context.insert(item)
        engine.decide(.remind(category, date))
        await notifications.setReminder(date, for: item, categoryTitle: category.title(in: categoryTitles))
        await advance()
    }

    func delete() async {
        guard phase == .reviewing else { return }
        engine.decide(.delete)
        await advance()
    }

    /// For a screenshot whose image could not be loaded: it stays in the inbox, undecided.
    func skip() async {
        guard phase == .reviewing else { return }
        engine.decide(.skip)
        await advance()
    }

    func undo() {
        guard phase == .reviewing, canUndo, let undone = engine.undo(),
              let item = try? context.screenshotItem(assetID: undone.assetID)
        else { return }
        // An undone Delete or Skip leaves no record behind and stops at the guard above.
        // Undoing Remind takes back both the record and the notification.
        if item.reminderNotificationID != nil {
            Task { await notifications.setReminder(nil, for: item, categoryTitle: "") }
        }
        context.delete(item)
    }

    /// Closing early keeps the decisions made so far; the rest stays in the inbox.
    func close() async {
        guard phase == .reviewing else { return }
        guard engine.canUndo else {
            library.stopPreheating()
            return
        }
        await finish(completed: false)
    }

    func reviewMore() {
        portion = Self.makePortion(library: library, context: context, size: portionSize, firstID: nil)
        engine = SessionEngine(assetIDs: portion.map(\.id))
        deletedNow = []
        hiddenNow = []
        freedNow = 0
        // A screenshot skipped because its image did not load is still in the inbox and may
        // come up again: it gets a fresh attempt instead of the remembered failure.
        prepared.subtract(unavailable)
        for id in unavailable { sensitivities[id] = nil }
        unavailable = []
        phase = .reviewing
        prepareUpcoming()
    }

    private func advance() async {
        if engine.isFinished {
            await finish(completed: true)
        } else {
            prepareUpcoming()
        }
    }

    private func finish(completed: Bool) async {
        phase = .finishing
        library.stopPreheating()
        let idsToDelete = engine.assetIDsMarkedForDeletion.filter { !deletedNow.contains($0) }
        var deleted = deletedNow.count
        var freedBytes = freedNow
        if !idsToDelete.isEmpty {
            let size = await library.byteSize(of: idsToDelete)
            // Declining the system confirmation leaves these screenshots in the inbox, undecided.
            if await library.delete(idsToDelete) {
                deleted += idsToDelete.count
                freedBytes += size
            }
        }
        if let log = try? context.dayLog() {
            let hadStar = log.hasStar
            let wasComplete = ((try? context.progress()) ?? RitualProgress()).isConstellationComplete
            log.add(kept: engine.keptCount, deleted: deleted, freedBytes: freedBytes, completed: completed)
            doneToday = log.reviewed
            earnedStar = completed && (RitualRules.starPerSession ? !wasComplete : !hadStar)
        }
        try? context.save()
        progress = (try? context.progress()) ?? RitualProgress()
        stats = (try? context.reviewStats()) ?? ReviewStats()
        nextPortionCount = min(portionSize, Self.inbox(library: library, context: context).count)
        phase = .summary
    }

    // MARK: Preparing screenshots

    /// Prepares the current screenshot and the next two: their images, whatever the
    /// detectors find in the text, and the model's answer, so that "the model is thinking"
    /// is rarely seen.
    private func prepareUpcoming() {
        let upcoming = portion.dropFirst(engine.currentIndex).prefix(3)
        library.preheat(upcoming.dropFirst().map(\.id))
        for screenshot in upcoming where prepared.insert(screenshot.id).inserted {
            if !insight.isAvailable {
                captions[screenshot.id] = templateCaption(for: screenshot)
            }
            // One load feeds both the detectors and the model.
            let loading = Task { await library.image(for: screenshot.id, size: .screen) }
            Task {
                guard let cgImage = await loading.value?.cgImage else {
                    unavailable.insert(screenshot.id)
                    sensitivities[screenshot.id] = Sensitivity.none
                    return
                }
                let text = await TextRecognizer.text(in: cgImage)
                texts[screenshot.id] = text
                actions[screenshot.id] = ContextAction.detect(in: text)
                let sensitivity = await SensitivityCheck.assess(text: text, image: cgImage)
                sensitivities[screenshot.id] = sensitivity
                // Kept before the text was recognized: the record gets its title now.
                if sensitivity == .none, insights[screenshot.id]?.isPersonal != true,
                   let item = try? context.screenshotItem(assetID: screenshot.id) {
                    item.recognizedTitle = ScreenshotItem.title(fromRecognizedText: text)
                }
            }
            guard insight.isAvailable else { continue }
            // The model does not wait for the detectors, only for its turn.
            let previous = lastInsightTask
            lastInsightTask = Task {
                await previous?.value
                guard let image = await loading.value else { return }
                let answer = await insight.insight(for: image)
                guard !insightTimedOut.contains(screenshot.id) else { return }
                insights[screenshot.id] = answer
                // A personal screenshot gets no guess; the template is only a fallback
                // for the case where the person says it is not sensitive after all.
                captions[screenshot.id] = answer.isPersonal
                    ? templateCaption(for: screenshot)
                    : answer.guess ?? templateCaption(for: screenshot)
            }
        }
    }

    private func makeItem(for screenshot: Screenshot, in category: Category) -> ScreenshotItem {
        let item = ScreenshotItem(assetID: screenshot.id, category: category, takenAt: screenshot.takenAt)
        item.sensitivityRaw = (sensitivities[screenshot.id] ?? .none).rawValue
        item.markedNotSensitive = cleared.contains(screenshot.id)
        // Text from a screenshot that looks private stays out of the list.
        if sensitivities[screenshot.id] == Sensitivity.none, insights[screenshot.id]?.isPersonal != true,
           let text = texts[screenshot.id] {
            item.recognizedTitle = ScreenshotItem.title(fromRecognizedText: text)
        }
        return item
    }

    private func templateCaption(for screenshot: Screenshot) -> String? {
        guard let takenAt = screenshot.takenAt else { return nil }
        let sameMinute = library.screenshots.count {
            $0.takenAt.map { Calendar.current.isDate($0, equalTo: takenAt, toGranularity: .minute) } ?? false
        }
        let captionContext = CaptionContext(takenAt: takenAt, sameMinuteCount: max(1, sameMinute))
        return rotation.next(for: captionContext).text(captionContext)
    }

    private static func inbox(library: any PhotoLibrary, context: ModelContext) -> [Screenshot] {
        let items = (try? context.fetch(FetchDescriptor<ScreenshotItem>())) ?? []
        return library.inbox(excluding: Set(items.map(\.assetID)))
    }

    private static func makePortion(
        library: any PhotoLibrary, context: ModelContext, size: Int, firstID: String?
    ) -> [Screenshot] {
        let inbox = inbox(library: library, context: context)
        let byID = Dictionary(uniqueKeysWithValues: inbox.map { ($0.id, $0) })
        return SessionEngine.portion(from: inbox.map(\.id), size: size, first: firstID).compactMap { byID[$0] }
    }
}
