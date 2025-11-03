import SwiftUI

// MARK: - CategoryStyle
// Consistent icon + color per material category, used to give every results
// screen's section headers a quick visual identity instead of plain text.
enum CategoryStyle {
    static func icon(for title: String) -> String {
        switch title {
        case "Decking": return "rectangle.grid.3x2.fill"
        case "Framing": return "hammer.fill"
        case "Railing": return "shield.fill"
        case "Stair Structure": return "figure.stairs"
        case "Fasteners": return "bolt.fill"
        case "Roofing": return "house.lodge.fill"
        case "Trim": return "ruler.fill"
        case "Landing": return "square.split.bottomrightquarter.fill"
        case "Planters": return "leaf.fill"
        default: return "shippingbox.fill"
        }
    }

    static func color(for title: String) -> Color {
        switch title {
        case "Decking": return .brown
        case "Framing": return .gray
        case "Railing": return .teal
        case "Stair Structure": return .orange
        case "Fasteners": return .indigo
        case "Roofing": return .indigo
        case "Trim": return .purple
        case "Landing": return .orange
        case "Planters": return .green
        default: return .secondary
        }
    }
}

// MARK: - CategoryHeader
// A colored, icon-led replacement for a plain Section("Title") header.
// `prefix` optionally prepends a component name (e.g. "Deck: Decking") while
// still styling by the category part alone.
struct CategoryHeader: View {
    let title: String
    var prefix: String? = nil

    var body: some View {
        let displayTitle = prefix.map { "\($0): \(title)" } ?? title
        Label(displayTitle, systemImage: CategoryStyle.icon(for: title))
            .foregroundStyle(CategoryStyle.color(for: title))
    }
}

// MARK: - TotalsSummary
// Quick "N line items" strip shown at the top of a results screen.
struct TotalsSummary: View {
    let itemCount: Int

    var body: some View {
        Label("\(itemCount) line item\(itemCount == 1 ? "" : "s")", systemImage: "checklist")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}
