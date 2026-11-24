import Testing
import UIKit
@testable import ShotByShot

/// Without the model's "personal" flag the result comes from the text rules and
/// the system analyzer alone.
struct SensitivityCheckTests {
    @Test func textRulesDecideWithoutTheModel() async throws {
        let image = try blankImage()
        #expect(await SensitivityCheck.assess(text: "Your password is hunter2", image: image) == .secret)
        #expect(await SensitivityCheck.assess(text: "Passport No. X1234567", image: image) == .personal)
    }

    @Test func anOrdinaryScreenshotIsNotSensitiveWithoutTheModel() async throws {
        #expect(await SensitivityCheck.assess(text: "Standing desk, oak, 140 cm. $499", image: try blankImage()) == .none)
    }

    private func blankImage() throws -> CGImage {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }
        return try #require(image.cgImage)
    }
}
