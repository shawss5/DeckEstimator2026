import SwiftUI
import UIKit

// MARK: - PDFPaginator
// Lays SwiftUI "blocks" (header, drawing, each material line…) onto US Letter
// pages. A block is never split across pages unless it is taller than a whole
// page. Before this, every PDF was one very tall page, which showed as a thin
// strip when viewed full screen and didn't print properly.
enum PDFPaginator {
    static let page = CGRect(x: 0, y: 0, width: 612, height: 792)   // 8.5 × 11 in at 72 dpi
    static let margin: CGFloat = 36                                   // ½ in
    static var contentWidth: CGFloat { page.width - margin * 2 }
    private static let blockGap: CGFloat = 4
    private static let footerSpace: CGFloat = 18

    @MainActor
    static func pdfData(blocks: [AnyView]) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: page, format: UIGraphicsPDFRendererFormat())
        return renderer.pdfData { ctx in
            var y = margin
            var pageNumber = 0
            let bottom = page.height - margin - footerSpace

            func newPage() {
                ctx.beginPage()
                pageNumber += 1
                UIColor.white.setFill()
                UIRectFill(page)
                // Disclaimer on every page: the PDF goes to customers who never saw the in-app warnings.
                let footer = "Material estimate only — not an engineered design. Verify sizes, spans and code requirements with your local building department.   •   Page \(pageNumber)" as NSString
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 7),
                    .foregroundColor: UIColor.gray
                ]
                let fs = footer.size(withAttributes: attrs)
                footer.draw(at: CGPoint(x: page.midX - fs.width / 2, y: page.height - margin + 4), withAttributes: attrs)
                y = margin
            }
            newPage()

            for block in blocks {
                let view = block
                    .frame(width: contentWidth, alignment: .leading)
                    .environment(\.colorScheme, .light)
                let r = ImageRenderer(content: view)
                r.scale = 1
                r.proposedSize = ProposedViewSize(width: contentWidth, height: nil)
                r.render { size, draw in
                    guard size.height > 0 else { return }
                    // Start a new page if this block doesn't fit (and the page isn't empty).
                    if y + size.height > bottom && y > margin { newPage() }
                    // Draw — slicing only if the block is taller than a page.
                    var offset: CGFloat = 0
                    while offset < size.height - 0.5 {
                        let slice = min(bottom - y, size.height - offset)
                        let cg = ctx.cgContext
                        cg.saveGState()
                        cg.clip(to: CGRect(x: margin, y: y, width: contentWidth, height: slice))
                        // SwiftUI draws with a bottom-left origin; flip into the page.
                        cg.translateBy(x: margin, y: y - offset + size.height)
                        cg.scaleBy(x: 1, y: -1)
                        draw(cg)
                        cg.restoreGState()
                        offset += slice
                        y += slice
                        if offset < size.height - 0.5 { newPage() }
                    }
                    y += blockGap
                }
            }
        }
    }

    // MARK: Material sections as blocks
    /// One block per material line; the section title travels with its first line.
    static func sectionBlocks(_ title: String, _ items: [MaterialItem], topPadding: CGFloat = 10) -> [AnyView] {
        guard let first = items.first else { return [] }
        var out: [AnyView] = [AnyView(
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline).padding(.top, topPadding)
                row(first)
            }
        )]
        for it in items.dropFirst() { out.append(AnyView(row(it))) }
        return out
    }

    @ViewBuilder static func row(_ it: MaterialItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(it.name).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text("\(displayNumber(it.qty)) \(displayUnit(it))").font(.footnote).foregroundStyle(.secondary)
            }
            if let notes = it.notes, !notes.isEmpty {
                Text(notes).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 3)
    }
}
