# PARÇA 1c — SpriteKit Maç Motoru (projenin kalbi) — İKİ TOP SİSTEMİ

**Önce oku:** CONSTITUTION.md, PHYSICS_CONSTANTS.md, DESIGN_TOKENS.md

## Amaç
Dönen, tek kale boşluklu arena içinde iki takım topunun (badge görselli) çarpışarak oynadığı, deterministik, spectator-only maç motoru.

## Kapsam
1. `Core/Engine/PhysicsConstants.swift`: PHYSICS_CONSTANTS.md'deki TÜM sabitler, aynı adlarla, tek `enum PhysicsConstants` altında. Collision bitmask'leri dahil. Oyuncu/disk sabitleri YOK.
2. `Core/Models/MatchConfig.swift`: `homeTeam, awayTeam, seed: UInt64, duration` — şema korunur. `MatchResult.swift`: skorlar, gol dakikaları `[Goal(minute:Int, teamID:String)]`, kazanan/beraberlik — şema korunur (`teamID` = gol ATAN takım).
3. `Core/Engine/SeededRNG.swift`: SplitMix64 — aynen korunur.
4. `Core/Engine/MatchSimulation.swift` (deterministik sabit-adımlı simülasyon — başsız test edilebilir):
   - İki top (homeBall, awayBall), her biri `ballRadius` çaplı, kütlesi `ballMassBase * (1 + (baseStrength-75) * massStrengthScale)`
   - Kickoff: iki top merkeze yakın simetrik konumdan, zıt yönlere `kickoffImpulseRange` içinde rastgele impuls
   - Boost mekaniği: her top, seed'li RNG ile `boostIntervalRange` aralığında kendi kendine impuls alır (`boostImpulseBase` × strength ölçekli, `boostDirectionNoise` ile rastgele yön sapması)
   - Stall koruması: `stallSpeedThreshold` altında 3 sn kalan topa `stallKickImpulse`
   - Çarpışmalar: top-top (`ballToBallRestitution`), top-duvar (`ballToWallRestitution`)
   - Gol algılama: her frame, her topun merkezden uzaklığı kontrol edilir. `> arenaRadius + exitMargin` ise → KARŞI takıma gol → `goalCelebrationPause` → iki top merkeze reset + yeni kickoff, arena dönüşü kesintisiz
   - Süre: `matchDuration` gerçek sn = 90 gösterim dk; 45'te devre arası (`halfTimePause` + reset+kickoff)
   - Maç sonu: `MatchResult` üretir, `runToCompletion()` ile başsız test edilebilir
5. `Core/Engine/MatchScene.swift` (SKScene — render katmanı):
   - Dairesel arena: `SKShapeNode` ile tek kale boşluklu (gapWidth genişliğinde) çember segment zinciri. Gap arenayla birlikte döner
   - Gap görseli: boşluğun iki yanında kale ağı hissi veren kısa çizgiler (vektör, asset değil)
   - İki top: `SKSpriteNode` — her biri ilgili takımın `TeamBadgeView`'inden `ImageRenderer` ile render edilen texture
   - Hiçbir oyuncu/disk node'u yok
   - Arena node'u `arenaRotationSpeed` ile sürekli döner
6. `Features/Match/MatchView.swift`: `SpriteView` sarmalayıcı + HUD (skorboard: iki badge + skor, dakika, yarı etiketi, gol anında flaş overlay). **Değişiklik:** gol flaş overlay'i korunur.
7. Unit test (`MatchEngineTests`): aynı seed + aynı takımlar → aynı `MatchResult` (determinizm). 20 farklı seed'de ortalama toplam gol 1.5–5 bandında. Sıfır gol biten maç oranı test edilir. Güçlü takım kazanma oranı test edilir.

## Kabul kriterleri
- [ ] Arena görünür şekilde dönüyor, TEK gap net görünüyor ve arenayla birlikte dönüyor
- [ ] İki top (badge görselli) birbirine ve duvarlara gerçekçi şekilde çarpışıyor
- [ ] Oyuncu diski YOK, playerDrive kavramı kodda hiç geçmiyor
- [ ] Bir top gap'ten çıkınca doğru şekilde RAKİBE gol yazılıyor, reset çalışıyor
- [ ] Aynı seed = aynı sonuç (determinizm testi geçiyor)
- [ ] 20-seed gol bandı testi geçiyor, sıfır-gollü maç oranı düşük
- [ ] Sahnede magic number yok — hepsi PhysicsConstants

## DO NOT TOUCH / YAPMA
- Oyuncu diski, 5v5, çift kale kavramlarını HİÇBİR ŞEKİLDE geri getirme
- Navigation/sonuç ekranı (1d)
- Reklam/IAP (1e)
- TeamSelect'e dokunma
- Üçüncü parti fizik/oyun kütüphanesi ekleme
