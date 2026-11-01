import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - StairsResultsView
struct StairsResultsView: View {
    let items: [MaterialItem]
    let input: StairsInput
    let projectDetails: ProjectDetails
    let logoImage: UIImage?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchases: PurchaseManager
    @State private var sharePayload: SharePayload? = nil
    @State private var showPaywall: Bool = false

    private func fmt(_ v: Double) -> String { displayNumber(v) }

    private struct ActivityView: UIViewControllerRepresentable {
        let activityItems: [Any]
        func makeUIViewController(context: Context) -> UIActivityViewController {
            let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
            #if targetEnvironment(simulator)
            // The iOS Simulator has no real AirDrop/Print hardware, and
            // UIActivityViewController evaluates every built-in activity
            // (including these) synchronously before it can show anything —
            // on Simulator that check can hang indefinitely, leaving the
            // sheet stuck on its loading spinner forever. Skip them here
            // only; real devices keep full sharing options.
            vc.excludedActivityTypes = [.airDrop, .print, .assignToContact]
            #endif
            return vc
        }
        func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
    }

    // Grouping helpers
    private func matches(_ it: MaterialItem, needles: [String]) -> Bool {
        let name = it.name.lowercased()
        return needles.contains { name.contains($0.lowercased()) }
    }

    private let structureNeedles = ["Risers", "Treads", "Stringers"]
    private let deckingNeedles = ["Riser boards", "Tread decking"]
    private let fastenerNeedles = ["Stair screws", "Stringer hangers"]
    private let landingNeedles = ["Landing"]
    private let railingNeedles = ["Stair railing", "Stair handrail"]
    private let planterNeedles = ["Planter"]

    private var structureItems: [MaterialItem] { items.filter { matches($0, needles: structureNeedles) } }
    private var deckingItems: [MaterialItem] { items.filter { matches($0, needles: deckingNeedles) } }
    private var fastenerItems: [MaterialItem] { items.filter { matches($0, needles: fastenerNeedles) } }
    private var landingItems: [MaterialItem] { items.filter { matches($0, needles: landingNeedles) } }
    private var railingItems: [MaterialItem] { items.filter { matches($0, needles: railingNeedles) } }
    private var planterItems: [MaterialItem] { items.filter { matches($0, needles: planterNeedles) } }
    private var otherItems: [MaterialItem] {
        let known = structureNeedles + deckingNeedles + fastenerNeedles + landingNeedles + planterNeedles + railingNeedles
        return items.filter { !matches($0, needles: known) }
    }

    @ViewBuilder private func materialRows(_ arr: [MaterialItem]) -> some View {
        ForEach(arr) { it in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(it.name)
                    Spacer()
                    Text("\(fmt(it.qty)) \(displayUnit(it))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if let notes = it.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func infoHeaderLine() -> String {
        let g = StairsCalculator.computeGeometry(input)
        var line = "Stairs: total rise \(fmt(input.totalRiseIn))\" over \(g.risers) risers (\(fmt(g.finalRiserIn))\" each) • width \(fmt(input.stairWidthIn))\" • waste \(fmt(input.wastePct))%"
        if input.includeLanding {
            let p = StairsCalculator.landingPlan(input)
            line += " • landing \(fmt(p.widthIn))″ × \(fmt(p.depthIn))″ at \(DeckHeightRules.feetInches(p.heightIn))"
        } else if input.totalRiseIn > StairsCalculator.maxFlightRiseIn {
            line += " • ⚠︎ over 12′ 7″ without a landing"
        }
        return line
    }

    @ViewBuilder private func pdfSection(_ title: String, _ arr: [MaterialItem]) -> some View {
        if !arr.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                ForEach(arr) { it in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(it.name).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            Text("\(fmt(it.qty)) \(displayUnit(it))").font(.footnote).foregroundStyle(.secondary)
                        }
                        if let notes = it.notes, !notes.isEmpty {
                            Text(notes).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
            .padding(.top, 10)
        }
    }

    /// Create a styled PDF from the grouped materials and return a file URL
    private func makeSummaryPDF() -> URL? {
        // Lay the PDF out on 8½ × 11 pages (see PDFPaginator).
        var blocks: [AnyView] = []
        blocks.append(AnyView(
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(projectDetails.projectName.isEmpty ? "Stair Materials Summary" : projectDetails.projectName)
                            .font(.title2).bold()
                        if !projectDetails.customerName.isEmpty { Text(projectDetails.customerName).font(.subheadline) }
                        if !projectDetails.jobsiteAddress.isEmpty { Text("Jobsite: \(projectDetails.jobsiteAddress)").font(.footnote).foregroundStyle(.secondary) }
                        if !projectDetails.contactInfo.isEmpty { Text("Contact: \(projectDetails.contactInfo)").font(.footnote).foregroundStyle(.secondary) }
                        Text(infoHeaderLine()).font(.footnote).foregroundStyle(.secondary)
                        Text(Date().formatted(date: .abbreviated, time: .shortened)).font(.footnote).foregroundStyle(.secondary)
                    }
                    .fixedSize(horizontal: false, vertical: true) // let header lines wrap instead of truncating
                    Spacer(minLength: 8)
                    // Your company block (letterhead): logo + saved contact info, kept
                    // apart from the customer/jobsite block so they can't be confused.
                    VStack(alignment: .trailing, spacing: 4) {
                        if let logo = logoImage {
                            Image(uiImage: logo).resizable().scaledToFit().frame(width: 140, height: 60, alignment: .trailing)
                        }
                        if !AppSettings.contactInfo.isEmpty {
                            Text(AppSettings.contactInfo)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 200, alignment: .trailing)
                                .fixedSize(horizontal: false, vertical: true) // company info wraps, never truncates
                        }
                    }
                    .frame(width: 170, alignment: .trailing) // fixed: never squeezed by long header lines
                    .layoutPriority(1)
                }
                if !projectDetails.notes.isEmpty {
                    Text(projectDetails.notes)
                        .font(.footnote)
                        .padding(8)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        ))
        blocks.append(AnyView(Divider()))
        blocks.append(AnyView(StairsSideDrawing(input: input).padding(.vertical, 6)))
        for (t, arr) in [("Stair Structure", structureItems), ("Decking", deckingItems), ("Fasteners", fastenerItems),
                         ("Railing", railingItems), ("Landing", landingItems), ("Planters", planterItems), ("Other", otherItems)] {
            blocks += PDFPaginator.sectionBlocks(t, arr)
        }
        let data = PDFPaginator.pdfData(blocks: blocks)
        let filename = "StairsEstimate-\(UUID().uuidString.prefix(8)).pdf"
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename, conformingTo: .pdf)
        do { try data.write(to: tmpURL); return tmpURL } catch { return nil }
    }

    private func makeSummaryTextFile() -> URL? {
        let summary = buildSummary()
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("StairsEstimate-\(UUID().uuidString.prefix(8)).txt")
        do {
            try summary.data(using: .utf8)?.write(to: tmpURL)
            return tmpURL
        } catch {
            return nil
        }
    }

    private func shareOrPrintSummary() {
        var out: [Any] = []
        if let pdfURL = makeSummaryPDF() {
            out = [ShareableFile(url: pdfURL)]
        } else if let txtURL = makeSummaryTextFile() {
            out = [ShareableFile(url: txtURL)]
        } else {
            out = [buildSummary()]
        }
        self.sharePayload = SharePayload(items: out)
    }

    private func buildSummary() -> String {
        var lines: [String] = []
        lines.append(infoHeaderLine())
        if !projectDetails.projectName.isEmpty { lines.append("Project: \(projectDetails.projectName)") }
        if !projectDetails.customerName.isEmpty { lines.append("Customer: \(projectDetails.customerName)") }
        if !projectDetails.jobsiteAddress.isEmpty { lines.append("Jobsite: \(projectDetails.jobsiteAddress)") }
        if !projectDetails.contactInfo.isEmpty { lines.append("Contact: \(projectDetails.contactInfo)") }
        if !AppSettings.contactInfo.isEmpty { lines.append("Prepared by: \(AppSettings.contactInfo)") }
        if !projectDetails.notes.isEmpty { lines.append("Notes: \(projectDetails.notes)") }
        lines.append("")
        lines.append("Materials:")
        for it in items {
            let qtyStr = fmt(it.qty)
            if let notes = it.notes, !notes.isEmpty {
                lines.append("- \(it.name): \(qtyStr) \(displayUnit(it)) (\(notes))")
            } else {
                lines.append("- \(it.name): \(qtyStr) \(displayUnit(it))")
            }
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        TotalsSummary(itemCount: items.count)
                            .padding(.bottom, 2)
                        Text(infoHeaderLine())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if !projectDetails.projectName.isEmpty { Text("Project: \(projectDetails.projectName)").font(.footnote).foregroundStyle(.secondary) }
                        if !projectDetails.customerName.isEmpty { Text("Customer: \(projectDetails.customerName)").font(.footnote).foregroundStyle(.secondary) }
                        if !projectDetails.jobsiteAddress.isEmpty { Text("Jobsite: \(projectDetails.jobsiteAddress)").font(.footnote).foregroundStyle(.secondary) }
                        if !projectDetails.contactInfo.isEmpty { Text("Contact: \(projectDetails.contactInfo)").font(.footnote).foregroundStyle(.secondary) }
                        if !projectDetails.notes.isEmpty { Text(projectDetails.notes).font(.footnote) }
                    }
                    .padding(.vertical, 4)
                }

                Section { StairsSideDrawing(input: input).padding(.vertical, 4) }

                Section("Guidance") {
                    Text("• Keep riser heights consistent — code typically limits variance between the largest and smallest riser to 3/8\".")
                    Text("• Stringers are shown as full-length stock; verify tail/top cut allowances on site.")
                    Text("• Confirm handrail and guard requirements with your local code (commonly required at 4+ risers).")
                }

                if !structureItems.isEmpty { Section { materialRows(structureItems) } header: { CategoryHeader(title: "Stair Structure") } }
                if !deckingItems.isEmpty { Section { materialRows(deckingItems) } header: { CategoryHeader(title: "Decking") } }
                if !fastenerItems.isEmpty { Section { materialRows(fastenerItems) } header: { CategoryHeader(title: "Fasteners") } }
                if !railingItems.isEmpty { Section { materialRows(railingItems) } header: { CategoryHeader(title: "Railing") } }
                if !landingItems.isEmpty { Section { materialRows(landingItems) } header: { CategoryHeader(title: "Landing") } }
                if !planterItems.isEmpty { Section { materialRows(planterItems) } header: { CategoryHeader(title: "Planters") } }
                if !otherItems.isEmpty { Section { materialRows(otherItems) } header: { CategoryHeader(title: "Other") } }
            }
            .navigationTitle("Results")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save/Print") {
                        if purchases.isPro {
                            shareOrPrintSummary()
                        } else {
                            showPaywall = true
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Copy Summary") {
                        UIPasteboard.general.string = buildSummary()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
            .sheet(item: $sharePayload) { payload in ActivityView(activityItems: payload.items) }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }
}

#Preview("StairsResultsView Preview") {
    StairsResultsView(
        items: StairsCalculator.materials(StairsInput()),
        input: StairsInput(),
        projectDetails: ProjectDetails(projectName: "Shaw Lake Deck Stairs", customerName: "Stephanie Shaw"),
        logoImage: nil
    )
}
