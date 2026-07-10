# PARÇA 3a — Turnuva Motoru (UI'sız, saf mantık)

**Önce oku:** CONSTITUTION.md, KIT_README.md (format tablosu)

## Amaç
UI'dan tamamen bağımsız, test edilebilir turnuva durum makinesi. Bracket UI (3b) bunun üstüne oturur.

## Kapsam
1. `Core/Tournament/TournamentFormat.swift`: 4 format enum'u (miniCup4, classicCup8, groupKnockout8, grand16) + her formatın yapı tanımı (grup sayısı, grup boyutu, eleme turları).
2. `Core/Tournament/Tournament.swift`: SwiftData `@Model` — format, katılımcı takım ID'leri, fixture listesi, oynanan maç sonuçları, mevcut aşama, tamamlanma durumu, createdAt, seed (turnuva seed'i → her maçın seed'i deterministik türetilir: `SplitMix64(tournamentSeed).next()` zinciri).
3. `Core/Tournament/TournamentEngine.swift`:
   - `nextMatch() -> MatchConfig?`: sıradaki oynanacak maç (grup fikstürü round-robin; eleme bracket eşleşmeleri)
   - `record(result:)`: sonucu işler, grup puan tablosunu günceller (3p/1p/0p, averaj, atılan gol tiebreak; hâlâ eşitse seed'li coin flip), aşama geçişlerini tetikler
   - Eleme maçında beraberlik: uzatma YOK, doğrudan seed'li penaltı simülasyonu (5+sudden death, her vuruş %75 gol olasılığı, seed'li RNG) — `PenaltyShootout.swift` ayrı, saf fonksiyon
   - `standings(group:)`, `bracket()` sorguları
4. Takım seçimi: kullanıcı formata göre takım seçer VEYA "otomatik doldur" (preset + özel takımlardan rastgele, seed'li).
5. Kapsamlı unit test: her 4 format için tam turnuva simülasyonu (motor maç sonuçlarını doğrudan `MatchResult` mock'larıyla besleyerek), aşama geçişleri, tiebreak senaryoları, penaltı determinizmi.

## Kabul kriterleri
- [ ] 4 formatın hepsi testte uçtan uca tamamlanıyor
- [ ] Aynı turnuva seed'i = aynı fixture + aynı penaltı sonuçları
- [ ] Grup tiebreak kuralları test edilmiş
- [ ] Motor hiçbir UI/SpriteKit tipine referans vermiyor (saf mantık)

## DO NOT TOUCH / YAPMA
- UI EKLEME (3b)
- MatchScene'e dokunma — motor MatchConfig üretir, sonucu tüketir, o kadar
- Rewarded kilit (3c)
