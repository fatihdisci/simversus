# KIT FAZ 5 — GENİŞLEME (v1.5+)

Hedef: içerik çeşitliliği — arena şekilleri, temalar, fizik modları. Talebe/metriklere göre sıra değişebilir; parçalar birbirinden bağımsızdır.

| Parça | İçerik |
|---|---|
| 5a | Arena çeşitliliği: yeni arena şekilleri + engeller |
| 5b | Görsel temalar: arka plan/saha temaları |
| 5c | Fizik modları: vahşi top, dev top, turbo, kaos modu |

## Monetizasyon notu
Bu fazın içerikleri karma modelle açılır: bir kısmı ücretsiz, bir kısmı rewarded (oturum başına), premium tema paketi opsiyonel İKİNCİ IAP olabilir (`com.simversus.themepack`) — karar metriklere göre; promptlar iki senaryoyu da destekleyecek şekilde flag'li yazıldı.

## Faz 6 ile ilişki
Çok oyunculu mod ayrı kittedir (KIT_FAZ6_MULTIPLAYER, Game Center). Bu fazdaki arena/tema/mod içerikleri Faz 6 online maçlarında da kullanılabilir olacak şekilde `MatchConfig` parametreleriyle taşınır — özel bir hazırlık gerekmez, konfigürasyon zaten seed ile birlikte serileştirilebilir tasarlanır (5a/5c parçalarında `Codable` şartı).
