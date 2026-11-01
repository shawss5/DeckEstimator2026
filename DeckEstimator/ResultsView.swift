import SwiftUI
import UIKit
import UniformTypeIdentifiers

// DeckInput now lives in Models.swift. This file holds the actual Rectangular
// Deck results/PDF-export view (previously nested inside DeckFormView.swift).

// MARK: - ResultsView
struct ResultsView: View {
    let items: [MaterialItem]
    let input: DeckInput?
    let species: LumberSpecies

    // Project header extras
    let projectName: String?
    let customerName: String?
    let jobsiteAddress: String?
    let contactInfo: String?
    let projectNotes: String?
    let logoImage: UIImage?
    let boardsParallelToHouse: Bool

    init(items: [MaterialItem],
         input: DeckInput? = nil,
         species: LumberSpecies,
         projectName: String? = nil,
         customerName: String? = nil,
         jobsiteAddress: String? = nil,
         contactInfo: String? = nil,
         projectNotes: String? = nil,
         logoImage: UIImage? = nil,
         boardsParallelToHouse: Bool = true) {
        self.items = items
        self.input = input
        self.species = species
        self.projectName = projectName
        self.customerName = customerName
        self.jobsiteAddress = jobsiteAddress
        self.contactInfo = contactInfo
        self.projectNotes = projectNotes
        self.logoImage = logoImage
        self.boardsParallelToHouse = boardsParallelToHouse
    }

    private func fmt(_ v: Double) -> String { displayNumber(v) }

    // MARK: - Share / Save / Print
    @EnvironmentObject private var purchases: PurchaseManager
    @State private var sharePayload: SharePayload? = nil
    @State private var showPaywall: Bool = false

    struct ActivityView: UIViewControllerRepresentable {
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

    /// Create a styled PDF from the grouped materials and return a file URL
    private func makeSummaryPDF() -> URL? {
        // Group items the same way the UI does
        let deckingNeedles = ["Deck boards", "Decking (linear", "Deck screws", "Hidden fastener", "Starter/edge clips"]
        let framingNeedles = ["Joists", "Joist hanger", "Blocking", "Rim board", "Ledger board", "Beam", "Posts ", "Post lumber", "Concrete footings", "Post bases", "Post-to-beam", "Ledger structural"]
        let railingNeedles = ["Railing"]
        let allNeedles = deckingNeedles + framingNeedles + railingNeedles

        let deckingItems = items.filter { matches($0, needles: deckingNeedles) }
        let framingItems = items.filter { matches($0, needles: framingNeedles) }
        let railingItems = items.filter { matches($0, needles: railingNeedles) }
        let otherItems = items.filter { !matches($0, needles: allNeedles) }

        @ViewBuilder func section(_ title: String, _ arr: [MaterialItem]) -> some View {
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

        // Lay the PDF out on 8½ × 11 pages (see PDFPaginator).
        var blocks: [AnyView] = []
        blocks.append(AnyView(
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(projectName?.isEmpty == false ? (projectName ?? "Deck Materials Summary") : "Deck Materials Summary")
                            .font(.title2).bold()
                        if let pn = customerName, !pn.isEmpty { Text(pn).font(.subheadline) }
                        if let js = jobsiteAddress, !js.isEmpty { Text("Jobsite: \(js)").font(.footnote).foregroundStyle(.secondary) }
                        if let ci = contactInfo, !ci.isEmpty { Text("Contact: \(ci)").font(.footnote).foregroundStyle(.secondary) }
                        if let di = input {
                            Text("Deck: \(fmt(di.lengthFt)) ft × \(fmt(di.widthFt)) ft • Joists \(Int(di.joistSpacingIn))\" OC • Waste \(fmt(di.wastePct))% • \(species.rawValue)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Text(Date().formatted(date: .abbreviated, time: .shortened))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
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
                if let notes = projectNotes, !notes.isEmpty {
                    Text(notes)
                        .font(.footnote)
                        .padding(8)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        ))
        blocks.append(AnyView(Divider()))
        if let di = input {
            blocks.append(AnyView(DeckPlanDrawing(input: di, boardsParallelToHouse: boardsParallelToHouse).padding(.vertical, 6)))
        }
        blocks.append(AnyView(VStack(alignment: .leading, spacing: 10) {
            // Height checks
            if let di = input {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Height checks (verify with local code)").font(.headline)
                    if di.deckHeightIn > 0 {
                        Text("Deck height: \(DeckHeightRules.feetInches(di.deckHeightIn)) at highest point").font(.footnote)
                    }
                    ForEach(DeckHeightRules.checks(for: di, items: items), id: \.self) { line in
                        Text("• \(line)").font(.footnote)
                    }
                }
                .padding(.bottom, 6)
            }

            // Education (concise)
            VStack(alignment: .leading, spacing: 4) {
                Text("Understanding lengths").font(.headline)
                Text("• Decking orientation controls joist direction; joists span the other dimension.").font(.footnote)
                Text("• Joists are single pieces between supports (no mid-span splices).").font(.footnote)
                Text("• Built-up beams splice only over posts.").font(.footnote)
            }
            .padding(.bottom, 6)

        }))
        blocks += PDFPaginator.sectionBlocks("Decking", deckingItems)
        blocks += PDFPaginator.sectionBlocks("Framing", framingItems)
        blocks += PDFPaginator.sectionBlocks("Railing", railingItems)
        blocks += PDFPaginator.sectionBlocks("Other", otherItems)
        let data = PDFPaginator.pdfData(blocks: blocks)
        let filename = "DeckEstimate-\(UUID().uuidString.prefix(8)).pdf"
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename, conformingTo: .pdf)
        do { try data.write(to: tmpURL); return tmpURL } catch { return nil }
    }

    /// Create a plain-text file (.txt) with the summary and return a file URL
    private func makeSummaryTextFile() -> URL? {
        let summary = buildSummary()
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("DeckEstimate-\(UUID().uuidString.prefix(8)).txt")
        do {
            try summary.data(using: .utf8)?.write(to: tmpURL)
            return tmpURL
        } catch {
            return nil
        }
    }

    /// Prepare and present the system share sheet with PDF (and TXT fallback)
    private func shareOrPrintSummary() {
        var items: [Any] = []
        if let pdfURL = makeSummaryPDF() {
            items = [ShareableFile(url: pdfURL)]
        } else if let txtURL = makeSummaryTextFile() {
            items = [ShareableFile(url: txtURL)]
        } else {
            items = [buildSummary()]
        }
        self.sharePayload = SharePayload(items: items)
    }

    var body: some View {
        NavigationStack {
            List {
                if let di = input {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            TotalsSummary(itemCount: items.count)
                                .padding(.bottom, 2)
                            Text("Deck: \(fmt(di.lengthFt)) ft × \(fmt(di.widthFt)) ft")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Joists \(Int(di.joistSpacingIn))\" OC • Waste \(fmt(di.wastePct))%")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            if di.deckHeightIn > 0 {
                                Text("Height: \(DeckHeightRules.feetInches(di.deckHeightIn)) at highest point")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Species: \(species.rawValue)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            if let pn = projectName, !pn.isEmpty { Text("Project: \(pn)").font(.footnote).foregroundStyle(.secondary) }
                            if let cn = customerName, !cn.isEmpty { Text("Customer: \(cn)").font(.footnote).foregroundStyle(.secondary) }
                            if let js = jobsiteAddress, !js.isEmpty { Text("Jobsite: \(js)").font(.footnote).foregroundStyle(.secondary) }
                            if let ci = contactInfo, !ci.isEmpty { Text("Contact: \(ci)").font(.footnote).foregroundStyle(.secondary) }
                            if let notes = projectNotes, !notes.isEmpty { Text(notes).font(.footnote) }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Drawing
                if let di = input {
                    Section { DeckPlanDrawing(input: di, boardsParallelToHouse: boardsParallelToHouse).padding(.vertical, 4) }
                }

                // Height-driven code checks
                if let di = input {
                    Section("Height checks (verify with local code)") {
                        ForEach(DeckHeightRules.checks(for: di, items: items), id: \.self) { line in
                            Text(line)
                                .font(.footnote)
                                .foregroundStyle(line.hasPrefix("⚠︎") ? Color.orange : Color.primary)
                        }
                    }
                }

                // Education first
                Section("Understanding lengths") {
                    Text("• Decking orientation controls joist direction. Boards run along the selected direction; joists span the other dimension.")
                    Text("• Joists should be single pieces spanning between supports (no mid-span splices). Add beams to reduce span if needed.")
                    Text("• Built-up beams can be spliced over posts only. Use full-length stock between posts where possible.")
                }

                // Suggested sizes (heuristic only — verify locally)
                Section("Suggested sizes (verify with local code)") {
                    if let di = input {
                        // Read the joist size the planner actually chose (it knows the framing direction).
                        let joistSize = items.first(where: { $0.name.hasPrefix("Joists ") })
                            .map { String($0.name.dropFirst("Joists ".count)) }
                            ?? recommendJoistSize(spanFt: max(0.1, di.widthFt), species: species)
                        let beamSize = recommendBeamSize(postSpacingFt: di.postSpacingFt, beamLines: di.ledgerAttached ? 1 : 2, species: species)
                        let postSize = "6×6 (nominal)"
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Joists: \(joistSize)")
                            Text("Beams: \(beamSize)")
                            Text("Posts: \(postSize)")
                            Text("Ledger: same depth as joists (or as required)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text("Splice built-up beams only over posts; do not splice joists mid-span.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Enter dimensions to see size suggestions")
                    }
                }

                // Categorized materials
                let deckingNeedles = ["Deck boards", "Decking (linear", "Deck screws", "Hidden fastener", "Starter/edge clips"]
                let framingNeedles = ["Joists", "Joist hanger", "Blocking", "Rim board", "Ledger board", "Beam", "Posts ", "Post lumber", "Concrete footings", "Post bases", "Post-to-beam", "Ledger structural"]
                let railingNeedles = ["Railing"]
                let allNeedles = deckingNeedles + framingNeedles + railingNeedles

                let deckingItems = items.filter { matches($0, needles: deckingNeedles) }
                let framingItems = items.filter { matches($0, needles: framingNeedles) }
                let railingItems = items.filter { matches($0, needles: railingNeedles) }
                let otherItems = items.filter { !matches($0, needles: allNeedles) }

                if !deckingItems.isEmpty { Section { materialRows(deckingItems) } header: { CategoryHeader(title: "Decking") } }
                if !framingItems.isEmpty { Section { materialRows(framingItems) } header: { CategoryHeader(title: "Framing") } }
                if !railingItems.isEmpty { Section { materialRows(railingItems) } header: { CategoryHeader(title: "Railing") } }
                if !otherItems.isEmpty { Section { materialRows(otherItems) } header: { CategoryHeader(title: "Other") } }

                Section("Fastener guidance") {
                    Text("• Deck screws: #9/#10 exterior (HDG or stainless). 2½\" for 5/4 boards, 3\" for 2×.")
                    Text("• Joist hangers: use 10d HDG nails or Simpson SD screws — follow manufacturer schedule.")
                    if let di = input, di.ledgerAttached {
                        Text("• Ledger: 1/2\" HDG lag bolts or 5/16\" structural screws at ~16\" OC (verify span table).")
                    }
                    Text("• Railing posts: use manufacturer-rated structural screws/bolts per post base detail.")
                }
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

    // Species-aware heuristics (very rough — verify locally)
    private func recommendJoistSize(spanFt: Double, species: LumberSpecies) -> String {
        switch species {
        case .southernPine:
            if spanFt <= 8 { return "2×8" }
            if spanFt <= 10 { return "2×10" }
            if spanFt <= 12 { return "2×12" }
            if spanFt <= 16 { return "2×12 (verify)" }
            return "Engineer review"
        case .douglasFirLarch:
            if spanFt <= 8 { return "2×8" }
            if spanFt <= 9.5 { return "2×10" }
            if spanFt <= 11.5 { return "2×12" }
            if spanFt <= 15 { return "2×12 (verify)" }
            return "Engineer review"
        case .hemFir:
            if spanFt <= 7.5 { return "2×8" }
            if spanFt <= 9.0 { return "2×10" }
            if spanFt <= 11.0 { return "2×12" }
            if spanFt <= 14 { return "2×12 (verify)" }
            return "Engineer review"
        }
    }

    private func recommendBeamSize(postSpacingFt: Double, beamLines: Int, species: LumberSpecies) -> String {
        let s = postSpacingFt
        let base: String
        switch species {
        case .southernPine:
            if s <= 6 { base = "(2) 2×8" }
            else if s <= 8 { base = "(2) 2×10" }
            else if s <= 10 { base = "(2) 2×12" }
            else { base = "(3) 2×12 (verify)" }
        case .douglasFirLarch:
            if s <= 6 { base = "(2) 2×8" }
            else if s <= 7.5 { base = "(2) 2×10" }
            else if s <= 9.5 { base = "(2) 2×12" }
            else { base = "(3) 2×12 (verify)" }
        case .hemFir:
            if s <= 5.5 { base = "(2) 2×8" }
            else if s <= 7.0 { base = "(2) 2×10" }
            else if s <= 9.0 { base = "(2) 2×12" }
            else { base = "(3) 2×12 (verify)" }
        }
        return beamLines == 2 ? "\(base) per beam line (2 lines)" : base
    }

    @Environment(\.dismiss) private var dismiss

    private func buildSummary() -> String {
        var lines: [String] = []
        if let di = input {
            lines.append("Deck: \(displayNumber(di.lengthFt)) ft × \(displayNumber(di.widthFt)) ft")
            lines.append("Joists \(Int(di.joistSpacingIn))\" OC • Waste \(displayNumber(di.wastePct))%")
            lines.append("Species: \(species.rawValue)")
            if di.deckHeightIn > 0 {
                lines.append("Height: \(DeckHeightRules.feetInches(di.deckHeightIn)) at highest point")
            }
            lines.append("")
            lines.append("Height checks (verify with local code):")
            for c in DeckHeightRules.checks(for: di, items: items) { lines.append("- \(c)") }
        }
        if let pn = projectName, !pn.isEmpty { lines.append("Project: \(pn)") }
        if let cn = customerName, !cn.isEmpty { lines.append("Customer: \(cn)") }
        if let js = jobsiteAddress, !js.isEmpty { lines.append("Jobsite: \(js)") }
        if let ci = contactInfo, !ci.isEmpty { lines.append("Contact: \(ci)") }
        if !AppSettings.contactInfo.isEmpty { lines.append("Prepared by: \(AppSettings.contactInfo)") }
        if let notes = projectNotes, !notes.isEmpty { lines.append("Notes: \(notes)") }
        lines.append("")
        lines.append("Materials:")
        for it in items {
            let qtyStr = displayNumber(it.qty)
            let unit = displayUnit(it)
            if let notes = it.notes, !notes.isEmpty {
                lines.append("- \(it.name): \(qtyStr) \(unit) (\(notes))")
            } else {
                lines.append("- \(it.name): \(qtyStr) \(unit)")
            }
        }
        return lines.joined(separator: "\n")
    }
}

#Preview("ResultsView Preview") {
    ResultsView(
        items: [
            MaterialItem(name: "Deck boards (linear feet)", qty: 160, unit: "lf", notes: "Approx 16 runs @ 10 ft"),
            MaterialItem(name: "Joists 2×10 × 12 ft", qty: 13, unit: "pcs", notes: "Clear span 12 ft each"),
            MaterialItem(name: "Beam segments (Line A) (2) 2×12 × 10 ft", qty: 6, unit: "pcs", notes: "Built-up pieces"),
            MaterialItem(name: "Beam segments (Line B) (2) 2×12 × 10 ft", qty: 6, unit: "pcs", notes: "Built-up pieces"),
            MaterialItem(name: "Beam segments total", qty: 12, unit: "pcs", notes: "2 plies • 3 spans per line • 10 ft stock"),
            MaterialItem(name: "Posts", qty: 6, unit: "pcs", notes: "Spacing ~8 ft")
        ],
        input: DeckInput(lengthFt: 10, widthFt: 10),
        species: .southernPine,
        projectName: "Shaw Lake Deck",
        customerName: "Stephanie Shaw",
        jobsiteAddress: "123 Lake Rd, Milledgeville, GA",
        contactInfo: "(555) 010-1234 • steph@example.com",
        projectNotes: "Build per local code; confirm railing style.",
        logoImage: nil
    )
}
