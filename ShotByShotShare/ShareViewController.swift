import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// E1. "Shot by Shot" in the system Share Sheet for images.
///
/// The app keeps references to Photos assets, never copies, and an extension is handed
/// the image rather than its asset. So the extension only records the file name with the
/// chosen category and note; the app finds the asset by that name the next time it opens.
final class ShareViewController: UIViewController {
    private let model = ShareModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: ShareView(
            model: model,
            onCancel: { [weak self] in
                self?.extensionContext?.cancelRequest(withError: CocoaError(.userCancelled))
            },
            onSave: { [weak self] in
                self?.model.save()
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
        ))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)

        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
            .filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
        Task {
            for provider in providers {
                if let image = await Self.load(provider) {
                    model.images.append(image)
                }
            }
            model.isLoading = false
        }
    }

    private static func load(_ provider: NSItemProvider) async -> SharedImage? {
        await withCheckedContinuation { continuation in
            _ = provider.loadFileRepresentation(for: .image) { url, _, _ in
                guard let url else {
                    continuation.resume(returning: nil)
                    return
                }
                // The file is only valid inside this handler: take what is needed now.
                let preview = UIImage(contentsOfFile: url.path)?
                    .preparingThumbnail(of: CGSize(width: 300, height: 650))
                continuation.resume(returning: SharedImage(filename: url.lastPathComponent, preview: preview))
            }
        }
    }
}

struct SharedImage: Identifiable, Sendable {
    let id = UUID()
    let filename: String
    let preview: UIImage?
}

@MainActor
@Observable
final class ShareModel {
    var images: [SharedImage] = []
    var isLoading = true
    var category = "other"
    var note = ""

    /// Queues the shared screenshots for the app. The keys mirror `RootView.importSharedScreenshots`;
    /// the two targets share no code.
    func save() {
        guard let defaults = UserDefaults(suiteName: "group.com.ruslangaziev.ShotByShot") else { return }
        var pending = defaults.array(forKey: "share.pending") as? [[String: String]] ?? []
        pending += images.map { ["filename": $0.filename, "category": category, "note": note] }
        defaults.set(pending, forKey: "share.pending")
    }
}

/// Same content as A1: preview, category, note. Several images go to one category.
struct ShareView: View {
    @Bindable var model: ShareModel
    let onCancel: () -> Void
    let onSave: () -> Void

    /// Raw values match `Category` in the app. Renamed categories show their default names here.
    private static let categories: [(id: String, title: LocalizedStringKey, symbol: String)] = [
        ("buy", "Buy", "cart"), ("read", "Read", "book"), ("watch", "Watch", "play.rectangle"),
        ("listen", "Listen", "headphones"), ("cook", "Cook", "fork.knife"), ("go", "Go", "map"),
        ("attend", "Attend", "calendar"), ("todo", "Do", "checklist"), ("tryOut", "Try", "hand.tap"),
        ("contact", "Contact", "person.crop.circle"), ("keep", "Keep", "archivebox"),
        ("inspire", "Inspire", "lightbulb"), ("other", "Other", "square.grid.2x2"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if model.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(model.images) { image in
                                    if let preview = image.preview {
                                        Image(uiImage: preview)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 220)
                                            .clipShape(.rect(cornerRadius: 8))
                                            .accessibilityLabel(Text("Screenshot"))
                                            .accessibilityIgnoresInvertColors()
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .listRowBackground(Color.clear)
                Section {
                    Picker("Category", selection: $model.category) {
                        ForEach(Self.categories, id: \.id) { category in
                            Label(category.title, systemImage: category.symbol).tag(category.id)
                        }
                    }
                    TextField("Add a note", text: $model.note, axis: .vertical)
                } footer: {
                    Text("It will appear in Library the next time you open Shot by Shot.")
                }
            }
            .navigationTitle("Save Screenshot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .disabled(model.images.isEmpty)
                }
            }
        }
    }
}

#if DEBUG
#Preview("E1 Share Extension") {
    let model = ShareModel()
    model.isLoading = false
    return ShareView(model: model, onCancel: {}, onSave: {})
}
#endif
