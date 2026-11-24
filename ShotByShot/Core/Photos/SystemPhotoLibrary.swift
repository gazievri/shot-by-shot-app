import Observation
import os
import Photos
import PhotosUI
import UIKit

@Observable
final class SystemPhotoLibrary: NSObject, PhotoLibrary, PHPhotoLibraryChangeObserver {
    private(set) var access: PhotoAccess
    private(set) var screenshots: [Screenshot] = []
    private(set) var isLoading = false

    @ObservationIgnored private let imageManager = PHCachingImageManager()
    @ObservationIgnored private var isObserving = false

    private static let thumbnailSize = CGSize(width: 360, height: 780)
    /// Long enough for an original to arrive from iCloud; after that the caller gets `nil`.
    private static let timeout = Duration.seconds(15)

    override init() {
        access = Self.access(for: PHPhotoLibrary.authorizationStatus(for: .readWrite))
        super.init()
        startIfAllowed()
    }

    func requestAccess() async {
        access = Self.access(for: await PHPhotoLibrary.requestAuthorization(for: .readWrite))
        startIfAllowed()
    }

    func refreshAccess() {
        let current = Self.access(for: PHPhotoLibrary.authorizationStatus(for: .readWrite))
        guard current != access else { return }
        access = current
        if access == .full || access == .limited {
            startIfAllowed()
        } else {
            // Nothing read while access was allowed may stay on screen.
            screenshots = []
        }
    }

    func image(for id: String, size: ImageSize) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else {
            return nil
        }
        let box = ImageRequestBox()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                box.start(continuation)
                // Cancelled before the request was made: the handler below had nothing to stop yet.
                guard !Task.isCancelled else {
                    box.finish(nil)
                    return
                }
                let requestID = imageManager.requestImage(
                    for: asset, targetSize: targetSize(for: size), contentMode: .aspectFit,
                    options: Self.imageOptions(for: size),
                    resultHandler: Self.resultHandler(for: box)
                )
                box.setRequestID(requestID)
                Task {
                    try? await Task.sleep(for: Self.timeout)
                    if box.finish(nil) {
                        self.imageManager.cancelImageRequest(requestID)
                    }
                }
            }
        } onCancel: {
            guard box.finish(nil), let requestID = box.requestID else { return }
            Task { @MainActor in
                self.imageManager.cancelImageRequest(requestID)
            }
        }
    }

    func preheat(_ ids: [String]) {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        // The same size and options as the request that follows, or the cache is of no use.
        imageManager.startCachingImages(
            for: assets.objects(at: IndexSet(integersIn: 0..<assets.count)),
            targetSize: targetSize(for: .screen), contentMode: .aspectFit,
            options: Self.imageOptions(for: .screen)
        )
    }

    func stopPreheating() {
        imageManager.stopCachingImagesForAllAssets()
    }

    func delete(_ ids: [String]) async -> Bool {
        do {
            try await Self.deleteAssets(ids)
        } catch {
            return false
        }
        // The change observer fires later; callers read the inbox right after deleting.
        await reload()
        return true
    }

    func hide(_ ids: [String]) async -> Bool {
        do {
            try await Self.hideAssets(ids)
        } catch {
            return false
        }
        await reload()
        return true
    }

    func presentLimitedLibraryPicker() {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        guard let controller = scene?.keyWindow?.rootViewController else { return }
        // Present from whatever is on top: the picker is a sheet of its own.
        var top = controller
        while let presented = top.presentedViewController { top = presented }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: top)
    }

    func assetID(forFilename filename: String) async -> String? {
        // Newest first: a screenshot that was just shared is near the top.
        let ids = screenshots.map(\.id)
        return await Task.detached(priority: .utility) {
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
            var byID: [String: PHAsset] = [:]
            for index in 0..<assets.count {
                byID[assets.object(at: index).localIdentifier] = assets.object(at: index)
            }
            return ids.first { id in
                guard let asset = byID[id] else { return false }
                return PHAssetResource.assetResources(for: asset).contains {
                    // `filename` replaced `originalFilename` in iOS 27.
                    let name = if #available(iOS 27, *) { $0.filename } else { $0.originalFilename }
                    return name?.caseInsensitiveCompare(filename) == .orderedSame
                }
            }
        }.value
    }

    func byteSize(of ids: [String]) async -> Int64 {
        await Task.detached(priority: .utility) {
            await Self.totalDataSize(of: ids)
        }.value
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            // Cached images may belong to assets that were just deleted or edited.
            self.imageManager.stopCachingImagesForAllAssets()
            await self.reload()
        }
    }

    private func startIfAllowed() {
        guard access == .full || access == .limited else { return }
        if !isObserving {
            PHPhotoLibrary.shared().register(self)
            isObserving = true
        }
        // A large library takes a moment to read; O2 shows a spinner meanwhile.
        isLoading = true
        Task {
            await reload()
            isLoading = false
        }
    }

    /// Reads the Screenshots album off the main actor. Hidden assets are not fetched.
    private func reload() async {
        screenshots = await Task.detached(priority: .userInitiated) {
            let albums = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum, subtype: .smartAlbumScreenshots, options: nil
            )
            guard let album = albums.firstObject else { return [Screenshot]() }
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let assets = PHAsset.fetchAssets(in: album, options: options)
            return (0..<assets.count).map { index in
                let asset = assets.object(at: index)
                return Screenshot(id: asset.localIdentifier, takenAt: asset.creationDate)
            }
        }.value
    }

    // PhotoKit runs a change block on a queue of its own. A block written inside a main-actor
    // method is a main-actor closure, and Swift stops the app when it is called anywhere else:
    // that was the crash on every deletion. Hence the two functions outside the main actor.

    nonisolated private static func deleteAssets(_ ids: [String]) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil))
        }
    }

    nonisolated private static func hideAssets(_ ids: [String]) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
            for index in 0..<assets.count {
                PHAssetChangeRequest(for: assets.object(at: index)).isHidden = true
            }
        }
    }

    private static func access(for status: PHAuthorizationStatus) -> PhotoAccess {
        switch status {
        case .authorized: .full
        case .limited: .limited
        case .notDetermined: .notDetermined
        case .denied, .restricted: .denied
        @unknown default: .denied
        }
    }

    /// Built outside the main actor: PhotoKit does not promise to call the handler on the
    /// main thread, and a main-actor closure called elsewhere traps at run time.
    nonisolated private static func resultHandler(
        for box: ImageRequestBox
    ) -> (UIImage?, [AnyHashable: Any]?) -> Void {
        { image, _ in
            box.finish(image)
        }
    }

    private func targetSize(for size: ImageSize) -> CGSize {
        switch size {
        case .thumbnail:
            return Self.thumbnailSize
        case .screen:
            // A square of the longer side, so the image fits the screen in either orientation.
            let screen = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.screen
            let side = screen.map { max($0.nativeBounds.width, $0.nativeBounds.height) } ?? 2800
            return CGSize(width: side, height: side)
        case .original:
            return PHImageManagerMaximumSize
        }
    }

    private static func imageOptions(for size: ImageSize) -> PHImageRequestOptions {
        let options = PHImageRequestOptions()
        // A single callback per request, with the final image.
        options.deliveryMode = .highQualityFormat
        options.resizeMode = size == .original ? .none : .fast
        options.isNetworkAccessAllowed = true
        return options
    }

    nonisolated private static func totalDataSize(of ids: [String]) async -> Int64 {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var total: Int64 = 0
        for index in 0..<assets.count {
            for resource in PHAssetResource.assetResources(for: assets.object(at: index)) {
                if #available(iOS 27, *) {
                    total += Int64(resource.dataSize ?? 0)
                } else {
                    total += await readDataSize(of: resource)
                }
            }
        }
        return total
    }

    /// Before iOS 27 a resource does not report its size, so its data is read and counted.
    /// Slower, but exact. A resource that is only in iCloud counts as zero: sizes are
    /// not worth a download.
    nonisolated private static func readDataSize(of resource: PHAssetResource) async -> Int64 {
        let size = OSAllocatedUnfairLock(initialState: Int64(0))
        return await withCheckedContinuation { continuation in
            PHAssetResourceManager.default().requestData(for: resource, options: nil) { data in
                size.withLock { $0 += Int64(data.count) }
            } completionHandler: { error in
                continuation.resume(returning: error == nil ? size.withLock { $0 } : 0)
            }
        }
    }
}

/// One image request. Whatever comes first — the callback, cancellation or the timeout —
/// resumes the continuation, and only once.
nonisolated private final class ImageRequestBox: Sendable {
    private struct State {
        var continuation: CheckedContinuation<UIImage?, Never>?
        var requestID: PHImageRequestID?
    }

    private let state = OSAllocatedUnfairLock(uncheckedState: State())

    var requestID: PHImageRequestID? {
        state.withLockUnchecked { $0.requestID }
    }

    func start(_ continuation: CheckedContinuation<UIImage?, Never>) {
        state.withLockUnchecked { $0.continuation = continuation }
    }

    func setRequestID(_ requestID: PHImageRequestID) {
        state.withLockUnchecked { $0.requestID = requestID }
    }

    /// Returns `false` when the request has already been finished.
    @discardableResult
    func finish(_ image: UIImage?) -> Bool {
        let continuation = state.withLockUnchecked { state in
            defer { state.continuation = nil }
            return state.continuation
        }
        continuation?.resume(returning: image)
        return continuation != nil
    }
}
