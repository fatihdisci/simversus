# I18N_RULES.md — TR/EN Yerelleştirme

## Kurallar

1. Base dil: **İngilizce** (App Store global). TR tam çeviri. Cihaz dili TR ise TR, diğer her şeyde EN.
2. Tek dosya: `Resources/Localizable.xcstrings` (String Catalog). `.strings` dosyası kullanma.
3. Anahtar formatı: `feature.context.name` — anahtarlar İngilizce, küçük harf, nokta ayraçlı.
4. Yeni string eklerken TR + EN aynı commit'te. Tek dilde string bırakan parça kabul edilmez.
5. Sayı/tarih formatları `formatted()` API'siyle locale'e bırakılır, elle format YASAK.
6. Takım adları da katalogdan gelir (`team.<id>.name`) — teams.json'daki nameTR/nameEN alanları katalog kaynağıdır.

## Çekirdek string kataloğu (Faz 1)

| Anahtar | EN | TR |
|---|---|---|
| `home.title` | SimVersus | SimVersus |
| `home.play` | Start Match | Maçı Başlat |
| `home.removeAds` | Remove Ads | Reklamları Kaldır |
| `teamselect.title` | Choose Teams | Takımları Seç |
| `teamselect.home` | Home | Ev Sahibi |
| `teamselect.away` | Away | Deplasman |
| `teamselect.start` | Kick Off | Başlama Vuruşu |
| `match.half.first` | 1st Half | İlk Yarı |
| `match.half.second` | 2nd Half | İkinci Yarı |
| `match.goal` | GOAL! | GOL! |
| `result.title` | Full Time | Maç Sonu |
| `result.winner %@` | %@ wins! | %@ kazandı! |
| `result.draw` | It's a draw | Berabere |
| `result.rematch` | Rematch | Rövanş |
| `result.newMatch` | New Match | Yeni Maç |
| `result.home` | Main Menu | Ana Menü |
| `iap.removeAds.success` | Ads removed. Enjoy! | Reklamlar kaldırıldı. Keyfini çıkar! |
| `iap.restore` | Restore Purchases | Satın Alımları Geri Yükle |
| `iap.error.generic` | Purchase failed. Please try again. | Satın alma başarısız. Lütfen tekrar deneyin. |
| `settings.title` | Settings | Ayarlar |
| `common.cancel` | Cancel | İptal |
| `common.ok` | OK | Tamam |

Faz 2+ stringleri ilgili parça promptlarında tanımlıdır; aynı formatta bu dosyaya eklenerek katalog büyütülür.
