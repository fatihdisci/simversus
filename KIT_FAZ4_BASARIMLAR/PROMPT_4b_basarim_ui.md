# PARÇA 4b — Başarım UI

**Önce oku:** CONSTITUTION.md, DESIGN_TOKENS.md, I18N_RULES.md
**Bağımlılık:** 4a tamamlanmış olmalı.

## Amaç
Başarım galerisi, parametrik rozetler, kazanım toast'ı, ilerleme göstergeleri.

## Kapsam
1. `DesignSystem/AchievementBadgeView.swift`: parametrik vektör rozet — altıgen madalyon formu, kademe rengi (bronz #B08D57 / gümüş #AEB6C2 / altın #E3B341), içinde başarıma özgü basit geometrik glif (katalogda glif adı tanımlı; SF Symbols + Path karışımı serbest, asset YOK). Kilitli hali: silüet (düşük opasite, gri). Gizli+kilitli: "?" glifi.
2. `Features/Achievements/AchievementsView.swift` (Home'dan giriş `home.achievements`):
   - Üstte özet: x/20 + kademe dağılımı
   - Grid galeri: rozet + başlık; kilitliler silüet + açıklama görünür (gizlilerde `achievement.hidden.placeholder`)
   - Sayaçlı başarımlarda ilerleme çubuğu (7/10 maç), `accent` renk
   - Satır detay sheet'i: büyük rozet, açıklama, kazanım tarihi
3. Kazanım toast'ı: `achievementUnlocked` yayınını dinleyen global overlay — üstten süzülen kompakt kart (rozet mini + `achievement.unlocked.toast` + başlık), 2.5 sn, üst üste kazanımlarda kuyruk. Maç SIRASINDA tetiklenirse maç bitişine kadar bekletilir (HUD temiz kalır). Reduced Motion: animasyonsuz görün/kaybol.
4. Result/Champion ekranlarına "bu maçta kazanılanlar" satırı (varsa).
5. Stringler (TR+EN): `home.achievements` (Başarımlar / Achievements), `achievement.unlocked.toast` (Başarım Kazanıldı! / Achievement Unlocked!), `achievement.progress %lld/%lld`, `achievement.summary %lld/%lld`, `achievement.tier.bronze/silver/gold`.

## Kabul kriterleri
- [ ] Galeri 20 başarımı doğru durumlarla gösteriyor (kilitli/açık/gizli/sayaçlı)
- [ ] Toast maç sırasında HUD'u bozmuyor, kuyruk çalışıyor
- [ ] Rozetler her kademe renginde ayırt edilebilir; VoiceOver etiketleri tam
- [ ] TR/EN eksiksiz

## DO NOT TOUCH / YAPMA
- AchievementEngine mantığına dokunma — UI yalnızca okur + yayın dinler
- Yeni başarım tanımı ekleme (tanımlar 4a kataloğunda)
- Konfeti/ağır animasyon (toast kompakt kalır)
