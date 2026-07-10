# PARÇA 6a — Game Center Temeli + Eşleştirme

**Önce oku:** CONSTITUTION.md, KIT_README.md (mimari temel), I18N_RULES.md

## Amaç
GC authentication ve iki eşleşme yolu: rastgele rakip + davetle eşleşme. Maç akışı 6b'de — bu parça eşleşmeyi kurup `GKMatch` teslim eder.

## Kapsam
1. Capability: Game Center. `Core/Multiplayer/GameCenterManager.swift`:
   - Sessiz authentication (app açılışında `GKLocalPlayer.local.authenticateHandler`); login zorlanmaz, başarısızsa multiplayer girişi kilitli görünür + dokununca GC ayarlarına yönlendirme (`mp.gc.required`)
   - `authState` published (notAuthenticated / authenticating / authenticated)
2. `Core/Multiplayer/MatchmakingService.swift`:
   - **Rastgele:** `GKMatchRequest` (min/max 2 kullanıcı) + `GKMatchmaker.shared().findMatch` — özel UI'lı bekleme ekranı (sistem VC değil), iptal edilebilir, 60 sn timeout → `mp.match.timeout`
   - **Davet:** `GKMatchmakerViewController` (sistem UI — arkadaş seçimi + iMessage davet linki buradan gelir); gelen davetleri `GKLocalPlayer` invite listener ile karşıla (app kapalıyken gelen davet → açılışta yakalanır)
   - Çıktı: kurulmuş `GKMatch` + rakip `GKPlayer` bilgisi (takma ad, avatar) → 6b'nin gireceği `MultiplayerSession` nesnesine sarılır
3. `Features/Multiplayer/MultiplayerLobbyView.swift` (Home'dan `home.multiplayer`):
   - GC durumu, iki büyük seçenek kartı: `mp.random` / `mp.invite`
   - Rastgele bekleme ekranı: arayış animasyonu (Reduced Motion uyumlu), iptal
   - Eşleşince: rakip kartı (GC takma adı + avatar) + 6b akışına geçiş noktası (şimdilik stub: "eşleşme kuruldu" durumu)
4. Stringler (TR+EN): `home.multiplayer` (Online Maç / Online Match), `mp.random` (Rastgele Rakip / Random Opponent), `mp.invite` (Arkadaşını Davet Et / Invite a Friend), `mp.searching` (Rakip aranıyor… / Finding opponent…), `mp.found %@`, `mp.match.timeout` (Rakip bulunamadı, tekrar dene / No opponent found, try again), `mp.gc.required` (Online maç için Game Center girişi gerekli / Game Center sign-in required for online matches), `common.cancel` mevcut.

## Kabul kriterleri
- [ ] GC girişli iki cihaz rastgele eşleşebiliyor
- [ ] Davet akışı: gönder → karşı cihazda kabul → eşleşme kuruluyor (app kapalıyken davet senaryosu dahil)
- [ ] GC'siz kullanıcıda single-player hiç etkilenmiyor; multiplayer girişi düzgün kilitli
- [ ] Arama iptali/timeout temiz (leak yok, tekrar aranabiliyor)

## DO NOT TOUCH / YAPMA
- Maç başlatma/agreement protokolü (6b) — eşleşme kurulunca dur
- Kendi sunucu/relay/Firebase EKLEME (bağımlılık ilkesi)
- Turn-based API (`GKTurnBasedMatch`) KULLANMA — realtime `GKMatch` (maç canlı izlenecek)
- Single-player koduna dokunma
