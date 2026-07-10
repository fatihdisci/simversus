# PARÇA 1b — Takım Modeli + Badge + Takım Seçim Ekranı

**Önce oku:** CONSTITUTION.md, TEAMS.json, DESIGN_TOKENS.md (TeamBadgeView bölümü), I18N_RULES.md

## Amaç
Takım verisinin yüklenmesi, parametrik logo (badge) ve kullanıcının Ev Sahibi/Deplasman seçtiği ekran.

## Kapsam
1. `Resources/teams.json`: TEAMS.json içeriğini AYNEN kopyala.
2. `Core/Models/Team.swift`: `Team: Codable, Identifiable, Hashable` — alanlar json şemasıyla birebir. `BadgeShape: String, Codable, CaseIterable` enum (star, chevron, wave, diamond, ring). Renkler için `Color` hesaplanan property (hex'ten).
3. `Core/Data/TeamStore.swift`: bundle'dan teams.json yükler, `tier == 1` filtreli `mvpTeams` sunar. Yükleme hatası = `fatalError` (bundle verisi, sessiz fallback yok).
4. `DesignSystem/TeamBadgeView.swift`: DESIGN_TOKENS.md spesifikasyonuna göre — shield `Shape`, 5 geometrik iç şekil, `short` kodu. Parametre: `team: Team, size: CGFloat`. SADECE vektör çizim (Path/Shape), asset yok.
5. `Features/TeamSelect/TeamSelectView.swift`:
   - İki sütun/bölge: Ev Sahibi (`teamselect.home`) ve Deplasman (`teamselect.away`)
   - 6 MVP takımı badge + isim ile listelenir; seçilenler vurgulanır
   - Aynı takım iki tarafta seçilemez
   - İkisi de seçiliyse `teamselect.start` CTA aktifleşir → `onStart(home:away:)` closure çağırır (navigation 1d'de bağlanacak)
6. String kataloğuna takım adı anahtarlarını ekle: `team.<id>.name` TR+EN (json'daki nameTR/nameEN'den).

## Kabul kriterleri
- [ ] 6 takım badge'i birbirinden görsel olarak ayırt edilebilir; hiçbir badge'de hayvan/kulüp simgesi yok
- [ ] TR/EN dilde takım adları doğru
- [ ] Aynı takımı iki tarafa seçmek imkânsız
- [ ] Badge 32pt'te de 120pt'te de keskin (vektör)
- [ ] Temiz build

## DO NOT TOUCH / YAPMA
- teams.json şemasına alan ekleme/çıkarma
- tier 2 takımları UI'da gösterme
- Maç motörüne dokunma (1c)
- Navigation kurma (1d) — closure ile dışarı ver
