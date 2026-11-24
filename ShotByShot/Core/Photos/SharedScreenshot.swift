import CoreTransferable
import UIKit
import UniformTypeIdentifiers

/// Exports the original image on demand, when the person picks a share target.
struct SharedScreenshot: Transferable {
    let assetID: String
    let library: any PhotoLibrary

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { shared in
            await shared.library.image(for: shared.assetID, size: .original)?.pngData() ?? Data()
        }
    }
}
