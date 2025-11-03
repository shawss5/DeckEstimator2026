import Foundation

// MARK: - Material item
// Shared line item used by every calculator's output (Deck, Stairs, Covered Deck).
struct MaterialItem: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var qty: Double
    var unit: String
    var notes: String?
}

// MARK: - RoofStyle
enum RoofStyle: String, CaseIterable, Codable, Hashable, Identifiable {
    case mono = "mono"
    case gable = "gable"
    case hip = "hip"
    case flat = "flat"

    var id: String { rawValue }
}

// Helper for UI labels without redefining the enum
extension RoofStyle {
    var displayName: String {
        switch self {
        case .mono: return "Mono"
        case .gable: return "Gable"
        case .hip: return "Hip"
        case .flat: return "Flat"
        }
    }
}

// MARK: - DeckInput
struct DeckInput: Identifiable, Hashable, Codable {
    let id: UUID
    var lengthFt: Double
    var widthFt: Double
    var boardWidthIn: Double
    var boardGapIn: Double
    var joistSpacingIn: Double
    var wastePct: Double
    var ledgerAttached: Bool
    var postSpacingFt: Double
    var includeRailing: Bool
    var railingSidesHouseIsOnLength: Bool
    /// Height of the finished deck surface above the ground, at the deck's
    /// HIGHEST point, in inches. 0 = not entered (height checks are skipped).
    var deckHeightIn: Double

    enum CodingKeys: String, CodingKey {
        case id, lengthFt, widthFt, boardWidthIn, boardGapIn, joistSpacingIn, wastePct, ledgerAttached, postSpacingFt, includeRailing, railingSidesHouseIsOnLength, deckHeightIn
    }

    init(id: UUID = UUID(),
         lengthFt: Double = 12,
         widthFt: Double = 16,
         boardWidthIn: Double = 5.5,
         boardGapIn: Double = 0.125,
         joistSpacingIn: Double = 16,
         wastePct: Double = 10,
         ledgerAttached: Bool = true,
         postSpacingFt: Double = 8,
         includeRailing: Bool = true,
         railingSidesHouseIsOnLength: Bool = true,
         deckHeightIn: Double = 36) {
        self.id = id
        self.lengthFt = lengthFt
        self.widthFt = widthFt
        self.boardWidthIn = boardWidthIn
        self.boardGapIn = boardGapIn
        self.joistSpacingIn = joistSpacingIn
        self.wastePct = wastePct
        self.ledgerAttached = ledgerAttached
        self.postSpacingFt = postSpacingFt
        self.includeRailing = includeRailing
        self.railingSidesHouseIsOnLength = railingSidesHouseIsOnLength
        self.deckHeightIn = deckHeightIn
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.lengthFt = try c.decodeIfPresent(Double.self, forKey: .lengthFt) ?? 12
        self.widthFt = try c.decodeIfPresent(Double.self, forKey: .widthFt) ?? 16
        self.boardWidthIn = try c.decodeIfPresent(Double.self, forKey: .boardWidthIn) ?? 5.5
        self.boardGapIn = try c.decodeIfPresent(Double.self, forKey: .boardGapIn) ?? 0.125
        self.joistSpacingIn = try c.decodeIfPresent(Double.self, forKey: .joistSpacingIn) ?? 16
        self.wastePct = try c.decodeIfPresent(Double.self, forKey: .wastePct) ?? 10
        self.ledgerAttached = try c.decodeIfPresent(Bool.self, forKey: .ledgerAttached) ?? true
        self.postSpacingFt = try c.decodeIfPresent(Double.self, forKey: .postSpacingFt) ?? 8
        self.includeRailing = try c.decodeIfPresent(Bool.self, forKey: .includeRailing) ?? true
        self.railingSidesHouseIsOnLength = try c.decodeIfPresent(Bool.self, forKey: .railingSidesHouseIsOnLength) ?? true
        // Saved decks from before this field existed load as "not entered".
        self.deckHeightIn = try c.decodeIfPresent(Double.self, forKey: .deckHeightIn) ?? 0
    }
}

// MARK: - StairsInput
struct StairsInput: Identifiable, Hashable, Codable {
    let id: UUID
    var totalRiseIn: Double
    var preferredRiserIn: Double
    var treadDepthIn: Double
    var stairWidthIn: Double
    var stringerSpacingIn: Double
    var boardWidthIn: Double
    var boardGapIn: Double
    var wastePct: Double
    var includeRisers: Bool
    // Landing (platform) between two flights. Height 0 = automatic (about halfway,
    // lined up with a riser). Width below the stair width is treated as the stair width.
    var includeLanding: Bool
    var landingWidthIn: Double
    var landingDepthIn: Double
    var landingHeightIn: Double
    // Planter boxes on the landing (built from decking boards on 2×4 corners).
    var includePlanters: Bool
    var planterCount: Double
    var planterLengthIn: Double
    var planterWidthIn: Double
    var planterHeightIn: Double

    enum CodingKeys: String, CodingKey {
        case id, totalRiseIn, preferredRiserIn, treadDepthIn, stairWidthIn,
             stringerSpacingIn, boardWidthIn, boardGapIn, wastePct, includeRisers,
             includeLanding, landingWidthIn, landingDepthIn, landingHeightIn,
             includePlanters, planterCount, planterLengthIn, planterWidthIn, planterHeightIn
    }

    init(id: UUID = UUID(),
         totalRiseIn: Double = 30,
         preferredRiserIn: Double = 7.5,
         treadDepthIn: Double = 10,
         stairWidthIn: Double = 36,
         stringerSpacingIn: Double = 16,
         boardWidthIn: Double = 5.5,
         boardGapIn: Double = 0.125,
         wastePct: Double = 10,
         includeRisers: Bool = false,
         includeLanding: Bool = false,
         landingWidthIn: Double = 36,
         landingDepthIn: Double = 36,
         landingHeightIn: Double = 0,
         includePlanters: Bool = false,
         planterCount: Double = 2,
         planterLengthIn: Double = 48,
         planterWidthIn: Double = 18,
         planterHeightIn: Double = 18) {
        self.id = id
        self.totalRiseIn = totalRiseIn
        self.preferredRiserIn = preferredRiserIn
        self.treadDepthIn = treadDepthIn
        self.stairWidthIn = stairWidthIn
        self.stringerSpacingIn = stringerSpacingIn
        self.boardWidthIn = boardWidthIn
        self.boardGapIn = boardGapIn
        self.wastePct = wastePct
        self.includeRisers = includeRisers
        self.includeLanding = includeLanding
        self.landingWidthIn = landingWidthIn
        self.landingDepthIn = landingDepthIn
        self.landingHeightIn = landingHeightIn
        self.includePlanters = includePlanters
        self.planterCount = planterCount
        self.planterLengthIn = planterLengthIn
        self.planterWidthIn = planterWidthIn
        self.planterHeightIn = planterHeightIn
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.totalRiseIn = try c.decodeIfPresent(Double.self, forKey: .totalRiseIn) ?? 30
        self.preferredRiserIn = try c.decodeIfPresent(Double.self, forKey: .preferredRiserIn) ?? 7.5
        self.treadDepthIn = try c.decodeIfPresent(Double.self, forKey: .treadDepthIn) ?? 10
        self.stairWidthIn = try c.decodeIfPresent(Double.self, forKey: .stairWidthIn) ?? 36
        self.stringerSpacingIn = try c.decodeIfPresent(Double.self, forKey: .stringerSpacingIn) ?? 16
        self.boardWidthIn = try c.decodeIfPresent(Double.self, forKey: .boardWidthIn) ?? 5.5
        self.boardGapIn = try c.decodeIfPresent(Double.self, forKey: .boardGapIn) ?? 0.125
        self.wastePct = try c.decodeIfPresent(Double.self, forKey: .wastePct) ?? 10
        self.includeRisers = try c.decodeIfPresent(Bool.self, forKey: .includeRisers) ?? false
        self.includeLanding = try c.decodeIfPresent(Bool.self, forKey: .includeLanding) ?? false
        self.landingWidthIn = try c.decodeIfPresent(Double.self, forKey: .landingWidthIn) ?? 36
        self.landingDepthIn = try c.decodeIfPresent(Double.self, forKey: .landingDepthIn) ?? 36
        self.landingHeightIn = try c.decodeIfPresent(Double.self, forKey: .landingHeightIn) ?? 0
        self.includePlanters = try c.decodeIfPresent(Bool.self, forKey: .includePlanters) ?? false
        self.planterCount = try c.decodeIfPresent(Double.self, forKey: .planterCount) ?? 2
        self.planterLengthIn = try c.decodeIfPresent(Double.self, forKey: .planterLengthIn) ?? 48
        self.planterWidthIn = try c.decodeIfPresent(Double.self, forKey: .planterWidthIn) ?? 18
        self.planterHeightIn = try c.decodeIfPresent(Double.self, forKey: .planterHeightIn) ?? 18
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(totalRiseIn, forKey: .totalRiseIn)
        try c.encode(preferredRiserIn, forKey: .preferredRiserIn)
        try c.encode(treadDepthIn, forKey: .treadDepthIn)
        try c.encode(stairWidthIn, forKey: .stairWidthIn)
        try c.encode(stringerSpacingIn, forKey: .stringerSpacingIn)
        try c.encode(boardWidthIn, forKey: .boardWidthIn)
        try c.encode(boardGapIn, forKey: .boardGapIn)
        try c.encode(wastePct, forKey: .wastePct)
        try c.encode(includeRisers, forKey: .includeRisers)
        try c.encode(includeLanding, forKey: .includeLanding)
        try c.encode(landingWidthIn, forKey: .landingWidthIn)
        try c.encode(landingDepthIn, forKey: .landingDepthIn)
        try c.encode(landingHeightIn, forKey: .landingHeightIn)
        try c.encode(includePlanters, forKey: .includePlanters)
        try c.encode(planterCount, forKey: .planterCount)
        try c.encode(planterLengthIn, forKey: .planterLengthIn)
        try c.encode(planterWidthIn, forKey: .planterWidthIn)
        try c.encode(planterHeightIn, forKey: .planterHeightIn)
    }
}

// MARK: - Covered Deck Input
struct CoveredDeckInput: Codable, Hashable {
    var lengthFt: Double = 12
    var projectionFt: Double = 10
    var overhangIn: Double = 12
    var pitchRisePer12: Double = 3
    var rafterSpacingIn: Double = 16
    var postSpacingFt: Double = 8
    var freestanding: Bool = false
    var roofingIsShingles: Bool = true
    var sheathingWastePct: Double = 10
    var roofingWastePct: Double = 10
    var hipLengthFt: Double = 0
    var valleyLengthFt: Double = 0
    // Not yet used by CoveredDeckCalculator — kept for future span/engineering checks.
    var groundSnowLoadPSF: Double = 20
    var windExposure: String = "B"
    var roofStyle: RoofStyle = .mono
}

// MARK: - Number display
/// Whole numbers print without decimals ("38", not "38.00"); others keep up
/// to 2 decimals without trailing zeros ("7.13", "12.5").
func displayNumber(_ v: Double) -> String {
    if v.rounded() == v { return String(format: "%.0f", v) }
    var s = String(format: "%.2f", v)
    while s.hasSuffix("0") { s.removeLast() }
    if s.hasSuffix(".") { s.removeLast() }
    return s
}
