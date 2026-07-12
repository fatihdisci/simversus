# KIT FAZ 5 — GENİŞLEME (v1.5+)

Hedef: Oynanış çeşitliliği ile yeni sonuç uzayları üretmek. **Önce fizik modları, sonra arena şekilleri, en son görsel temalar.** Görsel tema kullanıcıyı geri getirmez; yeni fizik kuralları getirir.

CONSTITUTION §4.9 (fizik parametreleri) ve determinizm kurallarına tabidir.

---

## Parça sıralama mantığı

| Öncelik | Parça | Neden |
|---|---|---|
| **1** | 5a — Fizik modları | Yeni sonuç uzayları üretir; her mod farklı strateji ve heyecan yaratır. Kullanıcıyı geri getirir. |
| **2** | 5b — Arena şekilleri | Denge ve kale geometrisini etkiler; dikkatli yapılmalı. Fizik modları oturduktan sonra gelir. |
| **3** | 5c — Görsel temalar | Güzel görünür ama retention'a katkısı en düşüktür. "Pastanın kreması" — en son gelir. |

---

## 5a — Fizik modları

Mevcut fizik motoruna **mod** parametresi ekler. Her mod aynı seed ile farklı sonuç üretir — yeni bir deneyimdir, sadece görsel değişiklik değildir.

**Mod tanımları:**

| Mod | Açıklama | Denge etkisi |
|---|---|---|
| **Kaos** | Tüm topların kütlesi %30 azalır, hız limiti kalkar, çarpışma esnekliği %50 artar | Yüksek skor, öngörülemez |
| **Ağır Çekim** | Fizik time-step 0.3×, süre aynı kalır. Hareketler ağır ve dramatik | Düşük skor, stratejik |
| **Ani Ölüm** | İlk gol maçı bitirir. Süre sınırı yok, maksimum 90 sn | Tek gerilim anı |
| **Power-up Yağmuru** | Pickup doğma aralığı 1.5 sn (normal: 4 sn). Arenada sürekli power-up döner | Kaotik, yüksek varyans |
| **Hızlanan Final** | Son 10 saniyede tüm topların hızı 2×, arena dönüş hızı 1.5× | Son saniye dramı |
| **Dev Top** | Bir takımın topu %40 büyük (kale çıkışı zor), diğeri normal. Her iki takım da dev topla oynayabilir | Asimetrik |
| **Ters Dönüş** | Arena saat yönünde değil, saat tersine döner. Kale boşluğu konumu aynı | Simetri kırıcı |
| **Rüzgar** | Sabit yönlü sahte "rüzgar" kuvveti tüm toplara etki eder. Yön ve şiddet seed'den | Pozisyonel oyun değişir |

**Teknik:**
- Her mod bir `PhysicsMod` enum case'i, `MatchConfig`'e `mod: PhysicsMod?` parametresi eklenir
- `PhysicsMod`, motorun `applyMod(_:)` metoduna parametreleri enjekte eder
- Tüm modlar seed'li ve deterministiktir (test edilebilir)
- Modlar takım gücünü değiştirmez; yalnızca fizik parametrelerini modüle eder
- `Codable` — Faz 6 online maçlarında ve meydan okuma kodlarında taşınabilir

**Erişim modeli:**
- 2 mod ücretsiz (Kaos, Ani Ölüm)
- 3 mod rewarded (oturum başına 1 izleme ile açılır)
- 3 mod premium tema paketiyle birlikte (`com.simversus.themepack` opsiyonel IAP)

## 5b — Arena şekilleri

Mevcut tek arena şekli (daire, 1 kale boşluğu) korunur. Yeni şekiller aynı fizik motoruyla çalışır ancak duvar geometrisi değişir.

**Dikkat:** Arena şekli değişiklikleri kale geometrisini ve dolayısıyla gol oranlarını etkiler. Her yeni şekil 40+ seed'lik gol bandı testinden geçmelidir (0.8–2.0 gol/maç bandı korunur).

**Aday şekiller (tek kale boşluğu korunur, CONSTITUTION §4.4):**
- Oval arena (genişlik > yükseklik: kanat oyunu)
- Altıgen arena (köşe sekmeleri)
- Dikdörtgen arena (yuvarlak köşeli, klasik saha hissi)
- Dambıl arena (dar orta koridor)

**Engeller (şekilden bağımsız, her arenaya eklenebilir):**
- Orta direk (arena merkezinde sabit engel)
- Hareketli bariyer (yavaşça dönen duvar parçası)
- Mini kale (boşluğun karşısında, topu yavaşlatan küçük cep)

## 5c — Görsel temalar

Arena ve UI görünümünü değiştirir; fizik sonuçlarını etkilemez. Tamamen kozmetik.

**Temalar:**
- **Gece Arenası** (varsayılan, mevcut)
- **Kar Arenası:** Beyaz zemin, buz mavisi duvarlar, kar efekti parçacıkları
- **Retro:** Pixel art estetiği, 8-bit gol efekti, yeşil-siyah zemin
- **Uzay:** Koyu mor/lacivert, yıldız parçacıkları, neon yeşil duvarlar
- **Ateş:** Turuncu-kırmızı gradient, kıvılcım parçacıkları, lav zemin

**Teknik:**
- `ArenaTheme` enum'ı, `MatchConfig`'e `theme` parametresi
- Tema değişikliği yalnızca render katmanını etkiler; `MatchSimulation`'a dokunmaz

---

## Monetizasyon (karma model)

| İçerik | Erişim |
|---|---|
| 2 fizik modu (Kaos, Ani Ölüm) | Ücretsiz |
| 3 fizik modu | Rewarded (oturum başına 1 izleme ile açılır) |
| 3 fizik modu + tüm temalar + 2 arena şekli | Premium tema paketi IAP (`com.simversus.themepack`, opsiyonel — metriklere göre karar verilir) |
| Arena şekilleri (2 tanesi) | Ücretsiz |
| Görsel temalar (Gece Arenası hariç) | Rewarded veya tema paketi |

---

## Faz 6 ile ilişki

Bu fazdaki tüm içerikler (`PhysicsMod`, `ArenaShape`, `ArenaTheme`) `MatchConfig` parametreleriyle taşınır ve `Codable`'dır. Faz 6 online maçlarında ve meydan okuma kodlarında (Faz 4d) hiçbir ek hazırlık gerektirmeden kullanılabilir.

---

## Faz kabul kriteri

- [ ] 8 fizik modu tanımlı, hepsi deterministik ve test edilebilir
- [ ] Her mod için 20 seed'lik gol bandı testi: ortalama 0.8–2.0 aralığında
- [ ] Arena şekilleri için gol bandı korunuyor (40 seed test)
- [ ] Mod + şekil + tema kombinasyonları çökmesiz çalışıyor
- [ ] Rewarded kilit mekaniği: kilitli mod seçildiğinde rewarded akışı, izlendikten sonra oturum boyunca açık
- [ ] `Codable` uyumu: mod/şekil/tema serileştirilip meydan okuma koduna gömülebiliyor
