import SwiftData
import SwiftUI
import WidgetKit

/// Root navigation. Features do not know about each other; transitions between them live here.
struct RootView: View {
    let library: any PhotoLibrary
    let insight: any InsightService

    @Environment(AppSettings.self) private var settings
    @Environment(NotificationService.self) private var notifications
    @Environment(PrivateLock.self) private var privateLock
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var items: [ScreenshotItem]
    @Query private var logs: [DayLog]
    @Query private var categoryTitles: [CategoryTitle]
    @State private var selectedTab = AppTab.library
    @State private var session: SessionRequest?
    @State private var showsSettings = false
    @State private var openedAssetID: String?
    @State private var openedCategory: Category?
    @State private var addRequest: AddRequest?

    private var inboxCount: Int {
        library.inbox(excluding: Set(items.map(\.assetID))).count
    }

    var body: some View {
        Group {
            if settings.hasCompletedOnboarding {
                tabs
            } else {
                OnboardingView(
                    library: library,
                    onReview: { session = SessionRequest(firstID: nil, portionSize: 3) },
                    onFinish: finishOnboarding
                )
            }
        }
        .fullScreenCover(item: $session, onDismiss: {
            // The first session is part of onboarding: whatever its outcome, the app opens on Inbox.
            if !settings.hasCompletedOnboarding {
                finishOnboarding(showInbox: true)
            }
            syncReminderAndWidget()
        }) { request in
            SessionView(
                library: library, insight: insight, notifications: notifications, context: modelContext,
                portionSize: request.portionSize, firstID: request.firstID
            )
        }
        .sheet(isPresented: $showsSettings, onDismiss: syncReminderAndWidget) {
            SettingsView(library: library)
        }
        .sheet(item: $addRequest) { request in
            AddScreenshotView(assetID: request.id, library: library, insight: insight) { category in
                // After saving, Library opens the category the screenshot went to.
                openedCategory = category
            }
        }
        .environment(\.categoryTitles, Dictionary(
            categoryTitles.map { ($0.categoryRaw, $0.title) }, uniquingKeysWith: { first, _ in first }
        ))
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                library.refreshAccess()
                syncReminderAndWidget()
            }
            // Private locks again as soon as the app leaves the screen.
            if phase == .background { privateLock.lock() }
        }
        .onChange(of: inboxCount) { syncReminderAndWidget() }
        .onChange(of: library.access) { syncReminderAndWidget() }
        // Tapping the daily notification opens a session right away.
        .onChange(of: notifications.sessionRequests) { openSession() }
        // Tapping a screenshot reminder opens that screenshot in Library.
        .onChange(of: notifications.openedAssetID) { _, assetID in
            guard let assetID, settings.hasCompletedOnboarding else { return }
            notifications.openedAssetID = nil
            session = nil
            showsSettings = false
            selectedTab = .library
            openedAssetID = assetID
        }
        // The widget opens a session while a portion is waiting, and Inbox otherwise.
        .onOpenURL { url in
            guard url.scheme == "shotbyshot", settings.hasCompletedOnboarding else { return }
            if url.host() == "session" {
                openSession()
            } else {
                selectedTab = .inbox
            }
        }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            Tab("Library", systemImage: "books.vertical", value: AppTab.library) {
                LibraryView(
                    library: library,
                    onShowInbox: { selectedTab = .inbox },
                    onShowSettings: { showsSettings = true },
                    openedAssetID: $openedAssetID,
                    openedCategory: $openedCategory,
                    onAdd: { addRequest = AddRequest(id: $0) }
                )
            }
            Tab("Inbox", systemImage: "tray.and.arrow.down", value: AppTab.inbox) {
                InboxView(library: library) { firstID in
                    session = SessionRequest(firstID: firstID, portionSize: settings.portionSize)
                }
            }
        }
    }

    private func importSharedScreenshots() {
        guard let defaults = UserDefaults(suiteName: AppSettings.appGroupID) else { return }
        Task { await ShareImport.run(defaults: defaults, library: library, context: modelContext) }
    }

    private func openSession() {
        guard settings.hasCompletedOnboarding, session == nil else { return }
        showsSettings = false
        selectedTab = .inbox
        if inboxCount > 0 {
            session = SessionRequest(firstID: nil, portionSize: settings.portionSize)
        }
    }

    private func finishOnboarding(showInbox: Bool) {
        selectedTab = showInbox ? .inbox : .library
        settings.hasCompletedOnboarding = true
    }

    /// The reminder must not fire once today's portion is done or the inbox is empty,
    /// and the widget shows the same state, so both follow every change of it.
    private func syncReminderAndWidget() {
        importSharedScreenshots()
        let enabled = settings.reminderEnabled
        let minutes = settings.reminderMinutes
        let portion = min(settings.portionSize, inboxCount)
        let progress = RitualProgress(logs: logs)
        let hasStarToday = progress.hasStarToday
        if let defaults = UserDefaults(suiteName: AppSettings.appGroupID) {
            WidgetSnapshot(
                hasAccess: library.access == .full || library.access == .limited,
                portion: portion, isDoneToday: hasStarToday,
                nights: progress.nightsLit, day: Calendar.current.startOfDay(for: .now)
            ).write(to: defaults)
            WidgetCenter.shared.reloadAllTimelines()
        }
        Task {
            await notifications.scheduleDaily(
                enabled: enabled, minutesFromMidnight: minutes, portion: portion, skipToday: hasStarToday
            )
        }
    }
}

private enum AppTab {
    case library, inbox
}

private struct AddRequest: Identifiable {
    /// Identifier of the picked asset.
    let id: String
}

private struct SessionRequest: Identifiable {
    let id = UUID()
    let firstID: String?
    let portionSize: Int
}

#if DEBUG
#Preview("Light") {
    RootView(library: PreviewPhotoLibrary(), insight: PreviewInsightService())
        .environment(AppSettings(defaults: UserDefaults(suiteName: "preview")!))
        .environment(NotificationService())
        .environment(PrivateLock())
        .modelContainer(.shotByShot(inMemory: true))
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    RootView(library: PreviewPhotoLibrary(), insight: PreviewInsightService())
        .environment(AppSettings(defaults: UserDefaults(suiteName: "preview")!))
        .environment(NotificationService())
        .environment(PrivateLock())
        .modelContainer(.shotByShot(inMemory: true))
        .preferredColorScheme(.dark)
}
#endif
