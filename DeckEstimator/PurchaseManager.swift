import Foundation
import StoreKit
import Combine

// MARK: - PurchaseManager
// Handles the single "Pro" non-consumable unlock via StoreKit 2. Free tier:
// Rectangular Deck calculator + Copy Summary. Pro unlocks Stairs, Covered
// Deck, Full Project, and PDF export (Save/Print) everywhere.
@MainActor
final class PurchaseManager: ObservableObject {
    static let proProductID = "com.stephanieshaw.DeckEstimator.prounlock"

    @Published private(set) var isPro: Bool = false
    @Published private(set) var product: Product?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = listenForTransactions()
        Task {
            await loadProduct()
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    /// Safe to call again. The paywall retries on appear, because a single
    /// failed load at launch used to leave Pro unbuyable for the whole life
    /// of the app.
    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.proProductID])
            product = products.first
            if product != nil { errorMessage = nil }
        } catch {
            errorMessage = "Couldn't load Pro pricing. Check your connection and try again."
        }
    }

    func refreshEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == Self.proProductID {
                unlocked = true
            }
        }
        isPro = unlocked
    }

    func purchase() async {
        guard let product else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshEntitlements()
                case .unverified:
                    // The customer has been charged, but the receipt did not
                    // pass App Store verification. Deliberately NOT finished:
                    // leaving it open lets StoreKit retry and keeps the
                    // purchase recoverable through Restore. Saying nothing
                    // here was taking money and delivering nothing.
                    errorMessage = "We could not verify that purchase. If you were charged, tap Restore Purchases, or email support and we will sort it out."
                }
            case .userCancelled:
                break
            case .pending:
                errorMessage = "Your purchase is waiting for approval."
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase failed. Please try again."
        }
    }

    func restore() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await AppStore.sync()
        } catch {
            // Not the same thing as having no purchase to restore; telling
            // someone who paid that nothing was found is the worse error.
            errorMessage = "Could not reach the App Store to restore. Check your connection and try again."
            return
        }
        await refreshEntitlements()
        if !isPro {
            errorMessage = "No previous purchase found for this Apple ID."
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refreshEntitlements()
                }
            }
        }
    }
}
