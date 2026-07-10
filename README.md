# SimVersus — Prompt Kit Sistemi (v2)

Fizik tabanlı, izlenebilir (spectator-only) futbol maç simülatörü. iOS, SwiftUI + SpriteKit, TR + EN.

## Klasör yapısı

```
simversus-kits/
├── README.md                    ← bu dosya
├── 00_TEMEL/                    ← HER prompttan önce ajana verilecek ortak dosyalar
│   ├── CONSTITUTION.md          ← proje anayasası (mimari, kurallar, DO NOT TOUCH)
│   ├── TEAMS.json               ← takım verisi (6 MVP + 10 genişleme)
│   ├── PHYSICS_CONSTANTS.md     ← fizik parametreleri kalibrasyon tablosu
│   ├── I18N_RULES.md            ← TR/EN yerelleştirme kuralları + string kataloğu
│   └── DESIGN_TOKENS.md         ← renk, tipografi, spacing tokenları
├── KIT_FAZ1_MVP/                ← 6 parça (1a–1f)
├── KIT_FAZ2_RETENTION/          ← 4 parça (2a–2d)
├── KIT_FAZ3_TURNUVA/            ← 4 parça (3a–3d)
├── KIT_FAZ4_BASARIMLAR/         ← 3 parça (4a–4c)
├── KIT_FAZ5_GENISLEME/          ← 3 parça (5a–5c)
└── KIT_FAZ6_MULTIPLAYER/        ← 3 parça (6a–6c, Game Center)
```

## Kullanım protokolü (vibecoding akışı)

1. **Her oturumda** ajana önce `00_TEMEL/CONSTITUTION.md` ver (context'e yapıştır veya repo kökünde tut — ajan her prompt başında okumaya zorlanır).
2. Kit içindeki parçaları **sırayla** çalıştır. Her parça bağımsız bir ajan oturumu olabilir; parçalar birbirinin çıktısına dosya sistemi üzerinden bağlanır.
3. Her parça promptunda: **Amaç → Kapsam → Kabul kriterleri → DO NOT TOUCH**. Kabul kriterlerinin tamamı karşılanmadan parça bitmiş sayılmaz.
4. Parça bittiğinde: build al, simülatörde smoke test, sonra sıradaki parça. Kırık build üstüne yeni parça başlatma.
5. Faz bittiğinde `git tag faz1`, `faz2`… ile işaretle.

## Faz haritası

| Faz | Parçalar | Çıktı |
|---|---|---|
| 1 — MVP | 1a kurulum · 1b takımlar+logo · 1c maç motoru · 1d akış+sonuç · 1e monetizasyon · 1f store hazırlık | App Store ilk sürüm |
| 2 — Retention | 2a takım oluşturucu · 2b rewarded ads · 2c geçmiş+istatistik · 2d ayarlar | v1.1–1.2 |
| 3 — Turnuva | 3a motor · 3b bracket UI · 3c şampiyonluk+kilit · 3d roster 16 takım | v1.3 |
| 4 — Başarımlar | 4a başarım motoru · 4b başarım UI · 4c paylaşım kartları | v1.4 |
| 5 — Genişleme | 5a arena çeşitliliği · 5b temalar · 5c fizik modları | v1.5 |
| 6 — Multiplayer | 6a Game Center + eşleştirme · 6b online maç akışı · 6c maç sonrası + entegrasyon | v2.0 |

## Değişmez kararlar (tartışmaya kapalı)

- Spectator-only: kullanıcı maça müdahale ETMEZ (tüm modlarda, online dahil).
- **Bağımlılık ilkesi: tek dış SDK = Google Mobile Ads (AdMob).** Geri kalan her şey Apple: StoreKit 2, SwiftData, SpriteKit, Game Center, String Catalog. Kendi backend'imiz YOK; multiplayer eşleştirme/iletişim Game Center üzerinden.
- Gerçek kulüp adı/logosu/arması ASLA kullanılmaz. Şehir+renk formatı, soyut badge.
- Reklam: 3 maçta 1 interstitial (sonuç ekranı sonrası) + rewarded kilitler + tek seferlik "Reklamsız" IAP (yalnız interstitial'ı kaldırır).
- i18n baştan: her kullanıcıya görünen string String Catalog'da, TR + EN.
- Maç motoru deterministik (seed'li) — testin VE Faz 6 online senkronizasyonun temeli.
- Lig/sezon modu YOK (bilinçli kapsam kararı). Kilitli içerik listesindeki hiçbir parça lig varsaymaz.
