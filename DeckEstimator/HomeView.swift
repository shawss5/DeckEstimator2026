import SwiftUI

// RoofStyle + its displayName helper now live in Models.swift.
// The Stairs and Covered Deck placeholders that used to live here have been
// replaced by the real StairsFormView.swift and CoveredDeckFormView.swift.

struct HomeView: View {
    @EnvironmentObject private var purchases: PurchaseManager
    @State private var showPaywall = false
    @State private var showIntro = false
    @State private var didCheckIntro = false
    @State private var openSettingsFromIntro = false

    var body: some View {
        NavigationStack {
            List {
                Section("Full Project") {
                    GatedRow(isLocked: !purchases.isPro, showPaywall: $showPaywall) {
                        ProjectView()
                    } label: {
                        HStack(spacing: 12) {
                            IconBadge(systemName: "shippingbox.fill", color: .accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Deck + Stairs + Roof")
                                Text("One combined estimate and PDF")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !purchases.isPro { ProBadge() }
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section("Individual Calculators") {
                    NavigationLink {
                        DeckFormView()
                    } label: {
                        HStack(spacing: 12) {
                            IconBadge(systemName: "square.grid.2x2.fill", color: .brown)
                            Text("Rectangular Deck")
                        }
                        .padding(.vertical, 2)
                    }

                    GatedRow(isLocked: !purchases.isPro, showPaywall: $showPaywall) {
                        StairsFormView()
                    } label: {
                        HStack(spacing: 12) {
                            IconBadge(systemName: "stairs", color: .orange)
                            Text("Stairs")
                            Spacer()
                            if !purchases.isPro { ProBadge() }
                        }
                        .padding(.vertical, 2)
                    }

                    GatedRow(isLocked: !purchases.isPro, showPaywall: $showPaywall) {
                        CoveredDeckFormView()
                    } label: {
                        HStack(spacing: 12) {
                            IconBadge(systemName: "house.lodge.fill", color: .indigo)
                            Text("Covered Deck")
                            Spacer()
                            if !purchases.isPro { ProBadge() }
                        }
                        .padding(.vertical, 2)
                    }
                }

                if !purchases.isPro {
                    Section {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack(spacing: 12) {
                                IconBadge(systemName: "checkmark.seal.fill", color: .orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Unlock DeckEstimator Pro")
                                    Text("Stairs, Covered Deck, Full Project, and PDF export")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section("Notes") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("All spans, sizes, and structural assumptions must be verified with your local building code and inspector. This tool produces estimates for planning only.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Tip: For composite treads or decking, consider 12\" OC joist/stringer spacing unless the manufacturer allows otherwise.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 2)
                }
            }
            .navigationTitle("Materials Estimator")
            .navigationDestination(isPresented: $openSettingsFromIntro) {
                SettingsView()
            }
            .onAppear {
                // Check once per launch (Home reappears every time you come back to it).
                guard !didCheckIntro else { return }
                didCheckIntro = true
                if IntroTour.shouldShow { showIntro = true }
            }
            .fullScreenCover(isPresented: $showIntro) {
                IntroTourView(
                    onSetUpCompany: {
                        IntroTour.markCompleted()
                        showIntro = false
                        // Push My Company after the cover finishes closing.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                            openSettingsFromIntro = true
                        }
                    },
                    onFinish: { completed in
                        if completed { IntroTour.markCompleted() } else { IntroTour.markSkipped() }
                        showIntro = false
                    }
                )
                .environmentObject(purchases)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("My Company settings")
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
}

// MARK: - GatedRow
// Shows a normal NavigationLink when unlocked; when locked, shows the same
// label but taps open the paywall instead of navigating.
struct GatedRow<Destination: View, RowLabel: View>: View {
    let isLocked: Bool
    @Binding var showPaywall: Bool
    @ViewBuilder var destination: () -> Destination
    @ViewBuilder var label: () -> RowLabel

    var body: some View {
        if isLocked {
            Button {
                showPaywall = true
            } label: {
                label()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
        } else {
            NavigationLink {
                destination()
            } label: {
                label()
            }
        }
    }
}

// MARK: - ProBadge
struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.orange.opacity(0.15))
            .foregroundStyle(.orange)
            .clipShape(Capsule())
    }
}

// MARK: - IconBadge
// Small rounded-square, colored icon badge used for row leading images —
// matches the Settings-app look instead of a bare SF Symbol.
struct IconBadge: View {
    let systemName: String
    var color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(color.gradient)
            .frame(width: 29, height: 29)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
            )
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environmentObject(PurchaseManager())
}
