import Foundation

/// C3. Something useful to do with what a screenshot says. Facts come only from
/// deterministic detectors, never from the model.
nonisolated enum ContextAction: Equatable, Sendable, Identifiable {
    case calendar(Date)
    case maps(String)
    case link(URL)
    case call(String)

    var id: String { title }

    var title: String {
        switch self {
        case .calendar: String(localized: "Add to Calendar")
        case .maps: String(localized: "Open in Maps")
        case .link: String(localized: "Open Link")
        case .call: String(localized: "Call")
        }
    }

    var symbolName: String {
        switch self {
        case .calendar: "calendar.badge.plus"
        case .maps: "map"
        case .link: "safari"
        case .call: "phone"
        }
    }

    /// The URL to open. Calendar has none: it presents the system event editor instead.
    var url: URL? {
        switch self {
        case .calendar:
            return nil
        case .maps(let address):
            var components = URLComponents(string: "https://maps.apple.com/")
            components?.queryItems = [URLQueryItem(name: "q", value: address)]
            return components?.url
        case .link(let url):
            return url
        case .call(let number):
            return URL(string: "tel:" + number.filter { $0.isNumber || $0 == "+" })
        }
    }

    /// At most one action of each kind, in priority order: date, address, link, phone.
    static func detect(in text: String, now: Date = .now) -> [ContextAction] {
        let types: NSTextCheckingResult.CheckingType = [.date, .address, .link, .phoneNumber]
        guard let detector = try? NSDataDetector(types: types.rawValue) else { return [] }
        var calendar: ContextAction?, maps: ContextAction?, link: ContextAction?, call: ContextAction?

        for match in detector.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range, in: text) else { continue }
            let matched = String(text[range])
            switch match.resultType {
            case .date:
                // A bare time such as the status bar clock is not an event, and neither is the past.
                let isTimeOnly = matched.allSatisfy { $0.isNumber || $0 == ":" || $0 == "." || $0.isWhitespace }
                    || matched.count < 6
                if calendar == nil, !isTimeOnly, let date = match.date, date > now {
                    calendar = .calendar(date)
                }
            case .address:
                if maps == nil { maps = .maps(matched.replacingOccurrences(of: "\n", with: ", ")) }
            case .link:
                if link == nil, let url = match.url, url.scheme == "http" || url.scheme == "https" {
                    link = .link(url)
                }
            case .phoneNumber:
                if call == nil, let number = match.phoneNumber { call = .call(number) }
            default:
                break
            }
        }
        return [calendar, maps, link, call].compactMap(\.self)
    }
}
