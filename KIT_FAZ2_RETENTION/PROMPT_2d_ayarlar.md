# PARÇA 2d — Ayarlar Ekranı

**Önce oku:** CONSTITUTION.md, PHYSICS_CONSTANTS.md (maxSimSpeed notu), I18N_RULES.md
**Bağımlılık:** Faz 1 (paralel koşabilir).

## Amaç
Ayarlar: maç hızı, maç süresi, satın alma yönetimi, hakkında.

## Kapsam
1. `Features/Settings/SettingsView.swift` (Home'dan dişli ikonla):
   - **Maç hızı:** 1x / 2x / 4x (`SKScene.speed` ile uygulanır — fizik sabitleri DEĞİŞMEZ, yalnızca zaman ölçeği). Varsayılan 1x, UserDefaults.
   - **Maç süresi:** Kısa 60sn / Normal 90sn / Uzun 120sn (gösterim hâlâ 90 dk'ya ölçeklenir). Varsayılan Normal.
   - **Satın almalar:** Reklamsız durumu (aktif/satın al) + `iap.restore`
   - **Hakkında:** sürüm no, gizlilik politikası linki (placeholder URL, RELEASE_TODO'ya not), "made with SwiftUI + SpriteKit" satırı
2. Spectator-only kuralı gereği maç İÇİNDE tek izinli kontrol eklenir: pause/resume butonu (HUD'a). Pause fizik dünyasını dondurur, süreyi durdurur.
3. `MatchConfig`'e speed/duration parametreleri eklenir; MatchScene bunları PhysicsConstants'ı değiştirmeden uygular.
4. Stringler (TR+EN): `settings.speed` (Maç Hızı / Match Speed), `settings.duration` (Maç Süresi / Match Length), `settings.duration.short/normal/long`, `settings.purchases`, `settings.about`, `settings.version`, `settings.privacy`, `match.pause` / `match.resume`.

## Kabul kriterleri
- [ ] 2x/4x'te maç görsel olarak hızlı ama sonuç dağılımı bozulmuyor (aynı seed 1x ve 4x'te AYNI sonucu veriyor — SKScene.speed determinizmi bozmamalı; bozuyorsa sabit-adımlı update ile düzelt ve belgeleyerek commit'le)
- [ ] Süre seçenekleri gol bandını orantılı etkiliyor (60sn ≈ daha az gol, kabul edilebilir)
- [ ] Pause/resume sağlam; pause'dayken arka plana at + geri gel senaryosu çalışıyor
- [ ] Restore ayarlardan çalışıyor

## DO NOT TOUCH / YAPMA
- PhysicsConstants değerlerini değiştirme (hız SKScene.speed ile)
- Dil seçici EKLEME (dil = cihaz dili, app içi seçim yok)
- Tema/görünüm ayarı (Faz 5b)
