import Foundation

// Shared substring-based grouping used by ProjectResultsView, which displays
// materials from more than one calculator at once. Each standalone results
// view (ResultsView, StairsResultsView, CoveredDeckResultsView) keeps its own
// small copy of this same idea — this shared version exists only so the
// combined Project view doesn't need a fourth copy.
enum MaterialGrouping {
    static func group(
        _ items: [MaterialItem],
        into categories: [(title: String, needles: [String])],
        otherTitle: String = "Other"
    ) -> [(title: String, items: [MaterialItem])] {
        func matches(_ it: MaterialItem, needles: [String]) -> Bool {
            let name = it.name.lowercased()
            return needles.contains { name.contains($0.lowercased()) }
        }

        var result: [(String, [MaterialItem])] = []
        var claimed = Set<UUID>()

        for (title, needles) in categories {
            let matched = items.filter { matches($0, needles: needles) && !claimed.contains($0.id) }
            if !matched.isEmpty {
                result.append((title, matched))
                matched.forEach { claimed.insert($0.id) }
            }
        }

        let leftover = items.filter { !claimed.contains($0.id) }
        if !leftover.isEmpty {
            result.append((otherTitle, leftover))
        }
        return result
    }

    static let deckCategories: [(title: String, needles: [String])] = [
        ("Decking", ["Deck boards", "Decking (linear", "Deck screws", "Hidden fastener", "Starter/edge clips"]),
        ("Framing", ["Joists", "Joist hanger", "Blocking", "Beam", "Posts ", "Post lumber", "Concrete footings", "Post bases", "Post-to-beam", "Ledger structural"]),
        ("Railing", ["Railing"])
    ]

    static let stairsCategories: [(title: String, needles: [String])] = [
        ("Stair Structure", ["Risers", "Treads", "Stringers"]),
        ("Decking", ["Riser boards", "Tread decking"]),
        ("Fasteners", ["Stair screws", "Stringer hangers"]),
        ("Railing", ["Stair railing", "Stair handrail"]),
        ("Landing", ["Landing"]),
        ("Planters", ["Planter"])
    ]

    static let coveredDeckCategories: [(title: String, needles: [String])] = [
        ("Framing", ["Rafters", "Posts", "Beam", "Ridge Board"]),
        ("Roofing", ["Roof Sheathing", "Shingles", "Metal Roofing"]),
        ("Trim", ["Hip Trim", "Valley Flashing"])
    ]
}
