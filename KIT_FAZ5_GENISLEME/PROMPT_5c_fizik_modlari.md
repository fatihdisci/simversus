# PARÇA 5c — Fizik Modları

**Önce oku:** CONSTITUTION.md, PHYSICS_CONSTANTS.md

## Amaç
Maçın kurallarını değiştiren eğlence modları. Spectator-only korunur — modlar otomatik işler, kullanıcı tetiklemez. BASE oyun artık iki-top sistemidir (her takımın kendi topu); modlar bu temel üzerine kurulur.

## Kapsam
1. `Core/Engine/MatchMode.swift`: enum + mod parametreleri, `MatchConfig`'e `mode` alanı (default `.classic`).
2. Modlar:
   - **Klasik** (mevcut iki-top sistemi)
   - **Vahşi Top (Wildcard Ball):** Sahaya kimseye ait olmayan, nötr, yüksek sekme katsayılı 3. bir top eklenir; bu top gol saymaz ama diğer iki topa çarparak yörüngelerini kaotikleştirir
   - **Kaos:** arena dönüş hızı her 15 sn'de rastgele değişir + yön değiştirir (seed'li)
   - **Dev Top:** ballRadius ×2, mass ×2 — komik/ağır fizik (her iki topa uygulanır)
   - **Turbo:** damping düşük, restitution 0.98 — pinball hissi (her iki topa uygulanır)
3. Her mod için `PhysicsConstants.modeOverrides` bölümü (override pattern, ana sabitler dokunulmaz).
4. Kalibrasyon: modların gol bandı esnetilir — Klasik 1.5–5, diğerleri 1.5–10 kabul edilebilir; stall koruması tüm modlarda aktif.
5. Mod seçimi maç öncesi (arena/tema seçicinin yanında). Turnuva yalnızca Klasik (istatistik bütünlüğü — bilinçli sınır).
6. Geçmiş kayıtlarında mod etiketi (`MatchRecord.mode`, migration).
7. Erişim: Klasik+Vahşi Top ücretsiz, diğerleri FeatureGate.
8. Stringler (TR+EN): mod adları + `mode.select`.

9. `MatchMode` `Codable`dır ve `MatchConfig` içinde serileştirilebilir (Faz 6 online iletim uyumu).

## Kabul kriterleri
- [ ] 5 mod da deterministik (aynı seed aynı sonuç)
- [ ] Vahşi Top modunda wildcard top gol saymıyor, yalnızca çarpışma kaosu yaratıyor
- [ ] Turnuvada mod seçici görünmüyor
- [ ] Migration mevcut kayıtları bozmuyor

## DO NOT TOUCH / YAPMA
- Kullanıcı müdahalesi (tap ile topa vurma vb.) EKLEME — bu ayrı, bilinçli reddedilmiş bir yön
- Klasik modun davranışını değiştirme (regresyon testi)
- "Çift Top" modunu geri getirme — base oyun zaten iki toplu, bu mod gereksiz hale geldi
