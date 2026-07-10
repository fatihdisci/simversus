# PARÇA 5b — Görsel Temalar

**Önce oku:** CONSTITUTION.md, DESIGN_TOKENS.md

## Amaç
Maç sahnesinin görsel temaları (MVP'nin "düz arka plan" kararı burada açılır). Fizik DEĞİŞMEZ — yalnızca görsel katman.

## Kapsam
1. `Core/Engine/ArenaTheme.swift`: zemin rengi/gradyanı, duvar rengi, çizgi rengi, top görünümü, opsiyonel partikül (yıldız, kar) tanımı. Temalar statik katalog (`ThemeCatalog`), asset-hafif (procedural/gradient ağırlıklı, büyük görsel dosyası YOK — app boyutu korunur).
2. Temalar: **Klasik** (mevcut, ücretsiz), **Gece Maçı** (neon çizgiler, ücretsiz), **Kar** (açık zemin + kar partikülü), **Retro** (CRT scanline hissi), **Uzay** (koyu + yıldız alanı).
3. Ayarlar + maç öncesi seçim; seçim UserDefaults'ta.
4. Partiküller `SKEmitterNode`, Reduced Motion'da kapalı; FPS 60 korunur (partikül bütçesi: max 80 aktif node).
5. Erişim: 5a'daki `FeatureGate` pattern'iyle aynı (Klasik+Gece ücretsiz, diğerleri gate'li).
6. Skorboard/HUD kontrast kontrolü: her temada text.primary okunabilirliği (açık zeminli Kar temasında HUD otomatik koyu varyanta geçer).
7. Stringler (TR+EN): `theme.select`, tema adları.

## Kabul kriterleri
- [ ] 5 tema da 60fps, kontrast sorunu yok
- [ ] Fizik sonuçları temadan bağımsız (aynı seed her temada aynı sonuç — test)
- [ ] Reduced Motion'da partikül yok
- [ ] App boyutu artışı < 2 MB

## DO NOT TOUCH / YAPMA
- Fizik/PhysicsConstants
- Ağır asset (video, büyük PNG atlas) ekleme
