import SwiftData
import SwiftUI

/// P2. Categories can be renamed, not added or removed.
struct RenameCategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var stored: [CategoryTitle]
    @State private var drafts: [Category: String] = [:]
    @State private var confirmsReset = false
    @FocusState private var focused: Category?

    /// The twelve working categories. Other and Private keep their names.
    private static let renamable = Array(Category.allCases.prefix(12))

    var body: some View {
        List(Self.renamable) { category in
            TextField(category.defaultTitle, text: binding(for: category))
                .focused($focused, equals: category)
                .onSubmit { commit(category) }
                .cardRowBackground()
        }
        .groupedScreenBackground()
        .navigationTitle("Rename Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button("Reset to Defaults") {
                    confirmsReset = true
                }
            }
        }
        .alert("Reset category names?", isPresented: $confirmsReset) {
            Button("Reset", role: .destructive) {
                drafts = [:]
                stored.forEach(modelContext.delete)
            }
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: focused) { previous, _ in
            if let previous { commit(previous) }
        }
        .onDisappear {
            Self.renamable.forEach(commit)
        }
    }

    private func binding(for category: Category) -> Binding<String> {
        Binding {
            drafts[category] ?? storedTitle(for: category)?.title ?? category.defaultTitle
        } set: {
            drafts[category] = $0
        }
    }

    private func storedTitle(for category: Category) -> CategoryTitle? {
        stored.first { $0.categoryRaw == category.rawValue }
    }

    /// An empty name is not saved: the previous one comes back.
    private func commit(_ category: Category) {
        guard let draft = drafts.removeValue(forKey: category) else { return }
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let existing = storedTitle(for: category)
        if title == category.defaultTitle {
            if let existing { modelContext.delete(existing) }
        } else if let existing {
            existing.title = title
        } else {
            modelContext.insert(CategoryTitle(category: category, title: title))
        }
    }
}

#if DEBUG
#Preview("P2 Rename Categories") {
    NavigationStack {
        RenameCategoriesView()
    }
    .modelContainer(.shotByShot(inMemory: true))
}

#Preview("P2 Dark") {
    NavigationStack {
        RenameCategoriesView()
    }
    .modelContainer(.shotByShot(inMemory: true))
    .preferredColorScheme(.dark)
}
#endif
