import Foundation

/// One real constellation per calendar month. Stars are listed in lighting order;
/// coordinates are normalized so the longer side equals 1, origin top-left.
nonisolated struct Constellation: Decodable, Equatable, Sendable {
    let month: Int
    let name: String
    let width: Double
    let height: Double
    let stars: [[Double]]
    let edges: [[Int]]

    static let all: [Constellation] = {
        struct File: Decodable {
            let constellations: [Constellation]
        }
        guard let url = Bundle.main.url(forResource: "constellations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data)
        else {
            fatalError("constellations.json is missing or malformed")
        }
        return file.constellations.sorted { $0.month < $1.month }
    }()

    static func forMonth(of date: Date, calendar: Calendar = .current) -> Constellation {
        all[calendar.component(.month, from: date) - 1]
    }
}
