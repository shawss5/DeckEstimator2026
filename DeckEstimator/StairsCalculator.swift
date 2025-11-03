import Foundation

struct StairsCalculator {

    private static func fmt(_ v: Double) -> String { displayNumber(v) }

    struct Computed {
        let risers: Int
        let finalRiserIn: Double
        let treads: Int
        let totalRunIn: Double
        let stringerCount: Int
        let stringerLenFt: Double
        let boardsPerTread: Double
    }

    static func computeGeometry(_ i: StairsInput) -> Computed {
        // Riser/tread counts
        let risers = max(2, Int(ceil(i.totalRiseIn / max(1, i.preferredRiserIn))))
        let finalRiser = i.totalRiseIn / Double(risers)
        let treads = max(1, risers - 1)
        let totalRunIn = Double(treads) * i.treadDepthIn

        // Stringers across width
        // e.g., 36" width @ 16" OC → floor(36/16)=2, +1 → 3 stringers
        let stringerCount = max(2, Int(floor(i.stairWidthIn / i.stringerSpacingIn)) + 1)

        // Stringer length along slope (add ~12" allowance for tail/top cuts)
        let hypIn = hypot(i.totalRiseIn, totalRunIn)
        let stringerLenFt = hypIn / 12.0 + 1.0

        // Deck boards per tread to achieve depth
        let moduleIn = max(0.01, i.boardWidthIn + i.boardGapIn)
        let boardsPerTread = ceil(i.treadDepthIn / moduleIn)

        return Computed(
            risers: risers,
            finalRiserIn: finalRiser,
            treads: treads,
            totalRunIn: totalRunIn,
            stringerCount: stringerCount,
            stringerLenFt: stringerLenFt,
            boardsPerTread: boardsPerTread
        )
    }

    // MARK: - Landing
    /// IRC R311.7.3: one flight may rise at most 151″ (12′ 7″) between floors or landings.
    static let maxFlightRiseIn: Double = 151
    /// IRC R311.7.6: landing at least as wide as the stairs and 36″ deep (straight run).
    static let minLandingDepthIn: Double = 36

    struct LandingPlan {
        let heightIn: Double      // ground to top of landing
        let lowerRiseIn: Double
        let upperRiseIn: Double
        let widthIn: Double
        let depthIn: Double
        let isAutoHeight: Bool
    }

    static func landingPlan(_ i: StairsInput) -> LandingPlan {
        let width = max(i.stairWidthIn, i.landingWidthIn)
        let depth = i.landingDepthIn > 0 ? i.landingDepthIn : minLandingDepthIn
        var h = i.landingHeightIn
        var auto = false
        if !(h > 0 && h < i.totalRiseIn) {
            // Halfway, snapped to a whole riser so both flights share the same riser height.
            let g = computeGeometry(i)
            let lowerRisers = g.risers / 2
            h = lowerRisers >= 1 ? Double(lowerRisers) * g.finalRiserIn : i.totalRiseIn / 2
            auto = true
        }
        return LandingPlan(heightIn: h, lowerRiseIn: h, upperRiseIn: i.totalRiseIn - h,
                           widthIn: width, depthIn: depth, isAutoHeight: auto)
    }

    static func materials(_ i: StairsInput) -> [MaterialItem] {
        guard i.includeLanding else { return flightMaterials(i, label: nil) }
        let plan = landingPlan(i)
        var upper = i; upper.totalRiseIn = plan.upperRiseIn; upper.includeLanding = false
        var lower = i; lower.totalRiseIn = plan.lowerRiseIn; lower.includeLanding = false
        var out = flightMaterials(upper, label: "Upper flight")
            + flightMaterials(lower, label: "Lower flight")
            + landingMaterials(i, plan)
        if i.includePlanters { out += planterMaterials(i) }
        return out
    }

    /// A planter counts as part of the guard only if it stands at least 36″
    /// above the landing (the IRC minimum guard height). Shorter planters
    /// still need railing behind them.
    static let planterGuardHeightIn: Double = 36

    static func planterCount(_ i: StairsInput) -> Int { max(0, Int(i.planterCount.rounded())) }

    /// Planter boxes built from decking boards stacked on 2×4 corner posts,
    /// with a slatted decking bottom and a landscape-fabric liner.
    static func planterMaterials(_ i: StairsInput) -> [MaterialItem] {
        let n = planterCount(i)
        guard n > 0, i.planterLengthIn > 0, i.planterWidthIn > 0, i.planterHeightIn > 0 else { return [] }
        let L = i.planterLengthIn, W = i.planterWidthIn, H = i.planterHeightIn
        let waste = 1 + i.wastePct / 100.0
        let moduleIn = max(0.01, i.boardWidthIn + i.boardGapIn)
        let courses = ceil(H / moduleIn)
        let perimeterIn = 2 * (L + W)
        let size = "\(fmt(L))″ × \(fmt(W))″ × \(fmt(H))″ tall"

        let sideLF = ceil(courses * perimeterIn / 12.0 * Double(n) * waste)
        let bottomBoards = ceil(L / moduleIn)
        let bottomLF = ceil(bottomBoards * W / 12.0 * Double(n) * waste)
        let cornerLF = ceil(4.0 * H / 12.0 * Double(n))
        let screws = ceil((courses * 16 + bottomBoards * 4) * Double(n) * waste)
        let fabricSqFt = ceil((perimeterIn * H + L * W) / 144.0 * Double(n) * 1.15)

        return [
            MaterialItem(name: "Planter side boards (linear feet)", qty: sideLF, unit: "LF",
                         notes: "\(n) planter\(n == 1 ? "" : "s"), \(size) • \(Int(courses)) rows of decking per side • includes waste"),
            MaterialItem(name: "Planter bottom boards (linear feet)", qty: bottomLF, unit: "LF",
                         notes: "Leave ¼″ gaps for drainage • includes waste"),
            MaterialItem(name: "Planter corner posts 2×4", qty: cornerLF, unit: "LF",
                         notes: "4 per planter, each \(DeckHeightRules.feetInches(H)) • screw side boards into these"),
            MaterialItem(name: "Planter screws (exterior)", qty: screws, unit: "pcs",
                         notes: "Side and bottom boards • includes waste"),
            MaterialItem(name: "Planter liner (landscape fabric)", qty: fabricSqFt, unit: "sq ft",
                         notes: "Lines sides and bottom • keeps soil off the wood")
        ]
    }

    /// The landing is built like a small freestanding deck: joists hung between
    /// two rim boards, 6×6 posts on footings, decking, and a guard when it's over 30″.
    static func landingMaterials(_ i: StairsInput, _ p: LandingPlan) -> [MaterialItem] {
        var out: [MaterialItem] = []
        let deepFrame = p.depthIn > 96
        let joistSize = deepFrame ? "2×10" : "2×8"
        let joistDepthIn = deepFrame ? 9.25 : 7.25
        let joistCount = Int(floor(p.widthIn / 16.0)) + 1
        let joistStock = Int(DeckPlanner.roundUpStockLength(p.depthIn / 12.0))
        let rimStock = Int(DeckPlanner.roundUpStockLength(p.widthIn / 12.0))
        let size = "\(fmt(p.widthIn))″ wide × \(fmt(p.depthIn))″ deep"

        out.append(MaterialItem(name: "Landing joists \(joistSize) × \(joistStock) ft", qty: Double(joistCount), unit: "pcs",
                                notes: "Span the \(fmt(p.depthIn))″ depth • 16″ OC • landing \(size)"))
        out.append(MaterialItem(name: "Landing rim boards \(joistSize) × \(rimStock) ft", qty: 2, unit: "pcs",
                                notes: "Along the \(fmt(p.widthIn))″ width; joists hang between them"))
        out.append(MaterialItem(name: "Landing joist hangers", qty: Double(joistCount * 2), unit: "pcs",
                                notes: "Both ends of each joist"))

        let posts = p.widthIn > 96 ? 6 : 4
        let postIn = p.heightIn - 1.0 - joistDepthIn
        if postIn > 0 {
            out.append(MaterialItem(name: "Landing posts 6×6", qty: Double(posts), unit: "pcs",
                                    notes: "Cut to ~\(DeckHeightRules.feetInches(postIn)) • footing to underside of frame • landing \(DeckHeightRules.feetInches(p.heightIn)) high"))
            let lp = DeckHeightRules.postLumberPlan(postIn: postIn, posts: posts)
            if lp.boards > 0 {
                let howToCut = lp.perBoard == 1 ? "1 post per board"
                    : (lp.boards == 1 ? "Cut all \(posts) posts from 1 board" : "Cut up to \(lp.perBoard) posts from each board")
                out.append(MaterialItem(name: "Landing post lumber 6×6 × \(lp.stockFt) ft", qty: Double(lp.boards),
                                        unit: lp.boards == 1 ? "board" : "boards", notes: howToCut))
            }
        } else {
            out.append(MaterialItem(name: "Landing posts", qty: 0, unit: "pcs",
                                    notes: "Landing is too low for posts under the frame — set the frame on footings or blocks"))
        }
        out.append(MaterialItem(name: "Landing concrete footings", qty: Double(posts), unit: "pcs", notes: "One per post"))
        out.append(MaterialItem(name: "Landing post bases (HDG)", qty: Double(posts), unit: "pcs", notes: "e.g., Simpson ABU66Z or equivalent"))

        let moduleIn = max(0.01, i.boardWidthIn + i.boardGapIn)
        let boardsAcross = ceil(p.depthIn / moduleIn)
        let deckLF = ceil(boardsAcross * (p.widthIn / 12.0) * (1 + i.wastePct / 100.0))
        out.append(MaterialItem(name: "Landing decking (linear feet)", qty: deckLF, unit: "LF",
                                notes: "\(Int(boardsAcross)) boards across the depth, each \(fmt(p.widthIn / 12.0)) ft • includes waste"))
        let screws = ceil(boardsAcross * Double(joistCount) * 2.0 * (1 + i.wastePct / 100.0))
        out.append(MaterialItem(name: "Landing deck screws", qty: screws, unit: "pcs", notes: "2 per joist crossing • includes waste"))

        if p.heightIn > 30 {
            // Straight run: stairs arrive on one side and leave from the opposite side.
            var openIn = 2 * (p.widthIn + p.depthIn) - 2 * i.stairWidthIn
            var note = "Open sides • guard required (landing more than 30″ above grade)"
            if i.includePlanters && planterCount(i) > 0 {
                if i.planterHeightIn >= planterGuardHeightIn {
                    let planterEdgeIn = min(openIn, Double(planterCount(i)) * i.planterLengthIn)
                    openIn -= planterEdgeIn
                    note += " • minus \(fmt(planterEdgeIn / 12.0)) ft where 36″+ planters form the edge (confirm with your inspector)"
                } else {
                    note += " • planters under 36″ tall don't count as a guard — railing still runs behind them"
                }
            }
            let openLF = ceil(max(0, openIn) / 12.0)
            out.append(MaterialItem(name: "Landing railing", qty: openLF, unit: "LF", notes: note))
        }
        return out
    }

    // MARK: - One flight
    static func flightMaterials(_ i: StairsInput, label: String?) -> [MaterialItem] {
        let g = computeGeometry(i)

        // Tread boards: run along width; board length = stair width (ft)
        let treadBoardLF = (i.stairWidthIn / 12.0) * Double(g.treads) * g.boardsPerTread
        let treadBoardLFWithWaste = ceil(treadBoardLF * (1 + i.wastePct / 100.0))

        // Screws: 2 per board per stringer (both edges) at each stringer crossing on each tread
        let screws = Double(g.treads) * g.boardsPerTread * Double(g.stringerCount) * 2.0
        let screwsWithWaste = ceil(screws * (1 + i.wastePct / 100.0))

        var out: [MaterialItem] = []

        out.append(MaterialItem(
            name: "Risers",
            qty: Double(g.risers),
            unit: "count",
            notes: "Final riser \(fmt(g.finalRiserIn))\" (verify ≤ 7.75\" by code)")
        )

        out.append(MaterialItem(
            name: "Treads",
            qty: Double(g.treads),
            unit: "count",
            notes: "Tread depth \(fmt(i.treadDepthIn))\"")
        )

        // Buy-able stock length; the note keeps the cut length.
        let stringerStock = Int(DeckPlanner.roundUpStockLength(g.stringerLenFt))
        out.append(MaterialItem(
            name: "Stringers 2×12 × \(stringerStock) ft",
            qty: Double(g.stringerCount),
            unit: "pcs",
            notes: "Cut length ≈ \(DeckHeightRules.feetInches(g.stringerLenFt * 12)) each (includes ~12″ for top and bottom cuts)")
        )

        if i.includeRisers {
            out.append(MaterialItem(
                name: "Riser boards (length = stair width)",
                qty: Double(g.treads),
                unit: "pcs",
                notes: "Each ≈ \(fmt(i.stairWidthIn/12.0)) ft")
            )
        }

        out.append(MaterialItem(
            name: "Tread decking (linear feet)",
            qty: treadBoardLFWithWaste,
            unit: "LF",
            notes: "\(Int(g.boardsPerTread)) boards per tread × \(g.treads) treads; length per board = stair width")
        )

        out.append(MaterialItem(
            name: "Stair screws",
            qty: screwsWithWaste,
            unit: "pcs",
            notes: "2 per board per stringer (incl. waste)")
        )

        out.append(MaterialItem(
            name: "Stringer hangers",
            qty: Double(g.stringerCount),
            unit: "pcs",
            notes: label == "Lower flight" ? "At the landing connection" : "At deck/ledger connection")
        )

        // Railing along the stairs, measured on the slope.
        // IRC: open sides of stairs rising more than 30″ need a guard (R312.1.1);
        // 4 or more risers need a handrail (R311.7.8).
        let slopeFt = hypot(i.totalRiseIn, g.totalRunIn) / 12.0
        let postsPerSide = Int(ceil(slopeFt / 6.0)) + 1
        if i.totalRiseIn > 30 {
            out.append(MaterialItem(
                name: "Stair railing (guard + handrail)",
                qty: ceil(slopeFt * 2),
                unit: "LF",
                notes: "Both open sides, \(DeckHeightRules.feetInches(slopeFt * 12)) each along the slope • guard required (stairs rise more than 30″) • if one side is against a wall, that side needs only a handrail"))
            out.append(MaterialItem(
                name: "Stair railing posts",
                qty: Double(postsPerSide * 2),
                unit: "pcs",
                notes: "~6 ft apart, both sides (verify locally)"))
        } else if g.risers >= 4 {
            out.append(MaterialItem(
                name: "Stair handrail",
                qty: ceil(slopeFt),
                unit: "LF",
                notes: "One side, along the slope • required at 4 or more risers"))
        }

        // Label each line when there are two flights ("Upper flight: Risers").
        if let label {
            let flightRise = DeckHeightRules.feetInches(i.totalRiseIn)
            out = out.map { item in
                var notes = item.notes
                if item.name == "Risers" { notes = "This flight rises \(flightRise) • " + (item.notes ?? "") }
                return MaterialItem(name: "\(label): \(item.name)", qty: item.qty, unit: item.unit, notes: notes)
            }
        }
        return out
    }
}
