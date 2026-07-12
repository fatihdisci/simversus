import GoogleMobileAds
import UserMessagingPlatform

@MainActor
final class ConsentManager: ObservableObject {
    static let shared = ConsentManager()

    @Published private(set) var canRequestAds = false
    private var didStartMobileAds = false

    private init() {}

    func requestConsent() async {
        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters())
            if ConsentInformation.shared.canRequestAds { startMobileAdsIfNeeded() }
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            // A previous consent decision may still permit non-personalized ads.
        }

        canRequestAds = ConsentInformation.shared.canRequestAds
        if canRequestAds { startMobileAdsIfNeeded() }
    }

    private func startMobileAdsIfNeeded() {
        guard !didStartMobileAds else { return }
        didStartMobileAds = true
        MobileAds.shared.start()
    }
}

extension Request {
    /// Keeps every request non-personalized; this app intentionally has no ATT flow.
    static func nonPersonalized() -> Request {
        let request = Request()
        let extras = Extras()
        extras.additionalParameters = ["npa": "1"]
        request.register(extras)
        return request
    }
}
