# PARÇA 4a — GameEvents + Başarım Motoru (UI'sız)

**Önce oku:** CONSTITUTION.md (§4.6 GameEvents), I18N_RULES.md

## Amaç
Merkezi oyun olayı yayıncısı + tamamen lokal, olay tabanlı, test edilebilir başarım motoru. UI 4b'de.

## Kapsam
1. `Core/Events/GameEvents.swift`: tekil yayıncı (Combine `PassthroughSubject` veya `AsyncStream`). Olaylar:
   - `matchCompleted(MatchResult, MatchContext)` — context: single/tournament, kullanılan takımlar, özel takım mı, mod (Faz 5 sonrası)
   - `goalScored(minute:Int, teamID:String)`
   - `tournamentWon(format:TournamentFormat, byTeamID:String, isCustomTeam:Bool)`
   - `customTeamCreated`
   - İleri uyumluluk: enum non-frozen tasarla; Faz 6 `onlineMatchCompleted` eklenecek
2. Mevcut kod entegrasyonu: MatchScene/ResultView, TournamentEngine, TeamCreator ilgili noktalarda olay yayınlar (feature mantığı DEĞİŞMEZ, yalnızca yayın satırları eklenir).
3. `Core/Achievements/AchievementDefinition.swift`: statik katalog — id, kademe (bronze/silver/gold), gizli mi, ilerleme hedefi (tekil veya sayaçlı), tetikleyici (olay + koşul closure'u). Başlangıç seti (~20):
   - **Maç sayısı:** İlk Maç (b) · 10 Maç (b) · 50 Maç (s) · 100 Maç (g)
   - **Skor/anlar:** 5+ Farkla Galibiyet (s) · Gol Yemeden Kazan (b) · 90. Dakika Golü (s) · Tek Maçta 8+ Toplam Gol (s)
   - **Turnuva:** İlk Şampiyonluk (b) · Her Formatı Kazan (g) · Namağlup Şampiyonluk (g, tüm turnuva maçları galibiyetle)
   - **Özel takım:** İlk Özel Takım (b) · Özel Takımla Şampiyonluk (s)
   - **Koleksiyon:** 16 Preset Takımın Hepsiyle En Az 1 Maç (g)
   - **Gizli (3):** "Sıfır-Sıfır" (0-0 biten maç izle) · "Rövanş Ustası" (aynı rakibe karşı 3 rövanş üst üste kazan) · "Gece Kuşu" (00:00–04:00 arasında maç bitir)
4. `Core/Achievements/AchievementEngine.swift`: olayları dinler, koşulları değerlendirir, sayaçları günceller, kazanımı persist eder (SwiftData `@Model AchievementState`: id, progress, unlockedAt). Kazanım anında `achievementUnlocked` yayını (4b toast'ı dinleyecek).
5. Unit testler: her başarım için sentetik olay dizisiyle kazanım testi; çifte kazanım imkânsızlığı; sayaç persist.
6. Stringler: her başarım için `achievement.<id>.title` + `achievement.<id>.desc` TR+EN (gizliler için ek `achievement.hidden.placeholder` = "???"). Katalog formatında eksiksiz ekle.

## Kabul kriterleri
- [ ] 20 başarımın tamamı testte sentetik olaylarla kazanılabiliyor
- [ ] Feature kodlarında yayın satırları dışında değişiklik yok (diff kontrolü)
- [ ] Kazanımlar restart sonrası kalıcı, çifte kazanım yok
- [ ] Tüm başarım stringleri iki dilde katalogda

## DO NOT TOUCH / YAPMA
- UI EKLEME (4b)
- Game Center achievement API'si KULLANMA
- Mevcut motor/turnuva mantığında yayın dışı değişiklik
