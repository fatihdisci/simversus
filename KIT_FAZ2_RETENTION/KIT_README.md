# KIT FAZ 2 — RETENTION (v1.1–1.2)

Hedef: kullanıcıyı geri getiren özellikler + rewarded ad kanalını açmak.

| Parça | İçerik | Bağımlılık |
|---|---|---|
| 2a | Özel takım oluşturucu (isim + renkler + şekil) | Faz 1 |
| 2b | Rewarded ads: ekstra özel takım slotu | 2a |
| 2c | Maç geçmişi + basit istatistik (SwiftData) | Faz 1 |
| 2d | Ayarlar: maç hızı/süresi, dil bilgisi, restore | Faz 1 |

2c ve 2d, 2a/2b'den bağımsızdır; paralel ayrı oturumlarda koşturulabilir.

## Yeni string anahtarları
Her parça kendi prompt dosyasında listeler; I18N_RULES.md formatında TR+EN eklenir.

## Faz kabul kriteri
- Özel takım oluştur → maça sok → geçmişte gör → rewarded ile 2. slot aç akışı uçtan uca çalışıyor
- isAdFree kullanıcıda rewarded HÂLÂ çalışıyor (interstitial kapalı, rewarded açık — CONSTITUTION §4.3)
