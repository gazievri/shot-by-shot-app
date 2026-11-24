import PhotosUI
import SwiftData
import SwiftUI

/// L1. Kept screenshots grouped by category.
struct LibraryView: View {
    let library: any PhotoLibrary
    let onShowInbox: () -> Void
    let onShowSettings: () -> Void
    /// Set from outside to open a kept screenshot, e.g. from its reminder.
    @Binding var openedAssetID: String?
    /// Set from outside to open a category, e.g. after saving a screenshot into it.
    @Binding var openedCategory: Category?
    /// A screenshot was picked with "+"; the argument is its asset identifier.
    let onAdd: (String) -> Void

    @Query private var items: [ScreenshotItem]
    @State private var opened: ScreenshotItem?
    @State private var picked: PhotosPickerItem?
    @Environment(\.categoryTitles) private var titles

    private var groups: [LibraryGroup] {
        LibraryGroup.groups(from: items.map { ($0.category, $0.addedAt) })
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing saved yet", systemImage: "tray")
                    } description: {
                        Text("Screenshots you keep will appear here.")
                    } actions: {
                        Button("Review screenshots", action: onShowInbox)
                            .buttonStyle(.bordered)
                    }
                    .background(Color(.appBackground))
                } else {
                    List(groups) { group in
                        NavigationLink(value: group.category) {
                            LabeledContent {
                                Text(group.count, format: .number)
                            } label: {
                                CategoryLabel(category: group.category)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text(group.category.title(in: titles)))
                            .accessibilityValue(Text("\(group.count) screenshots"))
                        }
                        .cardRowBackground()
                    }
                    .listStyle(.insetGrouped)
                    .groupedScreenBackground()
                }
            }
            .navigationTitle("Library")
            .toolbarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gearshape", action: onShowSettings)
                }
                // The record keeps a reference to the asset, so adding needs access to the library.
                if library.access == .full || library.access == .limited {
                    ToolbarItem(placement: .primaryAction) {
                        PhotosPicker(selection: $picked, matching: .screenshots, photoLibrary: .shared()) {
                            Label("Add", systemImage: "plus")
                        }
                    }
                }
            }
            .navigationDestination(item: $openedCategory) { category in
                CategoryView(category: category, library: library)
            }
            .onChange(of: picked) { _, item in
                if let assetID = item?.itemIdentifier {
                    onAdd(assetID)
                }
                picked = nil
            }
            .navigationDestination(item: $opened) { item in
                ScreenshotView(item: item, library: library) { opened = nil }
            }
            .onChange(of: openedAssetID, initial: true) { _, assetID in
                guard let assetID else { return }
                opened = items.first { $0.assetID == assetID }
                openedAssetID = nil
            }
            .navigationDestination(for: Category.self) { category in
                CategoryView(category: category, library: library)
            }
        }
    }
}

#if DEBUG
extension ModelContainer {
    /// In-memory store with a few kept screenshots that match `PreviewPhotoLibrary`.
    static var librarySample: ModelContainer {
        let container = ModelContainer.shotByShot(inMemory: true)
        let categories: [Category] = [.buy, .buy, .read, .go, .cook, .buy]
        for (index, category) in categories.enumerated() {
            let item = ScreenshotItem(
                assetID: "preview-\(index)", category: category,
                takenAt: Date(timeIntervalSinceNow: -Double(index) * 40 * 86_400),
                addedAt: Date(timeIntervalSinceNow: -Double(index) * 3_600)
            )
            item.isDone = index == 1
            item.note = index == 0 ? "Desk lamp for the hallway" : ""
            container.mainContext.insert(item)
        }
        return container
    }
}

#Preview("L1 Library") {
    LibraryView(library: PreviewPhotoLibrary(), onShowInbox: {}, onShowSettings: {}, openedAssetID: .constant(nil), openedCategory: .constant(nil), onAdd: { _ in })
        .modelContainer(.librarySample)
}

#Preview("L1 Dark") {
    LibraryView(library: PreviewPhotoLibrary(), onShowInbox: {}, onShowSettings: {}, openedAssetID: .constant(nil), openedCategory: .constant(nil), onAdd: { _ in })
        .modelContainer(.librarySample)
        .preferredColorScheme(.dark)
}

#Preview("L1 Empty") {
    LibraryView(library: PreviewPhotoLibrary(), onShowInbox: {}, onShowSettings: {}, openedAssetID: .constant(nil), openedCategory: .constant(nil), onAdd: { _ in })
        .modelContainer(.shotByShot(inMemory: true))
}
#endif
