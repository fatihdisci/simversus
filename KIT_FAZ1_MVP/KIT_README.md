# KIT FAZ 1 — MVP (App Store ilk sürüm)

Hedef: 2 takım seç → dönen arenada spectator maç → sonuç ekranı → 3 maçta 1 interstitial + Reklamsız IAP → App Store.

## Parça sırası ve bağımlılıklar

| Parça | İçerik | Bağımlılık |
|---|---|---|
| 1a | Proje kurulumu, klasör yapısı, design system, i18n altyapısı | — |
| 1b | Takım modeli, teams.json loader, TeamBadgeView, takım seçim ekranı | 1a |
| 1c | SpriteKit maç motoru: dönen arena, fizik, gol, skor, süre | 1a |
| 1d | Akış entegrasyonu: Home → TeamSelect → Match → Result, sonuç ekranı | 1b + 1c |
| 1e | Monetizasyon: AdMob interstitial (3 maçta 1) + StoreKit 2 Reklamsız + UMP | 1d |
| 1f | Cila + App Store hazırlığı: ikon, launch, privacy, review checklist | 1e |

## Her oturumda ajana verilecekler

1. `00_TEMEL/CONSTITUTION.md` (her zaman)
2. Parçanın kendi prompt dosyası
3. Parçanın gerektirdiği temel dosyalar (promptun başında listeli)

## Faz kabul kriteri (1f sonunda)

- Temiz build, sıfır warning, iPhone SE 3 + 15 Pro Max simülatörlerinde test edildi
- TR ve EN cihaz dilinde tüm ekranlar doğru
- 20 seed'lik otomatik maç testi: ortalama gol 2–6 bandında
- Interstitial akışı: 3. maç sonrası gösteriliyor, IAP sonrası gösterilmiyor, restore çalışıyor
