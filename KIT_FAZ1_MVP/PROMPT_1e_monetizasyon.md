# PARÇA 1e — Monetizasyon: Interstitial + Reklamsız IAP + Consent

**Önce oku:** CONSTITUTION.md (§4.3 kritik), I18N_RULES.md
**Bağımlılık:** 1d tamamlanmış olmalı.

## Amaç
3 maçta 1 interstitial (Result kapanışında), tek seferlik "Reklamsız" IAP, UMP consent akışı. Non-personalized reklam (ATT YOK).

## Kapsam
1. SPM ile GoogleMobileAds ekle (tek üçüncü parti bağımlılık). Info.plist: `GADApplicationIdentifier` = TEST app ID placeholder (`ca-app-pub-3940256099942544~1458002511`) + `// TODO: PROD` yorumu.
2. `Core/Monetization/ConsentManager.swift`: UMP — ilk açılışta consent info update + gerekiyorsa form. Consent alınamazsa/reddedilirse non-personalized devam. `GADRequest` extension'ı ile `npa=1` extras.
3. `Core/Monetization/AdManager.swift`:
   - Interstitial preload (test unit ID `ca-app-pub-3940256099942544/4411468910`, `// TODO: PROD`)
   - `AdGate.onResultDismiss()` implementasyonu: `matchesPlayedCount % 3 == 0` VE `!PurchaseManager.shared.isAdFree` ise göster; gösterim sonrası yeni interstitial preload
   - Reklam yüklenememişse akış BLOKLANMAZ (sessiz geç)
4. `Core/Monetization/PurchaseManager.swift` (StoreKit 2):
   - Ürün: `com.simversus.removeads` (non-consumable)
   - `purchase()`, `restore()`, `Transaction.updates` dinleyici, `isAdFree` published state (UserDefaults cache + her açılışta current entitlements doğrulaması)
5. UI bağlantıları:
   - HomeView `home.removeAds` → satın alma sheet'i: fiyat (`Product.displayPrice`), satın al butonu, `iap.restore` linki, başarıda `iap.removeAds.success`, hatada `iap.error.generic`
   - `isAdFree == true` ise `home.removeAds` butonu gizlenir
6. `.storekit` configuration dosyası ekle (local test için) + StoreKit test senaryosu notu.

## Kabul kriterleri
- [ ] 1-2. maç sonrası reklam yok, 3. maç sonrası test interstitial geliyor, 6.'da tekrar
- [ ] StoreKit test ortamında satın alma → interstitial kalıcı olarak kapanıyor (app restart dahil)
- [ ] Restore çalışıyor
- [ ] Reklam yüklenemediğinde akış donmuyor
- [ ] ATT prompt'u YOK; istekler npa=1
- [ ] Tüm IAP/consent stringleri katalogda TR+EN

## DO NOT TOUCH / YAPMA
- ATT (AppTrackingTransparency) EKLEME
- Rewarded ad ekleme (Faz 2b)
- Ürün ID veya sayaç eşiğini (3) değiştirme
- Mediation/başka network ekleme
