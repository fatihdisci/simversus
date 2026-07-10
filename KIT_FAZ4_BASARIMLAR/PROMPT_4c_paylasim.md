# PARÇA 4c — Paylaşım Kartları (organik büyüme kanalı)

**Önce oku:** CONSTITUTION.md, DESIGN_TOKENS.md
**Bağımlılık:** Faz 3. (4a/4b ile paralel başlanabilir; başarım kartı bölümü 4b bittikten sonra bağlanır.)

## Amaç
Maç sonucu / şampiyonluk / başarım kartlarının görsel render'ı + share sheet. Her paylaşım = ücretsiz reklam.

## Kapsam
1. `Core/Share/ShareCardRenderer.swift`: `ImageRenderer` ile SwiftUI view → UIImage (1080×1350, 4:5 — Instagram uyumlu):
   - **Maç kartı:** iki badge, skor büyük, gol dakikaları, tarih; turnuva maçıysa tur etiketi
   - **Şampiyonluk kartı:** şampiyon badge, format adı, "şampiyonluk yolu" özeti
   - **Başarım kartı:** büyük rozet, başlık, kazanım tarihi
   - Her kartta altta subtle watermark: "SimVersus" + accent şerit (kaldırılamaz — bilinçli karar, organik dağıtım)
2. Result / Champion / Achievement detay ekranlarına `share.cta` → `ShareLink`.
3. Kart tasarımı koyu tema, `.scoreboard` tipografi — gece maçı LED panosu hissi.
4. Dil: kart cihaz diliyle render edilir.
5. Stringler (TR+EN): `share.cta` (Paylaş / Share), `share.card.fulltime` (Maç Sonu / Full Time), `share.card.champion` (Şampiyon / Champion), `share.card.achievement`.

## Kabul kriterleri
- [ ] Üç kart tipi de 1080×1350, keskin (retina scale doğru)
- [ ] TR/EN kartlar doğru
- [ ] Watermark her kartta var
- [ ] Share sheet iptalinde crash/leak yok

## DO NOT TOUCH / YAPMA
- Video/replay paylaşımı EKLEME (ileri konu, ReplayKit ayrı iş)
- Sosyal SDK entegrasyonu (native share sheet yeter — bağımlılık ilkesi)
- Watermark'ı kaldırma seçeneği ekleme
