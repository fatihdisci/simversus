# KIT FAZ 4 — BAŞARIMLAR + PAYLAŞIM (v1.4)

Hedef: birikim/koleksiyon hissiyle retention (başarımlar) + organik büyüme kanalı (paylaşım kartları).

| Parça | İçerik | Bağımlılık |
|---|---|---|
| 4a | GameEvents olay sistemi + başarım motoru (tanımlar, tetikleme, persist) | Faz 3 |
| 4b | Başarım UI: galeri, rozetler, kazanım toast'ı, ilerleme | 4a |
| 4c | Paylaşım kartları: maç / şampiyonluk / başarım | Faz 3 (4a-4b ile paralel koşabilir; başarım kartı kısmı 4b sonrası bağlanır) |

## Tasarım ilkeleri

- **Tamamen lokal.** Game Center achievements KULLANILMAZ (bilinçli karar: GC girişi Faz 6'ya kadar app'te yok; Faz 6'da istenirse GC achievement mirror'ı ayrı iş olarak değerlendirilir). Durum SwiftData'da.
- **Olay tabanlı.** Başarımlar feature kodlarına dokunmaz; yalnızca `GameEvents` yayınlarını dinler. Faz 6 online olayları geldiğinde sadece yeni tanım eklenir, motor değişmez.
- Rozetler parametrik vektör (TeamBadgeView estetiği), asset yok.

## Faz kabul kriteri
- Temiz kurulumdan "İlk Maç" başarımına, oradan 10-maç ilerleme çubuğuna akış çalışıyor
- Şampiyonluk kartı + başarım kartı paylaşılabiliyor, TR/EN doğru
- Başarım durumu app silinmedikçe kalıcı; migration mevcut kayıtları bozmuyor
