import Foundation

// MARK: - Framing intelligence types (shared by DeckFormView and ProjectView)
enum LumberGrade: String, CaseIterable, Identifiable {
    case number2 = "#2"
    case number1 = "#1"
    var id: String { rawValue }
}

enum FastenerType: String, CaseIterable, Identifiable {
    case screws = "Deck screws"
    case trexClips = "Hidden clips (Trex Universal)"
    case timberTechClips = "Hidden clips (TimberTech CONCEALoc)"
    var id: String { rawValue }
}

// MARK: - Deck height rules
// Height drives post length, the 14 ft prescriptive post limit, and whether a
// guard (railing) is required. Thresholds follow the IRC; local codes vary,
// so every message tells the builder to verify locally.
enum DeckHeightRules {
    /// IRC R312.1.1: guards required where the walking surface is MORE than
    /// 30" above grade within 36" horizontally of the open side.
    static let guardRequiredAboveIn: Double = 30
    /// IRC Table R507.4 caps prescriptive deck-post height at 14 ft for every post size.
    static let maxPrescriptivePostFt: Double = 14
    /// 5/4 wood ≈ 1"; most composite ≈ 0.94". Use 1".
    static let deckingThicknessIn: Double = 1.0

    /// Actual depth (in) of a nominal size string like "2×10" or "(2) 2×12".
    /// Unknown sizes (e.g. "Engineer review") use the SHALLOWEST depth, so the
    /// post comes out longer — buying a post too long is safer than too short.
    static func actualDepthIn(_ nominal: String) -> Double {
        if nominal.contains("2×12") { return 11.25 }
        if nominal.contains("2×10") { return 9.25 }
        if nominal.contains("2×8")  { return 7.25 }
        return 7.25
    }

    /// Post height = top of footing/post base to underside of beam, assuming
    /// joists bear on top of a dropped beam (the standard prescriptive layout).
    static func postHeightIn(deckHeightIn: Double, joistSize: String, beamSize: String) -> Double {
        deckHeightIn - deckingThicknessIn - actualDepthIn(joistSize) - actualDepthIn(beamSize)
    }

    /// Cheapest sensible way to buy post stock: total board length is
    /// minimised, ties go to fewer boards. Short posts are cut several to a
    /// board (2″ per piece for squaring both ends + saw kerf), but only from
    /// boards 12 ft or shorter — longer 6×6s are heavy and often special order.
    /// A single post per board keeps the 6″ allowance used elsewhere.
    static func postLumberPlan(postIn: Double, posts: Int) -> (stockFt: Int, boards: Int, perBoard: Int) {
        guard posts > 0, postIn > 0 else { return (0, 0, 0) }
        let singleStock = Int(DeckPlanner.roundUpStockLength(postIn / 12.0 + 0.5))
        var best = (stockFt: singleStock, boards: posts, perBoard: 1)
        var bestTotal = singleStock * posts
        for s in [8, 10, 12, 14, 16] {
            var per = Int(Double(s * 12) / (postIn + 2.0))
            if per < 1 { continue }
            if per > 1 && s > 12 { per = 1 }
            if per == 1 && Double(s * 12) < postIn + 6.0 { continue }
            let boards = Int((Double(posts) / Double(per)).rounded(.up))
            let total = boards * s
            if total < bestTotal || (total == bestTotal && boards < best.boards) {
                best = (s, boards, per)
                bestTotal = total
            }
        }
        return best
    }

    /// 88.5 → "7′ 4½″"
    static func feetInches(_ inches: Double) -> String {
        let halfInches = (max(0, inches) * 2).rounded()
        let totalIn = halfInches / 2
        let ft = Int(totalIn / 12)
        let rem = totalIn - Double(ft * 12)
        let whole = Int(rem)
        let half = rem - Double(whole) >= 0.5 ? "½" : ""
        if ft == 0 { return "\(whole)\(half)″" }   // under a foot: "7″", not "0′ 7″"
        return "\(ft)′ \(whole)\(half)″"
    }

    /// Plain-language checks shown on the results screen, PDF and text summary.
    /// `items` = the calculated materials. The 14 ft limit applies to the POST
    /// (footing to underside of beam), which only the materials calculation
    /// knows, so the warning reads the post line instead of the deck height.
    static func checks(for i: DeckInput, items: [MaterialItem] = []) -> [String] {
        let h = i.deckHeightIn
        guard h > 0 else {
            return ["No deck height entered — post lengths and railing checks were skipped. Add the height at the deck's highest point."]
        }
        var out: [String] = []
        if h > guardRequiredAboveIn {
            out.append("Guard required: deck is more than 30″ above grade (IRC R312.1.1). Guards must be at least 36″ tall; some areas require 42″.")
            if !i.includeRailing {
                out.append("⚠︎ Railing is turned OFF, but at this height open sides need a guard. Turn railing on or confirm with your inspector.")
            }
            out.append("Stairs from this deck rise about \(feetInches(h)). Stairs over 30″ need guards on open sides, and 4 or more risers need a handrail.")
            out.append("Raised deck: check local requirements for post bracing (knee or diagonal braces) and lateral attachment to the house.")
        } else {
            out.append("At \(feetInches(h)) the IRC does not require a guard — but if the ground drops away within 36″ of any open edge, measure there too. A sloping yard can push it over 30″.")
        }
        if items.contains(where: { $0.name.hasPrefix("Posts — engineer required") }) {
            out.append("⚠︎ Posts would be taller than the 14 ft prescriptive limit (IRC Table R507.4, measured footing to underside of beam). Posts and bracing need an engineer's design.")
        }
        return out
    }
}

// MARK: - DeckPlanner
// Purchase-ready deck materials: augments DeckCalculator's base output with
// orientation-aware joist sizing, purchase-ready beam segments, fastener
// substitution, and board counts. This is the single source of truth for
// "what do I actually buy" — shared by DeckFormView (standalone) and
// ProjectView (combined project) so the two never drift apart.
enum DeckPlanner {

    static func adjustedJoistSize(spanFt: Double, species: LumberSpecies, spacingIn: Double, grade: LumberGrade) -> String {
        // Base thresholds ~16" OC, #2, wet service (heuristic)
        var t8:  Double; var t10: Double; var t12: Double; var max12: Double
        switch species {
        case .southernPine:     t8 = 8;   t10 = 10;  t12 = 12;  max12 = 16
        case .douglasFirLarch:  t8 = 8;   t10 = 9.5; t12 = 11.5; max12 = 15
        case .hemFir:           t8 = 7.5; t10 = 9.0; t12 = 11.0; max12 = 14
        }
        // Spacing adjustment (very rough): 12" OC +8%, 24" OC −15%
        let spacingFactor: Double = (spacingIn <= 12 ? 1.08 : (spacingIn >= 24 ? 0.85 : 1.0))
        t8  *= spacingFactor; t10 *= spacingFactor; t12 *= spacingFactor; max12 *= spacingFactor
        // Grade adjustment: #1 +5%
        if grade == .number1 { t8 *= 1.05; t10 *= 1.05; t12 *= 1.05; max12 *= 1.05 }
        if spanFt <= t8  { return "2×8" }
        if spanFt <= t10 { return "2×10" }
        if spanFt <= t12 { return "2×12" }
        if spanFt <= max12 { return "2×12 (verify)" }
        return "Engineer review"
    }

    static func roundUpStockLength(_ spanFt: Double) -> Double {
        let stock: [Double] = [8, 10, 12, 14, 16, 18, 20]
        for s in stock { if spanFt <= s { return s } }
        return ceil(spanFt / 2.0) * 2.0
    }

    static func recommendBeamSize(postSpacingFt: Double, beamLines: Int, species: LumberSpecies) -> String {
        let s = postSpacingFt
        let base: String
        switch species {
        case .southernPine:
            if s <= 6 { base = "(2) 2×8" }
            else if s <= 8 { base = "(2) 2×10" }
            else if s <= 10 { base = "(2) 2×12" }
            else { base = "(3) 2×12 (verify)" }
        case .douglasFirLarch:
            if s <= 6 { base = "(2) 2×8" }
            else if s <= 7.5 { base = "(2) 2×10" }
            else if s <= 9.5 { base = "(2) 2×12" }
            else { base = "(3) 2×12 (verify)" }
        case .hemFir:
            if s <= 5.5 { base = "(2) 2×8" }
            else if s <= 7.0 { base = "(2) 2×10" }
            else if s <= 9.0 { base = "(2) 2×12" }
            else { base = "(3) 2×12 (verify)" }
        }
        return beamLines == 2 ? "\(base) per beam line (2 lines)" : base
    }

    // Use DeckCalculator as the single source of truth, then augment with orientation + purchase guidance
    static func calculateMaterials(
        for i: DeckInput,
        species: LumberSpecies,
        deckingDirection: DeckingDirection,
        joistGrade: LumberGrade,
        fastenerType: FastenerType,
        stockLengthFt: Double,
        doubleCornerPosts: Bool
    ) -> [MaterialItem] {
        // 1) Base calculation from core engine
        var items = DeckCalculator.calculate(i)

        // 2) Orientation-aware helpers
        let L_ft = max(0.0, i.lengthFt)
        let W_ft = max(0.0, i.widthFt)
        let spacingIn = max(1.0, i.joistSpacingIn)
        let runDimensionFt: Double   = (deckingDirection == .alongLength) ? L_ft : W_ft
        let crossDimensionFt: Double = (deckingDirection == .alongLength) ? W_ft : L_ft
        let joistSpanFt = runDimensionFt
        let joistCount = Int(floor((crossDimensionFt * 12.0) / spacingIn)) + 1

        // Boards across for fastener math
        let moduleIn = max(0.01, i.boardWidthIn + i.boardGapIn)
        let boardsAcross = floor((crossDimensionFt * 12.0) / moduleIn)

        // 3) Joists — purchase-ready line (size × stock), remove generic line
        items.removeAll { $0.name.lowercased().hasPrefix("joists") }
        let joistSizeStr = adjustedJoistSize(spanFt: joistSpanFt, species: species, spacingIn: spacingIn, grade: joistGrade)
        let joistStockFt = roundUpStockLength(joistSpanFt)
        items.append(MaterialItem(
            name: "Joists \(joistSizeStr) × \(Int(joistStockFt)) ft",
            qty: Double(joistCount),
            unit: "pcs",
            notes: "Clear span \(String(format: "%.0f", joistSpanFt)) ft each • Buy \(Int(joistStockFt)) ft and cut to fit • No mid-span splices"
        ))

        // 4) Beams — convert to purchase-ready built-up segments per post bay
        let beamLines = i.ledgerAttached ? 1 : 2
        let spanCountPerLine = max(1, Int(ceil(L_ft / max(1.0, i.postSpacingFt))))
        let approxSpanLen = L_ft / Double(spanCountPerLine)
        let segStockFt = roundUpStockLength(approxSpanLen)
        let beamSizeStr = recommendBeamSize(postSpacingFt: i.postSpacingFt, beamLines: beamLines, species: species)
        // Parse plies from string like "(2) 2×10" or "(3) 2×12"
        let plies: Int = {
            if let first = beamSizeStr.first, first == "(",
               let x = beamSizeStr.dropFirst().first, let n = Int(String(x)) { return n }
            return 1
        }()
        // Remove any existing beam total length line
        items.removeAll { $0.name.lowercased().hasPrefix("beams (total length)") }
        // Per-line segments
        let perLineSegments = spanCountPerLine * plies
        let lineNames = ["Line A", "Line B", "Line C", "Line D"]
        for line in 0..<beamLines {
            let label = line < lineNames.count ? lineNames[line] : "Line \(line+1)"
            items.append(MaterialItem(
                name: "Beam segments (\(label)) \(beamSizeStr) × \(Int(segStockFt)) ft",
                qty: Double(perLineSegments),
                unit: "pcs",
                notes: "Built-up pieces • ~\(String(format: "%.1f", approxSpanLen)) ft between posts • Splice only over posts"
            ))
        }
        // Beam segments total
        let totalSegments = perLineSegments * beamLines
        items.append(MaterialItem(
            name: "Beam segments total",
            qty: Double(totalSegments),
            unit: "pcs",
            notes: "\(plies) plies • \(spanCountPerLine) spans per line • \(Int(segStockFt)) ft stock"
        ))
        // Posts per line (estimated)
        var perLinePosts = spanCountPerLine + 1 // spans create (spans+1) posts per line (including ends)
        if doubleCornerPosts { perLinePosts += 2 }
        // Post length from deck height (if entered)
        var postName = "Posts"
        var postHeightNote: String? = nil
        var postLumber: MaterialItem? = nil
        if i.deckHeightIn > 0 {
            let postIn = DeckHeightRules.postHeightIn(deckHeightIn: i.deckHeightIn,
                                                      joistSize: joistSizeStr,
                                                      beamSize: beamSizeStr)
            let postFt = postIn / 12.0
            if postIn <= 0 {
                postHeightNote = "Deck is too low for a beam under the joists — use a flush beam (joists hung from the beam) or ground-level framing"
            } else if postFt > DeckHeightRules.maxPrescriptivePostFt {
                postName = "Posts — engineer required"
                postHeightNote = "~\(DeckHeightRules.feetInches(postIn)) tall exceeds the 14 ft prescriptive limit (IRC Table R507.4)"
            } else {
                postName = "Posts 6×6"
                postHeightNote = "Cut to ~\(DeckHeightRules.feetInches(postIn)) • footing to underside of beam • deck \(DeckHeightRules.feetInches(i.deckHeightIn)) high"
                // What to actually buy: short posts can share a board.
                let totalPosts = perLinePosts * beamLines
                let plan = DeckHeightRules.postLumberPlan(postIn: postIn, posts: totalPosts)
                if plan.boards > 0 {
                    let howToCut: String
                    if plan.perBoard == 1 {
                        howToCut = "1 post per board"
                    } else if plan.boards == 1 {
                        howToCut = "Cut all \(totalPosts) posts from 1 board"
                    } else {
                        howToCut = "Cut up to \(plan.perBoard) posts from each board"
                    }
                    postLumber = MaterialItem(
                        name: "Post lumber 6×6 × \(plan.stockFt) ft",
                        qty: Double(plan.boards),
                        unit: plan.boards == 1 ? "board" : "boards",
                        notes: "\(howToCut) • \(totalPosts) posts total at ~\(DeckHeightRules.feetInches(postIn)) each")
                }
            }
        }
        for line in 0..<beamLines {
            let label = line < lineNames.count ? lineNames[line] : "Line \(line+1)"
            let cornerNote = doubleCornerPosts ? "Includes doubled corners" : "Standard corners"
            items.append(MaterialItem(
                name: "\(postName) (\(label))",
                qty: Double(perLinePosts),
                unit: "pcs",
                notes: postHeightNote.map { "\($0) • \(cornerNote)" } ?? cornerNote
            ))
        }
        if let postLumber { items.append(postLumber) }
        // Optional: bump related items for doubled corners
        if doubleCornerPosts {
            let extraCorners = beamLines * 2 // two corners per beam line
            func bumpQty(where needle: String, by delta: Double) {
                if let idx = items.firstIndex(where: { $0.name.localizedCaseInsensitiveContains(needle) }) {
                    items[idx] = MaterialItem(name: items[idx].name,
                                              qty: items[idx].qty + delta,
                                              unit: items[idx].unit,
                                              notes: items[idx].notes)
                }
            }
            let d = Double(extraCorners)
            bumpQty(where: "Posts", by: d)
            bumpQty(where: "Concrete footings", by: d)
            bumpQty(where: "Post bases", by: d)
            bumpQty(where: "Post-to-beam", by: d)
        }

        // 5) Fasteners — replace screws if hidden fasteners chosen
        let crossings = boardsAcross * Double(joistCount)
        if fastenerType != .screws {
            items.removeAll { $0.name.lowercased().contains("deck screws") }
            let brand: String = (fastenerType == .trexClips) ? "Trex Universal" : "TimberTech CONCEALoc"
            let fieldClips = ceil(crossings)           // ≈ 1 per board × joist crossing
            let starterClips = ceil(boardsAcross * 2)  // start + end rows
            items.append(MaterialItem(name: "Hidden fastener clips (field) — \(brand)", qty: fieldClips, unit: "pcs",
                                      notes: "~1 per board–joist crossing; verify manufacturer schedule"))
            items.append(MaterialItem(name: "Starter/edge clips — \(brand)", qty: starterClips, unit: "pcs",
                                      notes: "At starting/finishing edges; verify brand kit contents"))
        }

        // 6) Deck boards count line (right under linear feet)
        if let lfIndex = items.firstIndex(where: { $0.name.lowercased().contains("deck") && $0.name.lowercased().contains("linear") }) {
            let lfQty = items[lfIndex].qty
            let stockLenLF = max(1.0, stockLengthFt)
            let boardCount = ceil(lfQty / stockLenLF)
            items.insert(MaterialItem(
                name: "Deck boards (count)",
                qty: boardCount,
                unit: "boards",
                notes: "\(Int(stockLenLF)) ft stock • includes waste • runs \(String(format: "%.0f", runDimensionFt)) ft"
            ), at: lfIndex + 1)
        }

        // 6b) Footings and post hardware must match the posts actually listed.
        //     (The base engine assumed at least 3 posts per beam line; the
        //     per-line count above is what the span really needs, incl. doubled corners.)
        let totalPostCount = Double(perLinePosts * beamLines)
        for needle in ["Concrete footings", "Post bases", "Post-to-beam"] {
            if let idx = items.firstIndex(where: { $0.name.hasPrefix(needle) }) {
                items[idx].qty = totalPostCount
            }
        }

        // 7) The base engine's generic "Posts" line duplicates the per-line,
        //    purchase-ready post lines above — remove it (done last so the
        //    doubled-corner bump above can't land on the wrong line).
        items.removeAll { $0.name == "Posts" }

        return items
    }
}
