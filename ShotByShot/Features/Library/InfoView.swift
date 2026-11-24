import SwiftData
import SwiftUI

/// D2. Changes are saved as they are made; there is no Save button.
struct InfoView: View {
    @Bindable var item: ScreenshotItem
    let library: any PhotoLibrary

    @Environment(\.dismiss) private var dismiss
    @Environment(\.categoryTitles) private var titles
    @Environment(NotificationService.self) private var notifications
    @State private var byteSize: Int64?

    var body: some View {
        NavigationStack {
            form
                .navigationTitle("Info")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark") {
                            dismiss()
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .sheetBackground()
        .task {
            byteSize = await library.byteSize(of: [item.assetID])
        }
    }

    /// If notifications are not allowed, the toggle falls back to off: no reminder was set.
    private func remind(at date: Date?) {
        Task {
            await notifications.setReminder(date, for: item, categoryTitle: item.category.title(in: titles))
        }
    }

    private var form: some View {
        Form {
            Section {
                Picker("Category", selection: $item.category) {
                    ForEach(Category.allCases) { category in
                        CategoryLabel(category: category).tag(category)
                    }
                }
                .pickerStyle(.menu)
            }
            .cardRowBackground()
            Section("Note") {
                TextField("Add a note", text: $item.note, axis: .vertical)
            }
            .cardRowBackground()
            Section("Reminder") {
                Toggle("Remind me", isOn: Binding(
                    get: { item.reminderAt != nil },
                    set: { isOn in remind(at: isOn ? RemindOption.tomorrow.date(after: .now) : nil) }
                ))
                if let reminderAt = item.reminderAt {
                    DatePicker("Time", selection: Binding(
                        get: { reminderAt },
                        set: { remind(at: $0) }
                    ), in: Date.now...)
                }
            }
            .cardRowBackground()
            Section("Status") {
                Toggle("Done", isOn: $item.isDone)
            }
            .cardRowBackground()
            Section("Details") {
                LabeledContent("Added", value: item.addedAt, format: .dateTime.day().month().year())
                if let takenAt = item.takenAt {
                    LabeledContent("Taken", value: takenAt, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                }
                if let byteSize {
                    LabeledContent("Size", value: byteSize, format: .byteCount(style: .file))
                }
            }
            .cardRowBackground()
        }
        .groupedScreenBackground()
    }
}

#if DEBUG
#Preview("D2 Info") {
    let container = ModelContainer.librarySample
    let item = try! container.mainContext.fetch(FetchDescriptor<ScreenshotItem>()).first!
    Color.clear
        .sheet(isPresented: .constant(true)) {
            InfoView(item: item, library: PreviewPhotoLibrary())
                .environment(NotificationService())
        }
        .modelContainer(container)
}

#Preview("D2 Dark") {
    let container = ModelContainer.librarySample
    let item = try! container.mainContext.fetch(FetchDescriptor<ScreenshotItem>()).first!
    Color.clear
        .sheet(isPresented: .constant(true)) {
            InfoView(item: item, library: PreviewPhotoLibrary())
                .environment(NotificationService())
        }
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
#endif
