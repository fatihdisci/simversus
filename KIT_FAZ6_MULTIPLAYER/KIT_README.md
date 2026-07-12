# KIT FAZ 6 — ÇOK OYUNCULU (Game Center) (v2.0)

Hedef: İki gerçek kullanıcının online eşleşip aynı maçı izlemesi. Tamamen Game Center — kendi backend YOK (bağımlılık ilkesi korunur).

> **Ön koşul:** Bu fazın retention'a anlamlı katkı yapabilmesi için Faz 3 (turnuva + kupa dolabı), Faz 3.5 (tahmin + seri + takım ustalığı) ve Faz 4 (meydan okuma + başarımlar) sistemlerinin oturmuş olması gerekir. İki kişinin aynı pasif maçı izlemesi, tek kişinin izlemesinden otomatik olarak daha eğlenceli değildir. Online mod, mevcut tek oyunculu sistemlerin üzerine inşa edilen bir katmandır — onların yerine geçmez.

---

## Mimari temel: deterministik senkronizasyon

Maç motoru seed'li ve deterministik olduğu için gerçek zamanlı fizik senkronizasyonu GEREKMEZ. Protokol:

1. Eşleşme kurulur (GKMatchmaker)
2. Her kullanıcı takım seçer
3. Host (GC playerID'si alfabetik küçük olan — deterministik host seçimi) seed üretir
4. `MatchAgreement` paketi (iki seçim + seed + config, Codable/JSON) karşılıklı teyitleşir
5. İki cihaz maçı LOKAL oynatır — sonuç matematiksel olarak birebir aynı
6. Maç sırasında ağ trafiği YOK (yalnızca opsiyonel presence ping'i); kopma maçı etkilemez

Bu tasarım: sıfır sunucu, sıfır lag sorunu, sıfır anti-cheat karmaşası (sonuç seed'den türetilir, iki taraf da doğrular).

---

## Parça sırası ve bağımlılıklar

| Parça | İçerik | Bağımlılık |
|---|---|---|
| 6a | GC authentication + eşleştirme (rastgele + davet) | Faz 4 (GameEvents, meydan okuma kodu) |
| 6b | Online maç akışı: agreement protokolü, senkron başlangıç, kopma senaryoları | 6a |
| 6c | Maç sonrası: rövanş, geçmiş entegrasyonu, online başarımlar | 6b |

---

## Meydan okuma kodu entegrasyonu

Faz 4d'deki meydan okuma kodu sistemi, Faz 6 online maçlar için **hazır davet mekaniğidir:**

- Kullanıcı "Arkadaşa Meydan Oku" dediğinde meydan okuma kodu oluşturulur.
- Kod iMessage/AirDrop/URL ile paylaşılır.
- Alan kişi kodu açar → uygulama açılır → takım seçer → GKMatchmaker üzerinden eşleşme kurulur (host zaten kodu oluşturandır).
- Alternatif: GKMatchmakerViewController ile rastgele eşleşme.

Bu sayede meydan okuma kodu ve online eşleşme birbirini tamamlar.

---

## Bilinçli sınırlar

- **Kullanıcı adı araması yok:** GC serbest username aramaya izin vermez. Karşılığı: GC arkadaş listesi + `GKMatchmakerViewController` davet akışı (iMessage/AirDrop davet linki dahil). Kullanıcıya "arkadaşını davet et" olarak sunulur.
- **Turnuvalar online DEĞİL** (yalnızca tekli maç) — v2.0 kapsam sınırı.
- **Sesli/yazılı chat YOK.**
- **Sohbet ve sosyal ağ YOK.**
- GC hesabı olmayan/istemeyen kullanıcı: tüm single-player deneyimi aynen çalışır, multiplayer girişi GC login'e yönlendirir.

---

## Online maça özgü retention özellikleri

Faz 3.5'teki sistemler online maça uyarlanır:

- **Online tahmin:** İki oyuncu da maç başlamadan tahmin yapar. İkisi de doğru bilirse ikisine de seri sayacı işler.
- **Online seri:** Aynı iki oyuncu tekrar eşleşirse seri durumu gösterilir.
- **Online rövanş:** Maç sonunda "Rövanşı Al" → aynı oyuncuya GKMatchmaker üzerinden tekrar davet.
- **Online başarımlar:** "İlk online galibiyet", "3 online maç üst üste kazan", "Bir meydan okumayı kabul et ve kazan"

---

## Faz kabul kriteri

- İki gerçek cihazda (veya cihaz+simülatör) rastgele eşleşme VE davetle eşleşme uçtan uca çalışıyor
- Aynı maç iki ekranda aynı skorla bitiyor (agreement log'larıyla doğrulanır)
- Maç ortasında bağlantı/uygulama kapanma senaryoları çökmesiz
- Meydan okuma kodundan online eşleşme başlatılabiliyor
- Online maç geçmişe "vs [rakip GC adı]" formatında kaydediliyor
- Online rövanş akışı çalışıyor
