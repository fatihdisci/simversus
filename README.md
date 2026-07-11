# SimVersus

Fizik tabanlı, **izlenebilir (spectator-only)** futbol-esintili top çarpışma
simülatörü. İki takımın birer topu, sürekli dönen dairesel bir arena içinde
birbirine ve duvara çarpışır; topunu dönen kaleden dışarı çıkaran takım gol
atar. Kullanıcı yalnızca izler.

- **Platform:** iOS 17+ (iPhone), SwiftUI + SpriteKit + SwiftData
- **Diller:** Türkçe + İngilizce (String Catalog)
- **Determinizm:** aynı seed + aynı takımlar = birebir aynı maç
- **Dış bağımlılık:** yok (yalnız Faz 1e'de gelecek Google Mobile Ads planlı)

---

## Durum (bu repoda ne çalışıyor)

**✅ Uygulanmış**
- Çekirdek maç döngüsü: Home → Takım Seç → Maç → Sonuç
- Deterministik iki-top fizik motoru (özel, sabit-adımlı 120 Hz)
- Tek dönen kale boşluğu + gol/skor/süre/devre mantığı
- **Takım statları** (ağırlık / hız / boyut) — topun fiziğini top-başına etkiler
- **Özel takım oluşturucu** (SwiftData): isim + 2 renk + rozet + forma deseni + stat
- **Forma desenleri** (düz, dikey/yatay çizgili, kareli, çapraz, yarım)
- **Power-up'lar**: büyüme / küçülme / hızlanma / yavaşlama (seed'li, kapatılabilir)
- Görsel efektler: top izi (tail), çarpışma kıvılcımı, konfeti, kamera sarsıntısı, neon arena
- 16 takım (6 MVP + 10 genişleme), i18n (TR/EN)

**🚧 Henüz stub / gelecek**
- Monetizasyon (AdMob interstitial + "Reklamsız" IAP) — `AdGate` yer tutucu
- Ayarlar ekranı — `SettingsPlaceholder`
- Sonraki fazlar: turnuva, başarımlar, arena çeşitliliği, temalar, multiplayer

---

## Oynanış & mekanik

- **İki-top sistemi:** ayrı bir "top" yoktur; her takımın topu, o takımın
  dairesel amblemidir (`TeamBadgeView` görseli). İki top arenada birbirine ve
  duvara çarpar.
- **Tek dönen kale:** arena çemberinde **tek** bir boşluk (gap) vardır ve
  arenayla birlikte döner. İki ayrı kale yoktur.
- **Gol kuralı:** bir takımın topu bu boşluktan dışarı çıkarsa **o topun kendi
  takımı** gol kazanır ("topunu kaleye sok" — futbol mantığı). Gol sonrası iki
  top merkeze resetlenir, kickoff verilir, arena dönüşü kesintisiz sürer.
- **Süre:** 90 sn oyun = 90 dakika (1 sn = 1 dk), devre arası + gol kutlaması
  duraklamalarıyla.

### Takım statları

Her takımın 3 statı vardır (1–5 skala), **sabit 9 puan bütçesi** paylaşır — yani
hiçbir takım genel olarak daha güçlü değildir, sadece profili farklıdır.

| Stat | Etkilediği | Baseline (Sv3) | Aralık |
|---|---|---|---|
| Ağırlık | `Disc.mass` | 1.00 | 0.85–1.15 |
| Hız | `targetBallSpeed` | 180 | 165–195 |
| Boyut | `Disc.radius` | 28 | 26–30 |

Efektler kasıtlı küçük (±7–15%): seed/şans baskın kalır, statlar yalnız "eğim"
verir. Sayılar `PhysicsConstants.swift` + `teams.json`'da; profiller
kalibrasyonla ayarlanır (bkz. `MatchEngineTests`).

### Özel takımlar

Kullanıcı kendi takımını yaratır: isim (gerçek kulüp adı blocklist'i,
diakritik-duyarsız) + 2 preset renk + 5 rozet şekli + 6 forma deseni + 9 puanlık
stat dağıtımı. SwiftData ile kalıcı; ücretsizde 1 slot (Faz 2b rewarded ile
artacak). Özel takım motora `Team` adaptörüyle girer, önceden tanımlı takımlarla
birlikte maça sokulur.

### Power-up'lar

Arenada periyodik, **seed'li** (deterministik) beliren pickup'lar; top değince
5 sn süreli efekt. Denge için 2 buff + 2 debuff (ortalama gol etkisi ~nötr):

| Pickup | Etki | Görsel |
|---|---|---|
| Büyüme | radius ×1.25 | yeşil `+` |
| Küçülme | radius ×0.80 | mavi `−` |
| Hızlanma | hedef hız ×1.25 | sarı `»` |
| Yavaşlama | hedef hız ×0.80 | mor `«` |

Aktif efektte topun etrafında renkli halka görünür. `MatchConfig.powerUpsEnabled`
ile kapatılabilir (turnuva/ranked modları için — Anayasa §4.6).

---

## Mimari (kaynak ağacı)

```
SimVersus/
├── App/                     ← uygulama girişi + navigasyon
│   ├── SimVersusApp.swift   ← @main, SwiftData modelContainer
│   ├── RootView.swift       ← NavigationStack + [AppRoute] akışı
│   ├── AppRoute.swift       ← rota enum'u (home/teamSelect/teamCreator/match/result)
│   └── AppState.swift       ← maç sayacı (UserDefaults)
├── Core/
│   ├── Engine/              ← DETERMİNİSTİK maç motoru
│   │   ├── MatchSimulation.swift   ← saf Swift fizik (SpriteKit'ten bağımsız)
│   │   ├── MatchScene.swift        ← SpriteKit render (motoru çizer, sürmez)
│   │   ├── PhysicsConstants.swift  ← tüm fizik/stat/power-up sabitleri
│   │   └── SeededRNG.swift          ← tohumlanabilir RNG (determinizm)
│   ├── Models/              ← Team, TeamStats, KitPattern, CustomTeam,
│   │   │                       TeamNameValidator, MatchConfig, MatchResult
│   ├── Data/                ← TeamStore (teams.json), CustomTeamStore (slot)
│   └── Monetization/        ← AdGate (stub, Faz 1e)
├── DesignSystem/            ← Palette, Typography, Spacing, TeamBadgeView
├── Features/                ← Home, TeamSelect, TeamCreator, Match, Result, Settings
├── Resources/              ← teams.json, Localizable.xcstrings
└── SimVersusTests/         ← motor + stat + custom team + power-up testleri
```

**Anahtar ayrım:** `MatchSimulation` saf Swift'tir (SpriteKit yok) — başsız
(headless) ve tekrarlanabilir çalışır; `MatchScene` yalnızca onun durumunu her
kare çizer, fiziği asla sürmez. Bu, determinizmin (ve testlerin, Faz 6 online
senkronizasyonun) temelidir.

---

## Kurulum & çalıştırma

```bash
open SimVersus/SimVersus.xcodeproj
```

- **Xcode 16+**, iOS 17 SDK. Proje "file system synchronized groups" kullanır —
  yeni `.swift` dosyaları ilgili klasöre eklenince otomatik derlemeye girer.
- Harici bağımlılık / SPM paketi yok. Doğrudan Run (⌘R).
- Karanlık tema sabittir ("stadium night match").

### Test

```bash
# Xcode: ⌘U  — veya:
xcodebuild test -project SimVersus/SimVersus.xcodeproj \
  -scheme SimVersus -destination 'platform=iOS Simulator,name=iPhone 15'
```

Kapsam (`SimVersusTests/`):
- `MatchEngineTests` — determinizm + 20-seed gol-band kalibrasyonu + varyans
- `TeamStatsTests` — stat bütçe geçerliliği, baseline eşleşmesi, bant tutarlılığı
- `CustomTeamTests` — isim blocklist (diakritik), `Team` adaptörü, desen path'leri
- `PowerUpTests` — kapalıyken spawn yok, açıkken spawn, determinizm, sonuca etki
- `TeamMatchupTests` — aynı takım iki tarafta seçilemez

> **Determinizm sözleşmesi:** aynı `MatchConfig` (takımlar + seed + ayarlar) her
> zaman aynı `MatchResult`'ı üretir. Yeni bir "rastgelelik" eklerken mutlaka
> `SeededRandomNumberGenerator` üzerinden geç.

---

## Prompt kit sistemi (geliştirme yol haritası)

Repo kökündeki `00_TEMEL/` ve `KIT_FAZ*/` klasörleri, projeyi ajanlarla
aşama-aşama geliştirmek için hazırlanmış prompt kitlerini içerir.

- `00_TEMEL/CONSTITUTION.md` — proje anayasası (mimari, kurallar, DO NOT TOUCH).
  **Her oturumda önce okunur; prompt ile çelişirse anayasa kazanır.**
- `00_TEMEL/` ayrıca: `PHYSICS_CONSTANTS.md`, `DESIGN_TOKENS.md`,
  `I18N_RULES.md`, `TEAMS.json`.
- `PLAN_TAKIM_KIMLIGI.md` — takım kimliği çalışmasının (stat + oluşturucu +
  efekt + power-up) aşamalı planı ve kararları.

| Faz | Parçalar | Çıktı |
|---|---|---|
| 1 — MVP | 1a kurulum · 1b takımlar+logo · 1c maç motoru · 1d akış+sonuç · 1e monetizasyon · 1f store | App Store ilk sürüm |
| 2 — Retention | 2a takım oluşturucu · 2b rewarded · 2c geçmiş+istatistik · 2d ayarlar | v1.1–1.2 |
| 3 — Turnuva | 3a motor · 3b bracket · 3c şampiyonluk+kilit · 3d 16 takım | v1.3 |
| 4 — Başarımlar | 4a motor · 4b UI · 4c paylaşım kartları | v1.4 |
| 5 — Genişleme | 5a arena çeşitliliği · 5b temalar · 5c fizik modları | v1.5 |
| 6 — Multiplayer | 6a Game Center · 6b online maç · 6c maç sonrası | v2.0 |

> Çekirdek maç döngüsü (1a–1d) + stat sistemi + özel takım oluşturucu (2a) +
> efekt inceltme + power-up'lar bu repoda uygulanmıştır. 1e/1f ve sonraki fazlar
> beklemededir.

---

## Değişmez kararlar (tartışmaya kapalı)

- **Spectator-only:** kullanıcı maça müdahale ETMEZ (tüm modlarda, online dahil).
- **Tek dış SDK = Google Mobile Ads.** Geri kalan her şey Apple: StoreKit 2,
  SwiftData, SpriteKit, Game Center, String Catalog. Kendi backend'imiz YOK.
- **Marka güvenliği:** gerçek kulüp adı/logosu/arması ASLA. Şehir+renk formatı,
  soyut geometrik badge; hayvan/simge figürü yok.
- **Tek dönen kale boşluğu** — çift kale kavramı yeniden getirilmez.
- **i18n baştan:** her kullanıcıya görünen string String Catalog'da, TR + EN.
- **Maç motoru deterministik (seed'li)** — testin ve Faz 6 online senkronunun temeli.
- Fizik parametreleri yalnız `PhysicsConstants.swift`'te; sahnede magic number yok.
- Lig/sezon modu YOK (bilinçli kapsam kararı).
