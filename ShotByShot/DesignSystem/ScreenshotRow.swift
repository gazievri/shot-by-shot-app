import SwiftData
import SwiftUI

/// C1. A kept screenshot in a category list.
/// Holds values, not the record: a row can outlive its record for the length of the
/// removal animation, and a deleted record must not be read.
struct ScreenshotRow: View {
    let assetID: String
    let note: String
    let recognizedTitle: String?
    let addedAt: Date
    let hasReminder: Bool
    let isDone: Bool
    let library: any PhotoLibrary

    init(item: ScreenshotItem, library: any PhotoLibrary) {
        assetID = item.assetID
        note = item.note
        recognizedTitle = item.recognizedTitle
        addedAt = item.addedAt
        hasReminder = item.reminderAt != nil
        isDone = item.isDone
        self.library = library
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                thumbnail
                text
                status
            }
        } else {
            HStack(spacing: 12) {
                thumbnail
                text
                Spacer()
                status
            }
        }
    }

    private var thumbnail: some View {
        AssetImage(library: library, id: assetID, size: .thumbnail, contentMode: .fill)
            .frame(width: 60, height: 120)
            .clipShape(.rect(cornerRadius: 8))
            .accessibilityHidden(true)
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 4) {
            // The whole note is in Info; here a long one is cut off after a couple of lines.
            if note.contains(where: { !$0.isWhitespace }) {
                Text(note)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
            } else if let recognizedTitle {
                Text(recognizedTitle)
                    .lineLimit(1)
            } else {
                Text("Screenshot")
            }
            Text("Added \(addedAt, format: .dateTime.day().month().year())")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var status: some View {
        if hasReminder {
            Image(systemName: "bell.fill")
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text("Remind"))
        }
        if isDone {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text("Done"))
        }
    }
}

#if DEBUG
#Preview("C1 Long note") {
    let container = ModelContainer.librarySample
    let items = try! container.mainContext.fetch(FetchDescriptor<ScreenshotItem>())
    items.first?.note = "A long note without a single line break that used to take over the whole screen "
        + "of the category list because the row showed all of it, every word, down to the very last one."
    items.dropFirst(2).first?.recognizedTitle = "Boarding pass · Gate B12"
    return List(items.prefix(4)) { item in
        ScreenshotRow(item: item, library: PreviewPhotoLibrary())
    }
    .modelContainer(container)
}
#endif
