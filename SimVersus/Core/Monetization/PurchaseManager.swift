import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    static let removeAdsProductID = "com.simversus.removeads"
    private static let adFreeKey = "isAdFree"

    /// Lifecycle of the StoreKit product fetch, so UI can distinguish
    /// "still loading" from "failed — offer a retry" instead of showing an
    /// eternal loading label.
    enum ProductState: Equatable {
        case loading
        case loaded(Product)
        case failed
    }

    @Published private(set) var productState: ProductState = .loading
    @Published private(set) var isAdFree: Bool

    var product: Product? {
        if case .loaded(let product) = productState { return product }
        return nil
    }

    private var transactionUpdates: Task<Void, Never>?

    private init() {
        isAdFree = UserDefaults.standard.bool(forKey: Self.adFreeKey)
        transactionUpdates = observeTransactions()
        Task {
            await refreshProducts()
            await refreshEntitlements()
        }
    }

    deinit { transactionUpdates?.cancel() }

    func refreshProducts() async {
        if case .loaded = productState { return }
        productState = .loading
        do {
            if let product = try await Product.products(for: [Self.removeAdsProductID]).first {
                productState = .loaded(product)
            } else {
                // The query succeeded but the product ID isn't configured.
                productState = .failed
            }
        } catch {
            productState = .failed
        }
    }

    func purchase() async -> Bool {
        guard let product else { return false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return false }
                await unlock(transaction)
                return true
            case .pending, .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    func restore() async -> Bool {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            return isAdFree
        } catch {
            return false
        }
    }

    func refreshEntitlements() async {
        var ownsRemoveAds = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.removeAdsProductID {
                ownsRemoveAds = true
            }
        }
        setAdFree(ownsRemoveAds)
    }

    private func observeTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self, case .verified(let transaction) = result else { continue }
                await self.unlock(transaction)
            }
        }
    }

    private func unlock(_ transaction: Transaction) async {
        if transaction.productID == Self.removeAdsProductID { setAdFree(true) }
        await transaction.finish()
    }

    private func setAdFree(_ value: Bool) {
        isAdFree = value
        UserDefaults.standard.set(value, forKey: Self.adFreeKey)
    }
}
