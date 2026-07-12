# Plan: Faz 3W — Dünya Arenası 2026 / 48 Takımlı Uluslar Turnuvası

## Context

Mevcut turnuva sistemi 4 formatta (mini/classic/groupKO/grand) max 16 takım
destekliyor. 48 uluslu özel turnuva için motorun generic hale getirilmesi ve
milli takım veri katmanının eklenmesi gerekiyor. Bu, Faz 3'ün kapsamını
genişleten bir yan özelliktir; mevcut kulüp turnuvaları bozulmamalı.

## Audit Bulguları

### Kritik sorunlar (önce düzeltilmeli)

| # | Sorun | Dosya:Satır | Etki |
|---|---|---|---|
| 1 | **Swift Hasher ile seed** | `TournamentEngine.swift:141-147` | Uygulama yeniden açıldığında aynı turnuvada farklı sonuçlar üretir. FNV-1a 64-bit ile değiştirilmeli. |
| 2 | **"TBD" magic string bracket** | `TournamentEngine.swift:107,118` | İlk bulunan TBD slotuna sırayla doldurur. 32 takım bracket'ta hangi kazananın hangi slotta olduğunu garanti etmez. `FixtureSlotSource` enum'ı ile değiştirilmeli. |
| 3 | **Knockout beraberlik çözümü yok** | `TournamentBracketView.swift:364` | `homeScore >= awayScore ? home : away` — yazı-tura. Deterministik seeded penalty resolver eklenmeli. |
| 4 | **TournamentState schemaVersion yok** | `TournamentState.swift:11-32` | Yeni alanlar eklenince eski kaydedilmiş turnuvalar çöker. |
| 5 | **Group standings tiebreak zayıf** | `TournamentEngine.swift:195-202` | Sadece Puan > GD > GF. Head-to-head, wins count, seeded tiebreak yok. |

### Mevcut mimari kısıtlar

| # | Konu | Dosya | Açıklama |
|---|---|---|---|
| 6 | TournamentFormat enum'u switch'leniyor | `TournamentFormat.swift`, `TournamentBracketView.swift:121` | `.world2026` eklemek tüm switch'leri güncellemeyi gerektirir. |
| 7 | Grup harfleri hardcoded | `BracketView.swift:121` | `["A","B","C","D"]` — 12 grup için genellenmeli. |
| 8 | Milli takım modeli yok | — | Mevcut Team modeli şehir kulüpleri için; milli takımlar için `NationalTeamDefinition` + adapter gerekiyor. |
| 9 | Simülasyon MainActor'da | `BracketView.swift:296` | 72 grup maçını tek tek await'lemek UI'ı bloke eder. Batch headless simülasyon gerekli. |

---

## Mimari Kararlar

### A1: TournamentDefinition (veri odaklı)

`TournamentFormat` enum'una dokunmadan, yeni bir `TournamentDefinition` struct'ı
eklenir. Mevcut formatlar için adapter oluşturulur. Bu sayede:

- Mevcut mini/classic/groupKO/grand çalışmaya devam eder
- `.world2026` switch case'i eklenmez
- Gelecekteki özel turnuvalar (Euro, Libertadores vb.) sadece JSON ile eklenebilir

```swift
struct TournamentDefinition: Codable, Identifiable {
    let id: String            // "world2026"
    let kind: TournamentKind  // .nations2026
    let displayNameKey: String
    let teamCatalogID: String // "national_teams_2026"
    let pots: [[String]]      // seed torbası
    let groups: [GroupDef]    // 12 grup tanımı
    let knockout: KnockoutDef // bracket yapısı
    let branding: BrandingDef
}
```

### A2: NationalTeamDefinition + adapter

Mevcut `Team` modeli değişmez. `NationalTeamDefinition` ayrı bir struct'tır,
`.asTeam` adapter'ı ile `MatchSimulation`'a beslenir.

### A3: TournamentSeedDeriver (FNV-1a)

`Hasher` kullanımı kaldırılır, yerine FNV-1a 64-bit konur:

```swift
enum TournamentSeedDeriver {
    static func derive(tournamentSeed: UInt64, fixtureID: String) -> UInt64
}
```

### A4: FixtureSlotSource (TBD yerine)

```swift
enum FixtureSlotSource: Codable, Equatable {
    case team(String)
    case groupRank(groupIndex: Int, rank: Int)
    case bestThirdPlace(rank: Int)
    case winner(of: String)     // fixtureID
    case pending
}
```

`Fixture`'a `homeSource`/`awaySource` eklenir (mevcut `homeTeamID`/`awayTeamID` ile
birlikte, backward-compatible).

### A5: KnockoutResolution

```swift
struct KnockoutResolution {
    let matchResult: MatchResult
    let resolution: MatchResolution  // .regulation | .extraTime | .penalties
    let homePenaltyScore: Int?
    let awayPenaltyScore: Int?
    let winnerTeamID: String         // NEVER nil
}
```

Seed'li deterministic penalty: fixture seed'inden türetilen FNV-1a hash ile 5'er
penaltı simüle edilir. Eşitlikte sudden death.

### A6: 104 maç performans stratejisi

Tüm 104 maç tek seferde simüle EDİLMEZ. Akış:
1. Oyuncunun grubundaki maçlar önce resolve edilir (5 diğer maç headless)
2. Oyuncunun maçı render edilerek oynanır
3. Aynı matchday'deki diğer grup maçları batch headless
4. Tüm grup maçları bittiğinde grup sıralaması + en iyi üçüncüler hesaplanır
5. Bracket aşamalı olarak resolve edilir (oyuncu ilerledikçe)

`MatchSimulation.runToCompletion()` zaten headless. Her simülasyon ~0.01sn.
72 grup maçı < 1 saniyede biter.

### A7: Schema versioning

`TournamentState`'a `schemaVersion: Int` eklenir (şu an = 1). Eski turnuvalar
versiyonsuzsa (nil) → v1 kabul edilir, migration yapılmaz.

---

## Uygulama Planı (6 Commit)

### Commit 1: Deterministik seed + knockout slot düzeltmeleri

**Yeni dosyalar:**
- `Core/Engine/TournamentSeedDeriver.swift` — FNV-1a 64-bit
- `Core/Models/FixtureSlotSource.swift` — enum + Fixture'a homeSource/awaySource

**Değişen dosyalar:**
- `Core/Engine/TournamentEngine.swift` — deriveSeed → TournamentSeedDeriver kullanır, advanceKnockout FixtureSlotSource bazlı
- `Core/Models/Fixture.swift` — homeSource/awaySource eklendi (optional, backward-compatible), homeTeamID/awayTeamID computed
- `Core/Models/TournamentState.swift` — schemaVersion eklendi
- `Features/Tournament/TournamentBracketView.swift` — TBD kontrolleri FixtureSlotSource kontrolleriyle değişir

**Testler:**
- `TournamentSeedDeriverTests.swift` — stabilite, uniqueness, normalizasyon

### Commit 2: Milli takım kataloğu + doğrulama

**Yeni dosyalar:**
- `Core/Models/NationalTeamDefinition.swift` — model + asTeam adapter
- `Core/Data/NationalTeamStore.swift` — JSON loader
- `Resources/national_teams_2026.json` — 48 takım
- `Core/Models/TournamentDefinition.swift` — veri odaklı turnuva tanımı
- `Core/Models/TournamentKind.swift` — .standard | .nations2026
- `Core/Models/GroupDefinition.swift` — grup yapısı
- `Core/Engine/TournamentDefinitionAdapter.swift` — TournamentFormat -> TournamentDefinition dönüşümü

**Ülke verisi:** 48 ülke, 6 konfederasyon, UEFA ağırlıklı (16), her kıtadan temsili. Renkler bayraklardan esinlenmiş ama birebir pantone DEĞİL. İsimler İngilizce ISO standardı. TR karşılıklar String Catalog'da.

**Testler:**
- `NationalTeamStoreTests.swift` — 48 takım, unique ID/shortCode, valid hex/colors, stat budget=9

### Commit 3: 48 takım grup motoru + knockout resolution

**Yeni dosyalar:**
- `Core/Engine/GroupStageEngine.swift` — 12 grup × 4 takım, round-robin fixture generate, best-third ranking
- `Core/Engine/KnockoutResolver.swift` — deterministic penalty, extra time simülasyonu

**Değişen dosyalar:**
- `Core/Engine/TournamentEngine.swift` — bestThirdPlaceRanking(), generateFixtures(def:), groupStandings tiebreak güncellemesi
- `Core/Models/FixtureResult.swift` — resolution, homePenaltyScore, awayPenaltyScore eklendi

**Testler:**
- `GroupGenerationTests.swift` — 12 grup, 4 takım/grup, 72 fixture
- `BestThirdPlacedTests.swift` — 8 qualify, sıralama kuralları
- `KnockoutResolutionTests.swift` — deterministic winner, penalty determinism

### Commit 4: Bracket R32 + en iyi üçüncüler

**Yeni dosyalar:**
- `Core/Engine/WorldBracketResolver.swift` — 32 takım bracket (R32, R16, QF, SF, F), aynı gruptan gelenler ilk turda eşleşmez

**Değişen dosyalar:**
- `Core/Engine/TournamentEngine.swift` — 32-team bracket slot çözümleme
- `Core/Models/Fixture.swift` — round naming (R32, R16, etc.)

**Testler:**
- `WorldBracketTests.swift` — 32 qualifier, round fixture counts, winner propagation, same seed stability

### Commit 5: World Arena UI akışı

**Yeni dosyalar:**
- `Features/Tournament/WorldArenaLobbyView.swift` — intro + turnuva bilgisi
- `Features/Tournament/NationalTeamPickerView.swift` — flag + search + seçim
- `Features/Tournament/WorldGroupStageView.swift` — horizontal group pager A-L
- `Features/Tournament/WorldBracketView.swift` — 32-team round-based bracket
- `Features/Tournament/WorldChampionView.swift` — şampiyonluk ekranı

**Değişen dosyalar:**
- `App/AppRoute.swift` — world arena rotaları
- `App/RootView.swift` — route handling
- `Features/Home/HomeView.swift` — "Dünya Arenası 2026" kartı
- `Features/Tournament/TournamentLobbyView.swift` — Special Tournaments section
- `Resources/Localizable.xcstrings` — tüm world arena string'leri TR/EN

### Commit 6: World Arena testleri + lokalizasyon + legal

**Yeni dosyalar:**
- `SimVersusTests/WorldArenaTests.swift` — full tournament (20 seed), persistence, resume
- `SimVersusTests/WorldDrawTests.swift` — deterministic draw, pot dağılımı
- `Resources/Flags/` — flag asset'leri (basit SVG/PDF veya SwiftUI shape)

**Değişen dosyalar:**
- `Resources/Localizable.xcstrings` — disclaimer (TR/EN), tüm eksik string'ler
- `SimVersus/Info.plist` — gerekirse yeni URL scheme

---

## Branding / Güvenlik

- ❌ FIFA, World Cup, resmi logo, resmi kupa, maskot, federasyon arması
- ✅ "Dünya Arenası 2026" / "World Arena 2026"
- ✅ Soyut badge shape'ler (mevcut 5 shape)
- ✅ Ülke bayrakları (basit geometrik veya SwiftUI shape)
- ✅ Ülke renklerinden esinlenmiş renkler (birebir pantone değil)
- ✅ Disclaimer: "Bağımsız bir futbol simülasyonudur. Herhangi bir resmî organizasyonla bağlantılı değildir."
- ✅ CONSTITUTION §4.2: hayvan/simge figürleri YOK

---

## Verification

1. `xcodebuild clean build` — temiz derleme
2. Tüm mevcut testler (24 adet) + yeni testler
3. TR/EN tüm yeni string'ler String Catalog'da
4. Mevcut turnuva akışı (mini/classic/groupKO/grand) bozulmamış
5. Eski kaydedilmiş TournamentState yüklenebiliyor
6. Aynı seed ile aynı turnuva sonuçları (determinizm)
7. 48 takımın hepsi unique ID, unique shortCode, valid renk, valid stats
8. Branding kontrolleri (FIFA geçmiyor, resmi logo yok, disclaimer var)

---

## Bilinen Sınırlamalar

- Confederation constraint (örn. aynı grupta max 2 UEFA takımı) uygulanmaz.
  Kod yorumunda simplified draw olduğu belirtilir.
- Resmi 495 kombinasyonlu eşleşme tablosu kullanılmaz; uygulamaya ait
  deterministic bracket resolver kullanılır.
- Milli takım forma desenleri mevcut 5 `KitPattern` ile sınırlıdır.
- Turnuva kaydedilip resume edildiğinde fixture seed'leri FNV-1a sayesinde
  stabildir ancak SwiftData migration'da eski turnuvalar kaybolmaz.
