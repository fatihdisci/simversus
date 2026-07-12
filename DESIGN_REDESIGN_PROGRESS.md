# SimVersus Tasarım Dili Yenileme — İlerleme Belgesi

Son güncelleme: 12 Temmuz 2026

## Amaç

Mevcut işlevleri ve deterministik maç motorunu koruyarak tüm tek oyunculu akışı
"Gece Arenası / Canlı Yayın" tasarım dili altında birleştirmek. Görsel yön;
katmanlı koyu stadyum atmosferi, kontrollü neon enerji, güçlü takım kimliği ve
kompakt yayın grafikleri üzerine kuruludur.

## Kit ve faz denetimi

| Faz | Kod tabanındaki durum | Tasarım yenilemeyle ilişkisi |
|---|---|---|
| Faz 1 MVP | Ana ekran → takım seçimi → maç → sonuç akışı, temel design system ve i18n mevcut | Bu çalışmanın ana kapsamı |
| Faz 2a | Özel takım oluşturucu, renk/rozet/desen/stat sistemi mevcut | Creator UX yeniden düzenlenecek |
| Faz 2b | Rewarded ile ek takım slotu mevcut | Kilit alanı korunacak, yeni özellik eklenmeyecek |
| Faz 2c | Geçmiş ve istatistik ekranları mevcut | Ana ekranda sahte giriş oluşturulmayacak |
| Faz 2d | Ayarlar ekranı mevcut | Kontroller yeni dile uyarlandı |
| Faz 3 — Turnuva | **Yeniden tasarlandı:** "Benim takımım" yolculuğu, anında sonuçlandırma, kupa dolabı, özel yarı final/final sunumu, elenme akışı. CONSTITUTION §4.12'ye tabi. | Yeni bileşen sistemi turnuva ekranlarına temel olacak |
| Faz 3.5 — Retention | **Yeni ara faz:** Ses tasarımı, olay anlatımı, tahmin sistemi, rövanş/seri, takım ustalığı (kozmetik), günlük arena, ilk maç deneyimi. Faz 4'ten önce retention'ı sağlam temellere oturtur. | Anlatım UI ve tahmin kartları yeni bileşenleri kullanacak |
| Faz 4 — Başarımlar + Meydan Okuma | **Yeniden tasarlandı:** GameEvents olay sistemi, davranış odaklı başarımlar (pasif sayaç değil), meydan okuma kodu (backend'siz viral sistem), paylaşım kartları. CONSTITUTION §4.17'ye tabi. | Başarım galerisi ve meydan okuma kartları yeni tasarım dilinde |
| Faz 5 — Genişleme | **Sıralama değişti:** 5a fizik modları (önce), 5b arena şekilleri (sonra), 5c görsel temalar (en son). CONSTITUTION §4.9 determinizm kuralına tabi. | Mod seçim UI'ı yeni bileşenlerle |
| Faz 6 — Multiplayer | Game Center ile online eşleşme. **Ön koşul:** Faz 3–4 sistemlerinin oturmuş olması. Meydan okuma kodu ile entegre. | Kompakt HUD rakip adı/durum rozetini taşıyabilecek |

> **Temmuz 2026 revizyonu:** Faz sıralaması ve içerikleri ChatGPT ürün analizi doğrultusunda güncellendi. Detaylar için ilgili KIT_README.md dosyalarına ve CONSTITUTION.md §4.12–§4.19'a bakınız.

## Mevcut tasarım sorunları

- Düz siyah zemin ve büyük amaçsız boşluklar ürün kimliğini zayıflatıyor.
- SF Mono; bölüm başlıkları ve normal metinlerde fazla kullanıldığı için arayüz
  futbol/arcade yerine geliştirici aracı gibi görünüyor.
- Buton, kart, seçim ve navigasyon durumları ekran bazında tekrar yazılmış.
- Pasif CTA kontrastı yetersiz; seçili/pasif durumlar yalnız renge dayanıyor.
- Takım renkleri yalnız arma içinde kalıyor, ekran kompozisyonuna yansımıyor.
- Team Select eşleşmeyi göstermiyor; iki yatay liste aynı bilgiyi tekrar ediyor.
- Team Creator tek ve uzun form; önizleme ve kaydet aksiyonu kayboluyor.
- Match HUD arena estetiğinden kopuk ve kontrol butonları fazla baskın.
- Result ekranında gol satırları kırpılıyor ve kutlama hiyerarşisi zayıf.

## Yeni tasarım ilkeleri

1. **Arena önce gelir:** UI, oyunu kapatmaz; arena çizgileri ve takım renkleriyle onu çerçeveler.
2. **Takım rengi bağlamdır:** Seçilen takımlar düşük opaklıklı glow ve kenar vurgularıyla ekrana taşınır.
3. **Mono yalnız veridir:** Skor, dakika, kısa kod ve stat rakamlarında kullanılır.
4. **Durum yalnız renk değildir:** Seçimlerde check, border ve ölçek; kilitte ikon ve açıklama birlikte kullanılır.
5. **Tek bileşen dili:** Surface, CTA, icon button, section header ve selection card ortak sistemden gelir.
6. **Küçük ekran önce:** Sticky CTA, kontrollü yatay içerik, Dynamic Type ve en az 44 pt dokunma hedefi.
7. **Hareket anlam taşır:** 150/250/450 ms geçişler; Reduced Motion açıkken statik karşılık.

## Uygulama sırası

- [x] 1. Tasarım tokenları ve ortak bileşenler
- [x] 2. Ana ekran
- [x] 3. Takım seçimi
- [x] 4. Takım oluşturucu
- [x] 5. Maç HUD'ı
- [x] 6. Sonuç ekranı
- [x] 7. TR/EN, küçük ekran, erişilebilirlik ve final QA

## Değişiklik günlüğü

### Başlangıç denetimi

- Altı güncel ekran görüntüsü incelendi.
- `00_TEMEL/DESIGN_TOKENS.md`, `CONSTITUTION.md`, Faz 1–6 kit README'leri ve
  tasarımla ilişkili promptlar tarandı.
- Fizik ve 30 saniyelik maç değişikliklerinin bu UI çalışmasından ayrı korunacağı doğrulandı.

### Aşama 1 — Tasarım sistemi

- Katmanlı Gece Arenası renkleri, surface/border/metin rolleri eklendi.
- Display, ekran başlığı, headline, buton, section ve caption font rolleri tanımlandı.
- `ArenaBackground`, `ArenaSurface`, `ArenaButtonStyle`, `ArenaIconButton` ve
  `ArenaSectionHeader` ortak bileşenleri oluşturuldu.
- Ortak sistem iOS Simulator hedefinde temiz derlendi.

### Aşama 2 — Ana ekran

- Düz boş ekran; arena halkaları, takım orb'ları, marka mesajı ve bilgi satırıyla
  güçlü bir hero kompozisyonuna dönüştürüldü.
- Birincil maç CTA'sı ortak button/surface sistemine taşındı.

### Aşama 3 — Takım seçimi

- Tekrarlanan Ev Sahibi/Deplasman listeleri kaldırıldı.
- Üstte düzenlenebilir VS kartı, altta tek takım havuzu eklendi.
- İlk seçimden sonra deplasman slotuna otomatik odak ve sticky başlama CTA'sı eklendi.

### Aşama 4 — Takım oluşturucu

- Uzun form; Kimlik, Arma/Forma ve Oyun Tarzı kartlarına ayrıldı.
- Canlı takım önizlemesi üstte, kaydet CTA'sı altta sticky hale getirildi.
- Dengeli/Güçlü/Hızlı/Büyük hazır stat profilleri ve puan bütçesi açıklaması eklendi.
- Seçili renkler check işaretiyle güçlendirildi; pasif yüzey kontrastları iyileştirildi.

### Aşama 5 — Maç HUD'ı

- Skor, takım renkleriyle çevrelenen kompakt yayın şeridine taşındı.
- Dakika, devre ve 90 dakikalık ilerleme barı tek HUD'da birleştirildi.
- Çıkış/pause kontrolleri küçültüldü; duraklatma paneli ortak surface/button sistemine geçti.

### Aşama 6 — Sonuç ekranı

- Kazanan, skor ve iki takım güçlü bir hero kartta birleştirildi.
- Gol satırlarında kırpılan uzun takım adları kaldırıldı; dakika + orb + kısa kod kullanıldı.
- Rövanş/Yeni Maç/Ana Menü aksiyonları sticky ve hiyerarşik hale getirildi.

### Aşama 7 — QA ve erişilebilirlik

- Yeni kullanıcı metinlerinin tamamı TR/EN String Catalog'a eklendi.
- Seçimlerde renk yanında check/slot rozeti, pasif CTA'da okunur metin ve en az
  44 pt dokunma alanı kullanıldı.
- Uzun içerikli ekranlarda alt CTA sticky, içerik scroll edilebilir tutuldu.
- Tüm uygulama iOS Simulator arm64 hedefinde temiz derlendi.
- Ana ekran iPhone 17 Pro / iOS 26.5 simülatöründe gerçek screenshot ile kontrol
  edildi; safe-area, CTA kontrastı ve dikey yerleşim doğrulandı.

### Aşama 8 — Cihaz ekran görüntüsü denetimi (12 Temmuz)

Gerçek cihazdan alınan 11 ekran görüntüsü üzerinden yapılan sayfa sayfa
denetimde bulunan hatalar ve düzeltmeleri:

- **Geçmiş/İstatistikler ham anahtar gösteriyordu** (`stats.played`,
  `stats.wins`, `stats.goalsFor`): katalogdaki boş girdiler TR/EN dolduruldu.
- **Beraberlikte "BERABERE / Berabere" çift satır**: `result.draw` yayın diline
  çevrildi ("Puanlar paylaşıldı" / "The points are shared").
- **"Arena tamamlandı"** eyebrow'u "Maç tamamlandı" yapıldı.
- **Yarı devre kartı canlı oyunu gizliyordu** (motorda devre arası yok; kart
  2. yarının ilk dakikalarını örtüyordu): kart süresince sahne duraklatılıyor,
  kapanınca kullanıcının pause tercihine dönülüyor; alt metin "İkinci yarı
  başlamak üzere" oldu.
- **Takım seçiminde bayat ipucu** (iki takım seçiliyken hâlâ "Şimdi deplasman
  takımını seç"): eşleşme hazır olduğunda "Eşleşme hazır — başlama vuruşu!"
  gösteriliyor.
- **Ayarlar'da üst üste iki "Reklamları Kaldır"**: durum satırı "Reklamlar
  etkin" oldu, CTA tek kaldı.
- **"Fiyat yükleniyor…" kilitlenmesi**: `PurchaseManager`'a yükleme durumu
  (loading/loaded/failed) eklendi; başarısız yüklemede "Fiyat yüklenemedi." +
  "Tekrar Dene" aksiyonu ve sheet açılışında otomatik yeniden deneme var.
- **Reklam kaldırma ikonu**: tek başına "yasak" okunan `nosign`, megafon +
  yasak kompozisyonuna çevrildi.
- **Mono font ihlalleri** (kaydet ipucu, slot/hata mesajları cümle hâlinde SF
  Mono'daydı): ilke gereği cümleler `.caption`'a alındı, mono yalnız veride.
- **Oluşturucuda statik kayıt ipucu**: yalnız eksik olanı söyleyen dinamik
  ipucuna çevrildi; aktif stat preseti çipte vurgulanıyor; diğer slotta seçili
  olduğu için kapalı renk swatch'ına çapraz çizgi eklendi.
- **Geçmiş ekranı sistem parçaları**: segmented Picker yerine ortak
  `ArenaChoicePill` (Ayarlar süre seçimiyle aynı bileşen), maç satırlarına
  takım orb'ları + kazanan vurgusu, istatistikte kısa kod yerine tam ad; ham
  sistem `List` olan detay sayfası Arena diline (skor kartı + gol akışı)
  taşındı; `TeamStore`'un her render'da yeniden kurulması giderildi.

Tamamı iPhone 17 Pro simülatöründe temiz derlendi; 24 birim testin hepsi geçti.

### Aşama 9 — Kale fiziği ve akıcılık (12 Temmuz)

Kullanıcı raporu: "gol olacak top sekiyor, saçma sekmeler var, kasma oluyor."
Denetimde üç geometrik kusur bulundu ve motor yeniden kalibre edildi:

- **Görünmez ağız kirişi:** eski kabul kuralı topun kapıdan *tamamen temiz*
  geçmesini şart koşuyordu; 85 pt'lik görünür açıklığın yalnız ortadaki
  29 pt'i gol kabul ediyor, kalan kısımda top görünürde boşlukta radyal
  sekiyordu. Ağız artık gerçekten açık: direkler arasında duvar yok, kenar
  temasları yalnız fiziksel direk/ray çarpışmasından gelir.
- **Hayalet ayna kapısı:** açı testi `sin` simetrisi yüzünden kalenin tam
  karşısındaki ±5.3°'lik bantta da "kapı" görüyordu; top orada duvara her
  çarpışta bir kare sekmeyip sonra tekmeleniyordu (görünür titreme).
  Açısal açıklık testi (yarım açı < 90°) bunu kökten kapattı.
- **Direk-ray dikişi:** nokta-direk ve ayrı ray çözücülerinin çarpışma
  manifoldları çakışıyordu; direk yayı boyunca kayan top ray bölgesine
  15 pt gömülüp ani "ışınlanma" sekmesi yiyordu. İkisi tek kapsül
  (segment + uç yuvarlağı) çarpışmasında birleştirildi — direk sıyırması,
  ray kayması ve aradaki geçiş tek sürekli normalle çözülür.
- **Kalibrasyon:** dürüst ağız skoru artırdığı için `gapWidth` 0.54 → 0.44
  rad'a indirildi; 40 seed ölçümünde ortalama 1.33 gol (bant 0.8–2.0),
  0-0 oranı %20. `00_TEMEL/PHYSICS_CONSTANTS.md` senkronlandı.
- **Power-up doğum düzeltmesi:** pickup topun üstüne doğup aynı adımda
  yutulabiliyordu (anlık yanıp sönme); doğum noktası toplara çakışırsa
  seed'li sınırlı yeniden çekim yapılır.
- **Akıcılık:** SKView 60 fps kilidi kaldırıldı (panel yerlisi — ProMotion'da
  120 fps, sabit adımlı sim değişmez); gol anındaki 60 düğümlük konfeti
  patlaması için parçacık havuzu sahne kurulumunda ön-ısıtılır; power-up
  senkronunun her karedeki Set/Array tahsisi sabit-durum kısa yoluyla kesildi.

Determinizm, 20-seed gol bandı ve tüm birim testleri geçti.

## Bilinçli kapsam sınırları

- Ayarlar, geçmiş, başarımlar, turnuva ve multiplayer girişleri uygulanmış gibi
  gösterilmedi; ilgili kit fazları tamamlandığında bu bileşen sistemini kullanacak.
- Faz 5b tema kataloğu oluşturulmadı; Gece Arenası şu an uygulama kabuğunun
  varsayılan dili, ilerideki maç teması seçiminin yerine geçmiyor.
- Fizik sonuçları ve takım veri şeması tasarım çalışması kapsamında değiştirilmedi.
