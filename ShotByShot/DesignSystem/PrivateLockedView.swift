import SwiftUI

/// Shown instead of anything from the Private category until it is unlocked.
struct PrivateLockedView: View {
    @Environment(PrivateLock.self) private var lock

    var body: some View {
        ContentUnavailableView {
            Label("Private is locked", systemImage: "lock")
        } description: {
            Text("Use Face ID to view these screenshots.")
        } actions: {
            Button("Unlock with Face ID") {
                Task { await lock.unlock() }
            }
            .buttonStyle(.bordered)
        }
        .background(Color(.appBackground))
    }
}

#if DEBUG
#Preview("Private locked") {
    PrivateLockedView()
        .environment(PrivateLock())
}
#endif
