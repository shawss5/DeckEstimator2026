import Foundation

// MARK: - Calculator
// CoveredDeckInput, RoofStyle, and MaterialItem now live in Models.swift.
struct CoveredDeckCalculator {

    struct Geometry {
        let rafterLenFt: Double
        let roofAreaSqFt: Double
        let rafterCount: Int
        let postCount: Int
        let beamLines: Int
        let ridgeLenFt: Double
    }

    // MARK: - Geometry Calculations
    static func geometry(_ i: CoveredDeckInput) -> Geometry {
        let overhangFt = i.overhangIn / 12.0

        switch i.roofStyle {

        // ✅ MONO-SLOPE ROOF
        case .mono:
            let runFt = max(0, i.projectionFt + overhangFt)
            let riseFt = (i.pitchRisePer12 / 12.0) * runFt
            let rafterLenFt = hypot(runFt, riseFt)

            let rafters = Int((i.lengthFt * 12.0) / i.rafterSpacingIn) + 2
            let posts = Int(i.lengthFt / i.postSpacingFt) + 2

            let area = i.lengthFt * rafterLenFt

            return Geometry(
                rafterLenFt: rafterLenFt,
                roofAreaSqFt: area,
                rafterCount: rafters,
                postCount: posts,
                beamLines: 1,
                ridgeLenFt: 0
            )

        // ✅ GABLE ROOF
        case .gable:
            let runFt = max(0, (i.projectionFt / 2.0) + overhangFt)
            let riseFt = (i.pitchRisePer12 / 12.0) * runFt
            let rafterLenFt = hypot(runFt, riseFt)

            let raftersPerSide = Int((i.lengthFt * 12.0) / i.rafterSpacingIn) + 2
            let posts = i.freestanding
                ? (Int(i.lengthFt / i.postSpacingFt) + 2) * 2
                : (Int(i.lengthFt / i.postSpacingFt) + 2)

            let area = i.lengthFt * (rafterLenFt * 2)

            return Geometry(
                rafterLenFt: rafterLenFt,
                roofAreaSqFt: area,
                rafterCount: raftersPerSide * 2,
                postCount: posts,
                beamLines: i.freestanding ? 2 : 1,
                ridgeLenFt: i.lengthFt
            )

        // ✅ HIP ROOF
        case .hip:
            let runFt = max(0, (i.projectionFt / 2.0) + overhangFt)
            let riseFt = (i.pitchRisePer12 / 12.0) * runFt
            let rafterLenFt = hypot(runFt, riseFt)

            let raftersPerSide = Int((i.lengthFt * 12.0) / i.rafterSpacingIn) + 2

            let posts = i.freestanding
                ? (Int(i.lengthFt / i.postSpacingFt) + 2) * 2
                : (Int(i.lengthFt / i.postSpacingFt) + 2)

            let area = i.lengthFt * (rafterLenFt * 2)

            return Geometry(
                rafterLenFt: rafterLenFt,
                roofAreaSqFt: area,
                rafterCount: raftersPerSide * 2,
                postCount: posts,
                beamLines: i.freestanding ? 2 : 1,
                ridgeLenFt: 0
            )

        // ✅ FLAT ROOF
        case .flat:
            let rafterLenFt = i.projectionFt
            let rafters = Int((i.lengthFt * 12.0) / i.rafterSpacingIn) + 2
            let posts = i.freestanding
                ? (Int(i.lengthFt / i.postSpacingFt) + 2) * 2
                : (Int(i.lengthFt / i.postSpacingFt) + 2)

            let area = i.lengthFt * rafterLenFt

            return Geometry(
                rafterLenFt: rafterLenFt,
                roofAreaSqFt: area,
                rafterCount: rafters,
                postCount: posts,
                beamLines: i.freestanding ? 2 : 1,
                ridgeLenFt: 0
            )
        }
    }

    // MARK: - MATERIAL CALCULATIONS
    static func materials(_ i: CoveredDeckInput) -> [MaterialItem] {
        var out: [MaterialItem] = []
        let g = geometry(i)

        // ✅ Rafters
        out.append(MaterialItem(
            name: "Rafters",
            qty: Double(g.rafterCount),
            unit: "pcs",
            notes: "Approx length \(String(format: "%.1f", g.rafterLenFt)) ft"
        ))

        // ✅ Posts
        out.append(MaterialItem(
            name: "Posts",
            qty: Double(g.postCount),
            unit: "pcs",
            notes: "Spacing approx \(i.postSpacingFt) ft"
        ))

        // ✅ Beams
        out.append(MaterialItem(
            name: g.beamLines == 1 ? "Beam (total length)" : "Beams (total)",
            qty: Double(g.beamLines) * i.lengthFt,
            unit: "ft",
            notes: "Depends on local code"
        ))

        // ✅ Ridge (gable only)
        if i.roofStyle == .gable {
            out.append(MaterialItem(
                name: "Ridge Board",
                qty: g.ridgeLenFt,
                unit: "ft",
                notes: nil
            ))
        }

        // ✅ Sheathing
        let sheetArea = 32.0
        let sheetsNeeded = ceil((g.roofAreaSqFt / sheetArea) * (1 + i.sheathingWastePct/100))
        out.append(MaterialItem(
            name: "Roof Sheathing (4×8)",
            qty: sheetsNeeded,
            unit: "sheets",
            notes: nil
        ))

        // ✅ Roofing
        let squares = ceil((g.roofAreaSqFt / 100) * (1 + i.roofingWastePct/100))

        if i.roofingIsShingles {
            out.append(MaterialItem(
                name: "Shingles",
                qty: squares * 3,
                unit: "bundles",
                notes: "3 bundles per square"
            ))
        } else {
            out.append(MaterialItem(
                name: "Metal Roofing",
                qty: squares,
                unit: "sq",
                notes: nil
            ))
        }

        // ✅ Additional hip/valley
        if i.hipLengthFt > 0 {
            out.append(MaterialItem(
                name: "Hip Trim",
                qty: i.hipLengthFt,
                unit: "ft",
                notes: nil
            ))
        }

        if i.valleyLengthFt > 0 {
            out.append(MaterialItem(
                name: "Valley Flashing",
                qty: i.valleyLengthFt,
                unit: "ft",
                notes: nil
            ))
        }

        return out
    }
}
