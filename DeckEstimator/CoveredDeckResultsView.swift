import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - CoveredDeckResultsView
struct CoveredDeckResultsView: View {
    let items: [MaterialItem]
    let input: CoveredDeckInput
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

    private let framingNeedles = ["Rafters", "Posts", "Beam", "Ridge Board"]
    private let roofingNeedles = ["Roof Sheathing", "Shingles", "Metal Roofing"]
    private let trimNeedles = ["Hip Trim", "Valley Flashing"]

    private var framingItems: [MaterialItem] { items.filter { matches($0, needles: framingNeedles) } }
    private var roofingItems: [MaterialItem] { items.filter { matches($0, needles: roofingNeedles) } }
    private var trimItems: [MaterialItem] { items.filter { matches($0, needles: trimNeedles) } }
    private var otherItems: [MaterialItem] {
        let known = framingNeedles + roofingNeedles + trimNeedles
        return items.filter { !matches($0, needles: known) }
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

    private func infoHeaderLine() -> String {
        "Covered Deck: \(input.roofStyle.displayName) roof • \(fmt(input.lengthFt)) ft × \(fmt(input.projectionFt)) ft projection • pitch \(fmt(input.pitchRisePer12))/12 • \(input.freestanding ? "Freestanding" : "Attached")"
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
                            Text("\(fmt(it.qty)) \(it.unit)").font(.footnote).foregroundStyle(.secondary)
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
        let pageWidth: CGFloat = 612 // 8.5" at 72 dpi
        let content = VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(projectDetails.projectName.isEmpty ? "Covered Deck Materials Summary" : projectDetails.projectName)
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
            Divider()

            pdfSection("Framing", framingItems)
            pdfSection("Roofing", roofingItems)
            pdfSection("Trim", trimItems)
            pdfSection("Other", otherItems)
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
        let filename = "CoveredDeckEstimate-\(UUID().uuidString.prefix(8)).pdf"
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename, conformingTo: .pdf)
        do { try data.write(to: tmpURL); return tmpURL } catch { return nil }
    }

    private func makeSummaryTextFile() -> URL? {
        let summary = buildSummary()
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("CoveredDeckEstimate-\(UUID().uuidString.prefix(8)).txt")
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
                lines.append("- \(it.name): \(qtyStr) \(it.unit) (\(notes))")
            } else {
                lines.append("- \(it.name): \(qtyStr) \(it.unit)")
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

                Section("Guidance") {
                    Text("• Rafter size and ledger connection must be verified against your local snow load and wind exposure tables.")
                    Text("• Splice built-up beams only over posts.")
                    Text("• Confirm flashing details where the roof meets the house.")
                }

                if !framingItems.isEmpty { Section { materialRows(framingItems) } header: { CategoryHeader(title: "Framing") } }
                if !roofingItems.isEmpty { Section { materialRows(roofingItems) } header: { CategoryHeader(title: "Roofing") } }
                if !trimItems.isEmpty { Section { materialRows(trimItems) } header: { CategoryHeader(title: "Trim") } }
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

#Preview("CoveredDeckResultsView Preview") {
    CoveredDeckResultsView(
        items: CoveredDeckCalculator.materials(CoveredDeckInput()),
        input: CoveredDeckInput(),
        projectDetails: ProjectDetails(projectName: "Shaw Lake Deck Roof", customerName: "Stephanie Shaw"),
        logoImage: nil
    )
}
