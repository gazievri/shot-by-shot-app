import SwiftData
import SwiftUI

/// S1 and, as its last step, S2.
struct SessionView: View {
    let library: any PhotoLibrary

    @State private var model: SessionModel
    @State private var showsPickDate = false
    @State private var showsSecure = false
    @State private var dragOffset: CGFloat = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.categoryTitles) private var titles
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(AppSettings.self) private var settings
    @Environment(NotificationService.self) private var notifications

    /// How far the screenshot has to be dragged for the gesture to count as a decision.
    private static let dragThreshold: CGFloat = 100

    init(
        library: any PhotoLibrary, insight: any InsightService, notifications: NotificationService,
        context: ModelContext, portionSize: Int, firstID: String?
    ) {
        self.library = library
        _model = State(initialValue: SessionModel(
            library: library, insight: insight, notifications: notifications,
            context: context, portionSize: portionSize, firstID: firstID
        ))
    }

    var body: some View {
        NavigationStack {
            switch model.phase {
            case .reviewing, .finishing:
                review
            case .summary:
                SessionSummaryView(
                    doneToday: model.doneToday,
                    stats: model.stats,
                    progress: model.progress,
                    earnedStar: model.earnedStar,
                    nextPortionCount: model.nextPortionCount,
                    reminderOffer: notifications.status == .notDetermined
                        ? (settings.portionSize, settings.reminderTime) : nil,
                    onRemind: {
                        Task {
                            settings.reminderEnabled = await notifications.requestPermission()
                        }
                    },
                    onReviewMore: { model.reviewMore() },
                    onDone: { dismiss() }
                )
            }
        }
        .task {
            model.start()
        }
    }

    private var review: some View {
        Group {
            if let current = model.current {
                layout(for: current)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: model.current?.id) {
            if let current = model.current {
                await model.limitWaiting(for: current)
            }
        }
        // A crossfade rather than a card flying away, so Reduce Motion needs no special case.
        .animation(.default, value: model.engine.currentIndex)
        .background(Color(.appBackground))
        .navigationTitle("\(min(model.engine.currentIndex + 1, model.portion.count)) of \(model.portion.count)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", systemImage: "xmark") {
                    Task {
                        await model.close()
                        dismiss()
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Undo", systemImage: "arrow.uturn.backward") {
                    model.undo()
                }
                .disabled(!model.canUndo)
            }
        }
        .disabled(model.phase == .finishing)
        .sheet(isPresented: $showsPickDate) {
            PickDateSheet { date in
                remind(at: date)
            }
        }
        .sheet(isPresented: $showsSecure) {
            if let current = model.current {
                SecureScreenshotSheet(
                    library: library, assetID: current.id, text: model.recognizedText,
                    onDelete: { await model.deleteNow() }
                )
            }
        }
        .sensoryFeedback(trigger: model.engine.decisions) { old, new in
            guard new.count > old.count, new.last != .skip else { return nil }
            return new.last == .delete ? .impact : .success
        }
    }

    /// Three arrangements of the same parts: stacked and scrolling at accessibility
    /// sizes, side by side in landscape, and the default with the actions pinned below.
    @ViewBuilder
    private func layout(for current: Screenshot) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            ScrollView {
                VStack(spacing: 12) {
                    media(current)
                        .frame(height: 320)
                    details(current)
                    stackedActions
                }
                .padding()
            }
        } else if verticalSizeClass == .compact {
            HStack(spacing: 16) {
                media(current)
                VStack(spacing: 8) {
                    Spacer()
                    details(current)
                    Spacer()
                    actionRow
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
        } else {
            VStack(spacing: 8) {
                media(current)
                details(current)
            }
            .padding(.horizontal)
            .safeAreaInset(edge: .bottom) {
                actionRow
                    .padding()
            }
        }
    }

    @ViewBuilder
    private func media(_ current: Screenshot) -> some View {
        if model.isUnavailable {
            ContentUnavailableView {
                Label("Couldn’t load this screenshot", systemImage: "photo")
            } description: {
                Text("It may be in iCloud or no longer in Photos.")
            }
        } else if model.isAssessed {
            screenshot(current)
        } else {
            // Checked for private content before anything is shown.
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func details(_ current: Screenshot) -> some View {
        if let takenAt = current.takenAt {
            Text(takenAt, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        if model.isUnavailable {
            // Nothing to say about a screenshot that cannot be seen.
        } else if model.sensitivity == .secret {
            secretWarning
        } else {
            if let caption = model.caption {
                Text(caption)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            }
            Group {
                if model.sensitivity != .none {
                    Button {
                        Task { await model.hideInPhotos() }
                    } label: {
                        Label("Hide in Photos", systemImage: "eye.slash")
                            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
                    }
                } else if let action = model.contextActions.first {
                    ContextActionButton(action: action, fillsWidth: dynamicTypeSize.isAccessibilitySize)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(dynamicTypeSize.isAccessibilitySize ? .large : .regular)
        }
    }

    /// Dragging is an accelerator for the buttons: left deletes, right keeps in the
    /// suggested category. A symbol at the edge says which, so color is not the only cue.
    private func screenshot(_ current: Screenshot) -> some View {
        AssetImage(library: library, id: current.id)
            .blur(radius: model.isBlurred ? 40 : 0)
            .overlay {
                if model.isBlurred {
                    VStack(spacing: 8) {
                        Group {
                            Image(systemName: "eye.slash")
                                .font(.largeTitle)
                                .accessibilityHidden(true)
                            Text("Hidden until you tap Show")
                                .font(.footnote)
                        }
                        .foregroundStyle(.secondary)
                        Button("Show") {
                            model.reveal()
                        }
                        .buttonStyle(.bordered)
                    }
                    // The blurred screenshot can be any color; a material keeps the text legible.
                    .padding()
                    .background(.regularMaterial, in: .rect(cornerRadius: 16))
                }
            }
            .clipShape(.rect(cornerRadius: 8))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: dragOffset < 0 ? .trailing : .leading) {
                if abs(dragOffset) > 20 {
                    Image(systemName: dragOffset < 0 ? "trash" : "archivebox")
                        .font(.largeTitle)
                        .foregroundStyle(dragOffset < 0 ? AnyShapeStyle(.red) : AnyShapeStyle(.tint))
                        .opacity(min(1, abs(dragOffset) / Self.dragThreshold))
                        .accessibilityHidden(true)
                }
            }
            .offset(x: reduceMotion ? 0 : dragOffset)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { drag in
                        // Without a suggested category there is nothing a drag to the right could do.
                        dragOffset = drag.translation.width > 0 && model.suggestedCategory == nil
                            ? 0 : drag.translation.width
                    }
                    .onEnded { _ in
                        let offset = dragOffset
                        dragOffset = 0
                        if offset < -Self.dragThreshold {
                            Task { await model.delete() }
                        } else if offset > Self.dragThreshold, let category = model.suggestedCategory {
                            Task { await model.keep(in: category) }
                        }
                    }
            )
            .accessibilityLabel(Text("Screenshot"))
            .id(current.id)
            .transition(.opacity)
    }

    /// For a screenshot that may hold a password: what the risk is and what to do about it.
    private var secretWarning: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Label {
                    Text("This may contain a password")
                        .font(.subheadline)
                        .bold()
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .symbolRenderingMode(.multicolor)
                }
                Text("Screenshots sync to iCloud and can be read by apps with photo access. Move it somewhere safe, then delete it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.fill.tertiary, in: .rect(cornerRadius: 16))
            Button("Not sensitive") {
                model.markNotSensitive()
            }
        }
    }

    /// The default row. `ViewThatFits` is not used: menus report a width that never
    /// fits, so the row would always fall back to the stacked layout.
    private var actionRow: some View {
        HStack(spacing: 8) {
            if model.isUnavailable {
                skipButton
            } else if model.sensitivity == .secret {
                // No plain Delete or Remind here: the safe path is to move the secret first.
                Spacer()
                keepInPrivateButton
                moveAndDeleteButton
            } else {
                // Everything but Keep is pinned to its own width; Keep takes what is left,
                // so the row stays put when a suggestion arrives or changes.
                Group {
                    deleteButton
                    remindMenu
                }
                .fixedSize(horizontal: true, vertical: false)
                keepButton
                categoryMenu
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .controlSize(.large)
    }

    /// At accessibility sizes every action gets a full-width button with a text label.
    private var stackedActions: some View {
        VStack(spacing: 12) {
            if model.isUnavailable {
                skipButton
            } else if model.sensitivity == .secret {
                moveAndDeleteButton
                keepInPrivateButton
            } else {
                HStack(spacing: 8) {
                    keepButton
                    categoryMenu
                        .fixedSize()
                }
                Menu {
                    RemindMenuItems(onPick: remind(at:), onPickDate: { showsPickDate = true })
                } label: {
                    Text("Remind")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                deleteButton
            }
        }
        .controlSize(.large)
    }

    /// The only action for a screenshot that could not be loaded: deciding blind is not offered.
    private var skipButton: some View {
        Button {
            Task { await model.skip() }
        } label: {
            Text("Skip")
                .foregroundStyle(Color(.onAccent))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }

    private var keepInPrivateButton: some View {
        Button {
            Task { await model.keep(in: .private) }
        } label: {
            Text("Keep in Private")
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
        }
        .buttonStyle(.bordered)
    }

    private var moveAndDeleteButton: some View {
        Button {
            showsSecure = true
        } label: {
            Text("Move & Delete…")
                .foregroundStyle(Color(.onAccent))
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
        }
        .buttonStyle(.borderedProminent)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            Task { await model.delete() }
        } label: {
            Text("Delete")
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
        }
        .buttonStyle(.bordered)
    }

    private var remindMenu: some View {
        Menu {
            RemindMenuItems(onPick: remind(at:), onPickDate: { showsPickDate = true })
        } label: {
            Image(systemName: "bell.fill")
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .accessibilityLabel(Text("Remind"))
    }

    /// With a suggestion, a tap keeps the screenshot there and a long press opens the list.
    /// Without one, or while the model is thinking, a tap opens the list right away.
    /// These are two controls, a button and a menu, but both fill the same width,
    /// so only the label changes.
    private var keepButton: some View {
        Group {
            if let category = model.suggestedCategory {
                Button {
                    Task { await model.keep(in: category) }
                } label: {
                    keepLabel(Text("Keep in \(category.title(in: titles))"), isThinking: false)
                }
                // The long press that opens the list is a context menu.
                .contextMenu {
                    categoryPicker
                }
            } else {
                Menu {
                    categoryPicker
                } label: {
                    keepLabel(Text("Keep"), isThinking: model.isThinking)
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .animation(.default, value: model.suggestedCategory)
    }

    private func keepLabel(_ text: Text, isThinking: Bool) -> some View {
        HStack {
            if isThinking {
                ProgressView()
                    .controlSize(.small)
            }
            text
                .contentTransition(.opacity)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                // The width is fixed by the row, so a long category name shrinks a little
                // before it is cut off.
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(Color(.onAccent))
        .frame(maxWidth: .infinity)
    }

    private var categoryMenu: some View {
        Menu {
            categoryPicker
        } label: {
            // Sized by the bell of the Remind button, so the two circles match each other
            // and the height of Keep; a chevron alone makes a smaller circle.
            Image(systemName: "bell.fill")
                .hidden()
                .overlay {
                    Image(systemName: "chevron.down")
                        .foregroundStyle(Color(.onAccent))
                }
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .accessibilityLabel(Text("Choose category"))
    }

    /// Picking a category keeps the screenshot in it; the suggested one carries a checkmark.
    private var categoryPicker: some View {
        Picker("Choose category", selection: Binding<Category?>(
            get: { model.suggestedCategory },
            set: { picked in
                if let picked {
                    Task { await model.keep(in: picked) }
                }
            }
        )) {
            // Private joins the list only when the screenshot looks private.
            ForEach(model.sensitivity == .none ? Category.selectable : Category.allCases) { category in
                CategoryLabel(category: category).tag(Optional(category))
            }
        }
        .pickerStyle(.inline)
        .labelsHidden()
    }

    private func remind(at date: Date) {
        Task { await model.remind(at: date, categoryTitles: titles) }
    }
}

#if DEBUG
private struct SessionPreview: View {
    var hasModel = true
    var isUnavailable = false

    var body: some View {
        let container = ModelContainer.shotByShot(inMemory: true)
        let notifications = NotificationService()
        let library = PreviewPhotoLibrary()
        if isUnavailable {
            library.unavailableIDs = Set(library.screenshots.map(\.id))
        }
        return SessionView(
            library: library, insight: PreviewInsightService(isAvailable: hasModel),
            notifications: notifications, context: container.mainContext, portionSize: 3, firstID: nil
        )
        .environment(AppSettings(defaults: UserDefaults(suiteName: "preview")!))
        .environment(notifications)
    }
}

#Preview("S1 Session") {
    SessionPreview()
}

#Preview("S1 Dark") {
    SessionPreview()
        .preferredColorScheme(.dark)
}

#Preview("S1 Without Apple Intelligence") {
    SessionPreview(hasModel: false)
}

#Preview("S1 Image not loaded") {
    SessionPreview(isUnavailable: true)
}

#Preview("S1 Image not loaded, dark") {
    SessionPreview(isUnavailable: true)
        .preferredColorScheme(.dark)
}
#endif
