import Foundation
import UIKit

// MARK: - AppSettings
// Persistent "My Company" info (your own contact details + logo) that gets
// auto-filled into every new estimate's Project/Client section, so you don't
// have to retype it every time. Per-job fields (project name, customer,
// jobsite address, notes) are NOT stored here — only what's yours and stays
// the same from job to job.
enum AppSettings {
    private static let contactKey = "com.stephanieshaw.DeckEstimator.companyContactInfo"
    private static let logoFilename = "company_logo.png"

    static var contactInfo: String {
        get { UserDefaults.standard.string(forKey: contactKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: contactKey) }
    }

    private static var logoURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(logoFilename)
    }

    /// Logos never need to be bigger than this on a PDF header. Keeping them
    /// small stops full-size phone photos from slowing down every screen
    /// that shows the logo (and keeps exported PDFs small).
    static let maxLogoDimension: CGFloat = 600

    // In-memory cache so screens don't re-read and re-decode the file.
    private static var cachedLogo: UIImage?
    private static var didLoadLogo = false

    static func loadLogo() -> UIImage? {
        if didLoadLogo { return cachedLogo }
        didLoadLogo = true
        guard let data = try? Data(contentsOf: logoURL),
              let image = UIImage(data: data) else {
            cachedLogo = nil
            return nil
        }
        // Logos saved by older versions may be full-size photos: shrink once and re-save.
        if max(image.size.width, image.size.height) * image.scale > maxLogoDimension {
            let small = downscaled(image)
            saveLogo(small)
            return small
        }
        cachedLogo = image
        return image
    }

    static func saveLogo(_ image: UIImage?) {
        didLoadLogo = true
        guard let image else {
            cachedLogo = nil
            try? FileManager.default.removeItem(at: logoURL)
            return
        }
        let small = downscaled(image)
        cachedLogo = small
        if let data = small.pngData() { try? data.write(to: logoURL) }
    }

    /// Returns the image scaled so its longest side is at most `maxLogoDimension` pixels.
    static func downscaled(_ image: UIImage) -> UIImage {
        let pxW = image.size.width * image.scale
        let pxH = image.size.height * image.scale
        let longest = max(pxW, pxH)
        guard longest > maxLogoDimension else { return image }
        let ratio = maxLogoDimension / longest
        let target = CGSize(width: (pxW * ratio).rounded(), height: (pxH * ratio).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    static var hasSavedInfo: Bool {
        !contactInfo.isEmpty || loadLogo() != nil
    }
}
