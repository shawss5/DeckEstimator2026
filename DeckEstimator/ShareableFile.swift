import UIKit
import LinkPresentation

/// Wraps a file URL for the iOS share sheet while supplying our own link
/// metadata up front. Without this, `UIActivityViewController` tries to
/// generate its own preview/thumbnail for the file (via QuickLook) before it
/// can show anything — for a freshly-written PDF this can take a very long
/// time to resolve, and reliably hangs the Simulator indefinitely (the app
/// eventually gets killed by the watchdog). Supplying metadata ourselves
/// skips that step, so the share sheet appears immediately.
final class ShareableFile: NSObject, UIActivityItemSource {
    let url: URL
    let title: String

    init(url: URL, title: String? = nil) {
        self.url = url
        self.title = title ?? url.lastPathComponent
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        url
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        url
    }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        title
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.originalURL = url
        metadata.url = url
        metadata.title = title
        return metadata
    }
}

/// What the share sheet should share. Presenting the sheet *with* this value
/// (`.sheet(item:)`) guarantees the files are there on the very first open —
/// setting an array and a Bool separately could open an empty sheet once.
struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}
