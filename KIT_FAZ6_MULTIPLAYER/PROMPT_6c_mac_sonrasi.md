# PARÇA 6c — Maç Sonrası + Entegrasyon

**Önce oku:** CONSTITUTION.md, I18N_RULES.md
**Bağımlılık:** 6b tamamlanmış olmalı.

## Amaç
Online maç sonrası deneyim: rövanş, geçmiş entegrasyonu, online başarımlar, GC leaderboard.

## Kapsam
1. **Online Result ekranı:** standart Result + rakip GC adı + `mp.rematch.offer` CTA:
   - Rövanş teklifi karşı tarafa `GKMatch` üzerinden gider; kabul → yeni agreement (AYNI takımlar, YENİ host seed'i); ret/timeout(20sn)/kopmuş rakip → CTA disabled `mp.rematch.unavailable`
2. **Geçmiş entegrasyonu:** `MatchRecord`'a `isOnline: Bool` + `opponentAlias: String?` (migration). HistoryView'da online rozeti; StatsView'a online O-G-B-M satırı.
3. **Online başarımlar** (4a motoruna yalnızca tanım + olay eklenir):
   - `GameEvents`e `onlineMatchCompleted(won:Bool, opponentAlias:String)` olayı (6b Result noktasından yayınlanır)
   - Yeni tanımlar: İlk Online Maç (b) · İlk Online Galibiyet (b) · 10 Online Galibiyet (s) · 3 Rövanş Serisi Kazan (g, aynı rakibe üst üste) · 25 Online Maç (s)
   - Stringler TR+EN katalogda
4. **GC Leaderboard (tek):** `simversus.online.wins` — toplam online galibiyet. Kazanım anında `GKLeaderboard.submitScore`; lobby'e `mp.leaderboard` girişi (`GKGameCenterViewController` ile sistem UI). App Store Connect leaderboard kaydı `RELEASE_TODO.md`'ye eklenir.
5. Paylaşım: online maç kartında rakip GC adı (4c renderer'a küçük ek — rakip adı izinsiz sorun değil, GC takma adıdır; yine de karta yalnızca takma ad yazılır, gerçek ad ASLA).

## Kabul kriterleri
- [ ] Rövanş akışı çift yönlü çalışıyor (teklif/kabul/ret/timeout)
- [ ] Online maçlar geçmişte doğru etiketle; istatistikler ayrışıyor; migration eski kayıtları bozmuyor
- [ ] 5 online başarım sentetik olay testleriyle kazanılabiliyor
- [ ] Leaderboard'a skor gidiyor, sistem UI açılıyor
- [ ] GC'siz kullanıcıda hiçbir regresyon yok (tam single-player smoke test)

## DO NOT TOUCH / YAPMA
- AchievementEngine çekirdeğini değiştirme (yalnızca tanım + olay ekle)
- Birden fazla leaderboard/sezonluk leaderboard EKLEME (tek, kümülatif)
- ELO/rank sistemi kurma (bilinçli olarak yok — casual konumlandırma)
