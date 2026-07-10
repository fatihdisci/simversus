# PARÇA 3b — Turnuva UI + Akış

**Önce oku:** CONSTITUTION.md, DESIGN_TOKENS.md, I18N_RULES.md
**Bağımlılık:** 3a tamamlanmış olmalı.

## Amaç
Turnuva kurma, grup tablosu + bracket görselleştirme, maçları sırayla oynatma akışı.

## Kapsam
1. Home'a `home.tournament` girişi.
2. `Features/Tournament/TournamentSetupView.swift`: format seçimi (4 kart; kilitli formatlar kilit ikonuyla, 3c bağlayacak — şimdilik hepsi açık DEBUG flag'iyle), takım seçimi (manuel çoklu seçim veya `tournament.autofill`), başlat.
3. `Features/Tournament/TournamentHubView.swift` (turnuvanın ana ekranı):
   - Grup aşamasında: grup puan tabloları (O-G-B-M-A-P, sıra vurgusu: çıkanlar accent)
   - Eleme aşamasında: bracket görünümü (yatay scroll, tur sütunları, eşleşme kartları, kazanan ilerler çizgileri)
   - "Sıradaki Maç" kartı: iki badge + `tournament.playNext` CTA → MatchView (mevcut akış yeniden kullanılır) → sonuç motorla `record` edilir → Hub'a dönülür
   - Penaltıyla biten maçta skor yanında `(P 4-3)` gösterimi
4. Devam eden turnuva: Home'da "devam et" kartı (tek aktif turnuva sınırı — yenisi başlatılırken aktif olan varsa onay iste `tournament.abandon.confirm`).
5. Turnuva maçlarında Result ekranı kısaltılır: rövanş/yeni maç yerine tek CTA `tournament.backToHub`.
6. Stringler (TR+EN): `home.tournament` (Turnuva / Tournament), `tournament.setup.title`, `tournament.autofill` (Otomatik Doldur / Auto-fill), `tournament.playNext` (Sıradaki Maçı Oynat / Play Next Match), `tournament.group %@`, `tournament.round.semi/quarter/final`, `tournament.backToHub`, `tournament.abandon.confirm`, `tournament.continue` — tam liste ajan tarafından katalog formatında eklenir.

## Kabul kriterleri
- [ ] 4 takımlı Mini Kupa uçtan uca UI üzerinden oynanabiliyor
- [ ] 16 takımlı bracket okunabilir (iPhone SE dahil)
- [ ] App kill + reopen: turnuva kaldığı maçtan devam
- [ ] Interstitial sayacı turnuva maçlarında da işliyor

## DO NOT TOUCH / YAPMA
- TournamentEngine mantığını değiştirme — hata bulursan 3a'ya not düş, UI'da workaround yapma
- Şampiyonluk animasyonu (3c)
