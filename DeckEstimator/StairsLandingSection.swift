import SwiftUI

// MARK: - Landing (platform) inputs — shared by Stairs and Full Project
struct StairsLandingSection: View {
    @Binding var input: StairsInput
    /// Prefix for the section header ("Stairs — " in Full Project).
    var headerPrefix: String = ""

    private var maxRise: Double { StairsCalculator.maxFlightRiseIn }

    var body: some View {
        Section {
            Toggle("Add a landing (platform)", isOn: $input.includeLanding)

            if input.totalRiseIn > maxRise && !input.includeLanding {
                Label("Total rise is over 12′ 7″ — code requires a landing partway up.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            if input.includeLanding {
                HStack { Text("Landing width (in)"); Spacer(); NumberField(value: $input.landingWidthIn) }
                HStack { Text("Landing depth (in)"); Spacer(); NumberField(value: $input.landingDepthIn) }
                Toggle("Put landing halfway up", isOn: halfwayBinding)
                if !halfwayBinding.wrappedValue {
                    FeetInchesRow(label: "Landing height", inches: $input.landingHeightIn)
                }

                let plan = StairsCalculator.landingPlan(input)
                Text("Landing sits \(DeckHeightRules.feetInches(plan.heightIn)) up\(plan.isAutoHeight ? " (halfway, lined up with a step)" : ""). Lower stairs climb \(DeckHeightRules.feetInches(plan.lowerRiseIn)), upper stairs \(DeckHeightRules.feetInches(plan.upperRiseIn)).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Toggle("Add planter boxes", isOn: $input.includePlanters)
                if input.includePlanters {
                    HStack { Text("How many"); Spacer(); NumberField(value: $input.planterCount) }
                    HStack { Text("Planter length (in)"); Spacer(); NumberField(value: $input.planterLengthIn) }
                    HStack { Text("Planter width (in)"); Spacer(); NumberField(value: $input.planterWidthIn) }
                    HStack { Text("Planter height (in)"); Spacer(); NumberField(value: $input.planterHeightIn) }
                    Text(input.planterHeightIn >= StairsCalculator.planterGuardHeightIn
                         ? "36″ or taller: planters along the edge can take the place of railing there (confirm with your inspector)."
                         : "Under 36″ tall: planters don't count as a guard, so railing still runs behind them.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if input.landingWidthIn < input.stairWidthIn {
                    warning("Landing can't be narrower than the stairs — using the stair width (\(displayNumber(input.stairWidthIn))″).")
                }
                if input.landingDepthIn < StairsCalculator.minLandingDepthIn {
                    warning("Landings need to be at least 36″ deep in the direction you walk.")
                }
                if plan.lowerRiseIn > maxRise || plan.upperRiseIn > maxRise {
                    warning("A flight still rises more than 12′ 7″ — move the landing or add another one (check with your inspector).")
                }
            }
        } header: {
            Text("\(headerPrefix)Landing")
        } footer: {
            Text("A flight can climb at most 12′ 7″ before it needs a landing. A landing must be at least as wide as the stairs and 36″ deep — make it bigger (e.g. 60 × 60) for a wide platform.")
        }
        .onChange(of: input.totalRiseIn) { oldRise, newRise in
            // Crossing above 12′ 7″ turns the landing on (it can still be turned off; the warning stays).
            if newRise > maxRise && oldRise <= maxRise { input.includeLanding = true }
        }
    }

    /// On = automatic halfway landing (stored as height 0). Turning it off
    /// starts the height boxes at the halfway value so it's easy to adjust.
    private var halfwayBinding: Binding<Bool> {
        Binding(
            get: { !(input.landingHeightIn > 0 && input.landingHeightIn < input.totalRiseIn) },
            set: { halfway in
                if halfway {
                    input.landingHeightIn = 0
                } else {
                    var auto = input; auto.landingHeightIn = 0
                    input.landingHeightIn = StairsCalculator.landingPlan(auto).heightIn.rounded()
                }
            })
    }

    private func warning(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(.orange)
    }
}
