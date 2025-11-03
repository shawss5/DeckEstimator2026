import Foundation

struct DeckCalculator {

    static func calculate(_ i: DeckInput) -> [MaterialItem] {
        // Convert
        let W_in = i.widthFt * 12.0
        let spacingIn = max(1.0, i.joistSpacingIn)
    
        // 1) Decking boards (run along length)
        let module = max(0.01, i.boardWidthIn + i.boardGapIn) // board + gap
        let nBoards = floor(W_in / module)                     // runs across the width
        let deckingLF = nBoards * i.lengthFt                   // linear feet along the length
        let deckingLFWithWaste = ceil(deckingLF * (1 + i.wastePct / 100.0))
    
        // 2) Joists (perpendicular to boards, spanning the deck length)
        let nJoists = floor(W_in / spacingIn) + 1.0            // joists across width
        let rimJoists = 2.0
        let blockingRows = floor(i.lengthFt / 8.0)             // one row every ~8'
        let blocksPerRow = max(nJoists - 1.0, 0.0)
        let totalBlocks = blockingRows * blocksPerRow
    
        // 3) Beam & Posts (estimate using post spacing)
        // If ledger-attached: 1 outer beam; else 2 beam lines (outer + interior).
        let beamLines = i.ledgerAttached ? 1 : 2
        let spansPerLine = Int(ceil(i.lengthFt / max(1.0, i.postSpacingFt)))
        let postsPerLine = max(3, spansPerLine + 1)            // include ends; ensure ≥3 per line
        let nPosts = postsPerLine * beamLines
        let totalBeamLF = Double(beamLines) * i.lengthFt
    
        // 4) Railing (three sides if house on one length side)
        var railingLF: Double = 0
        if i.includeRailing {
            let threeSides = (i.lengthFt + i.widthFt + i.widthFt) // length + two widths
            let allFour = (i.lengthFt + i.widthFt + i.lengthFt + i.widthFt)
            railingLF = i.railingSidesHouseIsOnLength ? threeSides : allFour
        }
    
        // 5) Screws: 2 per joist crossing (two screws per board at each joist), include waste
        // crossings = number of board runs × number of joists
        let crossings = nBoards * nJoists
        let screws = ceil(crossings * 2.0 * (1 + i.wastePct / 100.0))
    
        // 6) Hangers & hanger fasteners
        let joistCountInt = Int(nJoists)
        let hangerPerJoist = i.ledgerAttached ? 1 : 2          // ledger side only vs both sides when free-standing
        let totalHangers = joistCountInt * hangerPerJoist
        let hangerFastenersPer = 8.0                            // typical schedule; verify manufacturer
        let totalHangerFasteners = ceil(Double(totalHangers) * hangerFastenersPer)
    
        // 7) Ledger fasteners (~16" OC) if ledger-attached
        let ledgerFasteners = i.ledgerAttached ? ceil((i.lengthFt * 12.0) / 16.0) : 0.0
    
        // 8) Railing posts @ ~6 ft spacing (+1)
        var railingPosts: Double = 0
        if i.includeRailing && railingLF > 0 {
            railingPosts = ceil(railingLF / 6.0) + 1.0
        }
    
        // Build list
        var out: [MaterialItem] = []
    
        // Decking
        out.append(MaterialItem(
            name: "Decking (linear feet)",
            qty: deckingLFWithWaste,
            unit: "LF",
            notes: "Assumes full-length runs; add cut plan if fixed board lengths.")
        )
        out.append(MaterialItem(
            name: "Deck screws",
            qty: screws,
            unit: "pcs",
            notes: "2 per joist crossing • includes waste")
        )
    
        // Joists & blocking
        out.append(MaterialItem(
            name: "Joists (length \(Int(i.lengthFt)) ft)",
            qty: nJoists,
            unit: "pcs",
            notes: "On-center spacing \(Int(spacingIn))\"")
        )
        out.append(MaterialItem(
            name: "Rim Joists",
            qty: rimJoists,
            unit: "pcs",
            notes: "One at each deck side parallel to joists")
        )
        if totalBlocks > 0 {
            out.append(MaterialItem(
                name: "Blocking",
                qty: totalBlocks,
                unit: "pcs",
                notes: "\(Int(blockingRows)) row(s) across joist field")
            )
        }
    
        // Hangers & hanger fasteners
        out.append(MaterialItem(
            name: "Joist hangers",
            qty: Double(totalHangers),
            unit: "pcs",
            notes: i.ledgerAttached ? "Ledger side only" : "Both sides (free-standing)")
        )
        out.append(MaterialItem(
            name: "Joist hanger nails/screws",
            qty: totalHangerFasteners,
            unit: "pcs",
            notes: "e.g., 10d HDG nails or Simpson SD screws • ~8 per hanger (verify)")
        )
    
        // Beams & posts
        if beamLines > 0 {
            out.append(MaterialItem(
                name: "Beams (total length)",
                qty: totalBeamLF,
                unit: "LF",
                notes: i.ledgerAttached ? "Ledger-attached: 1 outer beam" : "Free-standing: 2 beam lines")
            )
            out.append(MaterialItem(
                name: "Posts",
                qty: Double(nPosts),
                unit: "pcs",
                notes: "\(postsPerLine) per beam line • spacing ~\(Int(i.postSpacingFt)) ft")
            )
            // Footings = posts
            out.append(MaterialItem(
                name: "Concrete footings",
                qty: Double(nPosts),
                unit: "pcs",
                notes: "Match post count")
            )
            // Post hardware
            out.append(MaterialItem(
                name: "Post bases (HDG)",
                qty: Double(nPosts),
                unit: "pcs",
                notes: "e.g., Simpson ABU66Z or equivalent")
            )
            out.append(MaterialItem(
                name: "Post-to-beam connectors",
                qty: Double(nPosts),
                unit: "pcs",
                notes: "e.g., Simpson BC6/AC6 or through-bolts • verify locally")
            )
        }
    
        // Ledger fasteners (if applicable)
        if ledgerFasteners > 0 {
            out.append(MaterialItem(
                name: "Ledger structural fasteners",
                qty: ledgerFasteners,
                unit: "pcs",
                notes: "e.g., 1/2\" HDG lag or 5/16\" structural screws @ ~16\" OC (verify table)")
            )
        }
    
        // Railing
        if railingLF > 0 {
            out.append(MaterialItem(
                name: "Railing",
                qty: railingLF,
                unit: "LF",
                notes: i.railingSidesHouseIsOnLength ? "3 sides (house on one length side)" : "4 sides")
            )
            out.append(MaterialItem(
                name: "Railing posts",
                qty: railingPosts,
                unit: "pcs",
                notes: "Assuming ~6 ft spacing (verify locally)")
            )
        }
    
        return out
    }
}
