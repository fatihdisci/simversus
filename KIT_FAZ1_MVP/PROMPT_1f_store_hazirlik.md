# PARÇA 1f — Cila + App Store Hazırlığı

**Önce oku:** CONSTITUTION.md, DESIGN_TOKENS.md
**Bağımlılık:** 1e tamamlanmış olmalı.

## Amaç
Review'a hazır sürüm: ikon, launch, erişilebilirlik, performans, metadata taslakları, checklist.

## Kapsam (ajan işi)
1. App ikonu: TeamBadgeView estetiğinde vektör kaynak (SVG/Swift Playground render) — koyu zemin, accent yeşil, soyut top/arena motifi. 1024pt master.
2. Launch screen: bg.primary düz + merkezde küçük logo (storyboard'suz, Info.plist launch).
3. Erişilebilirlik geçişi: tüm butonlarda `accessibilityLabel`, Reduced Motion kontrolü (gol flaşı/animasyonlar), Dynamic Type'ta layout kırılmıyor (skorboard hariç — sabit kalabilir).
4. Performans: MatchScene 60fps hedefi; `SKView.showsFPS` debug-only; Instruments'ta bariz leak yok (Ad/Purchase manager'lar singleton lifecycle).
5. Sürüm: 1.0.0 (1), Release config'de test Ad ID'lerinin PROD ile değiştirileceği yerlerin listesi `RELEASE_TODO.md` olarak repo köküne.
6. `fastlane` YOK (manuel yükleme) — sadece archive öncesi kontrol scripti değil, checklist markdown'u.

## Kapsam (senin işin — ajan dışı, RELEASE_TODO.md'ye yazılacak)
- App Store Connect: app kaydı, IAP ürünü (`com.simversus.removeads`) oluşturma + review notu
- AdMob: gerçek app + interstitial unit oluşturma, app-ads.txt (varsa web sitene)
- Privacy Nutrition Label: reklam nedeniyle "Data Used to Track You: No / Identifiers: Device ID (advertising, non-personalized)" — AdMob non-personalized senaryosuna göre işaretle
- Ekran görüntüleri: 6.7" + 6.1", TR ve EN ayrı setler (maç anı, takım seçimi, sonuç ekranı)
- Metadata: isim "SimVersus", altbaşlık TR: "Fizik tabanlı maç simülasyonu" / EN: "Physics-based match simulator"

## Kabul kriterleri
- [ ] Archive başarılı, TestFlight'a yüklenebilir durumda
- [ ] RELEASE_TODO.md eksiksiz (yukarıdaki manuel adımlar + PROD ID değişim noktaları)
- [ ] VoiceOver ile ana akış tamamlanabiliyor
- [ ] TR + EN son tur ekran kontrolü yapıldı

## DO NOT TOUCH / YAPMA
- Yeni özellik ekleme — bu parça yalnızca cila
- PhysicsConstants'a "son dakika" ayarı
