import SwiftData
import SwiftUI

/// L2. Screenshots of one category.
struct CategoryView: View {
    let category: Category
    let library: any PhotoLibrary

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(NotificationService.self) private var notifications
    @Environment(PrivateLock.self) private var lock
    @Environment(\.categoryTitles) private var titles
    @Query private var items: [ScreenshotItem]
    @State private var newestFirst = true
    @State private var showDone = true
    @State private var opened: ScreenshotItem?
    @State private var remindTarget: ScreenshotItem?

    init(category: Category, library: any PhotoLibrary) {
        self.category = category
        self.library = library
        let raw = category.rawValue
        _items = Query(filter: #Predicate<ScreenshotItem> { $0.categoryRaw == raw })
    }

    private var visibleItems: [ScreenshotItem] {
        items
            .filter { showDone || !$0.isDone }
            .sorted { newestFirst ? $0.addedAt > $1.addedAt : $0.addedAt < $1.addedAt }
    }

    var body: some View {
        if category == .private && !lock.isUnlocked {
            PrivateLockedView()
                .navigationTitle(category.title(in: titles))
                .navigationBarTitleDisplayMode(.inline)
        } else {
            list
        }
    }

    private var list: some View {
        List(visibleItems) { item in
            // A button, not a NavigationLink: the trailing edge shows status, not a chevron.
            Button {
                opened = item
            } label: {
                ScreenshotRow(item: item, library: library)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .listRowBackground(Color(.appBackground))
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    delete(item)
                }
            }
            .swipeActions(edge: .leading) {
                Button("Remind", systemImage: "bell") {
                    remindTarget = item
                }
                .tint(.accentColor)
            }
            .contextMenu {
                Menu("Remind", systemImage: "bell") {
                    RemindMenuItems(
                        onPick: { date in remind(item, at: date) },
                        onPickDate: { remindTarget = item }
                    )
                }
                ScreenshotMenuItems(
                    assetID: item.assetID, isDone: item.isDone, library: library, isRowMenu: true,
                    onMove: { item.category = $0 },
                    onMarkDone: { item.isDone = true },
                    onRemove: {
                        notifications.cancelReminder(withID: item.reminderNotificationID)
                        modelContext.delete(item)
                    }
                )
                Button("Delete", systemImage: "trash", role: .destructive) {
                    delete(item)
                }
            } preview: {
                AssetImage(library: library, id: item.assetID)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.appBackground))
        .sheet(item: $remindTarget) { item in
            PickDateSheet { date in
                remind(item, at: date)
            }
        }
        .navigationDestination(item: $opened) { item in
            // Reset before the record is removed, so this state never holds a deleted record.
            ScreenshotView(item: item, library: library) { opened = nil }
        }
        .navigationTitle(category.title(in: titles))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("Sort", systemImage: "line.3.horizontal.decrease") {
                    Picker("Sort", selection: $newestFirst) {
                        Text("Newest").tag(true)
                        Text("Oldest").tag(false)
                    }
                    Toggle("Show done", isOn: $showDone)
                }
            }
        }
        // A category with nothing left is hidden in Library, so there is nothing to stay on.
        // After the last screenshot is deleted from its own screen this runs once that screen
        // has closed: the record is removed only then, so the two transitions never overlap.
        .onChange(of: items.isEmpty) { _, isEmpty in
            if isEmpty { dismiss() }
        }
    }

    private func remind(_ item: ScreenshotItem, at date: Date) {
        Task {
            await notifications.setReminder(date, for: item, categoryTitle: item.category.title(in: titles))
        }
    }

    private func delete(_ item: ScreenshotItem) {
        Task {
            // Read before the record is removed; cancelled only if the person confirms.
            let reminderID = item.reminderNotificationID
            if await deleteFromPhotos(item, library: library, context: modelContext) {
                notifications.cancelReminder(withID: reminderID)
            }
        }
    }
}

/// Actions shared by the row context menu in L2 and the More menu in D1.
/// The row menu offers Share; in D1 Share is in the toolbar and the menu has Mark as Done instead.
/// Takes values and actions rather than the record, so it never reads a deleted one.
struct ScreenshotMenuItems: View {
    let assetID: String
    let isDone: Bool
    let library: any PhotoLibrary
    var isRowMenu = false
    let onMove: (Category) -> Void
    let onMarkDone: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Menu("Move to…", systemImage: "folder") {
            ForEach(Category.allCases) { category in
                Button {
                    onMove(category)
                } label: {
                    CategoryLabel(category: category)
                }
            }
        }
        if isRowMenu {
            ShareLink(
                item: SharedScreenshot(assetID: assetID, library: library),
                preview: SharePreview("Screenshot")
            )
        } else if !isDone {
            Button("Mark as Done", systemImage: "checkmark.circle", action: onMarkDone)
        }
        Button("Remove from Library", systemImage: "minus.circle", action: onRemove)
    }
}

#if DEBUG
#Preview("L2 Category") {
    NavigationStack {
        CategoryView(category: .buy, library: PreviewPhotoLibrary())
    }
    .modelContainer(.librarySample)
    .environment(NotificationService())
    .environment(PrivateLock())
}

#Preview("L2 Dark") {
    NavigationStack {
        CategoryView(category: .buy, library: PreviewPhotoLibrary())
    }
    .modelContainer(.librarySample)
    .environment(NotificationService())
    .environment(PrivateLock())
    .preferredColorScheme(.dark)
}

#Preview("L2 Private locked") {
    NavigationStack {
        CategoryView(category: .private, library: PreviewPhotoLibrary())
    }
    .modelContainer(.librarySample)
    .environment(NotificationService())
    .environment(PrivateLock())
}
#endif
