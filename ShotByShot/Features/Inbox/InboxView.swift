import SwiftData
import SwiftUI

/// I1. Unsorted screenshots and the entry point to a review session.
struct InboxView: View {
    let library: any PhotoLibrary
    /// Start a session. The argument is the screenshot to show first, if one was tapped.
    let onReview: (_ firstID: String?) -> Void

    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query private var items: [ScreenshotItem]
    @Query private var logs: [DayLog]

    private var inbox: [Screenshot] {
        library.inbox(excluding: Set(items.map(\.assetID)))
    }

    var body: some View {
        NavigationStack {
            content
                .background(Color(.appBackground))
                .navigationTitle("Inbox")
                .toolbarTitleDisplayMode(.large)
        }
    }

    @ViewBuilder
    private var content: some View {
        let inbox = inbox
        switch library.access {
        case .notDetermined, .denied:
            ContentUnavailableView {
                Label("Inbox needs access to all photos", systemImage: "lock")
            } description: {
                Text("Shot by Shot reviews screenshots directly from your library.")
            } actions: {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .buttonStyle(.bordered)
            }
        case .full, .limited:
            if library.isLoading {
                // Not "all caught up" yet: the library is still being read.
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if inbox.isEmpty {
                ScrollView {
                    VStack(spacing: 8) {
                        CityScene(state: .empty, progress: RitualProgress(logs: logs))
                        Text("All caught up")
                            .font(.title3)
                            .bold()
                            .accessibilityAddTraits(.isHeader)
                        Text("Every window is lit. Nothing left to sort.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)
                }
                // With nothing left to sort, opening the app keeps the ritual going.
                .task {
                    try? modelContext.countDayWithEmptyInbox()
                }
            } else {
                grid(inbox)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                onReview(nil)
                            } label: {
                                Text("Review \(min(settings.portionSize, inbox.count))")
                                    .foregroundStyle(Color(.onAccent))
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
            }
        }
    }

    private func grid(_ inbox: [Screenshot]) -> some View {
        ScrollView {
            // An ordinary first item: it scrolls away with the title, no parallax.
            CityScene(state: sceneState(portion: min(settings.portionSize, inbox.count)), progress: RitualProgress(logs: logs))
            if library.access == .limited {
                limitedAccessNotice
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                ForEach(inbox) { screenshot in
                    Button {
                        onReview(screenshot.id)
                    } label: {
                        // Screen proportions of an iPhone, so the grid stays even
                        // whatever the size of the original.
                        Color.clear
                            .aspectRatio(9 / 19.5, contentMode: .fit)
                            .overlay {
                                AssetImage(library: library, id: screenshot.id, size: .thumbnail, contentMode: .fill)
                            }
                            .clipShape(.rect(cornerRadius: 8))
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Screenshot"))
                    .accessibilityValue(screenshot.takenAt.map { Text($0, format: .dateTime.day().month().year()) } ?? Text(verbatim: ""))
                    .contextMenu {
                        Button("Review", systemImage: "rectangle.stack") {
                            onReview(screenshot.id)
                        }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            Task { await delete(screenshot) }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    /// Inbox keeps working with the selected photos; this explains why it shows so few.
    private var limitedAccessNotice: some View {
        VStack(spacing: 8) {
            Text("Limited photo access")
                .font(.headline)
            Text("Shot by Shot sees only the screenshots you selected. Daily picks from your whole library need full access.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ViewThatFits {
                HStack { limitedAccessButtons }
                VStack { limitedAccessButtons }
            }
            .buttonStyle(.bordered)
        }
        .multilineTextAlignment(.center)
        .padding()
    }

    @ViewBuilder
    private var limitedAccessButtons: some View {
        Button("Select More Photos") {
            library.presentLimitedLibraryPicker()
        }
        Button("Allow Full Access") {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        }
    }

    private func sceneState(portion: Int) -> CityState {
        let progress = RitualProgress(logs: logs)
        if progress.hasStarToday { return .done(newStar: false) }
        if progress.skippedYesterday { return .skipped(clouds: portion) }
        return .waiting(clouds: portion)
    }

    private func delete(_ screenshot: Screenshot) async {
        let size = await library.byteSize(of: [screenshot.id])
        guard await library.delete([screenshot.id]) else { return }
        try? modelContext.dayLog().add(kept: 0, deleted: 1, freedBytes: size, completed: false)
    }
}

#if DEBUG
#Preview("Inbox") {
    InboxView(library: PreviewPhotoLibrary(), onReview: { _ in })
        .environment(AppSettings(defaults: UserDefaults(suiteName: "preview")!))
        .modelContainer(.shotByShot(inMemory: true))
}

#Preview("Inbox Dark") {
    InboxView(library: PreviewPhotoLibrary(), onReview: { _ in })
        .environment(AppSettings(defaults: UserDefaults(suiteName: "preview")!))
        .modelContainer(.shotByShot(inMemory: true))
        .preferredColorScheme(.dark)
}

#Preview("All caught up") {
    InboxView(library: PreviewPhotoLibrary(count: 0), onReview: { _ in })
        .environment(AppSettings(defaults: UserDefaults(suiteName: "preview")!))
        .modelContainer(.shotByShot(inMemory: true))
}

#Preview("No access") {
    InboxView(library: PreviewPhotoLibrary(access: .denied, count: 0), onReview: { _ in })
        .environment(AppSettings(defaults: UserDefaults(suiteName: "preview")!))
        .modelContainer(.shotByShot(inMemory: true))
}

#Preview("Limited access") {
    InboxView(library: PreviewPhotoLibrary(access: .limited, count: 5), onReview: { _ in })
        .environment(AppSettings(defaults: UserDefaults(suiteName: "preview")!))
        .modelContainer(.shotByShot(inMemory: true))
}
#endif
