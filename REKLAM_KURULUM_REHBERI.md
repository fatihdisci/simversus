# Reklam Kurulum Rehberi — Goal Arena

Bu rehber, Goal Arena uygulamasındaki reklam altyapısının **Google AdMob** tarafında nasıl aktif edileceğini adım adım anlatır.

> **Not:** Kod tarafındaki tüm reklam mantığı (`AdManager`, `ConsentManager`, `PurchaseManager`, `AdGate`) hazır durumdadır ve şu an **Google'ın test ID'leri** ile çalışmaktadır. Bu rehberdeki adımları tamamladıktan sonra sadece birkaç satır ID değişikliği yapmanız yeterli olacak.

---

## Mevcut Altyapı Özeti

| Özellik | Durum | Açıklama |
|---|---|---|
| **Interstitial (Geçiş) Reklamı** | ✅ Kod hazır | Her 3 maçta bir, sonuç ekranından çıkarken gösterilir |
| **Rewarded (Ödüllü) Reklam** | ✅ Kod hazır | Kullanıcı isteğe bağlı izler, ekstra takım slotu açar |
| **GDPR Onay Yönetimi** | ✅ Kod hazır | UMP SDK ile Avrupa kullanıcıları için onay formu |
| **Reklam Kaldırma (IAP)** | ✅ Kod hazır | StoreKit ile tek seferlik satın alma (`$1.99`) |
| **Non-Personalized Ads** | ✅ Kod hazır | ATT olmadan, kişiselleştirilmemiş reklamlar |

---

## Adım 1: AdMob Hesabı Açma

1. [admob.google.com](https://admob.google.com) adresine git
2. Google hesabınla giriş yap
3. Hesap oluşturma adımlarını tamamla (ödeme bilgileri, vergi formu vb.)

---

## Adım 2: Uygulamayı AdMob'a Kaydetme

1. AdMob panelinde **Apps** → **Add App** butonuna tıkla
2. Platform olarak **iOS** seç
3. **"App not published on the App Store"** seçeneğini işaretle
4. Uygulama adı: **Goal Arena**
5. Bundle ID: **`com.simversus.app`** (`project.yml:55`)
6. Kaydı tamamla

Kayıt tamamlandıktan sonra sana bir **App ID** verilecek. Bu ID şu formatta olur:
```
ca-app-pub-XXXXXXXXXX~NNNNNNNNNN
```

---

## Adım 3: Reklam Birimleri (Ad Units) Oluşturma

İki adet reklam birimi oluşturman gerekiyor:

### 3a. Interstitial Ad Unit

1. Kaydettiğin uygulamanın içinde **Ad Units** → **Add Ad Unit**
2. Format: **Interstitial** seç
3. Adı: `Interstitial` (veya istediğin bir isim)
4. Oluşturulduktan sonra sana **Interstitial Ad Unit ID** verilecek:
   ```
   ca-app-pub-XXXXXXXXXX/NNNNNNNNNN
   ca-app-pub-4346469553817108~4664586583
   ```

### 3b. Rewarded Ad Unit

1. **Ad Units** → **Add Ad Unit**
2. Format: **Rewarded** seç
3. Adı: `Rewarded` (veya istediğin bir isim)
4. Oluşturulduktan sonra sana **Rewarded Ad Unit ID** verilecek:
   ```
   ca-app-pub-XXXXXXXXXX/NNNNNNNNNN
   ca-app-pub-4346469553817108~4664586583
   ```

> Her iki ID'nin ortasındaki X'li kısım (Publisher ID) **aynı** olacak, sonundaki rakamlar farklı.

---

## Adım 4: GDPR Onay Mesajı Oluşturma (Zorunlu)

Avrupa kullanıcıları için GDPR uyumluluğu şarttır. Kodda UMP (User Messaging Platform) entegre ve uygulama açılışında otomatik çalışıyor, ancak mesajın AdMob panelinde oluşturulmuş olması gerekir.

1. AdMob panelinde **Privacy & Messaging** sekmesine git
2. **GDPR** kartına tıkla
3. **Create Message** butonuna tıkla
4. Mesaj tipini yapılandır:
   - **"I want to use the default consent message"** → varsayılan şablonu kullanabilirsin
   - Uygulamayı seç
   - Diller: İngilizce ve Türkçe ekle
5. **Publish** et

Bu mesaj yayınlandıktan sonra, Avrupa kullanıcıları uygulamayı ilk açtıklarında otomatik olarak onay formunu görecekler.

---

## Adım 5: Kod Tarafında ID'leri Değiştirme

Şu an tüm ID'ler **test** değerlerinde. Üç yerde değişiklik yapman gerekiyor.

### 5a. Info.plist — App ID

**Dosya:** `SimVersus/Info.plist` (satır 24-25)

```xml
<!-- Şu anki (test): -->
<key>GADApplicationIdentifier</key>
<string>ca-appub-3940256099942544~1458002511</string>

<!-- Değiştir: -->
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXXXX~NNNNNNNNNN</string>
```

### 5b. AdManager.swift — Unit ID'ler

**Dosya:** `SimVersus/Core/Monetization/AdManager.swift` (satır 7-8)

```swift
// Şu anki (test):
private static let interstitialUnitID = "ca-app-pub-3940256099942544/4411468910" // TODO: PROD
private static let rewardedUnitID    = "ca-app-pub-3940256099942544/1712485313" // TODO: PROD

// Değiştir:
private static let interstitialUnitID = "ca-app-pub-XXXXXXXXXX/NNNNNNNNNN" // PROD
private static let rewardedUnitID    = "ca-app-pub-XXXXXXXXXX/NNNNNNNNNN" // PROD
```

---

## Adım 6: SKAdNetwork ID'lerini Ekleme

Apple, reklam gösteren tüm uygulamaların `Info.plist` dosyasında reklam ağlarının SKAdNetwork kimliklerini içermesini zorunlu tutar. Bu olmadan **App Store incelemesinden geçemezsin**.

**Dosya:** `SimVersus/Info.plist`

Aşağıdaki bloğu `Info.plist` içindeki `<dict>` etiketinin içine (herhangi bir yere) ekle:

```xml
<key>SKAdNetworkItems</key>
<array>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>cstr6suwn9.skadnetwork</string>
    </dict>
</array>
```

> ⚠️ Bu liste Google'ın **güncel** SKAdNetwork ID'lerini içermelidir. Yayınlamadan önce [Google'ın resmi listesini](https://developers.google.com/admob/ios/3p-skadnetworks) kontrol et ve eksik ID varsa ekle.

---

## Adım 7: App Store Connect — IAP Ürününü Tanımlama

Reklam kaldırma satın alması (`com.simversus.removeads`) StoreKit ile entegre. Uygulama canlıya çıkmadan önce bu ürünün App Store Connect'te tanımlanmış olması gerekir.

1. [App Store Connect](https://appstoreconnect.apple.com) → Uygulamanı seç
2. **In-App Purchases** → **+ (Add)**
3. Tür: **Non-Consumable**
4. Reference Name: `Remove Ads`
5. Product ID: **`com.simversus.removeads`**
6. Fiyat: Tier seç (örneğin `$1.99`)
7. Display Name ve Description doldur (EN ve TR)
8. **Save**

> ℹ️ Geliştirme sırasında StoreKit sandbox ortamında test edebilmek için `SimVersus.storekit` dosyasındaki yapılandırma yeterlidir.

---

## Adım 8: Uygulama İçi Fiyat Güncellemesi (Opsiyonel)

Eğer IAP fiyatını değiştirmek istersen, `SimVersus/Resources/SimVersus.storekit` dosyasındaki `removeads` ürününün fiyatını da güncelle. Bu dosya sadece yerel geliştirme/test içindir — canlı fiyat App Store Connect'ten yönetilir.

---

## Adım 9: ATT Açıklaması Ekleme (Opsiyonel ama Önerilir)

Şu an uygulama **kişiselleştirilmemiş** reklamlar gösteriyor ve ATT (App Tracking Transparency) akışı yok. Bu bilinçli bir tercih. Ancak Apple'ın inceleme sürecinde sorun yaşamamak için `Info.plist`'e ATT kullanım açıklaması eklemeyi düşün:

```xml
<key>NSUserTrackingUsageDescription</key>
<string>Reklamları kişiselleştirmek için verileriniz kullanılabilir. Bu ayarı daha sonra Ayarlar > Gizlilik kısmından değiştirebilirsiniz.</string>
```

> ℹ️ Bu açıklamayı eklesen bile, **ATT prompt'unu göstermek için ayrıca kod yazman gerekir** — sadece bu satırı eklemek prompt'u göstermez, sadece Apple'ın zorunlu metadata kontrolünden geçmeni sağlar.

---

## Kontrol Listesi

Yayınlamadan önce her şeyin tamam olduğundan emin ol:

- [ ] AdMob hesabı açıldı
- [ ] Uygulama AdMob'a kaydedildi
- [ ] Interstitial ad unit oluşturuldu, ID alındı
- [ ] Rewarded ad unit oluşturuldu, ID alındı
- [ ] GDPR onay mesajı oluşturuldu ve yayınlandı
- [ ] `Info.plist` → Production App ID girildi
- [ ] `AdManager.swift` → Production interstitial unit ID girildi
- [ ] `AdManager.swift` → Production rewarded unit ID girildi
- [ ] `Info.plist` → SKAdNetwork ID'leri eklendi
- [ ] App Store Connect → IAP ürünü (`com.simversus.removeads`) tanımlandı
- [ ] Test: Reklamlar uygulama içinde gösteriliyor mu?
- [ ] Test: IAP satın alma çalışıyor mu?
- [ ] Test: GDPR formu AB IP'sinden test edildi mi?

---

## İlgili Dosyalar

| Dosya | İçerik |
|---|---|
| `SimVersus/Info.plist` | AdMob App ID, SKAdNetwork ID'leri |
| `SimVersus/Core/Monetization/AdManager.swift` | Reklam yükleme ve gösterme mantığı |
| `SimVersus/Core/Monetization/AdGate.swift` | Sonuç ekranı → interstitial köprüsü |
| `SimVersus/Core/Monetization/ConsentManager.swift` | GDPR onay ve MobileAds başlatma |
| `SimVersus/Core/Monetization/PurchaseManager.swift` | StoreKit satın alma/geri yükleme |
| `SimVersus/Features/Home/RemoveAdsSheet.swift` | Reklam kaldırma satın alma ekranı |
| `SimVersus/project.yml` | GoogleMobileAds ve UMP paket bağımlılıkları |
| `SimVersus/Resources/SimVersus.storekit` | Yerel StoreKit test yapılandırması |
