import SwiftUI

/// What the sky over the city shows. Geometry comes from `assets/city-reference`.
nonisolated enum CityState: Equatable, Sendable {
    /// O1: one cloud, no stars lit.
    case welcome
    /// O2: overcast.
    case counter
    /// I1: one cloud per screenshot of today's portion.
    case waiting(clouds: Int)
    /// S2 and I1 after today's session. `newStar` marks the star earned by this session.
    case done(newStar: Bool)
    /// I1 with nothing left to sort: every window is lit.
    case empty
    /// I1 after a missed day: three clouds more than the portion. Calm, no alarm.
    case skipped(clouds: Int)
}

/// C4. The only custom artwork in the app: the sky over the roofs of five houses.
/// Drawn in a 390 × 330 space and scaled to the available width.
struct CityScene: View {
    let state: CityState
    var progress = RitualProgress()
    var date = Date.now

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / Layout.size.width, y: size.height / Layout.size.height)
            draw(in: &context)
        }
        .aspectRatio(Layout.size.width / Layout.size.height, contentMode: .fit)
        .accessibilityIgnoresInvertColors()
        // One label for the whole scene, describing what it means rather than what is drawn.
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(isComplete ? Text(constellation.name) : Text(verbatim: ""))
        .accessibilityHidden(state == .welcome || state == .counter)
        // Reduce Motion needs no special case: states change with a crossfade only.
        .animation(.default, value: state)
    }

    private var label: Text {
        let total = constellation.stars.count
        switch state {
        case .waiting(let count), .skipped(let count):
            return Text("\(count) screenshots waiting, \(windowsLit) days this week, \(starsLit) of \(total) stars this month")
        default:
            return Text("\(windowsLit) days this week, \(starsLit) of \(total) stars this month")
        }
    }

    private var isComplete: Bool {
        starsLit > 0 && starsLit == constellation.stars.count
    }

    private var constellation: Constellation {
        .forMonth(of: date)
    }

    private var starsLit: Int {
        switch state {
        case .welcome, .counter: 0
        default: min(progress.starsLit, constellation.stars.count)
        }
    }

    private var windowsLit: Int {
        switch state {
        case .welcome, .counter: 1
        case .empty: Layout.windows.count
        default: progress.windowsLit
        }
    }

    private var clouds: [Layout.Cloud] {
        switch state {
        case .welcome: Layout.welcomeCloud
        case .counter: Layout.overcast
        case .waiting(let count): Layout.clouds(count)
        case .skipped(let count): Layout.clouds(count + 3)
        case .done, .empty: []
        }
    }

    private func draw(in context: inout GraphicsContext) {
        for star in Layout.smallStars {
            context.fill(circle(star.x, star.y, star.radius), with: .color(Color(.citySmallStar)))
        }
        drawConstellation(in: &context)
        drawLuminary(in: &context)
        for cloud in clouds {
            drawCloud(cloud, in: &context)
        }
        drawHouses(in: &context)
    }

    // MARK: Constellation

    private func drawConstellation(in context: inout GraphicsContext) {
        let constellation = constellation
        // The figure fits the same area of the sky, left of the sun or moon, in every state.
        let scale = min(Layout.sky.width / constellation.width, Layout.sky.height / constellation.height)
        let origin = CGPoint(
            x: Layout.sky.minX + (Layout.sky.width - constellation.width * scale) / 2,
            y: Layout.sky.minY + (Layout.sky.height - constellation.height * scale) / 2
        )
        let points = constellation.stars.map { CGPoint(x: origin.x + $0[0] * scale, y: origin.y + $0[1] * scale) }
        let lit = starsLit

        for point in points.dropFirst(lit) {
            context.fill(circle(point.x, point.y, 1.6), with: .color(Color(.cityStarUnlit)))
        }
        // A line appears once both of its stars are lit.
        for edge in constellation.edges where edge[0] < lit && edge[1] < lit {
            var line = Path()
            line.move(to: points[edge[0]])
            line.addLine(to: points[edge[1]])
            context.stroke(line, with: .color(Color(.cityLine)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
        }
        for (index, point) in points.prefix(lit).enumerated() {
            if state == .done(newStar: true), index == lit - 1 {
                context.fill(sparkle(at: point), with: .color(Color(.cityStar)))
            } else {
                context.fill(circle(point.x, point.y, 2.9), with: .color(Color(.cityStar)))
            }
        }
        // The name stays hidden until the constellation is complete.
        if isComplete {
            context.draw(
                Text(constellation.name).font(.footnote).foregroundStyle(Color(.cityLine)),
                at: Layout.namePosition
            )
        }
    }

    /// A four-pointed star for the one earned by this session.
    private func sparkle(at center: CGPoint) -> Path {
        let tips = [CGPoint(x: 0, y: -10), CGPoint(x: 10, y: 0), CGPoint(x: 0, y: 10), CGPoint(x: -10, y: 0)]
        var path = Path()
        path.move(to: CGPoint(x: center.x + tips[0].x, y: center.y + tips[0].y))
        for index in tips.indices {
            let from = tips[index], to = tips[(index + 1) % tips.count]
            // Control points sit close to the center, which pulls the sides inward.
            path.addCurve(
                to: CGPoint(x: center.x + to.x, y: center.y + to.y),
                control1: CGPoint(x: center.x + from.x * 0.4533 + to.x * 0.12, y: center.y + from.y * 0.4533 + to.y * 0.12),
                control2: CGPoint(x: center.x + from.x * 0.12 + to.x * 0.4533, y: center.y + from.y * 0.12 + to.y * 0.4533)
            )
        }
        path.closeSubpath()
        return path
    }

    // MARK: Sun and moon

    private func drawLuminary(in context: inout GraphicsContext) {
        let center = Layout.luminary, radius = 20.0
        guard colorScheme == .dark else {
            // The sun never changes size: "all caught up" is signalled by windows and text.
            context.fill(circle(center.x, center.y, 34), with: .color(Color(.cityLuminaryShade)))
            context.fill(circle(center.x, center.y, radius), with: .color(Color(.cityLuminary)))
            return
        }
        context.fill(circle(center.x, center.y, radius), with: .color(Color(.cityLuminaryShade)))

        let phase = MoonPhase(date: date)
        // The lit part lies between the limb and the terminator, which is half an
        // ellipse: it bulges away from the limb before the half phase and toward it after.
        // One closed outline: two shapes sharing the vertical chord leave a hairline there.
        var lit = Path()
        lit.addArc(center: .zero, radius: radius, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
        lit.addArc(
            center: .zero, radius: radius, startAngle: .degrees(90), endAngle: .degrees(-90), clockwise: true,
            transform: CGAffineTransform(scaleX: 1 - 2 * phase.illumination, y: 1)
        )
        lit.closeSubpath()
        // The lit side is on the right while waxing and on the left while waning.
        let side = CGAffineTransform(translationX: center.x, y: center.y).scaledBy(x: phase.isWaxing ? 1 : -1, y: 1)
        context.fill(lit.applying(side), with: .color(Color(.cityLuminary)))
    }

    // MARK: Clouds

    private func drawCloud(_ cloud: Layout.Cloud, in context: inout GraphicsContext) {
        var context = context
        context.translateBy(x: cloud.x, y: cloud.y)
        context.scaleBy(x: cloud.radius / 16, y: cloud.radius / 16)

        var shape = circle(16, 30, 16)
        shape.addPath(circle(36, 20, 20))
        shape.addPath(circle(60, 28, 16))
        shape.addRoundedRect(in: CGRect(x: 6, y: 28, width: 64, height: 18), cornerSize: CGSize(width: 9, height: 9))
        context.fill(shape, with: .color(Color(.cityCloud)))

        // The screenshot card each cloud carries: two sheets, slightly fanned.
        let back = card(x: 26.5, y: 18.2, angle: -13)
        context.fill(back, with: .color(Color(.cityCardBack)))
        let front = card(x: 32.9, y: 17.8, angle: 5)
        context.fill(front, with: .color(Color(.cityCardFront)))
        context.stroke(front, with: .color(Color(.cityCardStroke)), lineWidth: 0.96)
    }

    private func card(x: Double, y: Double, angle: Double) -> Path {
        let rect = CGRect(x: -5.6, y: -10.4, width: 11.2, height: 20.8)
        let transform = CGAffineTransform(translationX: x + 5.6, y: y + 10.4).rotated(by: angle * .pi / 180)
        return Path(roundedRect: rect, cornerRadius: 2.8).applying(transform)
    }

    // MARK: Houses

    private func drawHouses(in context: inout GraphicsContext) {
        for house in Layout.houses {
            context.fill(Path(house.body), with: .color(Color(house.isAlternate ? .cityHouseAlt : .cityHouse)))
            context.fill(house.roof, with: .color(Color(.cityRoof)))
        }
        let lit = Set(Layout.lightingOrder.prefix(windowsLit))
        for (index, origin) in Layout.windows.enumerated() {
            let isLit = windowsLit >= Layout.windows.count || lit.contains(index)
            context.fill(
                Path(roundedRect: CGRect(origin: origin, size: CGSize(width: 12, height: 14)), cornerRadius: 2),
                with: .color(Color(isLit ? .cityWindowLit : .cityWindow))
            )
        }
    }

    private func circle(_ x: Double, _ y: Double, _ radius: Double) -> Path {
        Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
    }
}

// MARK: - Layout

private enum Layout {
    struct Cloud {
        let x, y, radius: Double
    }

    struct House {
        let body: CGRect
        let roof: Path
        let isAlternate: Bool
    }

    static let size = CGSize(width: 390, height: 330)
    /// Area the constellation is fitted into.
    static let sky = CGRect(x: 44.7, y: 14, width: 202.6, height: 182)
    static let namePosition = CGPoint(x: 123, y: 207)
    static let luminary = CGPoint(x: 322, y: 54)

    static let welcomeCloud = [Cloud(x: 184, y: 120, radius: 16)]
    static let waitingClouds = [
        Cloud(x: 180.8, y: 91.5, radius: 15.2), Cloud(x: 235.6, y: 149, radius: 14.4),
        Cloud(x: 135.6, y: 159, radius: 14.4),
    ]
    static let skippedClouds = [
        Cloud(x: 177.2, y: 36, radius: 12.8), Cloud(x: 221.6, y: 91, radius: 14.4),
        Cloud(x: 146.4, y: 156.5, radius: 13.6), Cloud(x: 249.2, y: 154, radius: 12.8),
        Cloud(x: 288, y: 97.5, radius: 12), Cloud(x: 184.8, y: 109, radius: 11.2),
    ]
    static let overcast = [
        Cloud(x: 17.2, y: 36, radius: 12.8), Cloud(x: 96.4, y: 14.5, radius: 13.6),
        Cloud(x: 185.6, y: 29, radius: 14.4), Cloud(x: 45.6, y: 93, radius: 14.4),
        Cloud(x: 134.8, y: 79.5, radius: 15.2), Cloud(x: 230.4, y: 94.5, radius: 13.6),
        Cloud(x: 8, y: 157.5, radius: 12), Cloud(x: 89.6, y: 159, radius: 14.4),
        Cloud(x: 182.4, y: 154.5, radius: 13.6), Cloud(x: 277.2, y: 152, radius: 12.8),
        Cloud(x: 292.8, y: 91, radius: 11.2),
    ]

    /// The references define three layouts; larger portions reuse the denser ones.
    static func clouds(_ count: Int) -> [Cloud] {
        let layout = count <= waitingClouds.count ? waitingClouds
            : count <= skippedClouds.count ? skippedClouds : overcast
        return Array(layout.prefix(max(0, count)))
    }

    static let houses: [House] = [
        House(
            body: CGRect(x: 0, y: 268, width: 70, height: 62),
            roof: gable(left: -4, peak: 35, right: 74, top: 242, base: 268, chimneyX: 46, chimneyY: 238),
            isAlternate: false
        ),
        House(body: CGRect(x: 74, y: 246, width: 60, height: 84), roof: flat(x: 71, y: 240, width: 66), isAlternate: true),
        House(body: CGRect(x: 138, y: 226, width: 112, height: 104), roof: flat(x: 135, y: 220, width: 118), isAlternate: false),
        House(
            body: CGRect(x: 254, y: 258, width: 66, height: 72),
            roof: gable(left: 250, peak: 287, right: 324, top: 232, base: 258, chimneyX: 298, chimneyY: 228),
            isAlternate: true
        ),
        House(body: CGRect(x: 324, y: 278, width: 66, height: 52), roof: flat(x: 321, y: 272, width: 72), isAlternate: false),
    ]

    static let windows: [CGPoint] = [
        CGPoint(x: 12, y: 282), CGPoint(x: 46, y: 282), CGPoint(x: 12, y: 308), CGPoint(x: 46, y: 308),
        CGPoint(x: 86, y: 260), CGPoint(x: 110, y: 260), CGPoint(x: 86, y: 286), CGPoint(x: 110, y: 286),
        CGPoint(x: 150, y: 240), CGPoint(x: 188, y: 240), CGPoint(x: 226, y: 240),
        CGPoint(x: 150, y: 266), CGPoint(x: 188, y: 266), CGPoint(x: 226, y: 266),
        CGPoint(x: 150, y: 292), CGPoint(x: 188, y: 292), CGPoint(x: 226, y: 292),
        CGPoint(x: 266, y: 272), CGPoint(x: 296, y: 272), CGPoint(x: 266, y: 298), CGPoint(x: 296, y: 298),
        CGPoint(x: 336, y: 292), CGPoint(x: 366, y: 292),
    ]
    /// Which window lights up for the first, second, … seventh day of the week.
    /// The first five follow the references; the last two are not drawn there.
    static let lightingOrder = [7, 18, 4, 17, 11, 10, 1]

    static let smallStars: [(x: Double, y: Double, radius: Double)] = [
        (181, 83, 1), (79, 145, 1.3), (196, 189, 1), (134, 197, 1.7), (25, 85, 1.7), (360, 200, 1.3),
        (68, 56, 1), (59, 184, 1.7), (33, 147, 1.7), (338, 194, 1), (259, 155, 1.3), (339, 164, 1),
        (157, 77, 1), (84, 187, 1.3), (30, 85, 1.3), (61, 56, 1.7), (345, 31, 1.7), (11, 162, 1),
        (341, 49, 1), (340, 35, 1), (195, 124, 1.7), (351, 93, 1.3), (81, 163, 1.7), (225, 43, 1.7),
        (276, 16, 1.3), (215, 130, 1), (286, 157, 1.7), (379, 33, 1.7), (159, 191, 1), (236, 17, 1.3),
        (323, 113, 1.7), (297, 26, 1.3), (51, 186, 1.3), (177, 89, 1.7), (286, 85, 1.7), (132, 96, 1),
        (92, 62, 1), (124, 66, 1.7), (300, 13, 1.7), (309, 108, 1.7), (298, 122, 1), (167, 55, 1.3),
        (199, 201, 1.7), (147, 143, 1),
    ]

    private static func flat(x: Double, y: Double, width: Double) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: width, height: 8), cornerRadius: 2)
    }

    private static func gable(
        left: Double, peak: Double, right: Double, top: Double, base: Double, chimneyX: Double, chimneyY: Double
    ) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: left, y: base))
        path.addLine(to: CGPoint(x: peak, y: top))
        path.addLine(to: CGPoint(x: right, y: base))
        path.closeSubpath()
        path.addRect(CGRect(x: chimneyX, y: chimneyY, width: 8, height: 18))
        return path
    }
}

#if DEBUG
#Preview("Night") {
    ScrollView {
        VStack(spacing: 24) {
            CityScene(state: .welcome)
            CityScene(state: .counter)
            CityScene(state: .waiting(clouds: 3), progress: .preview(stars: 12, windows: 4))
            CityScene(state: .done(newStar: true), progress: .preview(stars: 13, windows: 5))
            CityScene(state: .empty, progress: .preview(stars: 13, windows: 5))
            CityScene(state: .skipped(clouds: 3), progress: .preview(stars: 9, windows: 2))
            CityScene(state: .done(newStar: false), progress: .preview(stars: 23, windows: 7))
        }
    }
    .background(Color(.appBackground))
    .preferredColorScheme(.dark)
}

#Preview("Day") {
    ScrollView {
        VStack(spacing: 24) {
            CityScene(state: .welcome)
            CityScene(state: .counter)
            CityScene(state: .waiting(clouds: 3), progress: .preview(stars: 12, windows: 4))
            CityScene(state: .done(newStar: true), progress: .preview(stars: 13, windows: 5))
            CityScene(state: .empty, progress: .preview(stars: 13, windows: 5))
            CityScene(state: .skipped(clouds: 3), progress: .preview(stars: 9, windows: 2))
            CityScene(state: .done(newStar: false), progress: .preview(stars: 23, windows: 7))
        }
    }
    .background(Color(.appBackground))
    .preferredColorScheme(.light)
}

extension RitualProgress {
    static func preview(stars: Int, windows: Int) -> RitualProgress {
        var progress = RitualProgress()
        progress.starsLit = stars
        progress.nightsLit = stars
        progress.starsTotal = 23
        progress.windowsLit = windows
        progress.constellationName = "Perseus"
        return progress
    }
}
#endif
