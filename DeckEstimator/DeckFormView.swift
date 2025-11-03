import SwiftUI
import UIKit
import PhotosUI

// MARK: - Species for span heuristics
enum LumberSpecies: String, CaseIterable, Identifiable {
    case southernPine = "Southern Pine"
    case douglasFirLarch = "Douglas Fir–Larch (DF-L)"
    case hemFir = "Hem-Fir"
    var id: String { rawValue }
}

// MARK: - Decking orientation (controls joist direction)
enum DeckingDirection: String, CaseIterable, Identifiable {
    case alongLength = "Boards run along deck LENGTH"
    case alongWidth  = "Boards run along deck WIDTH"
    var id: String { rawValue }
}

// MARK: - Deck board presets (local to this view)
struct DeckPreset: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var actualBoardWidthIn: Double
    var defaultGapIn: Double
    var defaultJoistSpacingIn: Double
    var suggestedWastePct: Double

    init(id: UUID = UUID(),
         name: String,
         actualBoardWidthIn: Double,
         defaultGapIn: Double,
         defaultJoistSpacingIn: Double,
         suggestedWastePct: Double) {
        self.id = id
        self.name = name
        self.actualBoardWidthIn = actualBoardWidthIn
        self.defaultGapIn = defaultGapIn
        self.defaultJoistSpacingIn = defaultJoistSpacingIn
        self.suggestedWastePct = suggestedWastePct
    }
}

// Note: ResultsView now lives in its own file, ResultsView.swift.

// MARK: - Simple numeric field (local, no dependencies)
private struct NumericField: View {
    @Binding var value: Double
    var width: CGFloat? = 100
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        return f
    }()

    var body: some View {
        TextField("", value: $value, formatter: Self.formatter)
            .textFieldStyle(.roundedBorder)
            .frame(width: width)
            .keyboardType(.decimalPad)
    }
}

// MARK: - Common Decking Presets (shared with ProjectView)
let presets: [DeckPreset] = [
    // Wood
    DeckPreset(name: "5/4×6 Wood (5.5\")", actualBoardWidthIn: 5.5, defaultGapIn: 0.125, defaultJoistSpacingIn: 16, suggestedWastePct: 10),
    DeckPreset(name: "2×6 Wood (5.5\")",   actualBoardWidthIn: 5.5, defaultGapIn: 0.125, defaultJoistSpacingIn: 16, suggestedWastePct: 10),

    // Composite (often tighter spacing required)
    DeckPreset(name: "Composite (5.25\")", actualBoardWidthIn: 5.25, defaultGapIn: 0.125, defaultJoistSpacingIn: 12, suggestedWastePct: 12),
    DeckPreset(name: "Composite (5.5\")",  actualBoardWidthIn: 5.5,  defaultGapIn: 0.125, defaultJoistSpacingIn: 12, suggestedWastePct: 12),

    // PVC / Cap-stock (verify with manufacturer)
    DeckPreset(name: "PVC (5.5\")",        actualBoardWidthIn: 5.5,  defaultGapIn: 0.125, defaultJoistSpacingIn: 16, suggestedWastePct: 12)
]

// MARK: - DeckFormView
struct DeckFormView: View {
    @State private var input = DeckInput()
    @State private var selectedPreset = presets.first!
    @State private var stockLengthFt: Double = 12
    @State private var doubleCornerPosts: Bool = false
    @State private var species: LumberSpecies = .southernPine
    @State private var deckingDirection: DeckingDirection = .alongLength

    // Framing intelligence (LumberGrade, FastenerType live in DeckPlanner.swift)
    @State private var joistGrade: LumberGrade = .number2
    @State private var fastenerType: FastenerType = .screws

    // Project / Client info for PDF header (shared component; also handles
    // auto-filling your saved contact info + logo from "My Company" settings).
    @State private var projectDetails = ProjectDetails()
    @State private var logoImage: UIImage? = nil

    private struct ResultsPayload: Identifiable {
        let id = UUID()
        let items: [MaterialItem]
        let input: DeckInput
    }
    @State private var resultsPayload: ResultsPayload? = nil

    private var hasValidDimensions: Bool {
        input.lengthFt > 0 && input.widthFt > 0
    }

    // Sizing/purchase-ready material logic lives in DeckPlanner.swift (shared with ProjectView).
    private func calculateMaterials(for i: DeckInput) -> [MaterialItem] {
        DeckPlanner.calculateMaterials(
            for: i,
            species: species,
            deckingDirection: deckingDirection,
            joistGrade: joistGrade,
            fastenerType: fastenerType,
            stockLengthFt: stockLengthFt,
            doubleCornerPosts: doubleCornerPosts
        )
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

    // MARK: - View
    var body: some View {
        Form {
            ProjectInfoSection(details: $projectDetails, logoImage: $logoImage)

            // Preset
            Section("Preset") {
                Picker("Board preset", selection: $selectedPreset) {
                    ForEach(presets) { p in
                        Text(p.name).tag(p)
                    }
                }
                .onChange(of: selectedPreset) { _, newVal in
                    input.boardWidthIn = newVal.actualBoardWidthIn
                    input.boardGapIn = newVal.defaultGapIn
                    input.joistSpacingIn = newVal.defaultJoistSpacingIn
                    input.wastePct = newVal.suggestedWastePct
                }
            }

            // Deck size
            Section {
                HStack { Text("Length (ft)"); Spacer(); NumericField(value: $input.lengthFt) }
                HStack { Text("Width (ft)");  Spacer(); NumericField(value: $input.widthFt) }
                HStack {
                    Text("Height (highest point)")
                    Spacer()
                    NumericField(value: heightFeetBinding($input.deckHeightIn), width: 56)
                    Text("ft").foregroundStyle(.secondary)
                    NumericField(value: heightInchesBinding($input.deckHeightIn), width: 56)
                    Text("in").foregroundStyle(.secondary)
                }
                if !hasValidDimensions {
                    Label("Length and width must both be greater than 0", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Deck Size")
            } footer: {
                Text("Height: feet and inches from the top of the decking down to the ground, where the deck is highest (e.g. 15 ft 0 in). Sets post lengths and whether railing is required (over 30″).")
            }

            // Decking
            Section("Decking") {
                Picker("Decking orientation", selection: $deckingDirection) {
                    ForEach(DeckingDirection.allCases) { o in
                        Text(o.rawValue).tag(o)
                    }
                }
                HStack { Text("Board width (in)"); Spacer(); NumericField(value: $input.boardWidthIn) }
                HStack { Text("Gap (in)");         Spacer(); NumericField(value: $input.boardGapIn) }
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
                        ForEach(FastenerType.allCases) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                }
                HStack { Text("Waste (%)");        Spacer(); NumericField(value: $input.wastePct) }
            }

            // Framing
            Section("Framing") {
                HStack { Text("Joist spacing (in)"); Spacer(); NumericField(value: $input.joistSpacingIn) }
                HStack {
                    Text("Lumber species")
                    Spacer()
                    Picker("", selection: $species) {
                        ForEach(LumberSpecies.allCases) { sp in
                            Text(sp.rawValue).tag(sp)
                        }
                    }
                }
                HStack {
                    Text("Joist grade")
                    Spacer()
                    Picker("", selection: $joistGrade) {
                        ForEach(LumberGrade.allCases) { g in
                            Text(g.rawValue).tag(g)
                        }
                    }
                }
                Toggle("Ledger-attached (1 beam line)", isOn: $input.ledgerAttached)
                Toggle("Double corner posts", isOn: $doubleCornerPosts)
                HStack { Text("Post spacing (ft)"); Spacer(); NumericField(value: $input.postSpacingFt) }
            }

            // Railing
            Section("Railing") {
                Toggle("Include railing", isOn: $input.includeRailing)
                if input.includeRailing {
                    Toggle("House on deck length side (3 sides railing)", isOn: $input.railingSidesHouseIsOnLength)
                }
                if input.deckHeightIn > DeckHeightRules.guardRequiredAboveIn && !input.includeRailing {
                    Label("This deck is over 30″ high — code requires a guard on open sides.", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }

            Section {
                Button {
                    // Calculate locally and present results via item-based sheet (no double-tap)
                    let computed = calculateMaterials(for: input)
                    resultsPayload = ResultsPayload(items: computed, input: input)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Text("Calculate Materials")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!hasValidDimensions)
            }
        }
        .navigationTitle("Rectangular Deck")
        .onChange(of: input.deckHeightIn) { oldH, newH in
            // Crossing above 30" turns railing on (the user can still turn it off; a warning stays).
            if newH > DeckHeightRules.guardRequiredAboveIn && oldH <= DeckHeightRules.guardRequiredAboveIn {
                input.includeRailing = true
            }
        }
        .sheet(item: $resultsPayload) { payload in
            ResultsView(
                items: payload.items,
                input: payload.input,
                species: species,
                projectName: projectDetails.projectName,
                customerName: projectDetails.customerName,
                jobsiteAddress: projectDetails.jobsiteAddress,
                contactInfo: projectDetails.contactInfo,
                projectNotes: projectDetails.notes,
                logoImage: logoImage
            )
        }
        .onAppear {
            // Seed inputs from the default preset
            input.boardWidthIn = selectedPreset.actualBoardWidthIn
            input.boardGapIn = selectedPreset.defaultGapIn
            input.joistSpacingIn = selectedPreset.defaultJoistSpacingIn
            input.wastePct = selectedPreset.suggestedWastePct
        }
    }
}
