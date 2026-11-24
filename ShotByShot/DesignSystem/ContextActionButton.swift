import EventKitUI
import SwiftUI

/// C3. One button; the caller decides its style and where the other actions go.
struct ContextActionButton: View {
    let action: ContextAction
    /// Full-width label, for the stacked layout at accessibility sizes.
    var fillsWidth = false

    @Environment(\.openURL) private var openURL
    @State private var eventDate: Date?

    var body: some View {
        Button {
            if case .calendar(let date) = action {
                eventDate = date
            } else if let url = action.url {
                openURL(url)
            }
        } label: {
            Label(action.title, systemImage: action.symbolName)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
        }
        .sheet(isPresented: Binding(get: { eventDate != nil }, set: { if !$0 { eventDate = nil } })) {
            if let eventDate {
                EventEditor(date: eventDate)
                    .ignoresSafeArea()
            }
        }
    }
}

/// The system event editor. It needs no calendar permission: the person saves the event themselves.
private struct EventEditor: UIViewControllerRepresentable {
    let date: Date

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.startDate = date
        event.endDate = date.addingTimeInterval(3_600)
        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        func eventEditViewController(
            _ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction
        ) {
            dismiss()
        }
    }
}
