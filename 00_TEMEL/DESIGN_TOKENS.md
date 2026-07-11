# DESIGN_TOKENS.md — SimVersus Görsel Sistem

> `DesignSystem/` altında Swift'e çevrilir. Yön: katmanlı koyu zeminli
> **Gece Arenası / Canlı Yayın** hissi — arena parlak, UI onu çerçeveler.
> Emoji ikon YASAK, SF Symbols + parametrik badge kullanılır.

## Renk tokenları

| Token | Hex | Kullanım |
|---|---|---|
| `bg.primary` | #0B111B | Ana zemin (koyu) |
| `bg.elevated` | #141D2A | Kartlar, sheet |
| `bg.deep` | #070B12 | Gradient kenarları, en derin zemin |
| `bg.elevatedStrong` | #1A2636 | Odaklı/seçili yüzey |
| `border.subtle` | #263549 | Kart hairline |
| `border.strong` | #41546D | Odak ve kontrol çerçevesi |
| `bg.arena` | #101820 | Maç sahnesi zemini (MVP düz arka plan) |
| `arena.wall` | #2A3442 | Arena çemberi çizgisi |
| `arena.line` | #3A4656 | Orta çizgi, işaretler |
| `text.primary` | #F2F4F7 | |
| `text.secondary` | #9AA4B2 | |
| `accent` | #38E07B | CTA, canlı skor vurgusu ("çim yeşili neon") |
| `energy` | #19D8F2 | Arena enerjisi ve dekoratif vurgu; CTA değildir |
| `accent.warning` | #F2C230 | |
| `danger` | #E5484D | |
| `goal.flash` | #FFFFFF @ %85 | Gol anı ekran flaşı |

Takım renkleri her zaman `teams.json`'dan gelir, token olarak sabitlenmez.

## Tipografi

| Rol | Font | Boyut/Ağırlık |
|---|---|---|
| Skorboard | SF Pro Rounded / monospacedDigit | 34 / heavy |
| Başlık | SF Pro Rounded | 28 / bold |
| Gövde | SF Pro | 17 / regular |
| Etiket/short kod | SF Mono | 13 / semibold |

Rakam içeren her yerde (`skor`, `dakika`) `.monospacedDigit()` zorunlu — sayaç zıplaması olmaz.

## Spacing & şekil

- 8pt grid. Kart köşe yarıçapı 16, buton 14, badge 12.
- Dokunma hedefi min 44×44.
- Reduced Motion: `accessibilityReduceMotion` true ise gol flaşı ve konfeti kapatılır, skor animasyonsuz güncellenir.

## TeamBadgeView (parametrik logo)

Girdi: `primary`, `secondary`, `badgeShape` (star|chevron|wave|diamond|ring), `short` kodu.
Çıktı: kalkan (shield) formu — dış kontur `secondary`, dolgu `primary`, ortada seçilen soyut şekil `secondary`, altında `short` kodu SF Mono.
Kural: hayvan/gerçek kulüp simgesi çizilmez; şekiller tamamen geometrik kalır. Tek SwiftUI `Shape` composition'ı, asset image YOK — her boyutta keskin render.

> **Top = Dairesel + Badge Sembolü:** Maç sahnesinde top, takımın `primary` renginde dairesel bir gövde ve üzerinde `secondary` renkte badge geometrik sembolüdür (`BadgeSymbolShape` ile aynı şekil: star/chevron/wave/diamond/ring). Core Graphics ile render edilir, ayrı bir asset yoktur. Gol anında hafif parçacık/confetti efekti (Reduced Motion'da kapalı).
