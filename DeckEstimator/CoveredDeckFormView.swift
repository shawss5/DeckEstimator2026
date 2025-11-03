import SwiftUI
import UIKit

// MARK: - CoveredDeckFormView
struct CoveredDeckFormView: View {
    @State private var input = CoveredDeckInput()
    @State private var projectDetails = ProjectDetails()
    @State private var logoImage: UIImage? = nil

    private struct ResultsPayload: Identifiable {
        let id = UUID()
        let items: [MaterialItem]
        let input: CoveredDeckInput
    }
    @State private var resultsPayload: ResultsPayload? = nil

    private var hasValidDimensions: Bool {
        input.lengthFt > 0 && input.projectionFt > 0
    }

    var body: some View {
        Form {
            ProjectInfoSection(details: $projectDetails, logoImage: $logoImage)

            Section("Roof Style") {
                Picker("Style", selection: $input.roofStyle) {
                    ForEach(RoofStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                Toggle("Freestanding (not attached to house)", isOn: $input.freestanding)
            }

            Section {
                HStack { Text("Length (along house)"); Spacer(); NumberField(value: $input.lengthFt) }
                HStack { Text("Projection (out from house)"); Spacer(); NumberField(value: $input.projectionFt) }
                HStack { Text("Overhang (in)"); Spacer(); NumberField(value: $input.overhangIn) }
                if !hasValidDimensions {
                    Label("Length and projection must both be greater than 0", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Dimensions (ft)")
            }

            Section("Roof Pitch & Framing") {
                HStack { Text("Pitch (rise per 12\")"); Spacer(); NumberField(value: $input.pitchRisePer12) }
                HStack { Text("Rafter spacing OC (in)"); Spacer(); NumberField(value: $input.rafterSpacingIn) }
                HStack { Text("Post spacing (ft)"); Spacer(); NumberField(value: $input.postSpacingFt) }
            }

            Section("Roofing Material") {
                Toggle("Shingles (off = metal roofing)", isOn: $input.roofingIsShingles)
                HStack { Text("Sheathing waste (%)"); Spacer(); NumberField(value: $input.sheathingWastePct) }
                HStack { Text("Roofing waste (%)"); Spacer(); NumberField(value: $input.roofingWastePct) }
            }

            Section("Hip / Valley Trim (optional)") {
                HStack { Text("Hip length (ft)"); Spacer(); NumberField(value: $input.hipLengthFt) }
                HStack { Text("Valley length (ft)"); Spacer(); NumberField(value: $input.valleyLengthFt) }
            }

            Section("Notes") {
                Text("Rafter sizing, ledger attachment hardware, and post footing depth must be verified against your local code, snow load, and wind exposure requirements. This tool estimates material quantities for planning only.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                Button {
                    let computed = CoveredDeckCalculator.materials(input)
                    resultsPayload = ResultsPayload(items: computed, input: input)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Text("Calculate Materials")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!hasValidDimensions)
            }
        }
        .navigationTitle("Covered Deck")
        .sheet(item: $resultsPayload) { payload in
            CoveredDeckResultsView(
                items: payload.items,
                input: payload.input,
                projectDetails: projectDetails,
                logoImage: logoImage
            )
        }
    }
}

#Preview {
    NavigationStack {
        CoveredDeckFormView()
    }
}
