import SwiftUI
import WidgetKit

/// W1. Shows the state of today's ritual; never the screenshots themselves.
@main
struct ShotByShotWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ShotByShotWidget", provider: Provider()) { entry in
            WidgetView(entry: entry)
        }
        .configurationDisplayName("Shot by Shot")
        .description("A few screenshots a day")
        .supportedFamilies([.systemSmall])
    }
}

struct Entry: TimelineEntry {
    let date: Date
    let state: WidgetSnapshot.State
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, state: .waiting(3))
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (Entry) -> Void) {
        completion(Entry(date: .now, state: Self.state(at: .now)))
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<Entry>) -> Void) {
        let now = Date.now
        // "Done for today" ends at midnight, and the nights start over with a new month,
        // even if the app is not opened.
        let midnight = Calendar.current.nextDate(
            after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(86_400)
        let entries = [now, midnight].map { Entry(date: $0, state: Self.state(at: $0)) }
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }

    static func state(at date: Date) -> WidgetSnapshot.State {
        guard let defaults = UserDefaults(suiteName: "group.com.ruslangaziev.ShotByShot") else { return .needsSetup }
        return WidgetSnapshot(defaults: defaults).state(at: date)
    }
}

struct WidgetView: View {
    let entry: Entry

    var body: some View {
        VStack(alignment: .leading) {
            switch entry.state {
            case .waiting(let count):
                figure(count)
                caption(Text("screenshots waiting"))
                Spacer(minLength: 0)
            case .done(let nights):
                VStack(alignment: .leading) {
                    figure(nights)
                    // The number is the figure above, so the caption cannot be a plural variation.
                    caption(nights == 1 ? Text("night this month") : Text("nights this month"))
                    Spacer(minLength: 0)
                    Label("Done for today", systemImage: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(Color(.accent))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Done for today, \(nights) nights this month"))
            case .needsSetup:
                Image(systemName: "lock")
                    .font(.largeTitle)
                    .widgetAccentable()
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                caption(Text("Open Shot by Shot to set up"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .containerBackground(for: .widget) {
            Color(.widgetBackground)
        }
        .widgetURL(URL(string: isDone ? "shotbyshot://inbox" : "shotbyshot://session"))
    }

    private var isDone: Bool {
        if case .done = entry.state { true } else { false }
    }

    /// The same structure for a waiting portion and a finished day: a large figure
    /// with its caption underneath.
    private func figure(_ value: Int) -> some View {
        Text(value, format: .number)
            .font(.largeTitle)
            .bold()
            .monospacedDigit()
            // Keeps the figure prominent in the tinted and clear Home Screen styles.
            .widgetAccentable()
    }

    private func caption(_ text: Text) -> some View {
        text
            .font(.footnote)
            .foregroundStyle(Color(.accent))
    }
}

#if DEBUG
#Preview("W1", as: .systemSmall) {
    ShotByShotWidget()
} timeline: {
    Entry(date: .now, state: .waiting(3))
    Entry(date: .now, state: .done(nights: 12))
    Entry(date: .now, state: .done(nights: 1))
    Entry(date: .now, state: .needsSetup)
}
#endif
