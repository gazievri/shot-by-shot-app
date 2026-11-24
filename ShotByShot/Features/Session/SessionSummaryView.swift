import SwiftUI

/// S2. The remaining inbox count is deliberately not shown.
struct SessionSummaryView: View {
    let doneToday: Int
    let stats: ReviewStats
    var progress = RitualProgress()
    var earnedStar = false
    /// Zero hides the button: the inbox is empty.
    let nextPortionCount: Int
    /// Offered only while notifications have not been asked for yet.
    var reminderOffer: (portion: Int, time: Date)?
    var onRemind: () -> Void = {}
    let onReviewMore: () -> Void
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                CityScene(state: .done(newStar: earnedStar), progress: progress)
                VStack(spacing: 12) {
                    LabeledContent("This week", value: stats.reviewedThisWeek, format: .number)
                    Divider()
                    LabeledContent("This month", value: stats.reviewedThisMonth, format: .number)
                    Divider()
                    LabeledContent("Freed this month", value: stats.freedBytesThisMonth, format: .byteCount(style: .file))
                }
                .padding()
                .background(Color(.cardBackground), in: .rect(cornerRadius: 26))
                .padding(.horizontal)
                VStack(spacing: 4) {
                    Text("\(doneToday) done today")
                        .font(.title2)
                        .bold()
                        .accessibilityAddTraits(.isHeader)
                    if earnedStar {
                        Group {
                            if progress.isConstellationComplete {
                                Text("\(progress.constellationName) is complete. \(progress.nightsLit) nights this month.")
                            } else {
                                Text("A new star tonight. \(progress.windowsLit) windows lit this week.")
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                if let reminderOffer {
                    VStack(spacing: 8) {
                        Text("Get \(reminderOffer.portion) screenshots every evening at \(reminderOffer.time.formatted(date: .omitted, time: .shortened)).")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Remind Me Daily", action: onRemind)
                            .buttonStyle(.bordered)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                }
            }
        }
        .background(Color(.groupedBackground))
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                if nextPortionCount > 0 {
                    Button("Review \(nextPortionCount) More", action: onReviewMore)
                        .buttonStyle(.bordered)
                }
                Button(action: onDone) {
                    Text("Done")
                        .foregroundStyle(Color(.onAccent))
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
            .padding()
        }
    }
}

#if DEBUG
#Preview("S2 Summary") {
    SessionSummaryView(
        doneToday: 3,
        stats: ReviewStats(reviewedThisWeek: 14, reviewedThisMonth: 52, freedBytesThisMonth: 184_000_000),
        progress: .preview(stars: 13, windows: 5), earnedStar: true,
        nextPortionCount: 3, reminderOffer: (3, .now), onReviewMore: {}, onDone: {}
    )
}

#Preview("S2 Dark") {
    SessionSummaryView(
        doneToday: 3,
        stats: ReviewStats(reviewedThisWeek: 14, reviewedThisMonth: 52, freedBytesThisMonth: 184_000_000),
        progress: .preview(stars: 23, windows: 7), earnedStar: true,
        nextPortionCount: 3, onReviewMore: {}, onDone: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("S2 Inbox empty") {
    SessionSummaryView(
        doneToday: 2,
        stats: ReviewStats(reviewedThisWeek: 2, reviewedThisMonth: 2, freedBytesThisMonth: 0),
        nextPortionCount: 0, onReviewMore: {}, onDone: {}
    )
}
#endif
