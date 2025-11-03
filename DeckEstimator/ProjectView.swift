import SwiftUI
import UIKit

// MARK: - ProjectView
// The combined estimate: a deck plus optional stairs and/or a covered deck
// roof, calculated together and delivered as one shopping list and one PDF.
// Reuses the exact same calculators as the standalone screens (DeckPlanner,
// StairsCalculator, CoveredDeckCalculator) so numbers never drift between
// "just the deck" and "the whole project."
struct ProjectView: View {
    @State private var includeDeck = true
    @State private var includeStairs = false
    @State private var includeCoveredDeck = false

    // Deck state (mirrors DeckFormView's own state)
    @State private var deckInput = DeckInput()
    @State private var selectedPreset = presets.first!
    @State private var stockLengthFt: Double = 12
    @State private var doubleCornerPosts: Bool = false
    @State private var species: LumberSpecies = .southernPine
    @State private var deckingDirection: DeckingDirection = .alongLength
    @State private var joistGrade: LumberGrade = .number2
    @State private var fastenerType: FastenerType = .screws

    // Stairs state
    @State private var stairsInput = StairsInput()

    // Covered Deck state
    @State private var coveredDeckInput = CoveredDeckInput()

    // Shared project info
    @State private var projectDetails = ProjectDetails()
    @State private var logoImage: UIImage? = nil

    private struct ResultsPayload: Identifiable {
        let id = UUID()
        var deckItems: [MaterialItem]? = nil
        var deckInputSnapshot: DeckInput? = nil
        var stairsItems: [MaterialItem]? = nil
        var stairsInputSnapshot: StairsInput? = nil
        var coveredDeckItems: [MaterialItem]? = nil
        var coveredDeckInputSnapshot: CoveredDeckInput? = nil
    }
    @State private var resultsPayload: ResultsPayload? = nil

    private var hasValidInputs: Bool {
        if includeDeck && (deckInput.lengthFt <= 0 || deckInput.widthFt <= 0) { return false }
        if includeStairs && (stairsInput.totalRiseIn <= 0 || stairsInput.stairWidthIn <= 0 || stairsInput.treadDepthIn <= 0) { return false }
        if includeCoveredDeck && (coveredDeckInput.lengthFt <= 0 || coveredDeckInput.projectionFt <= 0) { return false }
        return includeDeck || includeStairs || includeCoveredDeck
    }

    // Height is stored in inches but entered as feet + inches, so "15" in the
    // feet box means 15 ft (a single inches box let 15 ft become 15″).
    private func heightFeetBinding(_ h: Binding<Double>) -> Binding<Double> {
        Binding(
            get: { (h.wrappedValue / 12).rounded(.down) },
            set: { ft in
                let inches = h.wrappedValue - (h.wrappedValue / 12).rounded(.down) * 12
                h.wrappedValue = max(0, ft).rounded(.down) * 12 + inches
            })
    }
    private func heightInchesBinding(_ h: Binding<Double>) -> Binding<Double> {
        Binding(
            get: { h.wrappedValue - (h.wrappedValue / 12).rounded(.down) * 12 },
            set: { inch in
                let feet = (h.wrappedValue / 12).rounded(.down)
                h.wrappedValue = feet * 12 + max(0, inch)
            })
    }

    var body: some View {
        Form {
            ProjectInfoSection(details: $projectDetails, logoImage: $logoImage)

            Section("Include in This Project") {
                Toggle("Rectangular Deck", isOn: $includeDeck)
                Toggle("Stairs", isOn: $includeStairs)
                Toggle("Covered Deck", isOn: $includeCoveredDeck)
            }

            if includeDeck {
                Section("Deck — Preset") {
                    Picker("Board preset", selection: $selectedPreset) {
                        ForEach(presets) { p in Text(p.name).tag(p) }
                    }
                    .onChange(of: selectedPreset) { _, newVal in
                        deckInput.boardWidthIn = newVal.actualBoardWidthIn
                        deckInput.boardGapIn = newVal.defaultGapIn
                        deckInput.joistSpacingIn = newVal.defaultJoistSpacingIn
                        deckInput.wastePct = newVal.suggestedWastePct
                    }
                }

                Section("Deck — Size") {
                    HStack { Text("Length (ft)"); Spacer(); NumberField(value: $deckInput.lengthFt) }
                    HStack { Text("Width (ft)");  Spacer(); NumberField(value: $deckInput.widthFt) }
                    HStack {
                        Text("Height (highest point)")
                        Spacer()
                        NumberField(value: heightFeetBinding($deckInput.deckHeightIn)).frame(width: 56)
                        Text("ft").foregroundStyle(.secondary)
                        NumberField(value: heightInchesBinding($deckInput.deckHeightIn)).frame(width: 56)
                        Text("in").foregroundStyle(.secondary)
                    }
                    Text("Feet and inches from the top of the decking down to the ground, where the deck is highest (e.g. 15 ft 0 in). Sets post lengths, railing rules and the stairs' total rise.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if deckInput.lengthFt <= 0 || deckInput.widthFt <= 0 {
                        Label("Length and width must both be greater than 0", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }

                Section("Deck — Decking") {
                    Picker("Decking orientation", selection: $deckingDirection) {
                        ForEach(DeckingDirection.allCases) { o in Text(o.rawValue).tag(o) }
                    }
                    HStack { Text("Board width (in)"); Spacer(); NumberField(value: $deckInput.boardWidthIn) }
                    HStack { Text("Gap (in)");         Spacer(); NumberField(value: $deckInput.boardGapIn) }
                    HStack {
                        Text("Stock length (ft)")
                        Spacer()
                        Picker("", selection: $stockLengthFt) {
                            Text("8").tag(8.0)
                            Text("10").tag(10.0)
                            Text("12").tag(12.0)
                            Text("16").tag(16.0)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 220)
                    }
                    HStack {
                        Text("Fastening method")
                        Spacer()
                        Picker("", selection: $fastenerType) {
                            ForEach(FastenerType.allCases) { f in Text(f.rawValue).tag(f) }
                        }
                    }
                    HStack { Text("Waste (%)"); Spacer(); NumberField(value: $deckInput.wastePct) }
                }

                Section("Deck — Framing") {
                    HStack { Text("Joist spacing (in)"); Spacer(); NumberField(value: $deckInput.joistSpacingIn) }
                    HStack {
                        Text("Lumber species")
                        Spacer()
                        Picker("", selection: $species) {
                            ForEach(LumberSpecies.allCases) { sp in Text(sp.rawValue).tag(sp) }
                        }
                    }
                    HStack {
                        Text("Joist grade")
                        Spacer()
                        Picker("", selection: $joistGrade) {
                            ForEach(LumberGrade.allCases) { g in Text(g.rawValue).tag(g) }
                        }
                    }
                    Toggle("Ledger-attached (1 beam line)", isOn: $deckInput.ledgerAttached)
                    Toggle("Double corner posts", isOn: $doubleCornerPosts)
                    HStack { Text("Post spacing (ft)"); Spacer(); NumberField(value: $deckInput.postSpacingFt) }
                }

                Section("Deck — Railing") {
                    Toggle("Include railing", isOn: $deckInput.includeRailing)
                    if deckInput.includeRailing {
                        Toggle("House on deck length side (3 sides)", isOn: $deckInput.railingSidesHouseIsOnLength)
                    }
                    if deckInput.deckHeightIn > DeckHeightRules.guardRequiredAboveIn && !deckInput.includeRailing {
                        Label("This deck is over 30″ high — code requires a guard on open sides.", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }

            if includeStairs {
                Section("Stairs — Rise & Run") {
                    FeetInchesRow(label: "Total rise", inches: $stairsInput.totalRiseIn)
                    if includeDeck && deckInput.deckHeightIn > 0 {
                        Text("Filled in from the deck height. Change it if the ground at the bottom of the stairs is higher or lower.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    HStack { Text("Preferred riser (in)"); Spacer(); NumberField(value: $stairsInput.preferredRiserIn) }
                    HStack { Text("Tread depth (in)"); Spacer(); NumberField(value: $stairsInput.treadDepthIn) }
                    if stairsInput.totalRiseIn <= 0 || stairsInput.stairWidthIn <= 0 || stairsInput.treadDepthIn <= 0 {
                        Label("Total rise, tread depth, and stair width must all be greater than 0", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }

                Section("Stairs — Width & Decking") {
                    HStack { Text("Stair width (in)"); Spacer(); NumberField(value: $stairsInput.stairWidthIn) }
                    HStack { Text("Stringer spacing OC (in)"); Spacer(); NumberField(value: $stairsInput.stringerSpacingIn) }
                    HStack { Text("Board width (in)"); Spacer(); NumberField(value: $stairsInput.boardWidthIn) }
                    HStack { Text("Waste (%)"); Spacer(); NumberField(value: $stairsInput.wastePct) }
                    Toggle("Include closed risers (riser boards)", isOn: $stairsInput.includeRisers)
                }

                StairsLandingSection(input: $stairsInput, headerPrefix: "Stairs — ")
            }

            if includeCoveredDeck {
                Section("Covered Deck — Roof") {
                    Picker("Style", selection: $coveredDeckInput.roofStyle) {
                        ForEach(RoofStyle.allCases) { style in Text(style.displayName).tag(style) }
                    }
                    Toggle("Freestanding (not attached to house)", isOn: $coveredDeckInput.freestanding)
                }

                Section("Covered Deck — Dimensions (ft)") {
                    HStack { Text("Length (along house)"); Spacer(); NumberField(value: $coveredDeckInput.lengthFt) }
                    HStack { Text("Projection (out from house)"); Spacer(); NumberField(value: $coveredDeckInput.projectionFt) }
                    HStack { Text("Pitch (rise per 12\")"); Spacer(); NumberField(value: $coveredDeckInput.pitchRisePer12) }
                    if coveredDeckInput.lengthFt <= 0 || coveredDeckInput.projectionFt <= 0 {
                        Label("Length and projection must both be greater than 0", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }

                Section("Covered Deck — Roofing") {
                    Toggle("Shingles (off = metal roofing)", isOn: $coveredDeckInput.roofingIsShingles)
                }
            }

            Section {
                Button {
                    var payload = ResultsPayload()
                    if includeDeck {
                        payload.deckItems = DeckPlanner.calculateMaterials(
                            for: deckInput,
                            species: species,
                            deckingDirection: deckingDirection,
                            joistGrade: joistGrade,
                            fastenerType: fastenerType,
                            stockLengthFt: stockLengthFt,
                            doubleCornerPosts: doubleCornerPosts
                        )
                        payload.deckInputSnapshot = deckInput
                    }
                    if includeStairs {
                        payload.stairsItems = StairsCalculator.materials(stairsInput)
                        payload.stairsInputSnapshot = stairsInput
                    }
                    if includeCoveredDeck {
                        payload.coveredDeckItems = CoveredDeckCalculator.materials(coveredDeckInput)
                        payload.coveredDeckInputSnapshot = coveredDeckInput
                    }
                    resultsPayload = payload
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Text("Calculate Full Project")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!hasValidInputs)
            }
        }
        .navigationTitle("Full Project")
        .onChange(of: deckInput.deckHeightIn) { oldH, newH in
            if newH > DeckHeightRules.guardRequiredAboveIn && oldH <= DeckHeightRules.guardRequiredAboveIn {
                deckInput.includeRailing = true
            }
            // Stairs from the deck rise the deck's height.
            if newH > 0 { stairsInput.totalRiseIn = newH }
        }
        .sheet(item: $resultsPayload) { payload in
            ProjectResultsView(
                deckItems: payload.deckItems,
                deckInput: payload.deckInputSnapshot,
                species: species,
                stairsItems: payload.stairsItems,
                stairsInput: payload.stairsInputSnapshot,
                coveredDeckItems: payload.coveredDeckItems,
                coveredDeckInput: payload.coveredDeckInputSnapshot,
                projectDetails: projectDetails,
                logoImage: logoImage
            )
        }
        .onAppear {
            deckInput.boardWidthIn = selectedPreset.actualBoardWidthIn
            deckInput.boardGapIn = selectedPreset.defaultGapIn
            deckInput.joistSpacingIn = selectedPreset.defaultJoistSpacingIn
            deckInput.wastePct = selectedPreset.suggestedWastePct
            if deckInput.deckHeightIn > 0 { stairsInput.totalRiseIn = deckInput.deckHeightIn }
        }
    }
}

#Preview {
    NavigationStack {
        ProjectView()
    }
}
