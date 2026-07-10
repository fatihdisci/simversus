# PARÇA 1a — Proje Kurulumu + Design System + i18n Altyapısı

**Önce oku:** CONSTITUTION.md, DESIGN_TOKENS.md, I18N_RULES.md

## Amaç
Boş ama tam iskeletli, derlenen, TR/EN destekli SwiftUI projesi. Sonraki parçalar bu iskelete oturacak.

## Kapsam
1. Xcode projesi: `SimVersus`, bundle id `com.simversus.app`, iOS 17.0 min, iPhone-only, portrait-only.
2. CONSTITUTION.md §3'teki klasör yapısını AYNEN kur (boş klasör bırakma, her klasöre en az placeholder dosya).
3. `DesignSystem/`:
   - `Palette.swift`: DESIGN_TOKENS.md renk tokenları (`Color` extension, hex init helper dahil)
   - `Typography.swift`: font stilleri (`Font` extension: `.scoreboard`, `.titleXL`, `.body`, `.label`)
   - `Spacing.swift`: 8pt grid sabitleri
4. `Resources/Localizable.xcstrings`: I18N_RULES.md'deki Faz 1 kataloğunun TAMAMI, TR + EN.
5. `App/SimVersusApp.swift` + `App/AppState.swift` (ObservableObject; şimdilik `matchesPlayedCount: Int` tutar, UserDefaults'a persist).
6. `Features/Home/HomeView.swift`: başlık `home.title`, büyük CTA `home.play` (şimdilik boş action), altta küçük `home.removeAds` butonu (boş action). Koyu tema, token kullanımı.

## Oluşturulacak dosyalar
Yukarıdaki tümü + `.gitignore` (Xcode standart) + boş `SimVersusTests` target'ı.

## Kabul kriterleri
- [ ] `Cmd+B` temiz, sıfır warning
- [ ] Cihaz dili TR iken HomeView Türkçe, EN iken İngilizce
- [ ] Hiçbir view'da hardcoded kullanıcı stringi yok
- [ ] Palette/Typography dışında renk/font tanımı yok

## DO NOT TOUCH / YAPMA
- Reklam/IAP SDK'sı EKLEME (1e'nin işi)
- SpriteKit sahnesi kurma (1c'nin işi)
- Navigation akışı kurma (1d'nin işi) — HomeView butonları şimdilik inert
- teams.json ekleme (1b'nin işi)
