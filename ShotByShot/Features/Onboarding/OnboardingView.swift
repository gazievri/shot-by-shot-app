import SwiftUI

/// O1 and O2. Shown once, outside the tab view.
struct OnboardingView: View {
    let library: any PhotoLibrary
    /// Start the first session.
    let onReview: () -> Void
    /// Leave onboarding. `true` opens Inbox, `false` opens Library.
    let onFinish: (_ showInbox: Bool) -> Void

    @State private var isRequestingAccess = false

    var body: some View {
        switch library.access {
        case .notDetermined:
            WelcomeView(isBusy: isRequestingAccess) {
                isRequestingAccess = true
                Task {
                    await library.requestAccess()
                    isRequestingAccess = false
                    if library.access == .denied {
                        onFinish(false)
                    }
                }
            }
        case .full, .limited:
            CounterView(library: library, onReview: onReview, onLater: { onFinish(true) })
        case .denied:
            // Access was denied before onboarding finished, e.g. in Settings.
            Color(.appBackground)
                .ignoresSafeArea()
                .onAppear { onFinish(false) }
        }
    }
}

/// O1. Doubles as the pre-alert screen: one button, no way to skip.
private struct WelcomeView: View {
    let isBusy: Bool
    let onContinue: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !dynamicTypeSize.isAccessibilitySize {
                    OnboardingScene(state: .welcome)
                }
                Group {
                    Text("A few screenshots a day")
                        .font(.largeTitle)
                        .bold()
                        .accessibilityAddTraits(.isHeader)
                    Text("Each evening, Shot by Shot shows you a few old screenshots. Delete them, keep them, or act on them.")
                }
                .padding(.horizontal)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.appBackground))
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 16) {
                Label("Your screenshots never leave your iPhone.", systemImage: "lock")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button(action: onContinue) {
                    Text("Continue")
                        .foregroundStyle(Color(.onAccent))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isBusy)
            }
            .padding()
        }
    }
}

/// O2.
private struct CounterView: View {
    let library: any PhotoLibrary
    let onReview: () -> Void
    let onLater: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var totalBytes: Int64?

    private var olderThanYear: Int {
        let yearAgo = Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now
        return library.screenshots.count { ($0.takenAt ?? .now) < yearAgo }
    }

    var body: some View {
        if library.isLoading {
            counter
        } else if library.screenshots.isEmpty {
            ContentUnavailableView(
                "No screenshots yet", systemImage: "photo",
                description: Text("Take a screenshot and it will show up in your Inbox.")
            )
                .background(Color(.appBackground))
                .safeAreaInset(edge: .bottom) {
                    Button(action: onLater) {
                        Text("Continue")
                            .foregroundStyle(Color(.onAccent))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding()
                }
        } else {
            counter
        }
    }

    private var counter: some View {
        ScrollView {
            VStack(spacing: 8) {
                if !dynamicTypeSize.isAccessibilitySize {
                    OnboardingScene(state: .counter)
                }
                VStack(spacing: 4) {
                    if library.isLoading {
                        ProgressView()
                            .controlSize(.large)
                    } else {
                        Text(library.screenshots.count, format: .number)
                            .font(.largeTitle)
                            .bold()
                            .monospacedDigit()
                    }
                    Text("screenshots on your iPhone")
                }
                .padding(.horizontal)
                .accessibilityElement(children: .combine)
                if let totalBytes {
                    Text("\(olderThanYear.formatted()) are older than a year · \(totalBytes.formatted(.byteCount(style: .file)))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.appBackground))
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Button(action: onReview) {
                    Text("Review \(min(3, max(1, library.screenshots.count))) now")
                        .foregroundStyle(Color(.onAccent))
                }
                .buttonStyle(.borderedProminent)
                .disabled(library.isLoading)
                Button("Later", action: onLater)
                    .buttonStyle(.borderless)
            }
            .controlSize(.large)
            .padding()
        }
        .task(id: library.isLoading) {
            guard !library.isLoading else { return }
            totalBytes = await library.byteSize(of: library.screenshots.map(\.id))
        }
    }
}

/// The city on the onboarding screens: the houses fade into the background
/// so the scene reads as part of the page, not as an inserted picture.
private struct OnboardingScene: View {
    let state: CityState

    var body: some View {
        CityScene(state: state)
            .mask {
                LinearGradient(
                    stops: [.init(color: .black, location: 0.7), .init(color: .clear, location: 1)],
                    startPoint: .top, endPoint: .bottom
                )
            }
    }
}

#if DEBUG
#Preview("O1 Welcome") {
    OnboardingView(library: PreviewPhotoLibrary(access: .notDetermined), onReview: {}, onFinish: { _ in })
}

#Preview("O2 Counter") {
    OnboardingView(library: PreviewPhotoLibrary(count: 40), onReview: {}, onFinish: { _ in })
}

#Preview("O2 Counting") {
    let library = PreviewPhotoLibrary()
    library.isLoading = true
    return OnboardingView(library: library, onReview: {}, onFinish: { _ in })
}

#Preview("O2 No screenshots") {
    OnboardingView(library: PreviewPhotoLibrary(count: 0), onReview: {}, onFinish: { _ in })
}

#Preview("O1 Dark") {
    OnboardingView(library: PreviewPhotoLibrary(access: .notDetermined), onReview: {}, onFinish: { _ in })
        .preferredColorScheme(.dark)
}

#Preview("O2 Dark") {
    OnboardingView(library: PreviewPhotoLibrary(count: 40), onReview: {}, onFinish: { _ in })
        .preferredColorScheme(.dark)
}
#endif
