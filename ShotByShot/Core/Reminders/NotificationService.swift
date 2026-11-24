import Foundation
import Observation
import UserNotifications

/// Local notifications only. Permission is asked in context, never at launch.
@Observable
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    enum Status {
        case notDetermined, allowed, denied
    }

    private(set) var status = Status.notDetermined
    /// Grows each time the daily notification is tapped; the root view opens a session in response.
    private(set) var sessionRequests = 0
    /// Set when a screenshot reminder is tapped; the root view opens that screenshot and clears it.
    var openedAssetID: String?

    @ObservationIgnored private let center = UNUserNotificationCenter.current()

    /// How many days ahead the daily reminder is scheduled.
    private static let daysAhead = 7
    nonisolated private static let dailyKind = "daily"
    nonisolated private static let screenshotKind = "screenshot"

    override init() {
        super.init()
        center.delegate = self
    }

    func refreshStatus() async {
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: status = .notDetermined
        case .denied: status = .denied
        default: status = .allowed
        }
    }

    func requestPermission() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        await refreshStatus()
        return granted
    }

    /// N1. A repeating trigger cannot skip a single day, and the reminder must stay
    /// silent once today's portion is done or the inbox is empty. So each day gets its
    /// own notification, and the schedule is rebuilt whenever the app's state changes.
    func scheduleDaily(
        enabled: Bool, minutesFromMidnight: Int, portion: Int, skipToday: Bool,
        now: Date = .now, calendar: Calendar = .current
    ) async {
        let identifiers = (0..<Self.daysAhead).map { "daily-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        await refreshStatus()
        guard enabled, status == .allowed, portion > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "\(portion) screenshots are waiting")
        content.body = String(localized: "Take a minute to decide what to keep.")
        content.sound = .default
        content.userInfo = ["kind": Self.dailyKind]

        for (offset, identifier) in identifiers.enumerated() where !(offset == 0 && skipToday) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)),
                  let fireDate = calendar.date(byAdding: .minute, value: minutesFromMidnight, to: day),
                  fireDate > now
            else { continue }
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        }
    }

    /// N2. Sets, moves or, with a `nil` date, clears the reminder of a kept screenshot.
    /// If notifications are not allowed, the screenshot simply stays without a reminder.
    func setReminder(_ date: Date?, for item: ScreenshotItem, categoryTitle: String) async {
        if let identifier = item.reminderNotificationID {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
        }
        item.reminderAt = nil
        item.reminderNotificationID = nil
        guard let date else { return }

        if status == .notDetermined {
            _ = await requestPermission()
        } else {
            await refreshStatus()
        }
        guard status == .allowed else { return }

        // Never the contents of the screenshot or its recognized text.
        let content = UNMutableNotificationContent()
        content.title = item.note.split(whereSeparator: \.isNewline).first.map(String.init)
            ?? String(localized: "Screenshot reminder")
        content.body = String(localized: "\(categoryTitle) · saved \(item.addedAt.formatted(.dateTime.month().day()))")
        content.sound = .default
        content.userInfo = ["kind": Self.screenshotKind, "assetID": item.assetID]

        let identifier = "screenshot-\(item.assetID)"
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        // A reminder the system did not accept must not be shown as set.
        do {
            try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        } catch {
            return
        }
        item.reminderAt = date
        item.reminderNotificationID = identifier
    }

    /// A record that leaves Library takes its pending reminder with it.
    func cancelReminder(withID identifier: String?) {
        guard let identifier else { return }
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    // MARK: UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let kind = userInfo["kind"] as? String
        let assetID = userInfo["assetID"] as? String
        await MainActor.run {
            if kind == Self.dailyKind {
                sessionRequests += 1
            } else if kind == Self.screenshotKind {
                openedAssetID = assetID
            }
        }
    }
}
