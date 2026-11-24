import SwiftData
import SwiftUI

/// D1. A viewing mode with its own bottom toolbar, so the tab bar is hidden.
struct ScreenshotView: View {
    let item: ScreenshotItem
    let library: any PhotoLibrary
    /// Closes this screen. The owner of the navigation state does it, so the state
    /// never points at a record that is about to be removed.
    var onClose: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(PrivateLock.self) private var lock
    @Environment(NotificationService.self) private var notifications
    @Environment(\.categoryTitles) private var titles
    @State private var image: UIImage?
    @State private var didFailToLoad = false
    @State private var isZoomedIn = false
    @State private var showsInfo = false
    @State private var contextActions: [ContextAction] = []
    @State private var isDeleting = false
    @State private var removal: Removal?

    /// What to do with the record once this screen is gone.
    private enum Removal {
        case record
        case recordOfDeletedOriginal(freedBytes: Int64)
    }

    var body: some View {
        Group {
            if item.isDeleted || item.modelContext == nil {
                Color(.systemBackground)
            } else if item.category == .private && !lock.isUnlocked {
                // Also reached from a reminder, which must not open Private without Face ID.
                PrivateLockedView()
            } else {
                content
            }
        }
        // The record is removed only after the screen has left: until then the screen,
        // its menu and the Info sheet still show the record and must be able to read it.
        .onDisappear {
            if removal != nil { notifications.cancelReminder(withID: item.reminderNotificationID) }
            switch removal {
            case .record:
                modelContext.delete(item)
            case .recordOfDeletedOriginal(let freedBytes):
                modelContext.removeRecord(item, freedBytes: freedBytes)
            case nil:
                break
            }
            removal = nil
        }
    }

    private func close(removing removal: Removal) {
        showsInfo = false
        self.removal = removal
        if let onClose { onClose() } else { dismiss() }
    }

    private func deleteOriginal() async {
        let assetID = item.assetID
        isDeleting = true
        let size = await library.byteSize(of: [assetID])
        // `false` when the person declines the system confirmation: the screen stays open.
        if await library.delete([assetID]) {
            close(removing: .recordOfDeletedOriginal(freedBytes: size))
        } else {
            isDeleting = false
        }
    }

    private var isFound: Bool {
        library.screenshots.contains { $0.id == item.assetID }
    }

    private var date: Date {
        item.takenAt ?? item.addedAt
    }

    @ViewBuilder
    private var content: some View {
        // The original leaves the library a moment before this screen closes;
        // "not found" must not flash by in between.
        if isFound || isDeleting || removal != nil {
            viewer
        } else {
            ContentUnavailableView {
                Label("Screenshot not found", systemImage: "photo")
            } description: {
                Text("It may have been deleted from Photos.")
            } actions: {
                Button("Remove from Shot by Shot") {
                    close(removing: .record)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var viewer: some View {
        ZStack {
            if let image {
                ZoomableImage(image: image, isZoomedIn: $isZoomedIn)
                    .accessibilityElement()
                    .accessibilityAddTraits(.isImage)
                    .accessibilityLabel(Text(item.category.title(in: titles)))
                    .accessibilityValue(Text(date, format: .dateTime.day().month().year()))
                    .accessibilityZoomAction { action in
                        isZoomedIn = action.direction == .zoomIn
                    }
            } else {
                AssetImage(library: library, id: item.assetID, size: .thumbnail)
                    .blur(radius: 20)
                    .overlay {
                        // When the original cannot be loaded, the blurred thumbnail stays.
                        if !didFailToLoad { ProgressView() }
                    }
                    .accessibilityHidden(true)
            }
        }
        // The system background is black in the dark theme: a tinted one would distort the image.
        .background(Color(.systemBackground))
        // Accelerator for the Info button.
        .simultaneousGesture(
            DragGesture(minimumDistance: 40).onEnded { drag in
                if !isZoomedIn, drag.translation.height < -80, abs(drag.translation.width) < 60 {
                    showsInfo = true
                }
            }
        )
        .navigationTitle(Text(date, format: .dateTime.day().month().year()))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("More", systemImage: "ellipsis.circle") {
                    ScreenshotMenuItems(
                        assetID: item.assetID, isDone: item.isDone, library: library,
                        onMove: { item.category = $0 },
                        onMarkDone: { item.isDone = true },
                        onRemove: { close(removing: .record) }
                    )
                    // One action sits in the toolbar; the rest of what was found goes here.
                    ForEach(contextActions.dropFirst()) { action in
                        ContextActionButton(action: action)
                    }
                }
            }
            ToolbarItemGroup(placement: .bottomBar) {
                ShareLink(
                    item: SharedScreenshot(assetID: item.assetID, library: library),
                    preview: SharePreview("Screenshot")
                )
                Spacer()
                if let action = contextActions.first {
                    ContextActionButton(action: action)
                    Spacer()
                }
                Button("Info", systemImage: "info.circle") {
                    showsInfo = true
                }
                Spacer()
                Button("Delete", systemImage: "trash", role: .destructive) {
                    Task { await deleteOriginal() }
                }
            }
        }
        .sheet(isPresented: $showsInfo) {
            InfoView(item: item, library: library)
        }
        .task(id: item.assetID) {
            didFailToLoad = false
            let loaded = await library.image(for: item.assetID, size: .original)
            guard !Task.isCancelled else { return }
            image = loaded
            didFailToLoad = loaded == nil
            if let cgImage = image?.cgImage {
                contextActions = ContextAction.detect(in: await TextRecognizer.text(in: cgImage))
            }
        }
    }
}

/// Pinch and double-tap zoom. SwiftUI has no native equivalent, hence `UIScrollView`.
private struct ZoomableImage: UIViewRepresentable {
    let image: UIImage
    @Binding var isZoomedIn: Bool

    func makeUIView(context: Context) -> ZoomScrollView {
        let view = ZoomScrollView()
        view.onZoomChange = { isZoomedIn = $0 }
        return view
    }

    func updateUIView(_ view: ZoomScrollView, context: Context) {
        view.imageView.image = image
        if isZoomedIn != (view.zoomScale > view.minimumZoomScale) {
            view.setZoomScale(isZoomedIn ? ZoomScrollView.doubleTapScale : view.minimumZoomScale, animated: true)
        }
    }
}

private final class ZoomScrollView: UIScrollView, UIScrollViewDelegate {
    static let doubleTapScale: CGFloat = 2.5

    let imageView = UIImageView()
    var onZoomChange: ((Bool) -> Void)?

    init() {
        super.init(frame: .zero)
        delegate = self
        maximumZoomScale = 4
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        imageView.contentMode = .scaleAspectFit
        imageView.accessibilityIgnoresInvertColors = true
        addSubview(imageView)
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(toggleZoom))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if zoomScale == minimumZoomScale {
            imageView.frame = bounds
            contentSize = bounds.size
        }
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        onZoomChange?(scale > minimumZoomScale)
    }

    @objc private func toggleZoom() {
        setZoomScale(zoomScale > minimumZoomScale ? minimumZoomScale : Self.doubleTapScale, animated: true)
    }
}

#if DEBUG
#Preview("D1 Screenshot") {
    let container = ModelContainer.librarySample
    let item = try! container.mainContext.fetch(FetchDescriptor<ScreenshotItem>()).first!
    NavigationStack {
        ScreenshotView(item: item, library: PreviewPhotoLibrary())
    }
    .modelContainer(container)
    .environment(PrivateLock())
    .environment(NotificationService())
}

#Preview("D1 Dark") {
    let container = ModelContainer.librarySample
    let item = try! container.mainContext.fetch(FetchDescriptor<ScreenshotItem>()).first!
    NavigationStack {
        ScreenshotView(item: item, library: PreviewPhotoLibrary())
    }
    .modelContainer(container)
    .environment(PrivateLock())
    .environment(NotificationService())
    .preferredColorScheme(.dark)
}

#Preview("D1 Not found") {
    let container = ModelContainer.librarySample
    let item = try! container.mainContext.fetch(FetchDescriptor<ScreenshotItem>()).first!
    NavigationStack {
        ScreenshotView(item: item, library: PreviewPhotoLibrary(count: 0))
    }
    .modelContainer(container)
    .environment(PrivateLock())
    .environment(NotificationService())
}
#endif
