import SwiftData
import SwiftUI

@main
struct ShotByShotApp: App {
    private let container: ModelContainer
    private let settings: AppSettings
    private let library: any PhotoLibrary
    private let insight: any InsightService
    private let notifications = NotificationService()
    private let privateLock = PrivateLock()

    init() {
        #if DEBUG
        // The Simulator has no Screenshots album, so `-sampleLibrary` runs the whole
        // app on generated screenshots, starting from a clean first launch.
        if ProcessInfo.processInfo.arguments.contains("-sampleLibrary"),
           let defaults = UserDefaults(suiteName: "sample") {
            defaults.removePersistentDomain(forName: "sample")
            container = .shotByShot(inMemory: true)
            settings = AppSettings(defaults: defaults)
            let sampleLibrary = PreviewPhotoLibrary(access: .notDetermined)
            if ProcessInfo.processInfo.arguments.contains("-sampleStandardScreenshots") {
                sampleLibrary.screenshots.removeAll { $0.id == "preview-1" || $0.id == "preview-2" }
            }
            library = sampleLibrary
            // `-sampleModel` adds a stand-in for Apple Intelligence, which the Simulator lacks.
            insight = PreviewInsightService(
                isAvailable: ProcessInfo.processInfo.arguments.contains("-sampleModel")
            )
            return
        }
        #endif
        container = .shotByShot()
        settings = AppSettings()
        library = SystemPhotoLibrary()
        insight = SystemInsightService()
    }

    var body: some Scene {
        WindowGroup {
            RootView(library: library, insight: insight)
        }
        .modelContainer(container)
        .environment(settings)
        .environment(notifications)
        .environment(privateLock)
    }
}
