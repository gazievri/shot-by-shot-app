import SwiftData
import SwiftUI

/// P1.
struct SettingsView: View {
    let library: any PhotoLibrary

    @Environment(AppSettings.self) private var settings
    @Environment(NotificationService.self) private var notifications
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section("Daily Review") {
                    Toggle("Daily reminder", isOn: reminderBinding)
                    DatePicker("Time", selection: $settings.reminderTime, displayedComponents: .hourAndMinute)
                        .disabled(!settings.reminderEnabled)
                    Picker("Screenshots per session", selection: $settings.portionSize) {
                        ForEach([3, 5, 10], id: \.self) { size in
                            Text(size, format: .number).tag(size)
                        }
                    }
                }
                .cardRowBackground()
                Section("Categories") {
                    NavigationLink("Rename Categories") {
                        RenameCategoriesView()
                    }
                }
                .cardRowBackground()
                Section {
                    LabeledContent("Photos access", value: photosAccess)
                    Button("Open Settings", action: openAppSettings)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("All processing happens on your iPhone.")
                }
                .cardRowBackground()
                Section("About") {
                    LabeledContent("Version", value: version)
                }
                .cardRowBackground()
            }
            .groupedScreenBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheetBackground()
        .task {
            await notifications.refreshStatus()
        }
    }

    /// Turning the reminder on asks for permission in context. If notifications are
    /// blocked in the system, the only way forward is the app's page in Settings.
    private var reminderBinding: Binding<Bool> {
        Binding {
            settings.reminderEnabled && notifications.status == .allowed
        } set: { isOn in
            guard isOn else {
                settings.reminderEnabled = false
                return
            }
            switch notifications.status {
            case .allowed:
                settings.reminderEnabled = true
            case .denied:
                openAppSettings()
            case .notDetermined:
                Task {
                    settings.reminderEnabled = await notifications.requestPermission()
                }
            }
        }
    }

    private var photosAccess: String {
        switch library.access {
        case .full: String(localized: "Full Access")
        case .limited: String(localized: "Limited Access")
        case .notDetermined, .denied: String(localized: "None")
        }
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}

#if DEBUG
#Preview("P1 Settings") {
    SettingsView(library: PreviewPhotoLibrary())
        .environment(AppSettings(defaults: UserDefaults(suiteName: "preview")!))
        .environment(NotificationService())
        .modelContainer(.shotByShot(inMemory: true))
}

#Preview("P1 Dark") {
    SettingsView(library: PreviewPhotoLibrary())
        .environment(AppSettings(defaults: UserDefaults(suiteName: "preview")!))
        .environment(NotificationService())
        .modelContainer(.shotByShot(inMemory: true))
        .preferredColorScheme(.dark)
}
#endif
