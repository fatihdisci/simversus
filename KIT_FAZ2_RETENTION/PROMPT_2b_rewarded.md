# PARÇA 2b — Rewarded Ads: Ekstra Takım Slotu

**Önce oku:** CONSTITUTION.md (§4.3), I18N_RULES.md
**Bağımlılık:** 2a tamamlanmış olmalı.

## Amaç
"Reklam izle → +1 özel takım slotu (kalıcı)". Rewarded kanal açılışı — ileride turnuva kilitlerinde de (3c) aynı altyapı kullanılacak.

## Kapsam
1. `AdManager`'a rewarded desteği: test unit `ca-app-pub-3940256099942544/1712485313` (`// TODO: PROD`), preload, `showRewarded(onReward:)`. Reklam yüklü değilse buton disabled + `ads.rewarded.unavailable` mesajı.
2. Slot açma akışı: 2a'daki kilitli oluştur butonu → sheet: "Reklam izle, kalıcı yeni slot kazan" (`slots.unlock.title`, `slots.unlock.cta`) → ödül callback'inde `CustomTeamStore.unlockedSlots += 1` (UserDefaults, kalıcı, üst sınır toplam 5 slot).
3. **isAdFree kullanıcı:** rewarded AKIŞI AYNEN ÇALIŞIR (Reklamsız IAP yalnızca interstitial'ı kaldırır — sheet'te bunu netleştiren küçük not: `slots.unlock.adfreeNote`).
4. Ödül verilmeden reklam kapatılırsa slot AÇILMAZ; tekrar denenebilir.
5. Stringler (TR+EN): `slots.unlock.title` (Yeni Takım Slotu / New Team Slot), `slots.unlock.cta` (Reklam İzle ve Aç / Watch Ad to Unlock), `slots.unlock.adfreeNote`, `ads.rewarded.unavailable` (Reklam şu an hazır değil / Ad not ready yet), `slots.max` (Maksimum slota ulaştın / You've reached max slots).

## Kabul kriterleri
- [ ] Test rewarded izlenince slot kalıcı açılıyor (restart dahil)
- [ ] Erken kapatmada slot açılmıyor
- [ ] isAdFree'de rewarded çalışıyor, interstitial hâlâ kapalı
- [ ] 5 slot sınırında CTA yerine `slots.max` görünüyor

## DO NOT TOUCH / YAPMA
- Interstitial mantığına dokunma
- Slot dışında rewarded kullanım alanı ekleme (3c'nin işi)
