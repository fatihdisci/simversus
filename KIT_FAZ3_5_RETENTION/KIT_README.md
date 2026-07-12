# KIT FAZ 3.5 — RETENTION PAKETİ (v1.35)

Hedef: Kullanıcıya maç öncesinde karar, maç boyunca gerilim, maçtan sonra sonuç ve devamlılık vermek. Bu faz, Faz 3 turnuva sistemiyle birlikte veya hemen sonrasında gelir; Faz 4 paylaşım özelliklerinden önce retention'ı sağlam temellere oturtmak içindir.

CONSTITUTION §4.13–§4.16 ve §4.19'a tabidir.

---

## Parça sırası ve bağımlılıklar

| Parça | İçerik | Bağımlılık |
|---|---|---|
| 3.5a | Ses tasarımı: çarpışma, gol, düdük, tribün, ambiyans | Faz 1 (maç motoru) |
| 3.5b | Olay anlatımı: kural tabanlı kısa mesajlar, maç sonu ödülleri | 3.5a |
| 3.5c | Maç öncesi tahmin sistemi + tahmin serileri | Faz 2 (maç geçmişi) |
| 3.5d | Rövanş / seri sistemi + sonuç ekranı iyileştirmeleri | Faz 2 |
| 3.5e | Takım ustalığı: istatistik, seviye, kozmetik ödüller | Faz 2 |
| 3.5f | Günlük arena | 3.5c (tahmin sistemi) |
| 3.5g | İlk maç deneyimi (ilk kullanıcı için heyecan garantili seed) | 3.5a, 3.5b |

Parçalar birbirinden bağımsız değildir; sırayla uygulanmaları önerilir. 3.5a ve 3.5b (ses + anlatım) maç deneyiminin algılanan kalitesini en çok yükselten parçalardır, bu yüzden önce gelirler.

---

## Parça detayları

### 3.5a — Ses tasarımı

Maçın "spor draması" hissini görsel değişikliklerden daha fazla yükselten en kritik parça.

**Minimum ses seti:**
- Top-top çarpışması (farklı hızlarda farklı ses)
- Top-duvar çarpışması (metalik yankı)
- Top-direk çarpışması (keskin metalik)
- Kale yaklaşırken yükselen ambiyans (top gap'e 60 pt mesafede tetiklenir)
- Gol sesi (kısa, güçlü patlama + tribün coşkusu)
- İlk yarı düdüğü
- Final düdüğü (maçın havasına göre değişen yoğunluk)
- Tribün uğultusu (arka plan loop, maçın gerginliğine göre dinamik seviye)

**Teknik gereklilikler:**
- Tüm sesler asset catalog'da, format: `.caf` veya `.wav` (düşük gecikme)
- Ses seviyesi Ayarlar'dan kontrol edilebilir (mevcut sistem)
- Düşük güç modunda arka plan uğultusu kısılır
- Sessiz modda (ring/silent switch) ana sesler duyulur, tribün kısılır

### 3.5b — Olay anlatımı ve maç sonu ödülleri

Yapay zekâ yorumu değil, kural tabanlı kısa metin mesajları. Motor olaylarından tetiklenir:

**Maç içi anlatım (HUD altında kısa yanıp sönen metin):**
- "Direkten döndü!" (top direğe çarpıp kaleye giremediğinde)
- "Son saniye baskısı" (son 10 sn içinde top gap'e 40 pt yaklaştığında)
- "Üç çarpışmalık kontra" (3'ten fazla top-top veya top-duvar çarpışması 2 sn içinde)
- "Geri dönüş başladı" (1-0 gerideyken gol atıldığında)
- "Üst üste ikinci gol" (aynı takım 15 sn içinde 2. golü attığında)
- "Az farkla kaçtı" (top gap'ten 10 pt mesafeyle çıkamadıysa)
- "Köşeden döndü" (top gap'in kenarına çarpıp döndüyse)

**Maç sonu ödülleri (sonuç ekranında gösterilir):**
- "Maçın Topu" — en çok gol atan veya en uzun süre hayatta kalan top
- "En Hızlı Şut" — en yüksek anlık hız (pt/sn)
- "En Yakın Kaçan Pozisyon" — gap'e en yakın mesafeye gelip çıkamayan an
- "En Etkili Power-up" — en çok çarpışma/etki üreten power-up
- "Geri Dönüş Anı" — geriden gelip öne geçme anı
- "Direk Kurbanı" — en çok direğe çarpan top

**Teknik:**
- Tüm anlatım tetikleyicileri `GameEvents` üzerinden yayınlanır (Faz 4'te kurulacak olay sistemi bu fazda `GameEvents` temelini kurar).
- Anlatım metinleri String Catalog'da TR/EN karşılıklıdır.

### 3.5c — Maç öncesi tahmin sistemi

Oyuncuya maç başlamadan **önce** sorulan sorular. Doğru tahminler seri oluşturur. Seyirci oyununa oyuncu ajansı eklemenin en düşük maliyetli ve en etkili yoludur.

**Tahmin soruları (maç başına 1-2 soru, rastgele seçilir):**
- "Maçı kim kazanır?" (Ev Sahibi / Beraberlik / Deplasman)
- "Toplam gol 2'nin üstünde mi altında mı?"
- "İlk golü hangi takım atar?"
- "Maç uzatmaya gider mi?" (süre bitiminde skor eşitse)
- "Takım X gol atar mı?"

**Tahmin serisi:**
- Doğru tahminler bir "seri" sayacında birikir.
- 3, 5, 7, 10 doğru tahmin serisi rozetleri kazanılır.
- Yanlış tahminde seri sıfırlanır.
- "En uzun tahmin serisi" istatistiği tutulur.

**Tasarım kısıtları (CONSTITUTION §4.13):**
- Gerçek para veya bahis dili KULLANILMAZ.
- Puan, jeton, karmaşık ekonomi YOKTUR.
- Tahminler yalnızca rozet/başarım için kozmetik değer taşır.
- Tüm tahminler maç başlamadan önce kilitlenir.
- Tahmin UI'ı hafif ve hızlıdır (maç başlatma akışını yavaşlatmaz).

### 3.5d — Rövanş / seri sistemi

Aynı iki takım tekrar karşılaştığında maç bağlamı otomatik oluşur.

**Seri tipleri (maç geçmişinden otomatik hesaplanır):**
- **Rövanş:** Aynı iki takım 2. kez karşılaşıyor → "Seri: 1-0" veya "Seri berabere"
- **Üç maçlık seri:** Aynı iki takım 3 kez karşılaşmış → "Serinin final maçı"
- **Derbi:** Aynı şehirden iki takım (örn. İstanbul Demir vs İstanbul Rüzgar)
- **Ezeli rekabet:** 5+ kez karşılaşmış takımlar → head-to-head istatistikleri

**Sonuç ekranı iyileştirmeleri:**
- "Rövanşı Al" düğmesi — ana ekrana dönmekten daha güçlü bir devam aksiyonu
- Seri skoru görünür (örn. "Seri: İstanbul Demir 2 – 1 İstanbul Rüzgar")
- "Son karşılaşmayı 3–2 kaybetti" gibi bağlam mesajı
- Gol özeti: önceki maç(lar)ın skoru küçük kartlarda
- Önceki maçtaki aynı eşleşmenin kilit anları (örn. "Geçen maç 42. saniyede gol gelmişti")

**Teknik:**
- Maç geçmişi (SwiftData) zaten bu verileri sağlar.
- Seri durumu `MatchRecord` sorgularından türetilir, ayrı bir model gerektirmez.
- "Rövanşı Al" aynı takımlarla yeni `MatchConfig` oluşturur.

### 3.5e — Takım ustalığı

Oyuncunun seçtiği takımla zaman içinde kimlik oluşturmasını sağlar. Lig/sezon moduna girmeden, yol haritasının kapsamını aşmadan yapılır.

**Takım başına tutulan istatistikler ( SwiftData veya UserDefaults):**
- Oynanan maç sayısı
- Galibiyet / Beraberlik / Mağlubiyet
- Atılan toplam gol
- En uzun galibiyet serisi
- En büyük geri dönüş (kaç gol geriden gelip kazandığı)
- Farklı rakiplere karşı galibiyet sayısı
- Turnuva şampiyonlukları
- Tahmin doğruluk yüzdesi (o takımın maçlarında)

**Ustalık seviyeleri:**
| Seviye | Ad | Gereksinim (örnek) |
|---|---|---|
| 1 | Çaylak | 1 maç |
| 2 | Seyirci | 10 maç |
| 3 | Taraftar | 25 maç, en az 10 galibiyet |
| 4 | Kaptan | 50 maç, en az 1 kupa |
| 5 | Efsane | 100 maç, en az 3 kupa, 10+ farklı rakip |

**Kozmetik ödüller (CONSTITUTION §4.15 — performans avantajı SAĞLAMAZ):**
- Seviye 2: Rozet çerçevesi (takım seçiminde ve maç HUD'ında parlar)
- Seviye 3: Özel gol kutlaması (takımının renginde konfeti)
- Seviye 4: Maça giriş animasyonu (takım orb'u dönerak gelir)
- Seviye 5: Şampiyonluk yıldızı (takım kartında ve badge'de ⭐)
- Tüm seviyeler: Takım kartı zemini değişir (düz → metalik → altın)

**Takım seçim ekranına entegrasyon:**
- Her takım kartında ustalık seviyesi rozeti
- Ustalık ilerleme çubuğu (takım detayında)
- "En çok oynadığın takımlar" sıralaması

### 3.5f — Günlük arena

Backend olmadan günlük geri dönüş nedeni. CONSTITUTION §4.16'ya tabidir.

**Mekanik:**
- Tarihten türetilen sabit seed (YYYY-AA-GG hash → UInt64)
- Her gün bir "Günün Arenası" — sabit rakip, özel fizik modu (Faz 5 geldiğinde), tek deneme hakkı
- Günlük küçük görev (örn. "Bugün hafif takımla ağır rakibi yen", "En az 3 gol çıkan bir takım seç")
- Günün rozeti: görevi tamamlayanlara özel günlük rozet
- Günlük tahmin: tek seferlik tahmin hakkı (maç başlamadan)

**Tasarım kısıtları:**
- Cihaz saati değiştirilebilir — kabul edilebilir, tek oyunculu ve kozmetik ödüllü bir sistem
- "Küresel sıralama" veya "dünya genelinde X kişi tamamladı" gibi sahte rekabet hissi VERİLMEZ
- Kaçırılan günler için geriye dönük oynama YOKTUR
- Günlük arena ana ekranda özel bir kart/bölüm olarak gösterilir

### 3.5g — İlk maç deneyimi

Yeni kullanıcının ilk maçı heyecanlı olmalı. Golsüz veya yavan bir ilk maç gösterilmesi retention'ı daha ilk saniyede baltalar.

**Tasarım:**
- İlk maç için önceden test edilmiş, en az 2-3 gollü, heyecanlı 3-5 seed belirlenir.
- İlk maçta bu seed'lerden biri rastgele kullanılır.
- **Fizik hilesi yapılmaz** — seed'ler doğal oynanıştan seçilir.
- Kullanıcıya bunun "ilk maçı" olduğu hissettirilmez; normal bir maç gibi sunulur.
- Kullanıcının `matchesPlayedCount == 0` olması yeterli tetikleyicidir.

**Teknik:**
- Seçilmiş seed'ler `FirstMatchSeeds` adında bir enum/array olarak tanımlanır.
- İlk maç dışında bu seed'ler kullanılmaz.

---

## Faz kabul kriteri

- [ ] Ses tasarımı: tüm çarpışma, gol, düdük ve tribün sesleri çalışıyor; ses seviyesi ayarlardan kontrol ediliyor
- [ ] Olay anlatımı: en az 7 farklı maç içi mesaj tetikleniyor, TR/EN doğru, mesajlar kural tabanlı
- [ ] Maç sonu ödülleri: en az 5 farklı ödül tipi hesaplanıp sonuç ekranında gösteriliyor
- [ ] Tahmin: maç öncesi tahmin soruları geliyor, doğru/yanlış sayacı çalışıyor, seri rozetleri kazanılıyor
- [ ] Rövanş: aynı iki takım tekrar seçildiğinde seri durumu ve "Rövanşı Al" görünüyor
- [ ] Takım ustalığı: 5 seviye, her takım için istatistik, kozmetik ödüller çalışıyor; performans avantajı yok
- [ ] Günlük arena: tarih seed'i tutarlı, günlük görev ve rozet çalışıyor
- [ ] İlk maç: yeni kurulumda ilk maç seçilmiş seed'lerden biriyle başlıyor, en az 2 gol içeriyor
- [ ] Bağlamsız maç yasağı (CONSTITUTION §4.18): ana ekrandan serbest maç başlatılamıyor; tüm maçlar bir bağlam içinde
