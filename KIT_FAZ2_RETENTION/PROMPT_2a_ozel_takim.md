# PARÇA 2a — Özel Takım Oluşturucu

**Önce oku:** CONSTITUTION.md, DESIGN_TOKENS.md (TeamBadgeView), I18N_RULES.md

## Amaç
Kullanıcı kendi takımını yaratır: isim + 2 renk + badge şekli. Ücretsiz kullanıcıda 1 slot (2. slot 2b'de rewarded ile açılır).

## Kapsam
1. `Core/Models/CustomTeam.swift`: SwiftData `@Model` — name (kullanıcı girdisi, max 20 karakter), primaryHex, secondaryHex, badgeShape, createdAt. `Team` protokol/adapter ile motorun beklediği arayüze uydurulur (`baseStrength` sabit 75).
2. `Features/TeamCreator/TeamCreatorView.swift`:
   - İsim alanı (boş/sadece boşluk reddedilir; küfür filtresi YOK ama gerçek kulüp adları blocklist'i VAR: ["galatasaray","fenerbahçe","fenerbahce","beşiktaş","besiktas","trabzonspor","göztepe","goztepe","bursaspor"] — case/diacritic-insensitive kontrol, eşleşirse `creator.error.realClub` uyarısı)
   - 2 renk seçici (`ColorPicker` değil — 12 preset renkten swatch grid, kontrast garantisi için)
   - 5 badge şekli seçici, canlı TeamBadgeView önizlemesi
   - Kaydet → TeamSelect listesinde "Özel Takımlar" bölümünde görünür
3. Slot mantığı: `CustomTeamStore.maxSlots` = 1 (2b `unlockedSlots`'u artıracak; UserDefaults). Slot doluysa oluştur butonu kilitli görünür + kilit ikonu (rewarded bağlantısı 2b'de).
4. TeamSelect güncellemesi: preset 6 + özel takımlar birlikte listelenir; özel takım her iki tarafa da seçilebilir (kendi kendine karşı hariç).
5. Stringler (TR+EN): `creator.title` (Takımını Yarat / Create Your Team), `creator.name.placeholder`, `creator.colors`, `creator.shape`, `creator.save`, `creator.error.realClub` (Gerçek kulüp adları kullanılamaz / Real club names are not allowed), `teamselect.section.custom` (Özel Takımlar / Custom Teams), `creator.slot.locked`.

## Kabul kriterleri
- [ ] Özel takım oluşturulup maça sokulabiliyor, badge doğru render
- [ ] Blocklist çalışıyor (büyük/küçük harf + Türkçe karakter varyasyonları)
- [ ] 1 slot dolunca ikinci oluşturma kilitli
- [ ] App restart sonrası özel takım duruyor (SwiftData)

## DO NOT TOUCH / YAPMA
- Rewarded ad EKLEME (2b) — kilit UI'ı inert bırak
- teams.json'a yazma (özel takımlar yalnızca SwiftData'da)
- MatchScene fizik kodu
