import SwiftUI

struct NumberField: View {
    @Binding var value: Double
    @State private var text: String = ""

    private func format(_ v: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 3
        return nf.string(from: NSNumber(value: v)) ?? String(v)
    }

    var body: some View {
        TextField("", text: Binding(
            get: {
                if text.isEmpty {
                    return format(value)
                }
                return text
            },
            set: { newVal in
                text = newVal
                if let v = Double(newVal.replacingOccurrences(of: ",", with: "")) {
                    value = v
                }
            })
        )
        .keyboardType(.decimalPad)
        .multilineTextAlignment(.trailing)
        .frame(minWidth: 80)
        .onAppear {
            text = format(value)
        }
        .onChange(of: value) { _, newVal in
            // Keep the display in sync when the value changes from outside
            // (e.g. stairs rise filled in from deck height). While the user is
            // typing, the text already matches the value, so it's left alone.
            let typed = Double(text.replacingOccurrences(of: ",", with: ""))
            if typed != newVal { text = format(newVal) }
        }
    }
}
