# PARÇA 1d — Akış Entegrasyonu + Sonuç Ekranı

**Önce oku:** CONSTITUTION.md, I18N_RULES.md
**Bağımlılık:** 1b ve 1c tamamlanmış olmalı.

## Amaç
Uçtan uca akış: Home → TeamSelect → Match → Result → (Rövanş | Yeni Maç | Ana Menü).

## Kapsam
1. `App/` altında `NavigationStack` tabanlı route enum'u (`AppRoute: home, teamSelect, match(MatchConfig), result(MatchResult, MatchConfig)`).
2. HomeView `home.play` → TeamSelect. TeamSelect `onStart` → yeni `MatchConfig` (seed: `UInt64.random`) → MatchView.
3. MatchView `onMatchEnded` → ResultView'a geç; `AppState.matchesPlayedCount += 1` (1e'nin interstitial sayacı bunu okuyacak).
4. `Features/Result/ResultView.swift`:
   - Büyük skor, iki badge, kazanan metni `result.winner %@` / `result.draw`
   - Gol dakikaları listesi (dakika + takım kısa kodu, kronolojik)
   - 3 aksiyon: `result.rematch` (aynı takımlar, YENİ seed), `result.newMatch` (TeamSelect'e), `result.home`
5. Maç sırasında geri swipe/dismiss engellenir (maç yarıda bırakılırsa sonuç kaydedilmez, MVP'de basitçe kilitle).
6. Result ekranından çıkışta `AdGate.onResultDismiss()` çağrısı için boş bir protokol/stub bırak (`Core/Monetization/AdGate.swift`, no-op) — 1e dolduracak.

## Kabul kriterleri
- [ ] Uçtan uca akış iki dilde de sorunsuz
- [ ] Rövanş farklı seed ile farklı maç üretiyor
- [ ] matchesPlayedCount doğru artıyor ve app restart'ta korunuyor
- [ ] Maç ekranında yanlışlıkla geri çıkılamıyor

## DO NOT TOUCH / YAPMA
- AdMob/StoreKit EKLEME — sadece AdGate stub'ı
- MatchScene fizik koduna dokunma
- PhysicsConstants değiştirme
