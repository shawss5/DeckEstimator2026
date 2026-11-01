import SwiftUI

// MARK: - Shared drawing bits
private enum DrawColors {
    static let deckFill  = Color(red: 0.96, green: 0.92, blue: 0.85)
    static let joist     = Color(red: 0.62, green: 0.43, blue: 0.24)
    static let beam      = Color(red: 0.85, green: 0.42, blue: 0.10)
    static let railing   = Color(red: 0.10, green: 0.55, blue: 0.55)
    static let post      = Color(white: 0.15)
    static let house     = Color(white: 0.80)
    static let ground    = Color(white: 0.55)
}

private struct DrawingDisclaimer: View {
    var body: some View {
        Text("Not to scale • For estimating only — not a construction drawing")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
}

private func label(_ s: String, size: CGFloat = 9, weight: Font.Weight = .regular) -> Text {
    Text(s).font(.system(size: size, weight: weight))
}

// MARK: - Deck: top view
/// Plan view of the deck framing: outline, house + ledger, joists, beam(s),
/// posts, and railing on the open sides. Length runs along the house (left–right).
struct DeckPlanDrawing: View {
    let input: DeckInput
    var boardsParallelToHouse: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Deck framing — top view").font(.headline)
            Canvas { ctx, size in draw(ctx, size) }
                .frame(height: 240)
            (label("━ ", size: 10, weight: .bold).foregroundColor(DrawColors.beam) + label("beam   ", size: 10)
             + label("■ ", size: 10).foregroundColor(DrawColors.post) + label("posts   ", size: 10)
             + label("│ ", size: 10, weight: .bold).foregroundColor(DrawColors.joist) + label("joists   ", size: 10)
             + label("━ ", size: 10, weight: .bold).foregroundColor(DrawColors.railing) + label("railing", size: 10))
            DrawingDisclaimer()
        }
    }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize) {
        let L = max(1, input.lengthFt), W = max(1, input.widthFt)
        let leftPad: CGFloat = 70, rightPad: CGFloat = 20, topPad: CGFloat = 32, bottomPad: CGFloat = 30
        let availW = size.width - leftPad - rightPad, availH = size.height - topPad - bottomPad
        let s = min(availW / L, availH / W)
        let dw = L * s, dh = W * s
        let x0 = leftPad + (availW - dw) / 2, y0 = topPad
        let deck = CGRect(x: x0, y: y0, width: dw, height: dh)

        // House + ledger along the top (the length side).
        if input.ledgerAttached {
            let house = CGRect(x: x0 - 12, y: y0 - 24, width: dw + 24, height: 18)
            ctx.fill(Path(house), with: .color(DrawColors.house))
            ctx.draw(label("HOUSE", weight: .semibold).foregroundColor(.black.opacity(0.6)), at: CGPoint(x: house.midX, y: house.midY))
        }

        ctx.fill(Path(deck), with: .color(DrawColors.deckFill))

        // Joists: across the boards. Standard = run from the house out to the beam.
        let spacingFt = max(1, input.joistSpacingIn) / 12
        var joists = Path()
        if boardsParallelToHouse {
            var x = 0.0
            while x < L - 0.01 { let px = x0 + x * s; joists.move(to: CGPoint(x: px, y: y0)); joists.addLine(to: CGPoint(x: px, y: y0 + dh)); x += spacingFt }
            joists.move(to: CGPoint(x: x0 + dw, y: y0)); joists.addLine(to: CGPoint(x: x0 + dw, y: y0 + dh))
        } else {
            var y = 0.0
            while y < W - 0.01 { let py = y0 + y * s; joists.move(to: CGPoint(x: x0, y: py)); joists.addLine(to: CGPoint(x: x0 + dw, y: py)); y += spacingFt }
            joists.move(to: CGPoint(x: x0, y: y0 + dh)); joists.addLine(to: CGPoint(x: x0 + dw, y: y0 + dh))
        }
        ctx.stroke(joists, with: .color(DrawColors.joist), lineWidth: 1)
        ctx.stroke(Path(deck), with: .color(.black), lineWidth: 1.5)

        // Ledger
        if input.ledgerAttached {
            var ledger = Path(); ledger.move(to: CGPoint(x: x0, y: y0)); ledger.addLine(to: CGPoint(x: x0 + dw, y: y0))
            ctx.stroke(ledger, with: .color(.black), lineWidth: 4)
        }

        // Beam line(s) + posts — across the joists.
        let inset = min(10, (boardsParallelToHouse ? dh : dw) * 0.08)
        if boardsParallelToHouse {
            let ys: [CGFloat] = input.ledgerAttached ? [y0 + dh - inset] : [y0 + inset, y0 + dh - inset]
            let spans = max(1, Int(ceil(L / max(1, input.postSpacingFt))))
            for by in ys {
                var beam = Path(); beam.move(to: CGPoint(x: x0, y: by)); beam.addLine(to: CGPoint(x: x0 + dw, y: by))
                ctx.stroke(beam, with: .color(DrawColors.beam), style: StrokeStyle(lineWidth: 4, dash: [8, 4]))
                for k in 0...spans { postSquare(ctx, CGPoint(x: x0 + dw * CGFloat(k) / CGFloat(spans), y: by)) }
            }
        } else {
            let xs: [CGFloat] = [x0 + inset, x0 + dw - inset]
            let spans = max(1, Int(ceil(W / max(1, input.postSpacingFt))))
            for bx in xs {
                var beam = Path(); beam.move(to: CGPoint(x: bx, y: y0)); beam.addLine(to: CGPoint(x: bx, y: y0 + dh))
                ctx.stroke(beam, with: .color(DrawColors.beam), style: StrokeStyle(lineWidth: 4, dash: [8, 4]))
                for k in 0...spans { postSquare(ctx, CGPoint(x: bx, y: y0 + dh * CGFloat(k) / CGFloat(spans))) }
            }
        }

        // Railing just outside the open sides.
        if input.includeRailing {
            let o: CGFloat = 4
            var rail = Path()
            rail.move(to: CGPoint(x: x0 - o, y: y0)); rail.addLine(to: CGPoint(x: x0 - o, y: y0 + dh + o))
            rail.addLine(to: CGPoint(x: x0 + dw + o, y: y0 + dh + o)); rail.addLine(to: CGPoint(x: x0 + dw + o, y: y0))
            if !input.railingSidesHouseIsOnLength {
                rail.move(to: CGPoint(x: x0 - o, y: y0 - o)); rail.addLine(to: CGPoint(x: x0 + dw + o, y: y0 - o))
            }
            ctx.stroke(rail, with: .color(DrawColors.railing), lineWidth: 3)
        }

        // Dimensions
        ctx.draw(label("\(displayNumber(L)) ft along house", size: 10, weight: .semibold),
                 at: CGPoint(x: deck.midX, y: y0 + dh + 18))
        ctx.draw(label("\(displayNumber(W)) ft", size: 10, weight: .semibold), at: CGPoint(x: x0 - 12, y: deck.midY), anchor: .trailing)
        ctx.draw(label("out from house", size: 8).foregroundColor(.secondary), at: CGPoint(x: x0 - 12, y: deck.midY + 12), anchor: .trailing)
        if input.deckHeightIn > 0 {
            ctx.draw(label("\(DeckHeightRules.feetInches(input.deckHeightIn)) high", size: 9).foregroundColor(.secondary),
                     at: CGPoint(x: x0 - 12, y: deck.midY + 24), anchor: .trailing)
        }
    }

    private func postSquare(_ ctx: GraphicsContext, _ c: CGPoint) {
        ctx.fill(Path(CGRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8)), with: .color(DrawColors.post))
    }
}

// MARK: - Stairs: side view
/// Side elevation: ground, step profile (one flight, or two with a landing),
/// the deck at the top, landing posts, and the guard line when required.
struct StairsSideDrawing: View {
    let input: StairsInput

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Stairs — side view").font(.headline)
            Canvas { ctx, size in draw(ctx, size) }
                .frame(height: 230)
            DrawingDisclaimer()
        }
    }

    private struct Flight { let risers: Int; let riserH: Double; let treads: Int; let treadD: Double }

    private func flight(rise: Double) -> Flight {
        var f = input; f.totalRiseIn = rise; f.includeLanding = false
        let g = StairsCalculator.computeGeometry(f)
        return Flight(risers: g.risers, riserH: g.finalRiserIn, treads: g.treads, treadD: input.treadDepthIn)
    }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize) {
        let R = max(1, input.totalRiseIn)
        let plan = input.includeLanding ? StairsCalculator.landingPlan(input) : nil
        let flights: [Flight] = plan.map { [flight(rise: $0.lowerRiseIn), flight(rise: $0.upperRiseIn)] } ?? [flight(rise: R)]
        let landingDepth = plan?.depthIn ?? 0
        let deckStub: Double = 36
        let runTotal = flights.reduce(0) { $0 + Double($1.treads) * $1.treadD } + landingDepth

        let leftPad: CGFloat = 16, rightPad: CGFloat = 70, topPad: CGFloat = 16, bottomPad: CGFloat = 30
        let availW = size.width - leftPad - rightPad, availH = size.height - topPad - bottomPad
        let s = min(availW / (runTotal + deckStub), availH / (R + 36))
        let groundY = size.height - bottomPad
        let x0 = leftPad
        func P(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x0 + x * s, y: groundY - y * s) }

        // Ground
        var ground = Path(); ground.move(to: CGPoint(x: 0, y: groundY)); ground.addLine(to: CGPoint(x: size.width, y: groundY))
        ctx.stroke(ground, with: .color(DrawColors.ground), lineWidth: 1.5)

        // Step profile
        var profile = Path(); profile.move(to: P(0, 0))
        var x = 0.0, y = 0.0
        var nosings: [[CGPoint]] = []
        var landingPosts = Path()
        var landingLabel: (Text, CGPoint)? = nil
        for (idx, fl) in flights.enumerated() {
            var noses: [CGPoint] = []
            for r in 0..<fl.risers {
                y += fl.riserH; profile.addLine(to: P(x, y)); noses.append(P(x, y))
                if r < fl.risers - 1 { x += fl.treadD; profile.addLine(to: P(x, y)) }
            }
            nosings.append(noses)
            if idx == 0, plan != nil {
                // Landing
                let lx = x
                x += landingDepth; profile.addLine(to: P(x, y))
                for px in [lx + 4, x - 4] { landingPosts.move(to: P(px, y - 8)); landingPosts.addLine(to: P(px, 0)) }

                // Planter boxes sitting on the landing, drawn at their real height.
                var labelLift = 10.0
                if input.includePlanters, StairsCalculator.planterCount(input) > 0, input.planterHeightIn > 0 {
                    let ph = input.planterHeightIn
                    let pl = min(input.planterLengthIn, max(6, landingDepth - 4))
                    let px0 = lx + (landingDepth - pl) / 2
                    let top = P(px0, y + ph)
                    let box = CGRect(x: top.x, y: top.y, width: pl * s, height: ph * s)
                    ctx.fill(Path(box), with: .color(Color.green.opacity(0.30)))
                    ctx.stroke(Path(box), with: .color(Color.green), lineWidth: 1.5)
                    ctx.draw(label("Planters \(displayNumber(ph))″", size: 8).foregroundColor(.green),
                             at: CGPoint(x: box.midX, y: box.midY))
                    labelLift = max(labelLift, ph + 8)
                }
                _ = labelLift
                landingLabel = (label("Landing \(DeckHeightRules.feetInches(y)) up", size: 9, weight: .semibold), P((lx + x) / 2, y - 12))
            }
        }
        // Deck at the top
        let deckRect = CGRect(x: P(x, R).x, y: P(x, R).y, width: deckStub * s, height: 10)
        profile.addLine(to: P(x + deckStub, R))
        var fill = profile; fill.addLine(to: P(x + deckStub, 0)); fill.addLine(to: P(0, 0)); fill.closeSubpath()
        ctx.fill(fill, with: .color(DrawColors.deckFill))
        ctx.stroke(profile, with: .color(DrawColors.joist), lineWidth: 2)
        ctx.stroke(landingPosts, with: .color(DrawColors.post), lineWidth: 2.5)
        if let (t, at) = landingLabel { ctx.draw(t, at: at, anchor: .top) }
        ctx.fill(Path(deckRect), with: .color(DrawColors.joist.opacity(0.5)))
        ctx.draw(label("DECK", weight: .semibold), at: CGPoint(x: deckRect.midX, y: deckRect.minY - 8))

        // Guard / handrail line ~36″ above the nosings when required
        if R > 30 {
            var rail = Path()
            for noses in nosings where noses.count > 1 {
                let a = noses.first!, b = noses.last!
                rail.move(to: CGPoint(x: a.x, y: a.y - 36 * s)); rail.addLine(to: CGPoint(x: b.x, y: b.y - 36 * s))
            }
            if let p = plan, p.heightIn > 30 {
                let ly = p.heightIn
                let lx0 = flights.isEmpty ? 0 : Double(flights[0].treads) * flights[0].treadD
                rail.move(to: P(lx0, ly + 36)); rail.addLine(to: P(lx0 + landingDepth, ly + 36))
            }
            ctx.stroke(rail, with: .color(DrawColors.railing), lineWidth: 2.5)
        }

        // Dimensions
        let topRight = P(x + deckStub, R)
        var dim = Path(); dim.move(to: CGPoint(x: topRight.x + 8, y: topRight.y)); dim.addLine(to: CGPoint(x: topRight.x + 8, y: groundY))
        ctx.stroke(dim, with: .color(.secondary), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        ctx.draw(label("Total rise", size: 9).foregroundColor(.secondary), at: CGPoint(x: topRight.x + 12, y: (topRight.y + groundY) / 2 - 7), anchor: .leading)
        ctx.draw(label(DeckHeightRules.feetInches(R), size: 10, weight: .semibold), at: CGPoint(x: topRight.x + 12, y: (topRight.y + groundY) / 2 + 6), anchor: .leading)
        ctx.draw(label("Total run ≈ \(DeckHeightRules.feetInches(runTotal))", size: 10, weight: .semibold),
                 at: CGPoint(x: P(runTotal / 2, 0).x, y: groundY + 14))
    }
}

// MARK: - Covered deck: end view
/// End view looking along the house: deck surface, house wall (if attached),
/// posts and beam, and the roof line for the chosen style with its overhang.
struct RoofEndDrawing: View {
    let input: CoveredDeckInput

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Covered deck — end view (\(input.roofStyle.displayName))").font(.headline)
            Canvas { ctx, size in draw(ctx, size) }
                .frame(height: 230)
            DrawingDisclaimer()
        }
    }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize) {
        // Work in inches. x = out from the house, y = up from the deck surface.
        let P = max(12, input.projectionFt * 12)
        let H = max(12, input.postHeightIn)
        let oh = max(0, input.overhangIn)
        let pitch = max(0, input.pitchRisePer12) / 12
        let attached = !input.freestanding
        let style = input.roofStyle

        // Roof points (eaves/ridge) for each style
        var roof: [(Double, Double)] = []
        switch style {
        case .mono:
            roof = [(0, H + P * pitch), (P + oh, H - oh * pitch)]
        case .gable, .hip:
            let leftEdge = attached ? 0 : -oh
            let half = P / 2
            roof = [(leftEdge, H - (attached ? 0 : oh * pitch)), (half, H + half * pitch), (P + oh, H - oh * pitch)]
        case .flat:
            let slope = 0.25 / 12   // ¼″ per foot for drainage
            roof = [(0, H + P * slope), (P + oh, H - oh * slope)]
        }
        let maxY = roof.map { $0.1 }.max() ?? H
        let minX = min(0, roof.map { $0.0 }.min() ?? 0) - (attached ? 18 : 0)
        let maxX = (roof.map { $0.0 }.max() ?? P)

        let leftPad: CGFloat = 20, rightPad: CGFloat = 80, topPad: CGFloat = 18, bottomPad: CGFloat = 30
        let availW = size.width - leftPad - rightPad, availH = size.height - topPad - bottomPad
        let s = min(availW / (maxX - minX), availH / maxY)
        let baseY = size.height - bottomPad
        func Pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: leftPad + (x - minX) * s, y: baseY - y * s) }

        // Deck surface
        var deckLine = Path(); deckLine.move(to: Pt(minX, 0)); deckLine.addLine(to: Pt(maxX, 0))
        ctx.stroke(deckLine, with: .color(DrawColors.joist), lineWidth: 3)
        ctx.draw(label("deck surface", size: 8).foregroundColor(.secondary), at: Pt(P / 2, 0), anchor: .top)

        // House wall
        if attached {
            let wall = CGRect(x: Pt(-18, maxY).x, y: Pt(-18, maxY).y, width: 18 * s, height: maxY * s)
            ctx.fill(Path(wall), with: .color(DrawColors.house))
            ctx.draw(label("HOUSE", weight: .semibold).foregroundColor(.black.opacity(0.6)), at: CGPoint(x: wall.midX, y: wall.midY))
        }

        // Posts + beam
        let postXs: [Double] = attached ? [P] : [0, P]
        var posts = Path()
        for x in postXs { posts.move(to: Pt(x, 0)); posts.addLine(to: Pt(x, H)) }
        ctx.stroke(posts, with: .color(DrawColors.post), lineWidth: 4)
        for x in postXs {
            let b = Pt(x, H)
            ctx.fill(Path(CGRect(x: b.x - 7, y: b.y - 7, width: 14, height: 7)), with: .color(DrawColors.beam))
        }

        // Roof line
        var roofPath = Path()
        if let first = roof.first {
            roofPath.move(to: Pt(first.0, first.1))
            for p in roof.dropFirst() { roofPath.addLine(to: Pt(p.0, p.1)) }
        }
        ctx.stroke(roofPath, with: .color(DrawColors.railing), lineWidth: 3)

        // Labels
        let pitchText = style == .flat ? "low slope (¼″ per ft)" : "\(displayNumber(input.pitchRisePer12)) in 12"
        if let top = roof.max(by: { $0.1 < $1.1 }) {
            ctx.draw(label("Pitch \(pitchText)", size: 9, weight: .semibold), at: Pt(top.0, top.1 + 4), anchor: .bottom)
        }
        ctx.draw(label("Post \(DeckHeightRules.feetInches(H))", size: 9, weight: .semibold),
                 at: CGPoint(x: Pt(P, H / 2).x + 8, y: Pt(P, H / 2).y), anchor: .leading)
        if oh > 0 {
            ctx.draw(label("\(displayNumber(oh))″ overhang", size: 8).foregroundColor(.secondary),
                     at: CGPoint(x: Pt(P + oh, 0).x + 4, y: Pt(P, H).y + 14), anchor: .leading)
        }
        ctx.draw(label("\(displayNumber(input.projectionFt)) ft out from house", size: 10, weight: .semibold),
                 at: CGPoint(x: Pt(P / 2, 0).x, y: baseY + 16))
        if style == .hip {
            ctx.draw(label("Hip roof: ends also slope", size: 8).foregroundColor(.secondary),
                     at: CGPoint(x: size.width - 4, y: topPad), anchor: .topTrailing)
        }
    }
}
