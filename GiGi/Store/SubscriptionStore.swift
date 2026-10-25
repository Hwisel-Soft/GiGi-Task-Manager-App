import StoreKit
import Foundation
import Observation

@Observable
final class SubscriptionStore {

    static let monthlyId = "com.johnnassar.GiGi.pro.monthly"
    static let annualId  = "com.johnnassar.GiGi.pro.annual"

    var isPro: Bool = false
    var monthly: Product?
    var annual: Product?
    var isLoading: Bool = false
    var errorMessage: String?
    var showPaywall: Bool = false

    private var transactionListener: Task<Void, Never>?

    init() {
        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
            await refreshStatus()
        }
    }

    deinit { transactionListener?.cancel() }

    @MainActor
    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.monthlyId, Self.annualId])
            monthly = products.first { $0.id == Self.monthlyId }
            annual  = products.first { $0.id == Self.annualId }
        } catch {
            // Products unavailable in sandbox or simulator without StoreKit config
        }
    }

    @MainActor
    func refreshStatus() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }
            if (tx.productID == Self.monthlyId || tx.productID == Self.annualId),
               tx.revocationDate == nil {
                active = true
            }
        }
        isPro = active
    }

    @MainActor
    func purchase(_ product: Product) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let tx) = verification else { return }
                await tx.finish()
                await refreshStatus()
                if isPro { showPaywall = false }
            case .userCancelled: break
            case .pending: break
            @unknown default: break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func restore() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        await refreshStatus()
        if isPro { showPaywall = false }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let tx) = result else { continue }
                await tx.finish()
                await self?.refreshStatus()
            }
        }
    }
}
