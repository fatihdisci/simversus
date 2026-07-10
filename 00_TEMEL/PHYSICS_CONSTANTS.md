# PHYSICS_CONSTANTS.md — Kalibrasyon Tablosu (İki Top Sistemi)

> Bu dosyadan `Core/Engine/PhysicsConstants.swift` üretilir (Parça 1c). Değerler başlangıç kalibrasyonudur; ayar yalnızca bu dosya + Swift dosyası birlikte güncellenerek yapılır. Sahne kodunda magic number YASAK.
>
> **Motor notu (1c):** Maç, determinizmin (§11) ve headless test edilebilirliğin gereği olarak **özel deterministik sabit-adımlı bir simülasyonla** (`MatchSimulation`) çalışır; `SKScene` (`MatchScene`) yalnızca render eder. `SKPhysicsBody` yalnızca canlı render döngüsünde, değişken gerçek-zaman dt'siyle adımladığı için "aynı seed = aynı sonuç" ve 20-seed testlerini karşılayamaz. Değerler SpriteKit anlambilimini (restitution, damping, mass, impuls) korur.
>
> **Konsept:** Arena dairesel, sürekli dönüyor, çemberinde TEK bir kale boşluğu (gap) var. Sahada 2 top var: her takımın kendi topu (dairesel, takım renginde, üzerinde badge sembolü). Toplar birbirine ve arena duvarına çarpışır. Bir top gap'ten dışarı çıkarsa → KARŞI takım gol kazanır. Oyuncu diski YOK. Tüm takımlar eşit güçte; ileride power-up sistemi ile geçici boost çarpanı eklenebilir.

## Arena

| Sabit | Değer | Açıklama |
|---|---|---|
| `arenaRadius` | ekran genişliğinin %42'si | Sim-uzayında sabit 160 pt, render'da ölçeklenir |
| `arenaRotationSpeed` | 0.65 rad/s | Arenanın (ve gap'in) sabit dönüş hızı |
| `arenaWallRestitution` | 0.9 | Duvar sekme esnekliği |
| `gapWidth` | 0.18 rad | Kale boşluğunun açısal genişliği |
| `exitMargin` | 14 pt | Topun "çıkmış" sayılması için arenaRadius'u aşması gereken ek mesafe |

## Toplar (dairesel, takım renginde, badge sembollü)

| Sabit | Değer | Açıklama |
|---|---|---|
| `ballRadius` | 30 pt | Dairesel top yarıçapı — üzerinde takımın badge sembolü |
| `ballToBallRestitution` | 0.85 | İki top çarpıştığında sekme |
| `ballToWallRestitution` | 0.9 | |
| `ballLinearDamping` | 0.06 | Düşük damping = canlı hareket |
| `ballAngularDamping` | 0.25 | |
| `ballMass` | 1.0 | Tüm toplar eşit kütle (takımlar eşit güçte) |
| `kickoffImpulseRange` | 80...130 | Kickoff/reset sonrası her topa verilen rastgele yönlü impuls |

## Boost (periyodik kendi-itki — topları canlı tutar)

| Sabit | Değer | Açıklama |
|---|---|---|
| `boostIntervalRange` | 1.0...2.2 sn | Her topun rastgele aralıklarla aldığı kendi-itki periyodu (seed'li) |
| `boostImpulseBase` | 28 | Sabit boost büyüklüğü (tüm takımlar eşit; ileride power-up ölçekleyebilir) |
| `boostDirectionNoise` | 0.4 | Boost yönüne eklenen rastgele sapma (0-1, seed'li RNG) |

## Hız normalizasyonu (Mac-oto esintisi — topları canlı tutar)

| Sabit | Değer | Açıklama |
|---|---|---|
| `targetBallSpeed` | 140 pt/s | Topların yumuşakça normalize edildiği hedef hız |
| `speedNormalizationBlend` | 0.025 | Her frame'de hedef hıza yaklaşma oranı (düşük = yumuşak geçiş) |

## Rotasyon yön değişimi (Mac-oto esintisi — kaotik)

| Sabit | Değer | Açıklama |
|---|---|---|
| `rotationChangeIntervalRange` | 5...9 sn | Rastgele yön değiştirme aralığı (seed'li) |
| `rotationSpeedRange` | 0.35...0.7 rad/s | Yön değişiminde seçilebilecek dönüş hızları |

## Enerji tabanı (stall koruması)

| Sabit | Değer | Açıklama |
|---|---|---|
| `stallSpeedThreshold` | 4 pt/s | Bu hızın altında 3 sn kalan topa küçük rastgele impuls |
| `stallKickImpulse` | 15 | |

## Maç akışı

| Sabit | Değer | Açıklama |
|---|---|---|
| `matchDuration` | 90 sn → 90 dk gösterim | 1 sn = 1 dk. Skor ekranında dakika gösterilir |
| `halfTimePause` | 2.0 sn | Devre arası kısa duraklama + yeniden kickoff |
| `goalCelebrationPause` | 1.6 sn | Gol sonrası duraklama, skor overlay animasyonu |
| `maxSimSpeed` | 1x (MVP) | Hız ayarı Faz 2d'de 1x/2x/4x olur |

## Simülasyon sabitleri

| Sabit | Değer | Açıklama |
|---|---|---|
| `fixedTimeStep` | 1/120 sn | Sabit entegrasyon adımı — determinizmin temeli |
| `arenaRenderWidthFraction` | 0.42 | Arena yarıçapının render'da ekran genişliğine oranı |

## Collision kategorileri (bitmask)

| Kategori | Değer |
|---|---|
| `ballHome` | 1 << 0 |
| `ballAway` | 1 << 1 |
| `wall` | 1 << 2 |

## Kalibrasyon hedefi (kabul kriteri niteliğinde)

- 20 seed'lik test koşusunda 90 sn'lik maçta ortalama **1.5–5 gol** (iki topun toplamı).
- Hiçbir maç 0 gol ile bitmemeli >%90 ihtimalle (aksi halde boost/kaos parametreleri artırılır).
- Tüm takımlar eşit güçte — maç sonuçları seed'e ve rotasyon yön değişimlerine bağlı.
- Arena rotasyonu her 5–9 sn'de rastgele yön ve hız değiştirir (Mac-oto kaos mekaniği).
