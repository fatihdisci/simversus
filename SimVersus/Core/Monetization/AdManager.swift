import GoogleMobileAds

@MainActor
final class AdManager: NSObject, ObservableObject, FullScreenContentDelegate {
    static let shared = AdManager()

    private static let interstitialUnitID = "ca-app-pub-3940256099942544/4411468910" // TODO: PROD
    private static let rewardedUnitID = "ca-app-pub-3940256099942544/1712485313" // TODO: PROD
    private var interstitial: InterstitialAd?
    private var rewarded: RewardedAd?
    private var isLoading = false
    private var isLoadingRewarded = false
    @Published private(set) var isRewardedReady = false

    private override init() {}

    func preload() async {
        guard ConsentManager.shared.canRequestAds, !PurchaseManager.shared.isAdFree,
              interstitial == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let ad = try await InterstitialAd.load(with: Self.interstitialUnitID,
                                                    request: .nonPersonalized())
            ad.fullScreenContentDelegate = self
            interstitial = ad
        } catch {
            // Ads must never block the result flow.
        }
    }

    func matchCompleted(matchesPlayed: Int) {
        guard matchesPlayed > 0, matchesPlayed.isMultiple(of: 3),
              !PurchaseManager.shared.isAdFree else { return }
        guard let interstitial else {
            Task { await preload() }
            return
        }

        self.interstitial = nil
        interstitial.present(from: nil)
    }

    func preloadRewarded() async {
        guard ConsentManager.shared.canRequestAds, rewarded == nil, !isLoadingRewarded else { return }
        isLoadingRewarded = true
        defer { isLoadingRewarded = false }
        do {
            let ad = try await RewardedAd.load(with: Self.rewardedUnitID, request: .nonPersonalized())
            ad.fullScreenContentDelegate = self
            rewarded = ad
            isRewardedReady = true
        } catch { isRewardedReady = false }
    }

    func showRewarded(onReward: @escaping () -> Void) {
        guard let rewarded else { Task { await preloadRewarded() }; return }
        self.rewarded = nil
        isRewardedReady = false
        rewarded.present(from: nil, userDidEarnRewardHandler: onReward)
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { await preload() }
        Task { await preloadRewarded() }
    }

    func ad(_ ad: FullScreenPresentingAd,
            didFailToPresentFullScreenContentWithError error: Error) {
        Task { await preload() }
        Task { await preloadRewarded() }
    }
}
