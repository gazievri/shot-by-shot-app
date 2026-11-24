import SwiftUI

/// The choices of a Remind menu. Used in the session, and in the row context menu in L2.
struct RemindMenuItems: View {
    let onPick: (Date) -> Void
    let onPickDate: () -> Void

    var body: some View {
        ForEach(RemindOption.available(), id: \.option) { option, date in
            Button {
                onPick(date)
            } label: {
                Text(option.title)
                Text(option.detail(for: date))
            }
        }
        Button("Pick Date…", systemImage: "calendar", action: onPickDate)
    }
}

/// The sheet behind "Pick Date…".
struct PickDateSheet: View {
    let onDone: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date = RemindOption.tomorrow.date(after: .now) ?? .now

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Remind me", selection: $date, in: Date.now...)
                    .datePickerStyle(.graphical)
                    .cardRowBackground()
            }
            .groupedScreenBackground()
            .navigationTitle("Remind")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                        onDone(date)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sheetBackground()
    }
}

#if DEBUG
#Preview("Pick Date") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            PickDateSheet { _ in }
        }
}
#endif
