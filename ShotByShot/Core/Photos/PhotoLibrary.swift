import UIKit

nonisolated enum PhotoAccess: Sendable {
    case notDetermined, full, limited, denied
}

/// A screenshot in the Photos library, identified by `PHAsset.localIdentifier`.
nonisolated struct Screenshot: Identifiable, Hashable, Sendable {
    let id: String
    let takenAt: Date?
}

/// How large an image is asked for. Originals are only needed where the person can zoom in.
nonisolated enum ImageSize: Sendable {
    case thumbnail
    /// Fits the screen in pixels: enough for the session, text recognition and the model.
    case screen
    case original
}

@MainActor
protocol PhotoLibrary: AnyObject, Observable, Sendable {
    var access: PhotoAccess { get }
    /// Every screenshot the app can see, newest first. Hidden assets are not included.
    var screenshots: [Screenshot] { get }
    /// The library is being read for the first time; `screenshots` is not final yet.
    var isLoading: Bool { get }

    func requestAccess() async
    /// Reads the permission again: it can change in Settings while the app is in the background.
    func refreshAccess()
    /// `nil` when the image cannot be loaded: no such asset, no network for an original
    /// kept in iCloud, an error or a timeout. Never waits forever.
    func image(for id: String, size: ImageSize) async -> UIImage?
    /// Starts loading screen-size images that are about to be shown in a session.
    func preheat(_ ids: [String])
    /// Drops everything `preheat` has started; called when a session ends.
    func stopPreheating()
    /// Deletes the originals in one batch, so the system asks once.
    /// Returns `false` when the person declines; that is not an error.
    func delete(_ ids: [String]) async -> Bool
    func byteSize(of ids: [String]) async -> Int64
    /// Moves the originals to the Hidden album in Photos. Hidden screenshots leave the inbox.
    func hide(_ ids: [String]) async -> Bool
    /// With limited access: the system sheet for choosing more photos.
    func presentLimitedLibraryPicker()
    /// Finds a screenshot by the name of its original file, for items sent through the
    /// Share Extension. The newest match wins; `nil` when the app cannot see such a file.
    func assetID(forFilename filename: String) async -> String?
}

extension PhotoLibrary {
    /// The inbox is not stored: it is the screenshots album minus everything already kept.
    func inbox(excluding keptIDs: Set<String>) -> [Screenshot] {
        screenshots.filter { !keptIDs.contains($0.id) }
    }
}
