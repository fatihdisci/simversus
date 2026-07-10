# PARÇA 5a — Arena Çeşitliliği

**Önce oku:** CONSTITUTION.md, PHYSICS_CONSTANTS.md

## Amaç
Daire dışında yeni arena geometrileri + opsiyonel engeller. Maç öncesi arena seçimi.

## Kapsam
1. `Core/Engine/ArenaLayout.swift`: protokol — duvar segmentleri, kale konumları, dönüş davranışı, spawn noktaları. Mevcut daire `CircleArena` olarak bu protokole refactor edilir (davranış birebir korunur, regresyon testi: mevcut 20-seed sonuçları refactor öncesi/sonrası AYNI).
2. Yeni arenalar:
   - `HexArena`: altıgen, köşe sekmeleri sert
   - `OvalArena`: elips, uzun eksen sekmeleri hızlı
   - `GearArena`: dişli çark profili (iç girintili) — kaos maksimum
   - `PillarArena`: daire + merkezde dönen 2 sabit sütun engeli
3. Arena başına PhysicsConstants'a ek bölüm: `arenaOverrides` (rotationSpeed, restitution farkları) — ana sabitler değişmez, override pattern'i.
4. TeamSelect akışına arena seçici (yatay kart scroll, mini önizleme çizimi). Varsayılan: daire.
5. Kalibrasyon: HER arena 20-seed testinde 2–6 gol bandını tutmalı (override'larla ayarla).
6. Erişim: daire + oval ücretsiz; hex/gear/pillar → `FeatureGate` flag'i: `rewardedPerSession` VEYA `themePackIAP` (KIT_README senaryosu; default rewardedPerSession).
7. Stringler (TR+EN): `arena.select`, `arena.circle/oval/hex/gear/pillar` adları.

7. `ArenaLayout` seçimi `MatchConfig`e `Codable` alan olarak eklenir (Faz 6 online iletim uyumu).

## Kabul kriterleri
- [ ] Refactor regresyon testi geçiyor (daire davranışı değişmedi)
- [ ] 5 arena da gol bandında
- [ ] Kilit akışı flag'e göre çalışıyor
- [ ] Turnuva maçları arena seçimini destekliyor (tek arena tüm turnuva)

## DO NOT TOUCH / YAPMA
- Ana PhysicsConstants değerleri (override pattern dışında)
- Spectator-only ilkesi (engeller bile otomatik/sabit, kullanıcı kontrolü yok)
