import SwiftUI

@main
struct DeckEstimatorApp: App {
    @StateObject private var purchases = PurchaseManager()

    var body: some Scene {
        WindowGroup {
            HomeView()   // ✅ Launch the real HomeView
                .environmentObject(purchases)
        }
    }
}
