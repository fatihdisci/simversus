# PLAN — Takım Kimliği: Statlar, Özelleştirme, Efektler, Power-up'lar

Durum: taslak / onay bekliyor
Dal: `claude/interface-bugs-performance-0ahegx`
Amaç: Spectator maçta tek derinlik kaynağı takımdır. Takımlara **küçük ama
hissedilir mekanik kimlik** (hız/ağırlık/boyut) ve **zengin görsel kimlik**
(renk + rozet + forma pattern) vererek hem 6 hazır takımı hem de kullanıcının
yaratacağı özel takımı anlamlı kılmak.

---

## 0. Temel mekanik (güncel — Anayasa 2026-07 ile değişti)

- Arenada **TEK** dönen kale boşluğu vardır. İki ayrı kale YOKTUR ve
  getirilmez (Anayasa §4.4, §6 — çift kale hâlâ YASAK).
- **Gol mantığı (YENİ):** bir takımın topu dönen kale boşluğundan dışarı
  çıkarsa **O TOPUN kendi takımı** gol kazanır. "Topunu kaleye sok" — futbol
  mantığı. (Eski kural "çıkanın rakibi sayar" idi; tersine çevrildi.)
- Kullanıcı yalnızca izler (girdi yok). Determinizm korunur: aynı seed + aynı
  takımlar = birebir aynı sonuç.

> Skor yönü değişikliği fizik ve toplam gol sayısını DEĞİŞTİRMEZ, yalnızca
> sayının kime yazıldığını çevirir → mevcut testler kırılmaz.

---

## 1. Stat sistemi (min/max — ONAYLANDI)

3 stat, 1–5 skala, **sabit bütçe = 9 puan** (3/3/3 = nötr baseline = bugünkü
top). Kullanıcı/preset puanı üç stata dağıtır (her stat min 1, max 5).

| Stat | Sim alanı | Sv1 | Sv2 | Sv3 (baseline) | Sv4 | Sv5 | Bant |
|---|---|---|---|---|---|---|---|
| **Ağırlık** | `Disc.mass` | 0.85 | 0.925 | 1.00 | 1.075 | 1.15 | ±15% |
| **Hız** | `targetBallSpeed` | 165 | 172.5 | 180 | 187.5 | 195 | ±8% |
| **Boyut** | `Disc.radius` | 26 | 27 | 28 | 29 | 30 | ±7% |

**Doğal takaslar (yeni skor mantığına göre — topunu kaleye ulaştırmak İYİ):**
- Ağırlık↑: çarpışmada rakibi iter, kendi az itilir (rakip seni kaleden uzak
  itemez); ama boost `impulse/mass` olduğu için hantallaşır, manevrası yavaş.
- Hız↑: kaleye daha çabuk ulaşır → daha çok gol fırsatı; ama daha kaotik.
- Boyut↑: çarpışma yüzeyi/varlık artar; ama büyük top çarpışmalarda daha çok
  savrulur (daha büyük hedef). Boyutun exit sınırına etkisi için Açık Soru 1.

Hiçbir stat tek başına baskın olmamalı — preset dağılımları kalibrasyonla
dengelenir. Bantlar dar (±7–15%): seed/şans hâlâ baskın.

**Baseline sabitleri (değişmez referans):** `mass 1.0`, `targetBallSpeed 180`,
`ballRadius 28`. Statlar bu değerleri top-başına override eder; global sabitler
"Seviye 3" değeri olarak kalır.

---

## AŞAMA 1 — Statları motora bağla (KODLANDI ✅ — Xcode doğrulaması bekliyor)

**Hedef:** Takımın statları maç fiziğini top-başına etkilesin; determinizm ve
gol-band kalibrasyonu korunsun.

**Karar (Açık Soru 1):** Boyut, exit sınırını (`arenaRadius − radius`)
DOĞAL olarak etkiler — yapay dengeleme YOK. Büyük top doğal olarak daha kolay
gol atar (kullanıcı kararı: "kendiliğinden olsun").

**Dosyalar:**
- `Core/Models/TeamStats.swift` (YENİ): `struct TeamStats { weight, speed, size: Int (1...5) }` + bütçe doğrulama (toplam = 9) + seviye→değer map fonksiyonları. Varsayılan `.balanced` (3/3/3).
- `Core/Models/Team.swift`: `stats: TeamStats` alanı (opsiyonel, default balanced ki teams.json geriye uyumlu kalsın).
- `Resources/teams.json`: 6 tier-1 (+ tier-2) takıma profil ata. Eski
  `TEAMS.json`'daki güç sırası (88→69) referans; toplam hep 9. Örn:
  - IYR (eski 88): 4/3/2 gibi hafif "ağır+hızlı"
  - INY (eski 87): 3/4/2
  - … (kesin dağılım kalibrasyonla netleşir)
- `Core/Engine/MatchSimulation.swift`:
  - `homeBall`/`awayBall` init'inde `mass` ve `radius`'u takım statından al.
  - `normalizeBallSpeed`: global `targetBallSpeed` yerine top-başına hedef
    (yeni alan `Disc.targetSpeed`).
  - `resetFormation`: konum offset'i top yarıçapına göre (zaten `ballRadius`
    kullanıyor → per-team radius'a çevir).
- `Core/Engine/MatchScene.swift`:
  - `makeBallNode` ve `makeShadowNode`: global `ballRadius` yerine ilgili
    takımın radius'unu kullan.

**Kabul kriterleri:**
- [ ] `testSameSeedProducesSameResult` yeşil (determinizm bozulmadı).
- [ ] `testAverageGoalsInBandAcrossSeeds` yeşil (gerekirse bantı/profilleri
      ayarla; hedef 2.0–7.0 içinde kal).
- [ ] `testEqualTeamsProduceVariedOutcomes` yeşil.
- [ ] İki farklı statlı takım gözle bakınca farklı oynuyor (ağır top daha
      dominant, büyük top gözle büyük).

**Riskler / açık noktalar:**
- Boyut, exit sınırını (`arenaRadius − radius`) değiştiriyor. Kalibrasyonda
  "büyük top daha kolay gol yer" etkisi istenmezse exit sınırını radius'tan
  bağımsız (`arenaRadius − ballRadiusBaseline`) yapmayı değerlendir. **Karar
  bu aşamada verilecek.**
- Latent tutarsızlık: Anayasa exit eşiğini `arenaRadius + exitMargin` diyor,
  kod `arenaRadius − radius` kullanıyor (exitMargin atıl). Bu aşamada
  netleştir ama kalibrasyonu bozmadan.

**DO NOT TOUCH:** skor yönü, tek-gap mekaniği, dönüş sistemi, monetizasyon.

---

## AŞAMA 2 — Takım oluşturucu (özelleştirme)

**Hedef:** Kullanıcı isim + 2 renk + rozet şekli + **forma pattern** + **stat
dağıtımı** ile kendi takımını yaratır ve maça sokar. (FAZ2 §2a temel alınır,
üzerine stat + pattern eklenir.)

**Dosyalar:**
- `Core/Models/CustomTeam.swift` (YENİ): SwiftData `@Model` — name (≤20),
  primaryHex, secondaryHex, badgeShape, **pattern**, **stats(TeamStats)**,
  createdAt. `Team` arayüzüne adapter.
- `Core/Models/KitPattern.swift` (YENİ): `enum KitPattern { solid, verticalStripes, horizontalStripes, checkered, diagonal, halves }` + top dolgusunu çizen yardımcı.
- `Features/TeamCreator/TeamCreatorView.swift` (YENİ):
  - İsim alanı (boş red + gerçek kulüp blocklist: galatasaray/fenerbahçe/
    beşiktaş/trabzonspor/göztepe/bursaspor — diacritic-insensitive).
  - 12 preset renkten 2 swatch (kontrast garantili).
  - 5 rozet şekli + 6 pattern seçici, **canlı TeamBadgeView/top önizlemesi**.
  - Stat dağıtıcı: 9 puan, 3 slider/stepper (1–5), toplam kilidi; canlı "bu
    top nasıl oynar" mini açıklaması.
  - Kaydet → TeamSelect'te "Özel Takımlar" bölümünde.
- `CustomTeamStore` (YENİ): `maxSlots = 1` (2b rewarded ile artar; UserDefaults).
- `MatchScene.makeBallNode`: pattern'i dolguya uygula (solid dışı desenler).
- Stringler (TR+EN): creator.* + teamselect.section.custom + pattern isimleri.

**Kabul kriterleri:**
- [ ] Özel takım oluşturulup maça sokuluyor, rozet + pattern + stat doğru.
- [ ] Blocklist çalışıyor (harf/Türkçe karakter varyasyonları).
- [ ] 9-puan bütçe kilidi çalışıyor (fazla/eksik puan reddedilir).
- [ ] App restart sonrası özel takım duruyor (SwiftData).
- [ ] 1 slot dolunca ikinci oluşturma kilitli (inert; rewarded 2b'de).

**DO NOT TOUCH:** rewarded reklam (2b), teams.json'a yazma (özel takım yalnız
SwiftData), MatchScene fizik kodu.

---

## AŞAMA 3 — Görsel efekt inceltme

**Hedef:** Mevcut efektleri "hafif ve zarif" hale getirmek (sıfırdan değil,
mevcut sistem üzerine).

**Not:** Tail (`spawnTrail`) ve çarpışma efektleri (`spawnCollisionEffects`,
hem top-top hem top-duvar) motorda ZATEN var. Bu aşama onları ayarlar:
- Topların arkasına daha sürekli, ince, sönümlenen bir **kuyruk** (mevcut toz
  parçacığını inceltmek veya hafif bir SKEmitter/segment iz).
- Çarpışma kıvılcımını **azalt/inceltmek** (sayı ve parlaklık düşür) — "az
  belirgin hafif efekt".
- Gol anında kale file'ının hafif parlaması/şişmesi (opsiyonel).

**Kabul kriterleri:**
- [ ] Tail görünür ama dikkat dağıtmıyor; performans korunuyor (particle pool
      sınırları içinde).
- [ ] Çarpışma efektleri "hafif" — abartısız.

**DO NOT TOUCH:** fizik, skor, determinizm.

---

## AŞAMA 4 — Power-up'lar

**Hedef:** Arenada periyodik beliren, deterministik (seed'li) geçici efektler;
top değince süreli modifier.

**Tasarım:**
- Efektler: **büyüme** (radius ×1.3), **küçülme** (×0.75), **hızlanma**
  (targetSpeed ×1.3), **yavaşlama** (×0.7). Süre ~4–6 sn.
- `Disc`'e geçici modifier + kalan süre alanları; süre bitince baz stata döner.
- Spawn: seed'li RNG ile konum/zaman → determinizm korunur.
- Görsel: arenada küçük ikon, alınınca kısa efekt + HUD ipucu.

**Kabul kriterleri:**
- [ ] Determinizm korunuyor (aynı seed = aynı power-up akışı).
- [ ] Gol-band kalibrasyonu hâlâ makul (power-up'lar ortalamayı çok
      kaydırmıyor).
- [ ] Power-up görsel olarak okunuyor, oyunu kaotik-eğlenceli yapıyor.

**DO NOT TOUCH:** skor yönü, tek-gap mekaniği.

---

## Sıra ve bağımlılıklar

0. **Aşama 0 (TAMAMLANDI)** — Skor yönü tersine çevrildi (kaleye giren topun
   kendi takımı sayar). `MatchSimulation.swift` + `CONSTITUTION.md` güncellendi.
   Fizik/toplam gol değişmedi, testler kırılmadı.
1. **Aşama 1** (stat motoru) — temel; her şey buna dayanır.
2. **Aşama 2** (oluşturucu) — Aşama 1'in TeamStats'ına bağımlı.
3. **Aşama 3** (efekt) — bağımsız, araya alınabilir.
4. **Aşama 4** (power-up) — Aşama 1'in per-top modifier altyapısına bağımlı.

Her aşama: kendi commit(ler)i → `claude/interface-bugs-performance-0ahegx` →
gözden geçir → main'e merge. Xcode'da build/test doğrulaması kullanıcı
tarafında (bu ortamda Swift toolchain yok).

## Kararlar (kullanıcı onayı ile)

1. ✅ **Boyut → exit:** doğal etki kalsın, yapay dengeleme yok. Büyük top
   kendiliğinden daha kolay gol atar. (`arenaRadius − radius` olduğu gibi.)
2. ✅ Preset stat dağılımları ılımlı (2–4) atandı; kesin denge kalibrasyonla
   doğrulanacak (Xcode'da 20-seed testi).
3. ✅ Forma pattern seti 6 desen — şimdilik yeterli.
