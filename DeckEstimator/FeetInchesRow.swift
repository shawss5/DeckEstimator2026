import SwiftUI

// MARK: - FeetInchesRow
// A labeled row with separate feet and inches boxes for a value stored in inches.
// (A single inches box let "15" meaning 15 ft become 15″.)
struct FeetInchesRow: View {
    let label: String
    @Binding var inches: Double

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
            Spacer(minLength: 8)
            NumberField(value: feet).frame(width: 80)
            Text("ft").foregroundStyle(.secondary).fixedSize()
            NumberField(value: inchPart).frame(width: 80)
            Text("in").foregroundStyle(.secondary).fixedSize()
        }
    }

    private var feet: Binding<Double> {
        Binding(
            get: { (inches / 12).rounded(.down) },
            set: { ft in
                let rest = inches - (inches / 12).rounded(.down) * 12
                inches = max(0, ft).rounded(.down) * 12 + rest
            })
    }

    private var inchPart: Binding<Double> {
        Binding(
            get: { inches - (inches / 12).rounded(.down) * 12 },
            set: { inch in
                let ft = (inches / 12).rounded(.down)
                inches = ft * 12 + max(0, inch)
            })
    }
}
