import SwiftUI

/// Loads a screenshot from the Photos library. Shows a spinner while the image is loading,
/// which may include a download from iCloud, and a placeholder when it cannot be loaded.
struct AssetImage: View {
    let library: any PhotoLibrary
    let id: String
    var size = ImageSize.screen
    var contentMode: ContentMode = .fit

    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .accessibilityIgnoresInvertColors()
            } else {
                Rectangle()
                    .fill(.fill.tertiary)
                    .overlay {
                        if didFail {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        } else {
                            ProgressView()
                        }
                    }
            }
        }
        .task(id: id) {
            didFail = false
            let loaded = await library.image(for: id, size: size)
            // A cancelled request also comes back empty; that is not a failure.
            guard !Task.isCancelled else { return }
            image = loaded
            didFail = loaded == nil
        }
    }
}
