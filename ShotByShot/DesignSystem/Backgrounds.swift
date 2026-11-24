import SwiftUI

extension View {
    /// Background for `Form` and grouped `List` screens. In the light theme the
    /// color resolves to the system grouped background, so nothing changes there.
    func groupedScreenBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Color(.groupedBackground))
    }

    /// Cells keep the system look in the light theme and use the card color in the dark one.
    /// Apply to a `Section` or a row, not to the whole list.
    func cardRowBackground() -> some View {
        modifier(CardRowBackground())
    }

    /// Sheets keep the system material in the light theme and turn indigo in the dark one.
    func sheetBackground() -> some View {
        modifier(SheetBackground())
    }
}

private struct SheetBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if colorScheme == .dark {
            content.presentationBackground(Color(.groupedBackground))
        } else {
            content
        }
    }
}

private struct CardRowBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if colorScheme == .dark {
            content.listRowBackground(Color(.cardBackground))
        } else {
            content
        }
    }
}
