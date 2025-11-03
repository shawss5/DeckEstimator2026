import SwiftUI
import StoreKit

// MARK: - When to show the intro
// Lessons from MindAnchor's intro:
//  • Skip means "not now", not "never": it comes back next launch. Two skips on
//    the same app version stop it until the next update.
//  • Every app update brings it back once, so new features get seen.
//  • Only finishing it (last page, or "Set up my company") marks a version seen.
//  • It can always be reopened from My Company → "How it works".
enum IntroTour {
    private static let doneKey      = "com.stephanieshaw.DeckEstimator.intro.lastCompletedVersion"
    private static let skipVerKey   = "com.stephanieshaw.DeckEstimator.intro.skipVersion"
    private static let skipCountKey = "com.stephanieshaw.DeckEstimator.intro.skipCount"

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static var shouldShow: Bool {
        let d = UserDefaults.standard
        if d.string(forKey: doneKey) == currentVersion { return false }
        if d.string(forKey: skipVerKey) == currentVersion && d.integer(forKey: skipCountKey) >= 2 { return false }
        return true
    }

    static func markCompleted() {
        UserDefaults.standard.set(currentVersion, forKey: doneKey)
    }

    static func markSkipped() {
        let d = UserDefaults.standard
        if d.string(forKey: skipVerKey) == currentVersion {
            d.set(d.integer(forKey: skipCountKey) + 1, forKey: skipCountKey)
        } else {
            d.set(currentVersion, forKey: skipVerKey)
            d.set(1, forKey: skipCountKey)
        }
    }
}

// MARK: - IntroTourView (3 pages)
struct IntroTourView: View {
    /// Called when the user taps "Set up my company" on page 2.
    var onSetUpCompany: () -> Void
    /// Called when the tour closes. `completed` is true if they reached the end.
    var onFinish: (_ completed: Bool) -> Void

    @EnvironmentObject private var purchases: PurchaseManager
    @State private var page = 0
    private let lastPage = 2

    private var proPrice: String { purchases.product?.displayPrice ?? "$6.99" }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(page == lastPage ? "Close" : "Skip") {
                    onFinish(page == lastPage)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

            TabView(selection: $page) {
                howItWorks.tag(0)
                company.tag(1)
                freeVsPro.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack(spacing: 10) {
                if page == 1 {
                    Button {
                        onSetUpCompany()
                    } label: {
                        Text("Set up my company").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    Button("Later") { withAnimation { page += 1 } }
                } else if page < lastPage {
                    Button {
                        withAnimation { page += 1 }
                    } label: {
                        Text("Next").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button {
                        onFinish(true)
                    } label: {
                        Text("Get started").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // Page 1
    private var howItWorks: some View {
        IntroPage(symbol: "list.bullet.clipboard", tint: .orange,
                  title: "A materials list in seconds") {
            IntroRow(number: "1", text: "Pick a project: deck, stairs, covered deck, or all three.")
            IntroRow(number: "2", text: "Enter your measurements, including the deck's height at its highest point.")
            IntroRow(number: "3", text: "Get a list of what to buy: boards, joists, beams, posts cut to length, and hardware.")
            Text("Estimates are for planning. Always verify spans, sizes and railing rules with your local code.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    // Page 2
    private var company: some View {
        IntroPage(symbol: "building.2.fill", tint: .brown,
                  title: "Put your name on every estimate") {
            Text("Add your logo and contact info once. They print at the top of every PDF estimate you send a customer, so it looks like it came from your business.")
            Text("You can change them any time under the gear icon → My Company. PDF export is part of Pro.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // Page 3
    private var freeVsPro: some View {
        IntroPage(symbol: "star.circle.fill", tint: .orange,
                  title: "Free to use. Pro when you need it.") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Free").font(.headline)
                Label("Rectangular Deck materials list", systemImage: "checkmark")
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Pro: \(proPrice), one time").font(.headline)
                Label("Stairs", systemImage: "checkmark")
                Label("Covered Deck", systemImage: "checkmark")
                Label("Full Project (deck + stairs + roof)", systemImage: "checkmark")
                Label("Branded PDF estimates", systemImage: "checkmark")
            }
            Text("No subscription. No account. No ads.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Building blocks
private struct IntroPage<Content: View>: View {
    let symbol: String
    let tint: Color
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 24)
                Text(title)
                    .font(.title2).bold()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                content()
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 48) // room for the page dots
        }
    }
}

private struct IntroRow: View {
    let number: String
    let text: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(number)
                .font(.headline)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.accentColor.opacity(0.18)))
            Text(text)
        }
    }
}

#Preview {
    IntroTourView(onSetUpCompany: {}, onFinish: { _ in })
        .environmentObject(PurchaseManager())
}
