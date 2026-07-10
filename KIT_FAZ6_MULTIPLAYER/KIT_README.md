# KIT FAZ 6 — ÇOK OYUNCULU (Game Center) (v2.0)

Hedef: iki gerçek kullanıcının online eşleşip aynı maçı izlemesi. Tamamen Game Center — kendi backend YOK (bağımlılık ilkesi korunur).

## Mimari temel: deterministik senkronizasyon

Maç motoru seed'li ve deterministik olduğu için gerçek zamanlı fizik senkronizasyonu GEREKMEZ. Protokol:
1. Eşleşme kurulur (GKMatchmaker)
2. Her kullanıcı takım (+ arena/tema/mod, Faz 5 varsa) seçer
3. Host (GC playerID'si alfabetik küçük olan — deterministik host seçimi) seed üretir
4. `MatchAgreement` paketi (iki seçim + seed + config, Codable/JSON) karşılıklı teyitleşir
5. İki cihaz maçı LOKAL oynatır — sonuç matematiksel olarak birebir aynı
6. Maç sırasında ağ trafiği YOK (yalnızca opsiyonel presence ping'i); kopma maçı etkilemez

Bu tasarım: sıfır sunucu, sıfır lag sorunu, sıfır anti-cheat karmaşası (sonuç seed'den türetilir, iki taraf da doğrular).

| Parça | İçerik | Bağımlılık |
|---|---|---|
| 6a | GC authentication + eşleştirme (rastgele + davet) | Faz 4 (GameEvents) |
| 6b | Online maç akışı: agreement protokolü, senkron başlangıç, kopma senaryoları | 6a |
| 6c | Maç sonrası: rövanş, geçmiş entegrasyonu, online başarımlar, leaderboard | 6b |

## Bilinçli sınırlar

- **Kullanıcı adı araması yok:** GC serbest username aramaya izin vermez. Karşılığı: GC arkadaş listesi + `GKMatchmakerViewController` davet akışı (iMessage/AirDrop davet linki dahil). Kullanıcıya "arkadaşını davet et" olarak sunulur.
- Turnuvalar online DEĞİL (yalnızca tekli maç) — v2.0 kapsam sınırı.
- Sesli/yazılı chat YOK.
- GC hesabı olmayan/istemeyen kullanıcı: tüm single-player deneyimi aynen çalışır, multiplayer girişi GC login'e yönlendirir.

## Faz kabul kriteri
- İki gerçek cihazda (veya cihaz+simülatör) rastgele eşleşme VE davetle eşleşme uçtan uca çalışıyor
- Aynı maç iki ekranda aynı skorla bitiyor (agreement log'larıyla doğrulanır)
- Maç ortasında bağlantı/uygulama kapanma senaryoları çökmesiz
