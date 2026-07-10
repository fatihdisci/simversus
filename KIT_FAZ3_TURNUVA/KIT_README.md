# KIT FAZ 3 — TURNUVA (v1.3)

Hedef: Python Grand Prix formatının Swift'e taşınması — grup + eleme turnuvaları, bracket UI, büyük formatların rewarded ile kilidi.

| Parça | İçerik | Bağımlılık |
|---|---|---|
| 3a | Turnuva motoru: fixture üretimi, grup + eleme mantığı, durum makinesi | Faz 2 |
| 3b | Bracket/grup UI + turnuva akışı (maçlar sırayla oynanır/izlenir) | 3a |
| 3c | Şampiyonluk ekranı + büyük format rewarded kilidi | 3b |
| 3d | Roster genişlemesi: tier 2 takımların açılması (16 takım) | 3b |

## Format tanımları (sabit)

| Format | Takım | Yapı | Erişim |
|---|---|---|---|
| Mini Kupa | 4 | Tek eleme (yarı final + final) | Ücretsiz |
| Klasik Kupa | 8 | Tek eleme | Ücretsiz |
| Grup + Eleme | 8 | 2 grup × 4, ilk 2 → yarı final | Rewarded (turnuva başına 1 izleme) |
| Büyük Turnuva | 16 | 4 grup × 4, ilk 2 → çeyrek final | Rewarded |

## Faz kabul kriteri
- 16 takım tüm modlarda kullanılabilir; Büyük Turnuva (16) gerçek 16 preset ile oynanabiliyor
- 4 formatın hepsi uçtan uca oynanabiliyor, yarıda bırakılan turnuva kaldığı yerden devam ediyor (SwiftData persist)
- Turnuva maçları da interstitial sayacına dahil (her maç = 1 sayaç artışı; turnuva içinde maksimum 1 interstitial/3 maç kuralı aynen)
