# KIT FAZ 3 — TURNUVA (v1.3)

Hedef: "Benim takımım" yolculuğu ile tek maça bağlam ve sonuç kazandırmak. Bu fazın amacı, kullanıcının bir daha asla bağlamsız maç izlememesini sağlamaktır.

## Tasarım ilkeleri (CONSTITUTION §4.12'ye tabidir)

- Oyuncu turnuvaya girerken bir **"benim takımım"** seçer.
- **Yalnızca kendi takımının maçlarını izlemek zorundadır.** Diğer tüm karşılaşmalar mevcut deterministik simülasyonla anında sonuçlandırılır.
- İsteyen kullanıcı diğer maçları **opsiyonel olarak** izleyebilir; ancak varsayılan akış sadece kendi takımının maçlarıdır.
- **Yarı final ve final** özel sunuma sahiptir (büyütülmüş bracket, maç öncesi kısa gerginlik anı, kupa kaldırma).
- **Kupa dolabı:** Kazanılan her kupa SwiftData'da kalıcıdır; kupa dolabından görüntülenebilir.
- **Elenme akışı:** Elenince doğrudan "aynı takımla yeniden dene" veya "başka takımla kupaya gir" seçeneği çıkar — ana ekrana dönmek pasif bir seçenektir.
- Turnuva bracket'ı turnuva boyunca **her an görüntülenebilir** (nav bar veya özel buton).
- Turnuva içinde reklamlar duygusal akışı **bozmaz**: interstitial yalnızca turnuva sonuçlandıktan sonra (finalden çıkarken) ve yalnızca normal 3-maç sayacına uygun şekilde gösterilir. Turnuva maçları arasında interstitial GÖSTERİLMEZ.

## Parça sırası ve bağımlılıklar

| Parça | İçerik | Bağımlılık |
|---|---|---|
| 3a | Turnuva motoru: fixture üretimi, grup + eleme durum makinesi, anında sonuçlandırma | Faz 2 |
| 3b | Turnuva UI: bracket görünümü, "benim takımım" yolculuğu, maç akışı, yarı final/final özel sunumu | 3a |
| 3c | Kupa dolabı: SwiftData persist, kupa koleksiyonu UI, şampiyonluk ekranı | 3b |
| 3d | Roster genişlemesi: tier 2 takımların açılması (16 takım) | 3b |

## Format tanımları (sabit)

| Format | Takım | Yapı | Oyuncu maç sayısı | Erişim |
|---|---|---|---|---|
| Mini Kupa | 4 | Tek eleme (yarı final + final) | 2 | Ücretsiz |
| Klasik Kupa | 8 | Tek eleme (çeyrek → yarı → final) | 3 | Ücretsiz |
| Grup + Eleme | 8 | 2 grup × 4, ilk 2 → yarı final | 3-5 (grup: 2 maç izler + opsiyonel 1; eleme: 2) | Rewarded (turnuva başına 1 izleme) |
| Büyük Turnuva | 16 | 4 grup × 4, ilk 2 → çeyrek final | 4-7 (grup: 3 maç izler + opsiyonel; eleme: 3) | Rewarded |

> **Not:** "Oyuncu maç sayısı" = oyuncunun izlemek zorunda olduğu maçlar (kendi takımının maçları). Diğer maçlar anında sonuçlandırılır, isteyen tıklayıp izleyebilir. Bu sayede 16 takımlı turnuvada bile toplam süre ~3-5 dakikayı aşmaz.

## Anında sonuçlandırma (simülasyon modu)

Turnuvada oyuncunun takımının OLMADIĞI karşılaşmalar:

1. `MatchSimulation` aynı seed + iki takım + config ile tam simülasyon çalıştırır.
2. Simülasyon render edilmez; yalnızca `MatchResult` (skor, gol dakikaları, istatistikler) üretilir.
3. Sonuç bracket'a anında yansır, kazanan takım bir üst tura geçer.
4. Kullanıcı dilerse maç kartına tıklayıp **izleyebilir** (tam SpriteKit maçı başlatılır, bu opsiyonel ve bracket'tan erişilir).

Bu tasarım, mevcut `MatchSimulation` altyapısına yalnızca headless (grafik motoru olmadan) çalışma modu eklenmesini gerektirir.

## Faz kabul kriteri

- 16 takım tüm modlarda kullanılabilir; Büyük Turnuva (16) gerçek 16 preset ile oynanabiliyor
- 4 formatın hepsi uçtan uca oynanabiliyor; yarıda bırakılan turnuva kaldığı yerden devam ediyor (SwiftData persist)
- Anında sonuçlandırma doğru çalışıyor: oyuncunun izlemediği maçlar headless simülasyonla belirleniyor, sonuç bracket'a yansıyor
- Kupa dolabı kazanılan turnuvaları format + takım + tarih ile saklıyor
- Yarı final/final özel sunumu (görsel ve akış farkı) mevcut
- Turnuva içi maçlarda **interstitial gösterilmez**; yalnızca final sonrası, normal 3-maç sayacı uygunsa interstitial tetiklenir
- Elenme sonrası "aynı takımla yeniden dene" ve "başka takımla dene" akışı çalışıyor
