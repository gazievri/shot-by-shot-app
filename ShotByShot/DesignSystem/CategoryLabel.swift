import SwiftUI

/// C2. Category is never signalled by color, only by title and symbol.
struct CategoryLabel: View {
    let category: Category

    @Environment(\.categoryTitles) private var titles

    var body: some View {
        Label(category.title(in: titles), systemImage: category.symbolName)
    }
}
