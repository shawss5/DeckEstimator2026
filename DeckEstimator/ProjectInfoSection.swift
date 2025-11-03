import SwiftUI
import PhotosUI
import UIKit

// MARK: - Shared project/client details
// Used by every calculator's form + results/PDF (Deck, Stairs, Covered Deck).
struct ProjectDetails {
    var projectName: String = ""
    var customerName: String = ""
    var jobsiteAddress: String = ""
    var contactInfo: String = ""
    var notes: String = ""

    /// Puts dashes in any 10-digit US phone number as soon as it's complete:
    /// "6784523424", "678 452 3424", "(678) 452-3424", "678.452.3424" → "678-452-3424".
    /// Digits inside a word or email (e.g. "jl6784523424@gmail.com") are left alone.
    static func formattingPhoneNumbers(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: "(?<![\\w-])\\(?(\\d{3})\\)?[\\s.\\-]?(\\d{3})[\\s.\\-]?(\\d{4})(?![\\w])") else { return text }
        return regex.stringByReplacingMatches(
            in: text, range: NSRange(location: 0, length: (text as NSString).length),
            withTemplate: "$1-$2-$3")
    }

    /// Uppercases a 2-letter state right after a comma, or right before a ZIP:
    /// "Atlanta, ga 30030" → "Atlanta, GA 30030"; "Columbus, Ga" → "Columbus, GA".
    /// Only touches 2-letter words that follow a comma and end at a comma, a
    /// space before a ZIP, or the end — street names and other words are left alone.
    static func uppercasingStateAbbreviation(_ address: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: "(,\\s*)([A-Za-z]{2})(?=\\s*(,|\\d|$))") else { return address }
        let ns = address as NSString
        var result = address
        for m in regex.matches(in: address, range: NSRange(location: 0, length: ns.length)).reversed() {
            let r = m.range(at: 2)
            let upper = ns.substring(with: r).uppercased()
            result = (result as NSString).replacingCharacters(in: r, with: upper)
        }
        // Also a 2-letter state right before a ZIP with no comma: "Atlanta Ga 38283".
        // Street abbreviations (St, Rd, Dr, Ln, Pl) are never state codes, so skip them.
        if let zipRegex = try? NSRegularExpression(
            pattern: "\\b([A-Za-z]{2})(?=,?\\s+\\d{5}(-\\d{4})?\\s*$)") {
            let ns2 = result as NSString
            let streetWords: Set<String> = ["st", "rd", "dr", "ln", "pl"]
            for m in zipRegex.matches(in: result, range: NSRange(location: 0, length: ns2.length)).reversed() {
                let r = m.range(at: 1)
                let word = ns2.substring(with: r)
                if streetWords.contains(word.lowercased()) { continue }
                result = (result as NSString).replacingCharacters(in: r, with: word.uppercased())
            }
        }
        return result
    }
}

// MARK: - Reusable "Project / Client" form section with optional logo picker
struct ProjectInfoSection: View {
    @Binding var details: ProjectDetails
    @Binding var logoImage: UIImage?

    @State private var logoItem: PhotosPickerItem? = nil
    @State private var showLogoConsent: Bool = false
    @State private var showLogoPicker: Bool = false
    @FocusState private var jobsiteFocused: Bool

    var body: some View {
        Section("Project / Client") {
            HStack { Text("Project name"); Spacer(); TextField("e.g., Shaw Lake Deck", text: $details.projectName).multilineTextAlignment(.trailing).textInputAutocapitalization(.words) }
            HStack { Text("Customer"); Spacer(); TextField("Name / Company", text: $details.customerName).multilineTextAlignment(.trailing).textInputAutocapitalization(.words) }
            HStack {
                Text("Jobsite address")
                Spacer()
                TextField("Street, City, ST", text: $details.jobsiteAddress)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.words)
                    .focused($jobsiteFocused)
                    .onChange(of: jobsiteFocused) { _, focused in
                        // Tidy the state abbreviation when the user leaves the field.
                        if !focused {
                            details.jobsiteAddress = ProjectDetails.uppercasingStateAbbreviation(details.jobsiteAddress)
                        }
                    }
            }
            HStack { Text("Customer contact"); Spacer(); TextField("Phone / Email", text: $details.contactInfo)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: details.contactInfo) { _, new in
                        let formatted = ProjectDetails.formattingPhoneNumbers(new)
                        if formatted != new { details.contactInfo = formatted }
                    }
            }
            VStack(alignment: .leading) {
                Text("Notes")
                TextEditor(text: $details.notes)
                    .frame(minHeight: 80)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
            }
            Button {
                showLogoConsent = true
            } label: {
                HStack { Image(systemName: "photo.on.rectangle"); Text("Select logo (optional)"); Spacer() }
            }
            .alert("Add a logo?", isPresented: $showLogoConsent) {
                Button("Not Now", role: .cancel) {}
                Button("Continue") { showLogoPicker = true }
            } message: {
                Text("We only open the system photo picker so you can choose a logo image to include in your PDF. No photos are uploaded or scanned.")
            }
            .photosPicker(isPresented: $showLogoPicker, selection: $logoItem, matching: .images)
            .onChange(of: logoItem) { _, newItem in
                guard let item = newItem else { return }
                Task { @MainActor in
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let ui = UIImage(data: data) {
                        // Per-job logo: shrink it too (not saved to Settings).
                        logoImage = AppSettings.downscaled(ui)
                    }
                }
            }
            if let img = logoImage {
                HStack { Spacer(); Image(uiImage: img).resizable().scaledToFit().frame(maxWidth: 140, maxHeight: 60); Spacer() }
            }
        }
        .onAppear {
            // Auto-fill the logo from "My Company" settings. Your company contact
            // info is NOT copied into this form — "Customer contact" is the
            // customer's; your info prints on the PDF letterhead from Settings.
            if logoImage == nil {
                logoImage = AppSettings.loadLogo()
            }
        }
    }
}
