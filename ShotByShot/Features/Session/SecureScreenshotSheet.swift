import SwiftUI
import UniformTypeIdentifiers

/// S3. Helps move a secret somewhere safe and then delete the screenshot.
struct SecureScreenshotSheet: View {
    let library: any PhotoLibrary
    let assetID: String
    /// Text recognized on the screenshot.
    let text: String
    /// Deletes the original right away. Returns `false` if the person declines.
    let onDelete: () async -> Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    step("Move it somewhere safe", "Copy the text or share it to your password manager or a locked note.") {
                        HStack {
                            Button("Copy Text", action: copyText)
                                .disabled(text.isEmpty)
                            ShareLink(
                                "Share…",
                                item: SharedScreenshot(assetID: assetID, library: library),
                                preview: SharePreview("Screenshot")
                            )
                            .labelStyle(.titleOnly)
                        }
                        .buttonStyle(.bordered)
                    }
                    step("Delete the screenshot", "It moves to Recently Deleted in Photos.") {
                        Button("Delete from Photos", role: .destructive) {
                            Task {
                                // Closing without deleting returns to the same screenshot.
                                if await onDelete() { dismiss() }
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    step("Empty Recently Deleted", "Deleted screenshots stay there for 30 days. Open Photos and empty it to remove this one for good.") {
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle("Secure Screenshot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .sheetBackground()
    }

    private func step(
        _ title: LocalizedStringKey, _ detail: LocalizedStringKey, @ViewBuilder actions: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            actions()
        }
    }

    /// The clipboard copy stays on this device and clears itself after two minutes.
    private func copyText() {
        UIPasteboard.general.setItems(
            [[UTType.plainText.identifier: text]],
            options: [.localOnly: true, .expirationDate: Date.now.addingTimeInterval(120)]
        )
    }
}

#if DEBUG
#Preview("S3 Secure Screenshot") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            SecureScreenshotSheet(
                library: PreviewPhotoLibrary(), assetID: "preview-1", text: "Your password is hunter2",
                onDelete: { true }
            )
        }
}

#Preview("S3 Dark") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            SecureScreenshotSheet(
                library: PreviewPhotoLibrary(), assetID: "preview-1", text: "Your password is hunter2",
                onDelete: { true }
            )
        }
        .preferredColorScheme(.dark)
}
#endif
