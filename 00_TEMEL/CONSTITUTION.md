# SimVersus CONSTITUTION.md
> Bu dosya her ajan oturumunun başında okunur. Buradaki kurallar prompt içeriğiyle çelişirse BU DOSYA kazanır.

## 1. Ürün tanımı

SimVersus: fizik tabanlı, izlenebilir futbol-esintili top çarpışma simülatörü. İki takımın birer topu, sürekli dönen dairesel bir arena içinde birbirine ve arena duvarlarına çarpışır. Arenada TEK bir kale boşluğu vardır, bu boşluk arenayla birlikte döner. Bir takımın topu bu boşluktan (kaleden) dışarı çıkarsa O TOPUN takımı gol kazanır (topu kaleye sokan sayar — futbol mantığı). Kullanıcı yalnızca izler. iOS 17+, iPhone-only (MVP). Faz 6'da Game Center ile online eşleşme gelir; deterministik motor sayesinde iki cihaz yalnızca takım seçimi + seed paylaşır, maç her cihazda lokal ve birebir aynı oynanır.

## 2. Teknik stack (sabit)

| Katman | Karar | Yasak |
|---|---|---|
| Dil | Swift 5.10+ | Objective-C |
| UI | SwiftUI | UIKit (SKView köprüsü hariç) |
| Oyun motoru | SpriteKit (`SKScene`, `SKPhysicsBody`) | Unity, üçüncü parti motor |
| Kalıcı veri | SwiftData (maç geçmişi, ayarlar); takım verisi bundle JSON | CoreData doğrudan, Supabase, herhangi bir backend |
| Reklam | Google Mobile Ads SDK (interstitial + rewarded), UMP consent | Başka ad network, mediation (MVP'de) |
| IAP | StoreKit 2 (`Product`, `Transaction`) | RevenueCat |
| i18n | String Catalog (`Localizable.xcstrings`), TR + EN | Hardcoded kullanıcı stringi |
| Multiplayer (Faz 6) | Game Center (`GKMatchmaker`, davet) | Kendi backend, Firebase, üçüncü parti realtime |

**Bağımlılık ilkesi:** Projedeki TEK dış SDK Google Mobile Ads'tir (reklam için Apple alternatifi yok). Diğer her ihtiyaç Apple framework'leriyle çözülür; ajan hiçbir gerekçeyle başka üçüncü parti bağımlılık ekleyemez/öneremez.

## 3. Proje yapısı (sabit — ajan bu yapıyı bozamaz)

```
SimVersus/
├── App/                    # SimVersusApp.swift, AppState
├── Core/
│   ├── Models/             # Team, MatchResult, MatchConfig...
│   ├── Engine/             # SpriteKit sahneleri, fizik (oyuncu/disk yok, iki top sistemi)
│   │   ├── PhysicsConstants.swift   # TEK kaynak, PHYSICS_CONSTANTS.md'den üretilir
│   │   ├── SeededRNG.swift
│   │   ├── MatchSimulation.swift    # deterministik sabit-adımlı simülasyon
│   │   └── MatchScene.swift         # SKScene render katmanı
│   ├── Data/               # TeamStore (teams.json loader), SwiftData container
│   └── Monetization/       # AdManager, PurchaseManager
├── Features/
│   ├── Home/               # ana menü
│   ├── TeamSelect/         # takım seçimi
│   ├── Match/              # maç ekranı (SpriteView sarmalayıcı)
│   ├── Result/             # maç sonucu
│   └── Settings/           # (Faz 2d)
├── DesignSystem/           # renkler, tipografi, TeamBadgeView
├── Resources/              # teams.json, Localizable.xcstrings, assets
└── SimVersusTests/
```

## 4. Değişmez ürün kuralları

1. **Spectator-only:** Maç sırasında dokunma girdisi fizik dünyasını ETKİLEMEZ. (İzin verilen tek girdi: pause/hız butonu, Faz 2d'den itibaren.)
2. **Marka güvenliği:** Gerçek kulüp adı, logosu, arması, birebir renk pantone'u KULLANILMAZ. Takım isimleri şehir + renk formatındadır ve yalnızca `teams.json`'dan gelir. Aslan, kartal, kanarya gibi kulüplere özgü hayvan/simge figürleri badge'lerde YASAK.
3. **Top = Takım Kimliği:** Her topun görseli, o takımın `TeamBadgeView`'ıdır (fiziksel gövde dairesel, görsel katman badge). Ayrı bir "top" asset'i yoktur.
4. **Tek kale boşluğu:** Arenanın çemberinde tek bir gap vardır (iki ayrı kale YOKTUR). Gap, arena node'unun child'ı olarak onunla birlikte döner.
5. **Gol mantığı:** Bir top dönen kale boşluğundan dışarı çıktığında ("çıkmış" sayılma eşiği için PhysicsConstants) → O TOPUN takımına gol yazılır (topu kaleye sokan takım sayar) → her iki top merkeze resetlenir, kickoff impulse'ı verilir, arena dönüşü kesintisiz devam eder.
   > **Anayasa değişikliği (2026-07):** Skor yönü tersine çevrildi. Eskiden "çıkan topun RAKİBİ" sayı alıyordu; artık "kaleye giren topun KENDİ takımı" sayı alır. Fizik ve toplam gol sayısı aynı kalır, yalnızca atıf değişir. Tek kale boşluğu mimarisi korunur; çift kale hâlâ YASAK.
6. **Takım gücü:** Tüm takımlar eşit güçte başlar (`baseStrength: 75`). İleride power-up sistemi ile anlık/geçici güçlendirmeler eklenebilir (örn. boost çarpanı, kütle azaltma) — ancak bunlar turnuva/ranked modlarında devre dışıdır.
7. **Monetizasyon:** İnterstitial yalnızca `AdManager.matchCompleted()` sayacı 3'e ulaştığında ve yalnızca Result ekranı kapatılırken gösterilir. `PurchaseManager.isAdFree == true` ise hiçbir interstitial gösterilmez (rewarded gösterilebilir). IAP ürün ID: `com.simversus.removeads` (non-consumable).
8. **i18n:** Kullanıcıya görünen HER string `String(localized:)` / SwiftUI otomatik yerelleştirme ile String Catalog'dan gelir. Yeni string eklerken TR + EN karşılığı aynı commit'te eklenir. Anahtar formatı: `feature.context.name` (örn. `match.result.winner`).
9. **Fizik:** Tüm fizik parametreleri `PhysicsConstants.swift`'ten okunur. Sahne içinde magic number yasak.
10. **Oyun olayları:** Motor ve modlar önemli olayları (`matchCompleted`, `goalScored`, `tournamentWon`...) merkezi `GameEvents` yayıncısından duyurur (Faz 4'te kurulur); başarımlar ve ileride online istatistikler yalnızca bu olayları dinler, feature kodlarına doğrudan bağlanmaz.
11. **Determinizm için seed:** Maç motoru `MatchConfig.seed: UInt64` alır; aynı seed + aynı takımlar = aynı maç (test edilebilirlik için `SeededRandomNumberGenerator` kullan).

## 5. Kod standartları

- SwiftUI view'ları 150 satırı geçerse alt view'lara böl.
- Access control bilinçli: modül dışına açılması gerekmeyen her şey `internal`/`private`.
- Zorunlu olmayan hiçbir üçüncü parti bağımlılık ekleme. SPM ile yalnızca: GoogleMobileAds.
- Her parça sonunda proje `Cmd+B` ile temiz derlenmeli; warning bırakma.
- Türkçe yorum satırı serbest; tip/fonksiyon/değişken adları İngilizce.

## 6. Genel DO NOT TOUCH (her parçada geçerli)

- `PhysicsConstants.swift` değerlerini prompt açıkça istemedikçe DEĞİŞTİRME.
- `teams.json` şemasını değiştirme; yalnızca prompt istediğinde kayıt ekle.
- Önceki parçalarda tamamlanmış feature klasörlerine, prompt kapsamında değilse dokunma.
- Bundle ID, ürün ID'leri, AdMob unit ID placeholder'larını değiştirme.
- Mimari kararları (backend eklemek, RevenueCat'e geçmek vb.) "iyileştirme" adına önerme/uygulama.
- Oyuncu diski, 5v5 kavramı, çift kale kavramı YENİDEN GETİRİLMEZ — bu bilinçli olarak terk edilmiş bir yöndür.
