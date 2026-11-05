import SwiftUI
import PhotosUI

// MARK: - SettingsView ("My Company")
// One place to save your own business contact info and logo so every new
// estimate auto-fills them instead of you retyping/reselecting each time.
struct SettingsView: View {
    @State private var contactInfo: String = AppSettings.contactInfo
    @State private var logoImage: UIImage? = nil

    @State private var logoItem: PhotosPickerItem? = nil
    @State private var showLogoConsent: Bool = false
    @State private var showLogoPicker: Bool = false

    @State private var showSavedConfirmation: Bool = false
    @State private var showIntro: Bool = false
    @EnvironmentObject private var purchases: PurchaseManager

    // Explicit save action — the only thing that writes contactInfo to
    // AppSettings. No silent auto-save: the user taps Save and sees
    // confirmation that it happened.
    private func saveContactInfo() {
        AppSettings.contactInfo = contactInfo
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation {
            showSavedConfirmation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation {
                showSavedConfirmation = false
            }
        }
    }

    private var hasUnsavedChanges: Bool {
        contactInfo != AppSettings.contactInfo
    }

    var body: some View {
        Form {
            Section {
                Text("Saved here once, used everywhere: your contact info and logo print at the top of every PDF estimate. The customer's name, jobsite and contact still get entered per job.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                // The text box gets a row to itself: sharing a row with other
                // views makes iOS re-lay-out the whole row on every keystroke.
                TextEditor(text: $contactInfo)
                    .frame(minHeight: 100)
                    .autocorrectionDisabled()
                    .onChange(of: contactInfo) { _, new in
                        let formatted = ProjectDetails.formattingPhoneNumbers(new)
                        if formatted != new { contactInfo = formatted }
                    }

                Button {
                        saveContactInfo()
                    } label: {
                        HStack {
                            Spacer()
                            if showSavedConfirmation {
                                Label("Saved", systemImage: "checkmark.circle.fill")
                            } else {
                                Text("Save Contact Info")
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                .buttonStyle(.borderedProminent)
                .tint(showSavedConfirmation ? .green : .accentColor)
            } header: {
                Text("Your Contact Info")
            } footer: {
                Text("Shown on every PDF (e.g. business name, phone, email)")
            }

            Section("Your Logo") {
                Button {
                    showLogoConsent = true
                } label: {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text(logoImage == nil ? "Select logo" : "Change logo")
                        Spacer()
                    }
                }
                .alert("Add a logo?", isPresented: $showLogoConsent) {
                    Button("Not Now", role: .cancel) {}
                    Button("Continue") { showLogoPicker = true }
                } message: {
                    Text("We only open the system photo picker so you can choose a logo image to include on every PDF. No photos are uploaded or scanned.")
                }
                .photosPicker(isPresented: $showLogoPicker, selection: $logoItem, matching: .images)
                .onChange(of: logoItem) { _, newItem in
                    guard let item = newItem else { return }
                    Task { @MainActor in
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let ui = UIImage(data: data) {
                            AppSettings.saveLogo(ui)          // shrinks + saves
                            logoImage = AppSettings.loadLogo() // use the small copy
                        }
                    }
                }

                if let img = logoImage {
                    HStack {
                        Spacer()
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 160, maxHeight: 70)
                        Spacer()
                    }
                    Button(role: .destructive) {
                        logoImage = nil
                        AppSettings.saveLogo(nil)
                    } label: {
                        Text("Remove logo")
                    }
                }
            }

            Section {
                Button {
                    showIntro = true
                } label: {
                    Label("How it works", systemImage: "questionmark.circle")
                }
                Link(destination: URL(string: "https://shawcreativeworks.com/terms/deck-estimator.html")!) {
                    Label("Terms of Use", systemImage: "doc.text")
                }
            } header: {
                Text("Help")
            } footer: {
                Text("Deck Estimator gives material estimates for planning and bidding. It is not an engineered design. Always verify sizes, spans, footings and railing rules with your local building department.")
            }
        }
        .navigationTitle("My Company")
        .sheet(isPresented: $showIntro) {
            IntroTourView(
                onSetUpCompany: { showIntro = false },   // already on My Company
                onFinish: { _ in showIntro = false }
            )
            .environmentObject(purchases)
        }
        .onAppear {
            if logoImage == nil { logoImage = AppSettings.loadLogo() }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    saveContactInfo()
                } label: {
                    Text("Save")
                        .fontWeight(hasUnsavedChanges ? .semibold : .regular)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environmentObject(PurchaseManager())
}
