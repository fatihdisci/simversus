# PARÇA 6b — Online Maç Akışı (Agreement Protokolü)

**Önce oku:** CONSTITUTION.md, KIT_README.md (mimari temel — protokol adımları oradadır)
**Bağımlılık:** 6a tamamlanmış olmalı.

## Amaç
Eşleşmiş iki kullanıcının takım seçip AYNI deterministik maçı kendi cihazlarında izlemesi.

## Kapsam
1. `Core/Multiplayer/MatchAgreement.swift` (Codable):
   - `protocolVersion: Int` (uyumsuz sürüm → `mp.version.mismatch`, maç kurulmaz)
   - Kullanıcı seçimleri (takım ID; özel takımlar online'da KULLANILMAZ — yalnızca 16 preset; karşı cihazda özel takım verisi yok), opsiyonel arena/tema/mod (Faz 5 kuruluysa, Codable config)
   - `seed: UInt64` (host üretir; host = playerID'si sözlükbilimsel küçük olan — deterministik, tartışmasız)
2. `Core/Multiplayer/AgreementFlow.swift` (küçük durum makinesi):
   - selectingTeams → exchanging → confirmed → countdown(3sn) → playing → finished
   - Mesajlaşma: `GKMatch.send(data:mode:.reliable)` + JSON; her adım çift taraflı ACK
   - Takım seçim ekranı: kendi seçimini yap, rakibin seçimi geldiğinde göster (`mp.opponent.picked %@`); iki taraf hazır → host agreement paketi → guest doğrular + ACK → senkron geri sayım → iki cihaz LOKAL `MatchScene` başlatır (aynı config, aynı seed)
3. Maç sırasında: fizik trafiği YOK; 5 sn'de bir hafif presence ping (`.unreliable`) — 15 sn yanıtsızlık = rakip koptu göstergesi (HUD'da `mp.opponent.left` rozeti), MAÇ DEVAM EDER ve normal biter (deterministik — sonuç zaten belliydi)
4. Online maçta HUD'a rakip GC takma adı eklenir; skorboard aynı.
5. Kenar durumlar:
   - Agreement sırasında kopma → lobby'e temiz dönüş + `mp.connection.lost`
   - Uygulama arka plana → maç pause EDİLMEZ (online'da pause yok; geri gelince sahne kaldığı simülasyon zamanına hızlı ileri sarılır — deterministik motorla `update` adımlarını hızlı koşarak yakala)
   - Reklam: online maçlar interstitial sayacına dahil; reklam yalnız Result kapanışında (asla eşleşme akışının ortasında değil)
6. Stringler (TR+EN): `mp.opponent.picked %@`, `mp.waiting.opponent` (Rakip bekleniyor… / Waiting for opponent…), `mp.countdown %lld`, `mp.opponent.left` (Rakip ayrıldı / Opponent left), `mp.connection.lost` (Bağlantı koptu / Connection lost), `mp.version.mismatch` (Rakibin uygulama sürümü farklı / Opponent has a different app version).

## Kabul kriterleri
- [ ] İki cihazda aynı maç aynı skorla bitiyor (10 test maçında agreement log + sonuç karşılaştırması)
- [ ] Maç ortası kopma: kalan cihazda maç normal tamamlanıyor
- [ ] Arka plan → geri dönüş: simülasyon doğru zamana yetişiyor, sonuç değişmiyor (testle kanıtla)
- [ ] Özel takımlar online seçim ekranında görünmüyor
- [ ] Sürüm uyuşmazlığı düzgün mesajla kuruluyor

## DO NOT TOUCH / YAPMA
- MatchScene fizik koduna müdahale (determinizmi bozacak HER değişiklik yasak — motor dokunulmaz, sadece config ile beslenir)
- Frame-frame durum senkronizasyonu deneme (mimari karar: agreement + lokal simülasyon)
- Chat/emoji/tepki EKLEME
