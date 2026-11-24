import Foundation
import Observation
import SwiftData

/// Settings shared with the widget, so they live in the App Group defaults.
@Observable
final class AppSettings {
    static let appGroupID = "group.com.ruslangaziev.ShotByShot"

    @ObservationIgnored private let defaults: UserDefaults

    var portionSize: Int {
        didSet { defaults.set(portionSize, forKey: "portionSize") }
    }

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    var reminderEnabled: Bool {
        didSet { defaults.set(reminderEnabled, forKey: "reminderEnabled") }
    }

    /// Time of the daily reminder, in minutes from midnight.
    var reminderMinutes: Int {
        didSet { defaults.set(reminderMinutes, forKey: "reminderMinutes") }
    }

    /// The same time as a date, for `DatePicker` and for display.
    var reminderTime: Date {
        get {
            Calendar.current.date(byAdding: .minute, value: reminderMinutes, to: Calendar.current.startOfDay(for: .now)) ?? .now
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            reminderMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        }
    }

    init(defaults: UserDefaults = UserDefaults(suiteName: AppSettings.appGroupID) ?? .standard) {
        self.defaults = defaults
        let storedSize = defaults.integer(forKey: "portionSize")
        self.portionSize = storedSize > 0 ? storedSize : 3
        self.hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")
        self.reminderEnabled = defaults.bool(forKey: "reminderEnabled")
        // 8 PM until the person picks another time.
        self.reminderMinutes = defaults.object(forKey: "reminderMinutes") as? Int ?? 20 * 60
    }
}

extension ModelContainer {
    static func shotByShot(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([ScreenshotItem.self, DayLog.self, CategoryTitle.self])
        let configuration = inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, groupContainer: .none)
            : ModelConfiguration(schema: schema, groupContainer: .identifier(AppSettings.appGroupID))
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create the model container: \(error)")
        }
    }
}
