import SwiftUI
import StoreKit

// MARK: - PaywallView
// Shown whenever a locked calculator or PDF export is tapped without Pro.
struct PaywallView: View {
    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var showRedeemCode = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.orange)
                        Text("Unlock DeckEstimator Pro")
                            .font(.title2.bold())
                        Text("One purchase unlocks every calculator and PDF export — no subscription.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        FeatureRow(icon: "figure.stairs", text: "Stairs calculator")
                        FeatureRow(icon: "house.lodge.fill", text: "Covered Deck calculator")
                        FeatureRow(icon: "shippingbox.fill", text: "Full Project combined estimates")
                        FeatureRow(icon: "doc.richtext.fill", text: "Branded PDF export with your logo")
                    }

                    if let message = purchases.errorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Button {
                        Task { await purchases.purchase() }
                    } label: {
                        HStack {
                            Spacer()
                            if purchases.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text(purchases.product.map { "Unlock Pro — \($0.displayPrice)" } ?? "Unlock Pro")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(purchases.product == nil || purchases.isLoading)

                    // Without this, one failed load at launch left Unlock
                    // greyed out for good, with no way back.
                    if purchases.product == nil && !purchases.isLoading {
                        Button {
                            Task { await purchases.loadProduct() }
                        } label: {
                            HStack {
                                Spacer()
                                Label("Try again", systemImage: "arrow.clockwise")
                                Spacer()
                            }
                        }
                    }

                    Button {
                        Task { await purchases.restore() }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Restore Purchases")
                            Spacer()
                        }
                    }
                    .disabled(purchases.isLoading)

                    // Offer codes (free Pro codes handed out for promotions).
                    // A redeemed code shows up in Transaction.updates /
                    // currentEntitlements, which PurchaseManager already watches.
                    Button {
                        showRedeemCode = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Redeem a code")
                            Spacer()
                        }
                    }
                    .disabled(purchases.isLoading)

                    Text("One-time purchase, billed through your Apple ID. Rectangular Deck stays free forever.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .navigationTitle("DeckEstimator Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .offerCodeRedemption(isPresented: $showRedeemCode) { _ in
                Task { await purchases.refreshEntitlements() }
            }
            .onChange(of: purchases.isPro) { _, unlocked in
                if unlocked { dismiss() }
            }
            .task {
                if purchases.product == nil { await purchases.loadProduct() }
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 24)
            Text(text)
        }
    }
}

#Preview {
    PaywallView().environmentObject(PurchaseManager())
}
