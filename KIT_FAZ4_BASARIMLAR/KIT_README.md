# KIT FAZ 4 — BAŞARIMLAR + MEYDAN OKUMA + PAYLAŞIM (v1.4)

Hedef: Davranış odaklı başarımlarla retention + meydan okuma kodlarıyla organik büyüme. Paylaşım kartları meydan okuma kodlarından SONRA gelir; çünkü statik görsel tek başına viral döngü değildir — alıcıya eylem sunulmalıdır.

CONSTITUTION §4.10 (GameEvents), §4.17'ye (meydan okuma kodu) tabidir.

---

## Tasarım ilkeleri

- **Tamamen lokal.** Game Center achievements KULLANILMAZ. Durum SwiftData'da.
- **Olay tabanlı.** Başarımlar feature kodlarına dokunmaz; yalnızca `GameEvents` yayınlarını dinler.
- **Davranış > sayaç.** "100 maç izle" tipi pasif sayaçlar ana motivasyon değildir. Onun yerine: "Üç farklı takımla mini kupa kazan", "Bir rövanş serisini 0-1'den çevir", "Beş doğru tahmin yap".
- **Meydan okuma kodu > paylaşım kartı.** Kod, alıcıya bir eylem sunar; kart yalnızca görseldir.
- Rozetler parametrik vektör (TeamBadgeView estetiği), asset yok.

---

## Parça sırası ve bağımlılıklar

| Parça | İçerik | Bağımlılık |
|---|---|---|
| 4a | `GameEvents` olay sistemi: merkezi yayıncı, olay enum'ı | Faz 3.5 (anlatım tetikleyicileri burada birleşir) |
| 4b | Başarım motoru: tanımlar (davranış odaklı), tetikleme, persist, ilerleme | 4a |
| 4c | Başarım UI: galeri, rozetler, kazanım toast'ı, ilerleme çubukları | 4b |
| 4d | Meydan okuma kodu: encode/decode, kod giriş ekranı, paylaşım | Faz 3 (turnuva), 3.5e (takım ustalığı) |
| 4e | Paylaşım kartları: maç / şampiyonluk / başarım görselleri | 4c, 4d |

4a önce kurulur. 4b ve 4d paralel yürütülebilir. 4c (başarım UI) 4b'ye bağlıdır. 4e en son gelir.

---

## Parça detayları

### 4a — GameEvents olay sistemi

Merkezi event bus. Faz 3.5'teki olay anlatımı (`GoalLineClear`, `PostHit`, `ComebackStarted`) da bu sisteme taşınır.

```swift
enum GameEvent {
    // Maç olayları
    case matchCompleted(MatchResult)
    case goalScored(team: Team, minute: Int, matchID: UUID)
    case postHit(team: Team)
    case comebackStarted(team: Team)
    case nearMiss(team: Team, distance: CGFloat)
    
    // Turnuva olayları
    case tournamentWon(format: TournamentFormat, team: Team)
    case tournamentEliminated(format: TournamentFormat, team: Team, round: String)
    case trophyUnlocked(team: Team)
    
    // Tahmin olayları
    case predictionCorrect(predictionType: PredictionType)
    case predictionStreakReached(streak: Int)
    
    // Seri olayları
    case seriesWon(team: Team, opponent: Team)
    case comebackSeriesWin(team: Team, fromScore: String)
    
    // Ustalık olayları
    case teamMasteryLevelUp(team: Team, newLevel: Int)
    case teamStatMilestone(team: Team, stat: String, value: Int)
    
    // Günlük
    case dailyArenaCompleted
    case dailyStreakReached(days: Int)
    
    // Genel
    case appLaunch(count: Int)
    case firstMatchEver
}
```

**Teknik:** `@MainActor` singleton `GameEvents.shared`, `AsyncStream` veya Combine `PassthroughSubject` ile yayın yapar. Başarım motoru, anlatım motoru, ve ileride online istatistikler bu stream'i dinler.

### 4b — Başarım motoru

Davranış odaklı başarımlar. Pasif sayaçlar (örn. "100 maç izle") bilinçli olarak azınlıktadır; ana motivasyon kaynağı yapılmaz.

**Başarım kategorileri ve örnekler:**

| Kategori | Örnek başarımlar |
|---|---|
| **Kaşif** | İlk maç, İlk turnuva, İlk özel takım, Tüm preset takımlarla en az 1 maç, Her turnuva formatını dene |
| **Stratejist** | 3 doğru tahmin üst üste, 5 doğru tahmin üst üste, Tüm tahmin tiplerinde en az 1 doğru |
| **Rekabetçi** | Bir rövanş serisini kazan, 0-1'den seri çevir, 3 maçlık seriyi süpür, Aynı rakibe karşı 5 maçlık üstünlük |
| **Koleksiyoncu** | 3 farklı takımla mini kupa kazan, Her takım arketipiyle turnuva tamamla, 5 kupa kazan, Kendi oluşturduğun takımla kupa kazan |
| **Usta** | Bir takımı Seviye 3 yap, Bir takımı Seviye 5 yap, 3 farklı takımı Seviye 3 yap |
| **Günlük** | 3 gün üst üste günlük arena, 7 gün üst üste günlük arena, Günlük arenada 5 doğru tahmin üst üste |
| **Sosyal** | İlk meydan okuma kodu oluştur, Bir meydan okumayı kabul et ve kazan, 5 farklı kişiye meydan okuma gönder |

**Teknik:**
- Her başarım bir `Achievement` struct'ı: `id`, `category`, `title` (TR/EN), `description` (TR/EN), `icon` (SF Symbol), `progress` (0.0–1.0), `isUnlocked`, `unlockedAt`
- Başarım tanımları `AchievementDefinitions` enum'ında sabit; her tanım kendi `evaluate(_ event: GameEvent, state: AchievementState) -> Double` fonksiyonuna sahip
- Durum SwiftData'da `AchievementState` modelinde persist edilir
- Migration mevcut kayıtları bozmaz

### 4c — Başarım UI

- **Galeri:** Kategori bazlı grid, kilitli/açık rozet görünümü, ilerleme çubuğu
- **Toast:** Başarım kazanıldığında maç/turnuva sonu ekranında kısa animasyonlu bildirim
- **İlerleme:** Kilitli başarımda mevcut durum gösterilir (örn. "2/3 farklı takımla kupa")
- **Rozetler:** SF Symbol tabanlı, TeamBadgeView estetiğinde parametrik vektör
- Navigasyon: Ana ekran veya özel "Başarımlar" sekmesinden erişilir

### 4d — Meydan okuma kodu

Backend gerektirmeyen viral sistem. CONSTITUTION §4.17'ye tabidir.

**Kodun encode ettiği veriler:**
```
ChallengeCode {
    senderTeam: Team + CustomTeam? (görünüm + istatistik)
    arenaMode: ArenaMode (şimdilik: .standard, Faz 5 ile .chaos, .slowMo...)
    seed: UInt64
    matchDuration: MatchDurationOption
    timestamp: Date (kodun oluşturulma zamanı)
}
```

**Kod formatı:** Base32 kodlanmış, 8 karakter: `"SV-8K4P2X"`. `SV-` prefix'i uygulama tanıyıcıdır.

**Akış:**
1. **Oluşturma:** Turnuva kazanıldığında veya takım ustalık seviyesi atladığında "Meydan Okuma Kodu Oluştur" butonu çıkar.
2. **Paylaşma:** Standart iOS share sheet. Paylaşım metni: *"Şampiyonumu yenebilir misin? Meydan okuma: SV-8K4P2X"*
3. **Kabul etme:** Ana ekranda "Meydan Okumaya Katıl" butonu veya URL scheme (`arena30://challenge/SV-8K4P2X`) ile kod girilir.
4. **Oynama:** Alan kişi kendi takımını seçer (kendi oluşturduğu veya preset), gönderenin takımına karşı aynı seed + config ile maç oynanır.
5. **Sonuç:** Alan kişi kazanırsa "Meydan Okuma Tamamlandı!" rozeti; kaybederse "Tekrar Dene" → farklı bir takımla tekrar dene.

**Teknik:**
- `ChallengeCode.encode(ChallengeCode) -> String` ve `ChallengeCode.decode(String) -> ChallengeCode?`
- Deterministik motor zaten var; aynı seed + aynı takımlar = aynı maç
- URL scheme `arena30://` Info.plist'te tanımlanır
- Deep link `AppState` veya `ScenePhase` üzerinden yakalanır

### 4e — Paylaşım kartları

Meydan okuma kodundan sonra gelen ikincil paylaşım kanalı. Statik görseller, ancak meydan okuma koduyla birlikte sunulursa anlamlıdır.

**Kart tipleri:**
- **Maç sonuç kartı:** Skor, takım orb'ları, gol dakikaları, maç ödülleri. Altında meydan okuma kodu.
- **Şampiyonluk kartı:** Kupa, takım, turnuva formatı, bracket özeti. Altında meydan okuma kodu.
- **Başarım kartı:** Rozet, başarım adı, tarih. Altında meydan okuma kodu (varsa).

**Tasarım:** Arena tasarım dilinde, paylaşılabilir `UIImage` render'ı. Her kartta meydan okuma kodu gömülüdür — paylaşılan HER şey alıcıya bir eylem sunar.

---

## Faz kabul kriteri

- [ ] `GameEvents` tüm olay tiplerini yayınlıyor; başarım motoru ve anlatım motoru yayınları dinliyor
- [ ] Temiz kurulumdan "İlk Maç" başarımına, 3 doğru tahmin serisine, ilk turnuva zaferine kadar zincirleme akış çalışıyor
- [ ] En az 20 başarım tanımı var; en az 15'i davranış odaklı (pasif sayaç değil)
- [ ] Meydan okuma kodu oluşturma → share sheet → kod girme → maç oynama akışı uçtan uca çalışıyor
- [ ] URL scheme (`arena30://challenge/...`) ile uygulama açılıp meydan okuma başlatılabiliyor
- [ ] Paylaşım kartı içinde meydan okuma kodu görünüyor
- [ ] Başarım durumu app silinmedikçe kalıcı; migration mevcut kayıtları bozmuyor
- [ ] TR/EN tüm başarım metinleri ve meydan okuma arayüzü doğru
