# Yol Haritası — Arena30 (SimVersus)

> Son güncelleme: 12 Temmuz 2026. Bu belge kod tabanındaki gerçek yapıya dayanır; hiçbir şey uydurulmamıştır.
> Her maddenin altında **ne**, **nerede**, **nasıl** soruları cevaplanır.

---

## Tamamlananlar

### Faz 1 — MVP

```
SimVersus/App/SimVersusApp.swift          → @main, consent + ad preload
SimVersus/App/AppState.swift              → matchesPlayedCount, matchDuration (UserDefaults)
SimVersus/App/AppRoute.swift              → NavigationStack rotaları (home→teamSelect→match→result)
SimVersus/App/RootView.swift              → route → view mapping, rematch, saveMatchRecord (max 500)
SimVersus/Core/Models/Team.swift           → Team: id, nameKey, nameTR, nameEN, short, primary, secondary,
                                             badgeShape (star|chevron|wave|diamond|ring), tier, stats, pattern
SimVersus/Core/Models/TeamStats.swift      → weight/speed/size 1-5, toplam SABİT 9, fail-safe decode
SimVersus/Core/Models/MatchConfig.swift    → homeTeam, awayTeam, seed: UInt64, duration, powerUpsEnabled
SimVersus/Core/Models/MatchResult.swift    → homeScore, awayScore, goals: [Goal], winnerTeamID
SimVersus/Core/Engine/PhysicsConstants.swift → 152 satır, TEK kaynak; arena, top, boost, stall, power-up
SimVersus/Core/Engine/MatchSimulation.swift → saf Swift, headless çalışabilir, runToCompletion(), 120 Hz
SimVersus/Core/Engine/SeededRNG.swift      → deterministic random (seed → aynı sonuç)
SimVersus/Core/Engine/MatchScene.swift     → SpriteKit render, MatchSimulation'dan okur
SimVersus/Core/Data/TeamStore.swift        → teams.json loader, mvpTeams filtresi (tier 1)
SimVersus/Resources/teams.json             → 16 takım (6 tier 1 aktif, 10 tier 2 kilitli)
SimVersus/DesignSystem/                    → Palette, Spacing, Typography, ArenaComponents, TeamBadgeView
SimVersus/Features/Home/HomeView.swift     → hero kompozisyon, ambient arena, CTA
SimVersus/Features/Home/AmbientArenaView.swift → arka plan dönen arena
SimVersus/Features/TeamSelect/             → VS kartı, tek takım havuzu, sticky CTA
SimVersus/Features/Match/MatchView.swift   → SpriteView sarmalayıcı, pause/exit
SimVersus/Features/Match/MatchHUDComponents.swift → skor şeridi, dakika, ilerleme barı
SimVersus/Features/Result/ResultView.swift → hero kart, gol akışı, rematch/new/home
SimVersus/Features/Result/ResultComponents.swift → gol satırı, takım orb'ları
SimVersus/Core/Monetization/AdManager.swift     → interstitial (3 maçta 1), rewarded, preload
SimVersus/Core/Monetization/AdGate.swift         → ResultView.onDisappear → matchCompleted()
SimVersus/Core/Monetization/ConsentManager.swift → UMP consent, non-personalized ads (npa=1)
SimVersus/Core/Monetization/PurchaseManager.swift → StoreKit 2, isAdFree, restore, ProductState
SimVersus/Info.plist                         → GADApplicationIdentifier (test), SKAdNetwork yok
SimVersus/Resources/Localizable.xcstrings → TR+EN tüm string'ler
SimVersus/Resources/SimVersus.storekit    → removeads ürünü ($1.99)
```

- [x] 1a — Proje kurulumu, klasör yapısı, design system, i18n
- [x] 1b — Team modeli, teams.json, TeamBadgeView, takım seçimi
- [x] 1c — SpriteKit maç motoru: dönen arena, fizik, gol, skor, süre
- [x] 1d — Akış: Home → TeamSelect → Match → Result
- [x] 1e — Monetizasyon: AdMob + StoreKit 2 + UMP
- [x] 1f — Cila + ikon + launch + kalibrasyon (40 seed, 1.33 gol/maç, 0-0 %20)

### Faz 2 — Retention

- [x] 2a — Özel takım oluşturucu
  ```
  SimVersus/Core/Models/CustomTeam.swift        → @Model: name, primary, secondary, badgeShape, pattern, stats
  SimVersus/Core/Models/TeamNameValidator.swift  → min 2 char, max 16, unique
  SimVersus/Core/Models/KitPattern.swift         → solid|stripes|hoops|checks|half
  SimVersus/Features/TeamCreator/TeamCreatorView.swift → Kimlik/Arma/Oyun Tarzı kartları, canlı önizleme
  ```

- [x] 2b — Rewarded reklamla ek slot
  ```
  SimVersus/Core/Data/CustomTeamStore.swift → baseSlots=1, maxSlots=5, unlockAdditionalSlot()
  AdManager.showRewarded { CustomTeamStore.unlockAdditionalSlot() }
  ```

- [x] 2c — Maç geçmişi + istatistik
  ```
  SimVersus/Core/Models/MatchRecord.swift → @Model: homeTeamID, awayTeamID, homeScore, awayScore,
                                            goalsData (JSON), playedAt, seed
  SimVersus/Features/History/HistoryView.swift → ArenaChoicePill (tümü/maçlar/istatistikler),
                                                   takım orb + kazanan vurgusu, detay sayfası
  ```

- [x] 2d — Ayarlar
  ```
  SimVersus/Features/Settings/SettingsView.swift → maç süresi, reklam durumu, satın alma/restore, hakkında
  SimVersus/Features/Home/RemoveAdsSheet.swift    → satın alma sheet'i, fiyat yükleme/başarısız durumu
  ```

### Tasarım yenileme (Aşama 1-9)

- [x] ArenaComponents (ArenaBackground, ArenaSurface, ArenaButtonStyle, ArenaIconButton, ArenaSectionHeader, ArenaChoicePill)
- [x] Gece Arenası renkleri, 5 font rolü (display, title, headline, button, section, caption)
- [x] Tüm ekranlar yeni tasarım dilinde yeniden yazıldı
- [x] Mono yalnız veride (skor, dakika, kod), cümleler caption fontta
- [x] Kale fiziği düzeltildi (görünmez ağız kirişi, hayalet ayna kapısı, direk-ray dikişi)
- [x] 120 fps ProMotion desteği, konfeti havuzu ön-ısıtma, power-up tahsis kısa yolu

---

---

## Faz 3 — Turnuva

### 3a — Turnuva motoru

**Ne:** Turnuva fixture üretimi, grup + eleme durum makinesi, anında sonuçlandırma.
Mevcut `MatchSimulation.runToCompletion()` (satır 178-187) zaten headless çalışabiliyor — grafik
motoru olmadan sadece `MatchResult` üretiyor. Turnuva motoru bu yeteneği kullanarak oyuncunun
izlemediği maçları anında sonuçlandırır.

**Yeni dosyalar:**
```
SimVersus/Core/Models/TournamentFormat.swift   → enum: mini(4), classic(8), groupKO(8), grand(16)
SimVersus/Core/Models/TournamentState.swift    → @Model: format, teams, fixtures, results, phase, playerTeamID
SimVersus/Core/Engine/TournamentEngine.swift   → fixture üretimi, grup puan durumu, bracket ilerletme
```

**TournamentState (@Model, SwiftData):**
```swift
@Model final class TournamentState {
    var formatRaw: String          // TournamentFormat.rawValue
    var playerTeamID: String       // "benim takımım"
    var phaseRaw: String           // pending|groupStage|knockout|finished
    var fixturesJSON: Data         // [Fixture] encoded
    var resultsJSON: Data          // [FixtureResult] encoded
    var startedAt: Date
    var completedAt: Date?
    var trophyID: String?          // kazanılan kupanın ID'si (kupa dolabı için)
}
```

**TournamentEngine (pure Swift, referans: MatchSimulation kalıbı):**
- `generateFixtures(format: TournamentFormat, teams: [Team]) -> [Fixture]` — round-robin grup + tek eleme bracket
- `simulateMatch(home: Team, away: Team, seed: UInt64) -> MatchResult` — `MatchSimulation(config:).runToCompletion()` çağrısı
- `advanceTournament(state: inout TournamentState) -> [Fixture]` — kazananları üst tura taşır
- `isPlayerMatch(fixture: Fixture, playerTeamID: String) -> Bool` — oyuncunun maçı mı?
- Seed her fixture için `fixtureID.hashValue` + `tournamentSeed` kombinasyonundan türetilir (deterministik)

**Değişecek dosyalar:**
```
SimVersus/Core/Models/MatchConfig.swift → powerUpsEnabled parametresi turnuva için false
                                            (CONSTITUTION §4.6)
```

### 3b — Turnuva UI

**Ne:** Bracket görünümü, "benim takımım" yolculuk ekranı, maç akışı, yarı final/final özel sunumu.

**Yeni dosyalar:**
```
SimVersus/Features/Tournament/TournamentLobbyView.swift   → format seçimi, "benim takımım" seçimi
SimVersus/Features/Tournament/TournamentBracketView.swift  → bracket çizimi (scrollable, zoomable)
SimVersus/Features/Tournament/TournamentMatchFlow.swift    → kendi takımının maçı → MatchView,
                                                              diğer maçlar → anında sonuç + kart
SimVersus/Features/Tournament/TournamentFinaleView.swift   → yarı final/final özel sunum (büyük bracket,
                                                              gerginlik anı, kupa kaldırma animasyonu)
```

**Akış (AppRoute'a eklenecek):**
```
.tournamentLobby → .tournamentBracket → .match(config) → .result(result, config)
                                       ↘ (diğer maç) → bracket'a dön, sonuç kartı göster
                                       ↘ .tournamentFinale(trophyID)
```

**Nasıl:**
- NavigationStack path'i turnuva modundayken bracket her an görüntülenebilir (toolbar butonu)
- Oyuncunun izlemediği maç: `TournamentEngine.simulateMatch()` → `MatchResult` → bracket'a anında yansır
- Oyuncu dilerse bracket'taki herhangi bir maç kartına tıklayıp TAM maçı izleyebilir
  (bu durumda `MatchView` normal şekilde başlatılır, aynı seed ile)
- Yarı final ve final: `TournamentFinaleView` devreye girer — skor HUD'ı büyür, arena arka planı
  kararır, kupa gölgesi belirir

### 3c — Kupa dolabı

**Ne:** Kazanılan kupalar SwiftData'da kalıcı; kupa dolabından görüntülenebilir.

**Yeni dosyalar:**
```
SimVersus/Core/Models/Trophy.swift             → @Model: id, format, teamID, teamName, wonAt, isCustomTeam
SimVersus/Features/Tournament/TrophyCabinetView.swift → grid galeri: kupa ikonu + takım + format + tarih
```

**Trophy (@Model):**
```swift
@Model final class Trophy {
    var id: UUID
    var formatRaw: String       // mini, classic, groupKO, grand
    var teamID: String
    var teamName: String        // o anki takım adı (denormalize — takım sonradan silinse bile kupa kalır)
    var isCustomTeam: Bool
    var wonAt: Date
}
```

### 3d — Roster genişlemesi

**Ne:** 10 tier-2 takımın açılması (teams.json'da zaten var, sadece `TeamStore`'a filtre eklenecek).

**Değişecek dosyalar:**
```
SimVersus/Core/Data/TeamStore.swift → mvpTeams → allTeams (tier 1 + tier 2, 16 takım)
```

**Nasıl:** Tier-2 takımlar turnuva seçiminde görünür hale gelir. MVP serbest maçta sadece 6 takım kalır
(Faz 3 ile serbest maç kalkacağı için bu doğal olarak çözülür).

### Faz 3 kabul kriteri

- [ ] `TournamentEngine` 4 formatın hepsinde doğru fixture üretiyor
- [ ] `MatchSimulation.runToCompletion()` headless modda doğru `MatchResult` döndürüyor
- [ ] Yarıda bırakılan turnuva SwiftData'dan geri yüklenip kaldığı yerden devam ediyor
- [ ] Kupa dolabı kazanılan turnuvaları gösteriyor
- [ ] Yarı final/final özel sunumu mevcut
- [ ] Turnuva içi maçlarda interstitial YOK (sadece final sonrası)
- [ ] 16 takım tüm modlarda kullanılabiliyor

---

## Faz 3.5 — Retention Paketi

### 3.5a — Ses tasarımı

**Ne:** Minimum ses seti: çarpışma, gol, düdük, tribün. Hepsi asset catalog'da `.caf` formatında.

**Yeni dosyalar:**
```
SimVersus/Resources/Assets.xcassets/Sounds/   → *.caf dosyaları (topTop, topWall, topPost,
                                                  goalWhistle, halfTimeWhistle, finalWhistle,
                                                  crowdAmbient, crowdGoal, wallAmbientRise)
SimVersus/Core/Engine/AudioManager.swift      → @MainActor singleton, SKAudioNode pool
```

**AudioManager (referans: AdManager kalıbı — singleton + preload):**
- SKAudioNode havuzu (her ses için 2-3 node, aynı anda çalabilme)
- `play(_ sound: MatchSound)` → uygun node'u bul, çal
- Ses seviyesi `UserDefaults`'tan okunur (mevcut Settings ile entegre)
- Düşük güç modunda arka plan uğultusu kısılır
- Sessiz modda (ring/silent) ana sesler duyulur (AVAudioSession .playback kategorisi)

**MatchScene entegrasyonu (değişecek):**
```swift
// CollisionEvent geldiğinde:
if event.isBallBall { AudioManager.shared.play(.topTop) }
else { AudioManager.shared.play(.topWall) }

// processWallOrGoal → isInsideGoalMouth + outwardVelocity → AudioManager.shared.play(.wallAmbientRise)
// recordGoal → AudioManager.shared.play(.goalWhistle) + AudioManager.shared.play(.crowdGoal)
// didHalfTime → AudioManager.shared.play(.halfTimeWhistle)
// endMatch → AudioManager.shared.play(.finalWhistle)
```

### 3.5b — Olay anlatımı + maç sonu ödülleri

**Ne:** Kural tabanlı kısa metin mesajları (AI değil). Maç motoru olaylarından tetiklenir.

**Yeni dosyalar:**
```
SimVersus/Core/Engine/MatchCommentary.swift    → kural motoru: olay → mesaj
SimVersus/Features/Match/MatchCommentaryLabel.swift → HUD altında kısa yanıp sönen etiket
```

**MatchCommentary (pure func, referans: PhysicsConstants enum kalıbı):**
```swift
enum MatchCommentary {
    static func evaluate(snapshot: CommentarySnapshot) -> CommentaryEvent?
}

struct CommentarySnapshot {
    var ballVelocity: CGPoint
    var distanceToGap: CGFloat
    var didHitPost: Bool
    var goalsInLast15Sec: Int
    var isLast10Seconds: Bool
    var isComeback: Bool          // 1-0 gerideyken gol
    var collisionsIn2Sec: Int
    var nearestMissDistance: CGFloat
}
```

**Maç sonu ödülleri (MatchResult'a eklenecek computed property'ler):**
- `fastestShotSpeed: CGFloat?` — anlık en yüksek hız (simülasyondan hesaplanır)
- `closestMissDistance: CGFloat?` — gap'e en yakın mesafe
- `comebackMoment: Int?` — geri dönüşün gerçekleştiği dakika
- `postHitCount: (home: Int, away: Int)` — direğe çarpma sayıları
- `mostActivePowerUp: PowerUpKind?` — en çok efekt üreten power-up

**Nasıl:** `MatchSimulation` adım fonksiyonunda `CommentarySnapshot` doldurulur, her frame
`MatchCommentary.evaluate()` çağrılır. Sonuç HUD altında 2 sn görünür, sonra solar.

### 3.5c — Maç öncesi tahmin sistemi

**Ne:** Maç başlamadan önce kullanıcıya tahmin sorusu. Doğru tahminler seri oluşturur.
CONSTITUTION §4.13: Gerçek para/bahis YOK, tamamen kozmetik.

**Yeni dosyalar:**
```
SimVersus/Core/Models/PredictionType.swift     → enum: winner, overUnder, firstScorer, goesToExtraTime
SimVersus/Core/Models/PredictionRecord.swift   → @Model: matchSeed, prediction, actual, isCorrect, date
SimVersus/Features/Match/PredictionSheet.swift  → maç öncesi bottom sheet
```

**PredictionType ve değerlendirme:**
```swift
enum PredictionType: String, Codable, CaseIterable {
    case winner          // home / draw / away
    case overUnder       // over 2.5 / under 2.5
    case firstScorer     // home / away / noGoal
    case goesToExtraTime // yes / no (süre bitiminde skor eşitse)
}
```

**Akış:**
1. `TeamSelectView` → "Başla" butonu → önce tahmin sheet'i açılır
2. Kullanıcı 1-2 soru cevaplar (rastgele seçilir, maç başına en fazla 2)
3. Tahminler `PredictionRecord` olarak SwiftData'ya yazılır (`matchSeed` ile eşleşir)
4. Maç bittikten sonra `ResultView.onAppear` → tahmin değerlendirilir → doğru/yanlış kaydedilir
5. `AppState`'e `predictionStreak: Int` eklenir (UserDefaults)

### 3.5d — Rövanş / seri sistemi

**Ne:** Aynı iki takım tekrar karşılaştığında önceki sonuçlar ve seri durumu görünür.

**Değişecek dosyalar:**
```
SimVersus/App/RootView.swift           → rematch metodu zaten var (satır 88-93)
SimVersus/Features/Result/ResultView.swift → "Rövanşı Al" birincil CTA, seri skoru
SimVersus/Features/TeamSelect/TeamMatchup.swift → head-to-head istatistikleri
```

**Nasıl (mevcut altyapı üzerine):**
- `MatchRecord` SwiftData'da zaten var. Head-to-head sorgusu:
  ```swift
  // TeamMatchup.swift'a eklenecek:
  func headToHead(teamA: String, teamB: String) -> [MatchRecord] {
      // fetch: (homeTeamID==A && awayTeamID==B) || (homeTeamID==B && awayTeamID==A)
      // sort: playedAt descending
  }
  ```
- Seri durumu son N maçın kazananına göre hesaplanır: "Seri: İstanbul Demir 2 – 1 İstanbul Rüzgar"
- `ResultView`'da `onRematch` callback'i zaten mevcut (AppRoute üzerinden yeni seed'li config)
- Ek olarak "Üç Maçlık Seri" butonu: aynı takımlarla 3 maçlık mini seri başlatır

### 3.5e — Takım ustalığı

**Ne:** Her takım için yerel istatistik, 5 ustalık seviyesi, kozmetik ödüller.
CONSTITUTION §4.15: Ödüller kesinlikle performans avantajı SAĞLAMAZ.

**Yeni dosyalar:**
```
SimVersus/Core/Models/TeamMastery.swift        → @Model: teamID, matches, wins, draws, losses,
                                                  goalsFor, longestStreak, biggestComeback,
                                                  uniqueOpponents, level, tournamentsWon
SimVersus/Features/TeamSelect/TeamMasteryBadge.swift → seviye rozeti (takım kartında)
```

**TeamMastery (@Model):**
```swift
@Model final class TeamMastery {
    var teamID: String              // preset team.id veya custom team UUID
    var matches: Int = 0
    var wins: Int = 0
    var draws: Int = 0
    var losses: Int = 0
    var goalsFor: Int = 0
    var longestWinStreak: Int = 0
    var biggestComeback: Int = 0   // kaç gol geriden gelip kazandı
    var uniqueOpponents: [String] = []  // farklı rakip ID'leri
    var level: Int = 0             // 0-5 arası
    var tournamentsWon: Int = 0
}
```

**Seviye eşikleri ve kozmetik ödüller:**
| Level | Gereksinim | Kozmetik ödül |
|---|---|---|
| 1 Çaylak | 1 maç | — |
| 2 Seyirci | 10 maç | Rozet çerçevesi (takım seçiminde ve HUD'da hafif glow) |
| 3 Taraftar | 25 maç, 10 galibiyet | Özel gol kutlaması (takım renginde konfeti) |
| 4 Kaptan | 50 maç, 1 kupa | Maça giriş animasyonu (takım orb'u dönerek gelir) |
| 5 Efsane | 100 maç, 3 kupa, 10+ rakip | Şampiyonluk yıldızı ⭐ + altın takım kartı zemini |

**Nasıl (mevcut altyapı üzerine):**
- `RootView.saveMatchRecord()` (satır 95-102) → `TeamMastery` güncellemesi de burada yapılır
- Ustalık seviyesi atladığında `AppState`'e toast tetiklenir
- Ödüller `TeamBadgeView` ve `MatchHUDComponents`'ta koşullu render: `if mastery.level >= 2 { ... }`

### 3.5f — Günlük arena

**Ne:** Tarihten türetilen sabit seed ile her gün özel maç. CONSTITUTION §4.16: Sahte küresel rekabet YOK.

**Yeni dosyalar:**
```
SimVersus/Core/Engine/DailyArena.swift          → tarih → seed, rakip, mod, görev
SimVersus/Features/Home/DailyArenaCard.swift     → ana ekranda günlük kart
SimVersus/Core/Models/DailyRecord.swift          → @Model: date, completed, predictionCorrect, teamUsed
```

**DailyArena (pure func):**
```swift
enum DailyArena {
    static func config(for date: Date) -> DailyArenaConfig {
        let seed = UInt64(date.yyyyMMdd.hashValue) // deterministik, cihaz bağımsız değil
        let opponentIndex = Int(seed % 16)         // 16 takımdan biri
        // ...
    }
}
```

**Günlük görev örnekleri:**
- "Bugün hafif takımla ağır rakibi yen" (size < 3 olan takım seç)
- "En az 3 gol çıkan bir takım seç"
- "Kazananı maç başlamadan tahmin et" (günlük tahmin)
- "Günün şampiyonunu belirle" (mini turnuva)

### 3.5g — İlk maç deneyimi

**Ne:** Yeni kullanıcının ilk maçı için önceden test edilmiş heyecanlı seed.

**Değişecek dosyalar:**
```
SimVersus/App/RootView.swift → matchesPlayedCount==0 ise ilk maç seed'i
```

**Nasıl:**
```swift
// AppState'e eklenecek:
static let firstMatchSeeds: [UInt64] = [
    // 40 seed'lik testten: en az 2 gol, heyecanlı anları olan 5 seed
    // (gerçek test sonuçlarına göre belirlenir, uydurma değil)
]
```
`RootView.teamSelect` → `onStart` callback'i → `matchesPlayedCount == 0` ise seed havuzdan seçilir.
Fizik hilesi YAPILMAZ; seed'ler doğal oynanıştan seçilir.

### Faz 3.5 kabul kriteri

- [ ] Tüm sesler çalışıyor; ses seviyesi Ayarlar'dan kontrol ediliyor
- [ ] En az 7 farklı olay anlatımı mesajı tetikleniyor, TR/EN doğru
- [ ] Tahmin → maç → değerlendirme → seri zinciri uçtan uca çalışıyor
- [ ] Aynı takımlar tekrar seçildiğinde head-to-head ve seri durumu görünüyor
- [ ] Takım ustalığı 5 seviye; kozmetik ödüller seviyeye göre render ediliyor
- [ ] Günlük arena tarih seed'i tutarlı; günlük görev tamamlanabiliyor
- [ ] İlk maç garantili heyecanlı seed ile başlıyor
- [ ] CONSTITUTION §4.18: Ana ekrandan serbest maç başlatılamıyor

---

## Faz 4 — Başarımlar + Meydan Okuma + Paylaşım

### 4a — GameEvents olay sistemi

**Ne:** Merkezi event bus. Tüm motor ve mod olayları buradan yayınlanır; başarım motoru,
anlatım motoru, analitik dinler.

**Yeni dosyalar:**
```
SimVersus/Core/Engine/GameEvents.swift → @MainActor singleton, AsyncStream tabanlı
```

**GameEvents (referans: AdManager singleton kalıbı):**
```swift
@MainActor final class GameEvents {
    static let shared = GameEvents()
    private var continuations: [UUID: AsyncStream<GameEvent>.Continuation] = [:]

    func emit(_ event: GameEvent) { /* tüm kontinuasyonlara gönder */ }
    func stream() -> AsyncStream<GameEvent> { /* yeni stream oluştur */ }
}
```

**GameEvent enum (tüm olaylar):** KIT_FAZ4_BASARIMLAR/KIT_README.md §4a'da tam liste var.

**Nasıl:** `MatchSimulation.recordGoal()` → `GameEvents.shared.emit(.goalScored(...))`.
`RootView.saveMatchRecord()` → `GameEvents.shared.emit(.matchCompleted(...))`.
Her dinleyici `Task { for await event in GameEvents.shared.stream() { ... } }` ile dinler.
Faz 3.5b anlatım motoru bu sisteme taşınır.

### 4b — Başarım motoru

**Ne:** Davranış odaklı başarım tanımları, tetikleme, persist. Pasif sayaçlar (örn. "100 maç izle")
bilinçli olarak azınlıktadır.

**Yeni dosyalar:**
```
SimVersus/Core/Engine/AchievementEngine.swift   → tanım yükleme, olay dinleme, ilerleme hesaplama
SimVersus/Core/Models/AchievementState.swift    → @Model: achievementID, progress, isUnlocked, unlockedAt
SimVersus/Core/Models/AchievementDefinition.swift → enum: tüm başarım tanımları (en az 20)
```

**AchievementDefinition yapısı:**
```swift
struct AchievementDefinition {
    let id: String
    let category: AchievementCategory  // explorer, strategist, competitor, collector, master, daily, social
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let icon: String                   // SF Symbol adı
    let evaluate: (GameEvent, AchievementState) -> Double  // 0.0–1.0 arası ilerleme
}
```

**Örnek tanım (gerçek yapıya dayalı):**
```swift
AchievementDefinition(
    id: "comeback_series",
    category: .competitor,
    title: "achievement.comebackSeries.title",
    description: "achievement.comebackSeries.desc",
    icon: "arrow.triangle.turn.up.right.diamond.fill",
    evaluate: { event, state in
        // event: .seriesWon, state'ten önceki seri durumunu kontrol et
        // 0-1 geriden gelip seri kazandıysa → 1.0
    }
)
```

**Nasıl:** `AchievementEngine` init'te `GameEvents.shared.stream()` dinlemeye başlar.
Her olayda tüm kilitli başarımları değerlendirir. İlerleme `AchievementState`'e yazılır.
Kazanım anında `.achievementUnlocked` olayı emit edilir → UI toast'ı tetiklenir.

### 4c — Başarım UI

**Ne:** Galeri, rozetler, toast bildirimi, ilerleme çubukları.

**Yeni dosyalar:**
```
SimVersus/Features/Achievements/AchievementGalleryView.swift → kategori grid, kilitli/açık rozet
SimVersus/Features/Achievements/AchievementToast.swift       → kazanım anı toast'ı
```

**Nasıl:** `AchievementGalleryView` ana ekrandan veya özel sekmeden erişilir.
`AchievementToast` `.overlay` ile root view'da gösterilir; `GameEvents`'ten `.achievementUnlocked`
olayı gelince 3 sn görünür, sonra solar. Rozetler SF Symbol tabanlı, `TeamBadgeView` estetiğinde.

### 4d — Meydan okuma kodu

**Ne:** Backend'siz viral sistem. CONSTITUTION §4.17'ye tabi.

**Yeni dosyalar:**
```
SimVersus/Core/Models/ChallengeCode.swift       → encode/decode, Base32, "SV-XXXXXXXX" formatı
SimVersus/Features/Home/ChallengeEntryView.swift → kod giriş alanı, "Meydan Okumaya Katıl"
SimVersus/Features/Result/ChallengeShareView.swift → meydan okuma oluşturma + share sheet
```

**ChallengeCode (encode/decode):**
```swift
struct ChallengeCode {
    let senderTeam: ChallengeTeamSnapshot  // id, name, short, primary, secondary, badgeShape, pattern, stats, masteryLevel
    let arenaMode: String                  // "standard" (Faz 5: chaos, slowMo...)
    let seed: UInt64
    let matchDuration: TimeInterval
    let timestamp: Date

    func encode() -> String                // → "SV-8K4P2X" (8 char Base32 + prefix)
    static func decode(_ string: String) -> ChallengeCode?
}
```

**Nasıl (mevcut altyapıyla):**
- Base32 karakter seti: `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (benzer karakterler çıkarılmış)
- 8 karakter = 40 bit → seed ve config için yeterli
- `encode()`: JSON → Data → Base32 → "SV-" + ilk 8 char + checksum (son 1 char)
- URL scheme: `arena30://challenge/SV-8K4P2X` → `Info.plist`'te `CFBundleURLSchemes` tanımlanır
- Deep link: `SimVersusApp.onOpenURL` veya `ScenePhase.onChange` ile yakalanır

### 4e — Paylaşım kartları

**Ne:** Maç / şampiyonluk / başarım görselleri. Her kartta meydan okuma kodu gömülüdür.

**Yeni dosyalar:**
```
SimVersus/Features/Share/ShareCardRenderer.swift → UIImage render: arena tasarım dilinde kart
```

**Nasıl:** `ImageRenderer` ile SwiftUI view'ından `UIImage` üretilir.
- Maç sonuç kartı: skor + orb'lar + gol dakikaları + maç ödülleri + altta meydan okuma kodu
- Şampiyonluk kartı: kupa + takım + format + bracket özeti + meydan okuma kodu
- Başarım kartı: rozet + başarım adı + tarih + meydan okuma kodu

### Faz 4 kabul kriteri

- [ ] `GameEvents` en az 15 olay tipi yayınlıyor; stream API'si çalışıyor
- [ ] En az 20 başarım tanımı; en az 15'i davranış odaklı
- [ ] Meydan okuma kodu oluşturma → share sheet → kod girme → maç oynama uçtan uca
- [ ] URL scheme ile uygulama açılıp meydan okuma başlatılabiliyor
- [ ] Başarım durumu app silinmedikçe kalıcı; migration bozmuyor

---

## Faz 5 — Genişleme

### 5a — Fizik modları (ÖNCE)

**Ne:** 8 fizik modu, her biri `MatchSimulation` parametrelerini değiştirir.
Yeni `MatchConfig` parametresi: `mod: PhysicsMod?`.

**Yeni/değişecek dosyalar:**
```
SimVersus/Core/Models/PhysicsMod.swift          → enum: chaos, slowMo, suddenDeath, powerUpRain,
                                                   turboFinish, giantBall, reverseSpin, wind
SimVersus/Core/Engine/MatchSimulation.swift      → applyMod() metodu
SimVersus/Core/Models/MatchConfig.swift          → mod parametresi eklenecek
```

**Her modun MatchSimulation'da neyi değiştirdiği (gerçek parametrelerle):**

| Mod | Değişiklik | PhysicsConstants etkisi |
|---|---|---|
| `.chaos` | Kütle ×0.7, hız limiti kalkar, restitution ×1.5 | `ballMass`, `speedNormalizationBlend=0`, `ballToWallRestitution` |
| `.slowMo` | time-step ×0.3, süre aynı | `fixedTimeStep` (sadece render'da yavaşlatılır, simülasyon normal hızda) |
| `.suddenDeath` | İlk gol maçı bitirir, max 90 sn | `matchDuration=90`, `isFinished` tetiği ilk golde |
| `.powerUpRain` | Spawn interval 1.5 sn | `powerUpSpawnIntervalRange=1.3...1.7` |
| `.turboFinish` | Son 10 sn: top hızı ×2, arena dönüşü ×1.5 | `targetBallSpeed` geçici override, `arenaRotationSpeed` |
| `.giantBall` | Bir top %40 büyük | `powerUpGrowScale=1.4` (kalıcı, power-up değil) |
| `.reverseSpin` | Arena ters yönde döner | `arenaRotationSpeed` negatif |
| `.wind` | Sabit yönlü kuvvet (0.1× boost) | Tüm toplara her frame `+rüzgarVektörü` |

**Nasıl:** `MatchConfig`'e `mod: PhysicsMod?` eklenir. `MatchSimulation.init` → `mod.apply(to: &self)`.
Tüm modlar seed'li ve deterministik (test edilebilir). `Codable` — meydan okuma koduna gömülebilir.

### 5b — Arena şekilleri (SONRA)

**Ne:** Yeni arena geometrileri. Her şekil 40 seed'lik gol bandı testinden geçer (0.8–2.0).

**Değişecek dosyalar:**
```
SimVersus/Core/Engine/MatchSimulation.swift → processWallOrGoal: arena geometrisi soyutlaması
```

**Nasıl:** `ArenaGeometry` protocol'ü:
```swift
protocol ArenaGeometry {
    func wallBoundary(for position: CGPoint) -> CGFloat     // duvar sınırı mesafesi
    func containsPoint(_ point: CGPoint) -> Bool
    func wallNormal(at position: CGPoint) -> CGPoint
    var goalMouthAngle: CGFloat { get }                     // kale boşluğu açısı
}
```
İlk implementasyon: `CircleArena` (mevcut). Sonra `OvalArena`, `HexArena`, `RectArena`, `DumbbellArena`.

### 5c — Görsel temalar (EN SON)

**Ne:** Arena ve UI görünümü. Fizik sonuçlarını etkilemez, sadece render katmanı.

**Değişecek dosyalar:**
```
SimVersus/Core/Models/ArenaTheme.swift          → enum: night, snow, retro, space, fire
SimVersus/Core/Engine/MatchScene.swift           → tema parametrelerine göre render
```

### Faz 5 kabul kriteri

- [ ] 8 fizik modu tanımlı, hepsi deterministik ve test edilebilir
- [ ] Her mod için 20 seed'lik gol bandı testi geçti
- [ ] Mod + şekil + tema kombinasyonları çökmesiz
- [ ] `Codable` uyumu: mod meydan okuma koduna gömülebiliyor

---

## Faz 6 — Çok Oyunculu (Game Center)

### 6a — Game Center auth + eşleştirme

**Ne:** GC girişi, rastgele eşleşme, arkadaş daveti.

**Yeni dosyalar:**
```
SimVersus/Core/Multiplayer/GCMatchmaker.swift → GKMatchmakerViewController, GKMatchmaker
SimVersus/Features/Multiplayer/OnlineLobbyView.swift → eşleşme ekranı
```

**Nasıl:** `GKLocalPlayer.local.authenticateHandler` → auth. Rastgele eşleşme: `GKMatchmaker.shared().findMatch(for: request)`.
Davet: `GKMatchmakerViewController` + iMessage/AirDrop.

### 6b — Online maç akışı

**Ne:** `MatchAgreement` protokolü: iki cihaz takım seçimi + seed + config paylaşır, maçı lokal oynatır.
Ağ trafiği sadece başlangıçta; maç sırasında trafik YOK.

**Yeni dosyalar:**
```
SimVersus/Core/Multiplayer/MatchAgreement.swift → Codable: homeTeam, awayTeam, seed, config, playerIDs
```

**Protokol:**
1. Host (alfabetik küçük playerID) → takım seçer → seed üretir → `MatchAgreement` gönderir
2. Guest → takım seçer → `MatchAgreement`'i onaylar
3. İki cihaz → aynı `MatchConfig` + seed ile `MatchSimulation` başlatır → lokal render
4. Sonuç → iki cihazda birebir aynı (determinizm sayesinde)

### 6c — Online maç sonrası

**Ne:** Online rövanş, geçmiş entegrasyonu, online başarımlar.

**Nasıl:** `MatchRecord`'a `opponentPlayerID: String?` eklenir. Geçmişte "vs [rakip GC adı]" görünür.
Online rövanş: aynı `GKMatch` üzerinden yeniden `MatchAgreement`.

### Faz 6 kabul kriteri

- [ ] İki gerçek cihazda rastgele + davet eşleşmesi çalışıyor
- [ ] Aynı maç iki ekranda aynı skorla bitiyor
- [ ] Kopma senaryoları çökmesiz
- [ ] Online maç geçmişe kaydediliyor
- [ ] Online rövanş akışı çalışıyor

---

## Bilinçli olarak kapsam dışı

Bu özellikler ChatGPT ürün analiziyle birlikte değerlendirilmiş ve **bilinçli olarak elenmiştir:**

| Özellik | Elenme nedeni |
|---|---|
| Sunucusuz küresel sıralama | Sahte rekabet hissi — CONSTITUTION §4.16 ihlali |
| Sohbet / sosyal ağ | Teknik kapsam dışı; oyunun temiz kimliğini bozar |
| Kullanıcı takımı pazarı | Backend gerektirir; bağımlılık ilkesi ihlali |
| Sezon / lig sistemi | Sürekli içerik gerektirir; tek geliştirici için sürdürülemez |
| AI canlı yorumcu | Harici API bağımlılığı; CONSTITUTION §2 ihlali. Kural tabanlı anlatım yeterli (Faz 3.5b) |
| Pay-to-win stat | CONSTITUTION §4.15 ihlali: ustalık ödülleri performans avantajı sağlamaz |
| Top kontrolü | CONSTITUTION §4.1 ihlali: spectator-only |
| Para birimi / sandık / gacha | Karmaşa ve karanlık pattern; oyunun temiz kimliğini bozar |
| RevenueCat / 3. parti IAP | CONSTITUTION §2 ihlali: StoreKit 2 yeterli |
| Backend / Firebase / Supabase | CONSTITUTION §2 ihlali: her şey lokal + GC |
| Çift kale | CONSTITUTION §4.4: tek kale boşluğu kalıcı |
| Oyuncu diski / 5v5 | CONSTITUTION §6: terk edilmiş yön |
