# PARÇA 3c — Şampiyonluk Ekranı + Rewarded Format Kilidi

**Önce oku:** CONSTITUTION.md (§4.3), DESIGN_TOKENS.md, I18N_RULES.md
**Bağımlılık:** 3b tamamlanmış olmalı.

## Amaç
Turnuva finali sonrası kutlama ekranı ve büyük formatların rewarded ad kilidi.

## Kapsam
1. `Features/Tournament/ChampionView.swift`:
   - Şampiyon badge büyük, `champion.title %@`, konfeti partikülü (SKEmitter veya Canvas; Reduced Motion'da statik)
   - Turnuva özeti: toplam gol, en farklı skor, şampiyonun yolu (yendiği rakipler)
   - CTA: `champion.newTournament`, `champion.home`
   - Turnuva `MatchRecord`'ları geçmişte turnuva etiketiyle görünür (2c entegrasyonu: `MatchRecord`'a optional `tournamentID` alanı migration ile eklenir)
2. Rewarded kilit (2b altyapısı yeniden kullanılır):
   - Ücretsiz: Mini Kupa (4), Klasik Kupa (8)
   - Kilitli: Grup+Eleme (8), Büyük Turnuva (16) — **turnuva başına 1 rewarded izleme** (kalıcı satın alma DEĞİL; her yeni kilitli turnuva kurulumunda 1 izleme)
   - Setup ekranındaki DEBUG flag kaldırılır, kilit UI'ı gerçek akışa bağlanır
   - isAdFree kullanıcıda da rewarded akışı geçerli (CONSTITUTION §4.3)
3. Stringler (TR+EN): `champion.title %@` (%@ Şampiyon! / %@ are Champions!), `champion.newTournament`, `champion.home`, `champion.path` (Şampiyonluk Yolu / Road to Glory), `tournament.locked.cta` (Reklam İzle ve Başlat / Watch Ad to Start), `tournament.locked.note`.

## Kabul kriterleri
- [ ] Final bitince ChampionView otomatik açılıyor, özet doğru
- [ ] Kilitli format rewarded izlenmeden başlatılamıyor; izlenince o turnuva başlıyor
- [ ] Reduced Motion'da konfeti yok, ekran yine anlamlı
- [ ] SwiftData migration sorunsuz (mevcut geçmiş kayıtları bozulmuyor)

## DO NOT TOUCH / YAPMA
- Format yapılarını değiştirme
- Interstitial mantığına dokunma
- Kalıcı format satın alması ekleme (bilinçli karar: turnuva başına izleme)
