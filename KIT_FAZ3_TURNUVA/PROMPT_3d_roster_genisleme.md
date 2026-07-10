# PARÇA 3d — Roster Genişlemesi: 16 Takım

**Önce oku:** CONSTITUTION.md, TEAMS.json, I18N_RULES.md
**Bağımlılık:** 3b tamamlanmış olmalı (Büyük Turnuva 16 takım gerektirir; bu parça o formatın gerçek içeriğini sağlar).

## Amaç
tier 2 takımlarının (10 adet) tüm modlarda kullanıma açılması.

## Kapsam
1. `TeamStore`: `allTeams` (tier 1 + 2) sunumu; TeamSelect ve turnuva kurulum ekranları artık 16 preset gösterir (bölgesel/alfabetik gruplu, aranabilir liste — 16 + özel takımlar tek scroll'da ezilmesin).
2. String kataloğuna tier 2 takım adları (`team.<id>.name`, TR+EN — TEAMS.json nameTR/nameEN'den).
3. tier 2 badge'lerinin görsel kontrolü: 16 badge yan yana DEBUG önizleme view'ında hiçbir ikili karıştırılacak kadar benzer olmamalı; benzerlik varsa badgeShape/renk TEAMS.json'da değer düzeyinde ayarlanır (şema değişmez, commit'te belirt).
4. baseStrength dengesi: 20 seed × rastgele eşleşme testinde tier 2 takımlar tier 1'e karşı %20–40 bandında kazanabilmeli (tamamen ezilmemeli).

## Kabul kriterleri
- [ ] 16 takım tekli maç + tüm turnuva formatlarında seçilebilir, adlar iki dilde doğru
- [ ] Büyük Turnuva (16) autofill'i 16 farklı preset ile dolduruyor
- [ ] Seçim ekranları 16+N takımla kullanılabilir (iPhone SE dahil)
- [ ] Badge ayırt edilebilirlik kontrolü yapıldı
- [ ] Güç dengesi testi geçiyor

## DO NOT TOUCH / YAPMA
- Yeni takım İCAT ETME — yalnızca TEAMS.json'daki tier 2
- json şemasını değiştirme
- Gerçek kulüp çağrışımını artıracak isim/renk "iyileştirmesi"
- TournamentEngine mantığı
