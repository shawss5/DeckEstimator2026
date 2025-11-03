import SwiftUI
import UIKit

// StairsInput now lives in Models.swift.

// MARK: - StairsFormView
struct StairsFormView: View {
    @State private var input = StairsInput()
    @State private var projectDetails = ProjectDetails()
    @State private var logoImage: UIImage? = nil

    private struct ResultsPayload: Identifiable {
        let id = UUID()
        let items: [MaterialItem]
        let input: StairsInput
    }
    @State private var resultsPayload: ResultsPayload? = nil

    private var hasValidInputs: Bool {
        input.totalRiseIn > 0 && input.stairWidthIn > 0 && input.treadDepthIn > 0
    }

    var body: some View {
        Form {
            ProjectInfoSection(details: $projectDetails, logoImage: $logoImage)

            Section {
                FeetInchesRow(label: "Total rise", inches: $input.totalRiseIn)
                HStack { Text("Preferred riser (in)"); Spacer(); NumberField(value: $input.preferredRiserIn) }
                HStack { Text("Tread depth (in)"); Spacer(); NumberField(value: $input.treadDepthIn) }
                if !hasValidInputs {
                    Label("Total rise, tread depth, and stair width must all be greater than 0", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Rise & Run")
            } footer: {
                Text("Total rise: from the ground where the bottom step will sit up to the top of the deck boards.")
            }

            Section("Stair Width & Stringers") {
                HStack { Text("Stair width (in)"); Spacer(); NumberField(value: $input.stairWidthIn) }
                HStack { Text("Stringer spacing OC (in)"); Spacer(); NumberField(value: $input.stringerSpacingIn) }
            }

            StairsLandingSection(input: $input)

            Section("Tread Decking") {
                HStack { Text("Board width (in)"); Spacer(); NumberField(value: $input.boardWidthIn) }
                HStack { Text("Gap (in)"); Spacer(); NumberField(value: $input.boardGapIn) }
                HStack { Text("Waste (%)"); Spacer(); NumberField(value: $input.wastePct) }
                Toggle("Include closed risers (riser boards)", isOn: $input.includeRisers)
            }

            Section("Notes") {
                Text("Risers are spread as evenly as possible from your total rise and preferred riser height. Verify final riser height (typically ≤ 7.75\") and tread depth against your local building code.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                Button {
                    let computed = StairsCalculator.materials(input)
                    resultsPayload = ResultsPayload(items: computed, input: input)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Text("Calculate Materials")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!hasValidInputs)
            }
        }
        .navigationTitle("Stairs")
        .sheet(item: $resultsPayload) { payload in
            StairsResultsView(
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
        StairsFormView()
    }
}
