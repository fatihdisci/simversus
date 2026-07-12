# SimVersus CONSTITUTION.md
> Bu dosya her ajan oturumunun başında okunur. Buradaki kurallar prompt içeriğiyle çelişirse BU DOSYA kazanır.

## 1. Ürün tanımı

SimVersus: fizik tabanlı, izlenebilir futbol-esintili top çarpışma simülatörü. İki takımın birer topu, sürekli dönen dairesel bir arena içinde birbirine ve arena duvarlarına çarpışır. Arenada TEK bir kale boşluğu vardır, bu boşluk arenayla birlikte döner. Bir takımın topu bu boşluktan (kaleden) dışarı çıkarsa O TOPUN takımı gol kazanır (topu kaleye sokan sayar — futbol mantığı). Kullanıcı yalnızca izler. iOS 17+, iPhone-only (MVP). Faz 6'da Game Center ile online eşleşme gelir; deterministik motor sayesinde iki cihaz yalnızca takım seçimi + seed paylaşır, maç her cihazda lokal ve birebir aynı oynanır.

**Ürünün temel vaadi "30 saniyelik fizik maçı" değil, "30 saniyelik spor draması"dır.** Her maç bir turnuvanın, tahmin serisinin, rekabetin veya meydan okumanın parçası olmalıdır. Kullanıcı hiçbir zaman bağlamsız, tek başına anlamı olmayan bir maç izlemez. Bu ilke tüm fazların tasarımını yönlendirir.

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

12. **Turnuva — benim takımım:** Turnuvalarda oyuncu bir "benim takımım" seçer. Yalnızca kendi takımının maçlarını izlemek zorundadır; diğer maçlar deterministik simülasyonla anında sonuçlandırılır (isteyen izleyebilir). Yarı final ve final özel sunuma sahiptir. Kazanılan kupalar SwiftData'da kalıcı kupa dolabında saklanır. Elenme sonrası "aynı takımla yeniden dene" ve "başka takımla kupaya gir" seçenekleri sunulur.

13. **Tahmin sistemi:** Maç öncesinde oyuncuya tahmin sorulabilir (kazanan, gol sayısı, ilk golü atan). Doğru tahminler seri oluşturur. Tahmin sistemi gerçek para, bahis dili veya karmaşık ekonomi İÇERMEZ. Tamamen kozmetik rozet/başarım odaklıdır. Tüm tahminler maç başlamadan önce kilitlenir, fizik sonucu belirledikten sonra değiştirilemez.

14. **Rövanş / seri bağlamı:** Aynı iki takım tekrar karşılaştığında bu yeni ve bağımsız bir maç gibi sunulmaz. Önceki sonuç, seri durumu (1-0, 1-1, 2-1) ve bağlam (rövanş, üç maçlık seri, derbi) görünür olur. Sonuç ekranında "Rövanşı Al" düğmesi, ana ekrana dönmekten daha güçlü bir devam aksiyonudur. Seri durumu maç geçmişinden otomatik hesaplanır.

15. **Takım ustalığı — kozmetik:** Her takım için yerel istatistik tutulur (oynanan maç, galibiyet, atılan gol, en uzun seri, en büyük geri dönüş, farklı rakiplere karşı başarı). Bunlar "Takım Ustalığı" seviyesine dönüşür. Ustalık ödülleri **kesinlikle performans avantajı sağlamaz**; yalnızca kozmetik olabilir: rozet çerçevesi, gol kutlaması, giriş animasyonu, top izi, şampiyonluk yıldızı, özel takım kartı zemini. Denge bozulmaz.

16. **Günlük arena:** Tarihten türetilen sabit seed ile her gün bir "Günün Arenası" üretilir. Sabit rakip, özel fizik modu, tek deneme hakkı ve günlük küçük görev içerir. Cihaz saati değiştirilebilir — tek oyunculu, ödülü kozmetik olan bir sistemde bu kabul edilebilir. Sunucu gerektiren sahte küresel sıralama/rekabet hissi VERİLMEZ.

17. **Meydan okuma kodu:** Paylaşım sistemi backend gerektirmez. Kod; gönderenin takımını, takım görünümünü/istatistiklerini, rakip ayarlarını, arena modunu, seed'i ve maç süresini kodlar. Alan kişi kendi takımını seçer ve gönderenin takımına karşı aynı koşullarda oynar. Deterministik motor mevcut olduğu için teknik temel hazırdır. Statik skor görseli tek başına paylaşım için yeterli değildir; paylaşılan şey alıcıya bir eylem sunmalıdır.

18. **Bağlamsız maç yasağı:** Ana ekrandan doğrudan başlatılan, hiçbir üst yapıya bağlı olmayan "serbest maç" yoktur. Her karşılaşma bir turnuva, seri, tahmin, takım yolculuğu, günlük arena veya meydan okuma için oynanır. Bu kural Faz 2 sonrası tüm fazlarda geçerlidir; Faz 1-2'deki serbest maç akışı, Faz 3 ile birlikte bağlam zorunlu hale gelecek şekilde dönüşür.

19. **Ses tasarımı:** Maçta en az: çarpışma sesleri (top-top, top-duvar, top-direk), kale yaklaşırken yükselen ambiyans, gol sesi, devre düdüğü, final düdüğü ve tribün tepkileri bulunur. Ses tasarımı, görsel iyileştirmelerden (tema, arena şekli) daha önce gelir. Olay anlatımı harici yapay zekâ değil, kural tabanlı kısa mesajlardır ("Direkten döndü", "Son saniye baskısı", "Geri dönüş başladı").

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
- Tahmin sistemine bahis/puan/ekonomi ekleme; meydan okuma koduna backend şartı getirme.
- Takım ustalığından performans avantajı türetme; stat güçlendiren ücretli ilerleme ekleme.
- Bağlamsız maçı (serbest maç) Faz 3 sonrası ana akışta tutma.
