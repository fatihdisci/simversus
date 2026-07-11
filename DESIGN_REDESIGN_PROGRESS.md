# SimVersus Tasarım Dili Yenileme — İlerleme Belgesi

Son güncelleme: 11 Temmuz 2026

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
| Faz 2b | Rewarded ile ek takım slotu henüz bağlı değil | Kilit alanı korunacak, yeni özellik eklenmeyecek |
| Faz 2c | Geçmiş ve istatistik ekranları henüz yok | Ana ekranda sahte giriş oluşturulmayacak |
| Faz 2d | Ayarlar ekranı placeholder; maç içi pause/exit sonradan eklendi | Kontroller yeni dile uyarlanacak, eksik ayarlar bu kapsamda tamamlanmayacak |
| Faz 3–4 | Turnuva, başarım ve paylaşım henüz uygulanmamış | Yeni bileşen sistemi gelecekteki ekranlara temel olacak |
| Faz 5b | Klasik/Gece/Kar/Retro/Uzay maç temaları planlanmış | Uygulama kabuğu varsayılan Gece Arenası olur; tema sistemi taklit edilmeyecek |
| Faz 6 | Multiplayer plan aşamasında | Kompakt HUD ileride rakip adı/durum rozetini taşıyabilecek |

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

## Bilinçli kapsam sınırları

- Ayarlar, geçmiş, başarımlar, turnuva ve multiplayer girişleri uygulanmış gibi
  gösterilmedi; ilgili kit fazları tamamlandığında bu bileşen sistemini kullanacak.
- Faz 5b tema kataloğu oluşturulmadı; Gece Arenası şu an uygulama kabuğunun
  varsayılan dili, ilerideki maç teması seçiminin yerine geçmiyor.
- Fizik sonuçları ve takım veri şeması tasarım çalışması kapsamında değiştirilmedi.
