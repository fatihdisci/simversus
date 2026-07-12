import SwiftUI

struct RemoveAdsSheet: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var isWorking = false
    @State private var messageKey: String?

    var body: some View {
        NavigationStack {
            ZStack {
                ArenaBackground(showsRings: false)
                VStack(spacing: Spacing.m) {
                    // "No ads" composition: a muted megaphone crossed out by the
                    // accent no-sign — the bare no-sign alone reads as a generic
                    // "forbidden", not as "ad-free".
                    ZStack {
                        Image(systemName: "megaphone.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Palette.textSecondary)
                        Image(systemName: "nosign")
                            .font(.system(size: 52, weight: .semibold))
                            .foregroundStyle(Palette.accent)
                    }
                    .accessibilityHidden(true)

                    VStack(spacing: Spacing.s) {
                        Text("iap.removeAds.title")
                            .font(.screenTitle)
                            .foregroundStyle(Palette.textPrimary)
                        Text("iap.removeAds.description")
                            .font(.body)
                            .foregroundStyle(Palette.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    if let messageKey {
                        Text(LocalizedStringKey(messageKey))
                            .font(.caption)
                            .foregroundStyle(Palette.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: Spacing.s) {
                        if case .failed = purchaseManager.productState {
                            Text("iap.loadFailed")
                                .font(.caption)
                                .foregroundStyle(Palette.textSecondary)
                            ArenaCTAButton(title: "iap.retry",
                                           systemImage: "arrow.clockwise",
                                           kind: .secondary) {
                                Task { await purchaseManager.refreshProducts() }
                            }
                        } else {
                            Button(action: purchase) {
                                HStack(spacing: Spacing.s) {
                                    Text(verbatim: purchaseTitle)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.82)
                                    Spacer(minLength: Spacing.s)
                                    Image(systemName: "checkmark.shield.fill")
                                        .font(.system(size: Layout.ctaAccessoryIcon, weight: .bold))
                                        .frame(width: Layout.ctaAccessory, height: Layout.ctaAccessory)
                                        .background(Palette.bgDeep.opacity(0.15), in: Circle())
                                }
                            }
                            .buttonStyle(ArenaButtonStyle(kind: .primary))
                            .disabled(purchaseManager.product == nil || isWorking)
                        }

                        Button("iap.restore", action: restore)
                            .font(.sectionLabel)
                            .foregroundStyle(Palette.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: Layout.minTouchTarget)
                            .buttonStyle(.plain)
                            .disabled(isWorking)
                    }
                }
                .padding(Spacing.l)
            }
            .task {
                // A fetch that failed before the sheet opened (offline, product
                // not yet approved) gets one automatic retry on appearance.
                if case .failed = purchaseManager.productState {
                    await purchaseManager.refreshProducts()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ArenaIconButton(systemName: "xmark", accessibilityKey: "common.cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(430)])
        .presentationDragIndicator(.visible)
    }

    private var purchaseTitle: String {
        switch purchaseManager.productState {
        case .loaded(let product):
            return String(format: String(localized: "iap.removeAds.buy %@"), product.displayPrice)
        case .failed:
            return String(localized: "iap.loadFailed")
        case .loading:
            return String(localized: "iap.loading")
        }
    }

    private func purchase() {
        guard !isWorking else { return }
        isWorking = true
        Task {
            let succeeded = await purchaseManager.purchase()
            isWorking = false
            // Success dismisses immediately — a message would never be seen.
            if succeeded { dismiss() } else { messageKey = "iap.error.generic" }
        }
    }

    private func restore() {
        guard !isWorking else { return }
        isWorking = true
        Task {
            let restored = await purchaseManager.restore()
            isWorking = false
            if restored { dismiss() } else { messageKey = "iap.restore.empty" }
        }
    }
}
