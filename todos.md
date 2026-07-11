# TODO

Bilinen, önceden var olan ve henüz düzeltilmemiş iki test hatası. İkisi de
2026-07-12 tarihli "Tek hızlı ambient top, sonuç ekranı iyileştirmeleri ve
gerçek Ayarlar ekranı" değişikliğinden bağımsız — dokunulan dosyalarla hiç
ilgisi yok, sadece test çalıştırılırken fark edildi.

## 1. `CustomTeamTests.testCleanNamesPass` başarısız

- Dosya: `SimVersus/SimVersusTests/CustomTeamTests.swift` (satır ~22-26)
- Hata: `TeamNameValidator.validate("Kuzey Kartalları 1907")` `nil` (izinli)
  dönmesi beklenirken `.tooLong` dönüyor.
- Şüphe: `SimVersus/Core/Models/TeamNameValidator.swift`'teki uzunluk sınırı
  muhtemelen kullanıcının gördüğü karakter sayısı yerine UTF-16/UTF-8 kod
  birimi üzerinden ölçülüyor, ya da Türkçe aksanlı karakterler (ı, ç, ş)
  beklenenden farklı sayılıyor — "Kuzey Kartalları 1907" (boşluklarla 22
  karakter) sınırı aşıyor.
- Karar verilmesi gereken: sınır mantığını mı düzeltmeli yoksa test
  fixture'ındaki ismi mi değiştirmeli — CONSTITUTION.md / takım ismi
  kurallarının gerçek niyetine bakılarak karar verilmeli.

## 2. `MatchEngineTests.testAverageGoalsInBandAcrossSeeds` başarısız

- Dosya: `SimVersus/SimVersusTests/MatchEngineTests.swift` (satır ~23-38)
- Hata: 20 seed ortalaması `(2.0...7.0)` bandında olmalıyken ~1.2 çıkıyor;
  0-0 biten maç sayısı `<= 4/20` olmalıyken 7/20.
- Dikkat: Dosyanın kendi başlık yorumu (satır 6) "Goal band: 1.5–5" diyor —
  koddaki `2.0...7.0` ile tutarsız. Bu, bir noktada fizik/power-up ayarı
  değişmiş ama test bandı güncellenmemiş gibi görünüyor (bkz. git log:
  "Maç fiziği ve HUD iyileştirmeleri", "Aşama 4: Power-up sistemi").
- Karar verilmesi gereken: `PhysicsConstants.swift` ayarları mı gol atma
  oranını gerçekten düşürdü (asıl regresyon) yoksa test bandı mı bayat —
  gerçek uyuşmazlığı bulup düzeltmeli. CONSTITUTION.md açıkça istenmedikçe
  `PhysicsConstants` değerlerinin değiştirilmesini yasaklıyor; çözüm bir
  sabit değişikliğiyse bunu sessizce yapmak yerine açıkça işaretle.
- Doğrulama: `xcodebuild test -project SimVersus/SimVersus.xcodeproj -scheme SimVersus -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
