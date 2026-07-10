# PARÇA 2c — Maç Geçmişi + Basit İstatistik

**Önce oku:** CONSTITUTION.md, DESIGN_TOKENS.md, I18N_RULES.md
**Bağımlılık:** Faz 1 (2a/2b'den bağımsız, paralel koşabilir).

## Amaç
Oynanan maçların kaydı ve takım bazlı basit istatistik — retention'ın "birikim hissi" ayağı.

## Kapsam
1. `Core/Models/MatchRecord.swift`: SwiftData `@Model` — homeTeamID, awayTeamID, homeScore, awayScore, goals (dakika+takım, Codable blob), playedAt, seed. Result ekranına gelindiğinde otomatik kaydedilir (yarıda bırakılan maç kaydedilmez).
2. `Features/History/HistoryView.swift`:
   - Kronolojik liste (yeni üstte): iki badge, skor, tarih (`formatted(.relative)`)
   - Satıra dokun → detay: gol dakikaları timeline'ı
   - Boş durum: `history.empty` + oyna CTA'sı
3. `Features/History/StatsView.swift` (History içinde segment/tab):
   - Takım bazlı: O-G-B-M, atılan/yenilen gol, galibiyet yüzdesi (preset + özel takımlar)
   - En gollü maç, toplam maç sayısı
4. Home'a `home.history` girişi ekle.
5. Veri büyümesi: 500 kayıt üstünde en eskiler silinir (sessiz FIFO).
6. Stringler (TR+EN): `home.history` (Geçmiş / History), `history.title`, `history.empty` (Henüz maç oynanmadı / No matches played yet), `history.stats` (İstatistikler / Stats), `stats.played`, `stats.wins`, `stats.draws`, `stats.losses`, `stats.goalsFor`, `stats.goalsAgainst`, `stats.winRate`.

## Kabul kriterleri
- [ ] Her tamamlanan maç kaydediliyor; yarıda bırakılan kaydedilmiyor
- [ ] İstatistikler elle doğrulanan 3 maçlık senaryoda doğru
- [ ] TR/EN tarih formatları locale'e uygun (elle format yok)
- [ ] 500+ kayıt FIFO çalışıyor (test ile)

## DO NOT TOUCH / YAPMA
- Grafik kütüphanesi ekleme (Swift Charts bile YOK — bu fazda sayısal kartlar yeter)
- Paylaşım özelliği (4c'nin işi)
