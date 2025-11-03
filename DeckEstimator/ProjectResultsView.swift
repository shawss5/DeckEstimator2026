import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - ProjectResultsView
// One combined shopping list and PDF for however many components (Deck,
// Stairs, Covered Deck) were included — each keeps its own grouped
// breakdown, all under one project header.
struct ProjectResultsView: View {
    let deckItems: [MaterialItem]?
    let deckInput: DeckInput?
    let species: LumberSpecies

    let stairsItems: [MaterialItem]?
    let stairsInput: StairsInput?

    let coveredDeckItems: [MaterialItem]?
    let coveredDeckInput: CoveredDeckInput?

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

    // MARK: - Per-component header lines

    private func deckHeaderLine(_ di: DeckInput) -> String {
        let height = di.deckHeightIn > 0 ? " • Height \(DeckHeightRules.feetInches(di.deckHeightIn))" : ""
        return "Deck: \(fmt(di.lengthFt)) ft × \(fmt(di.widthFt)) ft\(height) • Joists \(Int(di.joistSpacingIn))\" OC • Waste \(fmt(di.wastePct))% • \(species.rawValue)"
    }

    private func stairsHeaderLine(_ si: StairsInput) -> String {
        let g = StairsCalculator.computeGeometry(si)
        var line = "Stairs: total rise \(fmt(si.totalRiseIn))\" over \(g.risers) risers (\(fmt(g.finalRiserIn))\" each) • width \(fmt(si.stairWidthIn))\""
        if si.includeLanding {
            let p = StairsCalculator.landingPlan(si)
            line += " • landing \(fmt(p.widthIn))″ × \(fmt(p.depthIn))″ at \(DeckHeightRules.feetInches(p.heightIn))"
        } else if si.totalRiseIn > StairsCalculator.maxFlightRiseIn {
            line += " • ⚠︎ over 12′ 7″ without a landing"
        }
        return line
    }

    private func coveredDeckHeaderLine(_ ci: CoveredDeckInput) -> String {
        "Covered Deck: \(ci.roofStyle.displayName) roof • \(fmt(ci.lengthFt)) ft × \(fmt(ci.projectionFt)) ft projection • pitch \(fmt(ci.pitchRisePer12))/12 • \(ci.freestanding ? "Freestanding" : "Attached")"
    }

    // MARK: - Grouped sections per component

    private var deckGroups: [(title: String, items: [MaterialItem])] {
        guard let items = deckItems else { return [] }
        return MaterialGrouping.group(items, into: MaterialGrouping.deckCategories)
    }
    private var stairsGroups: [(title: String, items: [MaterialItem])] {
        guard let items = stairsItems else { return [] }
        return MaterialGrouping.group(items, into: MaterialGrouping.stairsCategories)
    }
    private var coveredDeckGroups: [(title: String, items: [MaterialItem])] {
        guard let items = coveredDeckItems else { return [] }
        return MaterialGrouping.group(items, into: MaterialGrouping.coveredDeckCategories)
    }

    @ViewBuilder private func materialRows(_ arr: [MaterialItem]) -> some View {
        ForEach(arr) { it in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(it.name)
                    Spacer()
                    Text("\(fmt(it.qty)) \(it.unit)")
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

    // MARK: - PDF / text export

    @ViewBuilder private func pdfSection(_ title: String, _ arr: [MaterialItem]) -> some View {
        if !arr.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                ForEach(arr) { it in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(it.name).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            Text("\(fmt(it.qty)) \(it.unit)").font(.footnote).foregroundStyle(.secondary)
                        }
                        if let notes = it.notes, !notes.isEmpty {
                            Text(notes).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder private func pdfComponent(_ title: String, _ headerLine: String?, _ groups: [(title: String, items: [MaterialItem])]) -> some View {
        if let headerLine {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title3).bold()
                Text(headerLine).font(.footnote).foregroundStyle(.secondary)
                ForEach(groups, id: \.title) { group in
                    pdfSection(group.title, group.items)
                }
            }
            .padding(.top, 14)
        }
    }

    private func makeSummaryPDF() -> URL? {
        let pageWidth: CGFloat = 612 // 8.5" at 72 dpi
        let content = VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(projectDetails.projectName.isEmpty ? "Project Materials Summary" : projectDetails.projectName)
                            .font(.title2).bold()
                        if !projectDetails.customerName.isEmpty { Text(projectDetails.customerName).font(.subheadline) }
                        if !projectDetails.jobsiteAddress.isEmpty { Text("Jobsite: \(projectDetails.jobsiteAddress)").font(.footnote).foregroundStyle(.secondary) }
                        if !projectDetails.contactInfo.isEmpty { Text("Contact: \(projectDetails.contactInfo)").font(.footnote).foregroundStyle(.secondary) }
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
            Divider()

            if let di = deckInput { pdfComponent("Rectangular Deck", deckHeaderLine(di), deckGroups) }
            if let si = stairsInput { pdfComponent("Stairs", stairsHeaderLine(si), stairsGroups) }
            if let ci = coveredDeckInput { pdfComponent("Covered Deck", coveredDeckHeaderLine(ci), coveredDeckGroups) }
        }
        .padding(24)
        .frame(width: pageWidth, alignment: .leading)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 1

        var pdfData: Data?
        renderer.render { size, render in
            let pageRect = CGRect(origin: .zero, size: size)
            let format = UIGraphicsPDFRendererFormat()
            let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
            pdfData = pdfRenderer.pdfData { ctx in
                ctx.beginPage()
                let cg = ctx.cgContext
                cg.saveGState()
                cg.setFillColor(UIColor.white.cgColor)
                cg.fill(CGRect(origin: .zero, size: pageRect.size))
                cg.translateBy(x: 0, y: pageRect.height)
                cg.scaleBy(x: 1, y: -1)
                render(cg)
                cg.restoreGState()
            }
        }
        guard let data = pdfData else { return nil }
        let filename = "ProjectEstimate-\(UUID().uuidString.prefix(8)).pdf"
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename, conformingTo: .pdf)
        do { try data.write(to: tmpURL); return tmpURL } catch { return nil }
    }

    private func makeSummaryTextFile() -> URL? {
        let summary = buildSummary()
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("ProjectEstimate-\(UUID().uuidString.prefix(8)).txt")
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

    private func appendComponent(_ lines: inout [String], title: String, headerLine: String?, items: [MaterialItem]?) {
        guard let headerLine, let items else { return }
        lines.append("")
        lines.append("== \(title) ==")
        lines.append(headerLine)
        for it in items {
            let qtyStr = fmt(it.qty)
            if let notes = it.notes, !notes.isEmpty {
                lines.append("- \(it.name): \(qtyStr) \(it.unit) (\(notes))")
            } else {
                lines.append("- \(it.name): \(qtyStr) \(it.unit)")
            }
        }
    }

    private func buildSummary() -> String {
        var lines: [String] = []
        if !projectDetails.projectName.isEmpty { lines.append("Project: \(projectDetails.projectName)") }
        if !projectDetails.customerName.isEmpty { lines.append("Customer: \(projectDetails.customerName)") }
        if !projectDetails.jobsiteAddress.isEmpty { lines.append("Jobsite: \(projectDetails.jobsiteAddress)") }
        if !projectDetails.contactInfo.isEmpty { lines.append("Contact: \(projectDetails.contactInfo)") }
        if !AppSettings.contactInfo.isEmpty { lines.append("Prepared by: \(AppSettings.contactInfo)") }
        if !projectDetails.notes.isEmpty { lines.append("Notes: \(projectDetails.notes)") }

        appendComponent(&lines, title: "Rectangular Deck", headerLine: deckInput.map(deckHeaderLine), items: deckItems)
        appendComponent(&lines, title: "Stairs", headerLine: stairsInput.map(stairsHeaderLine), items: stairsItems)
        appendComponent(&lines, title: "Covered Deck", headerLine: coveredDeckInput.map(coveredDeckHeaderLine), items: coveredDeckItems)

        return lines.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        TotalsSummary(itemCount: (deckItems?.count ?? 0) + (stairsItems?.count ?? 0) + (coveredDeckItems?.count ?? 0))
                            .padding(.bottom, 2)
                        if !projectDetails.projectName.isEmpty { Text("Project: \(projectDetails.projectName)").font(.footnote).foregroundStyle(.secondary) }
                        if !projectDetails.customerName.isEmpty { Text("Customer: \(projectDetails.customerName)").font(.footnote).foregroundStyle(.secondary) }
                        if !projectDetails.jobsiteAddress.isEmpty { Text("Jobsite: \(projectDetails.jobsiteAddress)").font(.footnote).foregroundStyle(.secondary) }
                        if !projectDetails.contactInfo.isEmpty { Text("Contact: \(projectDetails.contactInfo)").font(.footnote).foregroundStyle(.secondary) }
                        if !projectDetails.notes.isEmpty { Text(projectDetails.notes).font(.footnote) }
                    }
                    .padding(.vertical, 4)
                }

                if let di = deckInput {
                    Section {
                        Text(deckHeaderLine(di)).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        ForEach(DeckHeightRules.checks(for: di, items: deckItems ?? []), id: \.self) { line in
                            Text(line)
                                .font(.footnote)
                                .foregroundStyle(line.hasPrefix("⚠︎") ? Color.orange : Color.primary)
                        }
                    } header: {
                        Label("Rectangular Deck", systemImage: "square.grid.2x2.fill").foregroundStyle(.brown)
                    }
                    ForEach(deckGroups, id: \.title) { group in
                        Section { materialRows(group.items) } header: { CategoryHeader(title: group.title, prefix: "Deck") }
                    }
                }

                if let si = stairsInput {
                    Section {
                        Text(stairsHeaderLine(si)).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    } header: {
                        Label("Stairs", systemImage: "stairs").foregroundStyle(.orange)
                    }
                    ForEach(stairsGroups, id: \.title) { group in
                        Section { materialRows(group.items) } header: { CategoryHeader(title: group.title, prefix: "Stairs") }
                    }
                }

                if let ci = coveredDeckInput {
                    Section {
                        Text(coveredDeckHeaderLine(ci)).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    } header: {
                        Label("Covered Deck", systemImage: "house.lodge.fill").foregroundStyle(.indigo)
                    }
                    ForEach(coveredDeckGroups, id: \.title) { group in
                        Section { materialRows(group.items) } header: { CategoryHeader(title: group.title, prefix: "Covered Deck") }
                    }
                }
            }
            .navigationTitle("Project Results")
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

#Preview("ProjectResultsView Preview") {
    ProjectResultsView(
        deckItems: DeckPlanner.calculateMaterials(
            for: DeckInput(), species: .southernPine, deckingDirection: .alongLength,
            joistGrade: .number2, fastenerType: .screws, stockLengthFt: 12, doubleCornerPosts: false
        ),
        deckInput: DeckInput(),
        species: .southernPine,
        stairsItems: StairsCalculator.materials(StairsInput()),
        stairsInput: StairsInput(),
        coveredDeckItems: CoveredDeckCalculator.materials(CoveredDeckInput()),
        coveredDeckInput: CoveredDeckInput(),
        projectDetails: ProjectDetails(projectName: "Shaw Lake Deck — Full Project", customerName: "Stephanie Shaw"),
        logoImage: nil
    )
}
