import SwiftData
import SwiftUI

/// A1. Saves a screenshot picked with the system photo picker.
struct AddScreenshotView: View {
    let assetID: String
    let library: any PhotoLibrary
    let insight: any InsightService
    /// Called after a successful save with the category the screenshot went to.
    let onSaved: (Category) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.categoryTitles) private var titles
    @Environment(NotificationService.self) private var notifications
    @State private var category: Category?
    @State private var note = ""
    @State private var remindsMe = false
    @State private var reminderDate = RemindOption.tomorrow.date(after: .now) ?? .now
    /// The person changed something; closing now would lose it.
    @State private var isEdited = false
    @State private var isSuggesting = false
    @State private var confirmsDiscard = false
    @State private var saveFailed = false
    /// A screenshot already in Library is edited in place rather than saved twice.
    @State private var existing: ScreenshotItem?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AssetImage(library: library, id: assetID)
                        .frame(maxWidth: .infinity)
                        .frame(height: 260)
                        .clipShape(.rect(cornerRadius: 8))
                        .accessibilityLabel(Text("Screenshot"))
                }
                .listRowBackground(Color.clear)
                Section {
                    Picker(selection: Binding(
                        get: { category ?? .other },
                        set: { category = $0; isEdited = true }
                    )) {
                        ForEach(Category.allCases) { category in
                            CategoryLabel(category: category).tag(category)
                        }
                    } label: {
                        HStack {
                            Text("Category")
                            // Save stays enabled while the model is still deciding.
                            if isSuggesting {
                                ProgressView()
                            }
                        }
                    }
                    TextField("Add a note", text: Binding(
                        get: { note },
                        set: { note = $0; isEdited = true }
                    ), axis: .vertical)
                    Toggle("Remind me", isOn: Binding(
                        get: { remindsMe },
                        set: { remindsMe = $0; isEdited = true }
                    ))
                    if remindsMe {
                        DatePicker("Time", selection: Binding(
                            get: { reminderDate },
                            set: { reminderDate = $0; isEdited = true }
                        ), in: Date.now...)
                    }
                }
                .cardRowBackground()
            }
            .groupedScreenBackground()
            .navigationTitle("Save Screenshot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isEdited {
                            confirmsDiscard = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
            .confirmationDialog("Discard Changes", isPresented: $confirmsDiscard) {
                Button("Discard Changes", role: .destructive) {
                    dismiss()
                }
                Button("Keep Editing", role: .cancel) {}
            }
            .alert("Couldn’t save the screenshot", isPresented: $saveFailed) {
                Button("Retry", action: save)
                Button("Cancel", role: .cancel) {}
            }
        }
        .presentationDetents([.large])
        // With unsaved input, swiping down would lose it silently.
        .interactiveDismissDisabled(isEdited)
        .sheetBackground()
        .task {
            await prepare()
        }
    }

    private func prepare() async {
        if let item = try? modelContext.screenshotItem(assetID: assetID) {
            existing = item
            category = item.category
            note = item.note
            remindsMe = item.reminderAt != nil
            reminderDate = item.reminderAt ?? reminderDate
            return
        }
        guard insight.isAvailable, let image = await library.image(for: assetID, size: .screen) else { return }
        isSuggesting = true
        let answer = await insight.insight(for: image)
        isSuggesting = false
        // The person's own choice wins over a late suggestion.
        if category == nil {
            category = answer.isPersonal ? .private : answer.category
        }
    }

    private func save() {
        // The picker can return a photo this app is not allowed to see, e.g. with limited access.
        guard let screenshot = library.screenshots.first(where: { $0.id == assetID }) else {
            saveFailed = true
            return
        }
        let chosen = category ?? .other
        let item = existing ?? ScreenshotItem(assetID: assetID, category: chosen, takenAt: screenshot.takenAt)
        item.category = chosen
        item.note = note
        if existing == nil {
            modelContext.insert(item)
        }
        do {
            try modelContext.save()
        } catch {
            // What was typed stays in the form.
            saveFailed = true
            return
        }
        let date = remindsMe ? reminderDate : nil
        let title = chosen.title(in: titles)
        Task {
            await notifications.setReminder(date, for: item, categoryTitle: title)
        }
        dismiss()
        onSaved(chosen)
    }
}

#if DEBUG
#Preview("A1 Save Screenshot") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            AddScreenshotView(
                assetID: "preview-7", library: PreviewPhotoLibrary(), insight: PreviewInsightService(),
                onSaved: { _ in }
            )
            .environment(NotificationService())
        }
        .modelContainer(.shotByShot(inMemory: true))
}

#Preview("A1 Dark") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            AddScreenshotView(
                assetID: "preview-7", library: PreviewPhotoLibrary(), insight: PreviewInsightService(),
                onSaved: { _ in }
            )
            .environment(NotificationService())
        }
        .modelContainer(.shotByShot(inMemory: true))
        .preferredColorScheme(.dark)
}
#endif
