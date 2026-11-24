#if DEBUG
import Observation
import UIKit

/// Stand-in library for Previews: generated images, no Photos access.
@Observable
final class PreviewPhotoLibrary: PhotoLibrary {
    var access: PhotoAccess
    var screenshots: [Screenshot]
    var isLoading = false
    /// Screenshots whose image fails to load, for the error states.
    var unavailableIDs: Set<String> = []
    /// File names the library can resolve, for items sent through the Share Extension.
    var assetIDsByFilename: [String: String] = [:]

    init(access: PhotoAccess = .full, count: Int = 12) {
        self.access = access
        self.screenshots = (0..<count).map { index in
            Screenshot(id: "preview-\(index)", takenAt: Date(timeIntervalSinceNow: -Double(index) * 40 * 86_400))
        }
    }

    func requestAccess() async {
        access = .full
    }

    func refreshAccess() {}

    func image(for id: String, size: ImageSize) async -> UIImage? {
        guard !unavailableIDs.contains(id) else { return nil }
        // The number in the identifier, not the position: positions shift when samples are deleted.
        guard screenshots.contains(where: { $0.id == id }), let index = Int(id.dropFirst("preview-".count)) else {
            return nil
        }
        let size = CGSize(width: 390, height: 844)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor(hue: CGFloat(index % 12) / 12, saturation: 0.25, brightness: 0.95, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(white: 1, alpha: 0.7).setFill()
            for row in 0..<6 {
                context.fill(CGRect(x: 24, y: 120 + row * 90, width: 342 - row * 30, height: 56))
            }
            // Two of the samples carry text the sensitivity rules react to.
            let line: String? = switch index {
            case 1: "Your password is hunter2"
            case 2: "Passport No. X1234567"
            default: nil
            }
            line?.draw(
                at: CGPoint(x: 32, y: 132),
                withAttributes: [.font: UIFont.systemFont(ofSize: 26, weight: .semibold)]
            )
        }
    }

    func preheat(_ ids: [String]) {}

    func stopPreheating() {}

    func presentLimitedLibraryPicker() {}

    func assetID(forFilename filename: String) async -> String? {
        assetIDsByFilename[filename]
    }

    func delete(_ ids: [String]) async -> Bool {
        screenshots.removeAll { ids.contains($0.id) }
        return true
    }

    func hide(_ ids: [String]) async -> Bool {
        await delete(ids)
    }

    func byteSize(of ids: [String]) async -> Int64 {
        Int64(ids.count) * 1_200_000
    }
}
#endif
