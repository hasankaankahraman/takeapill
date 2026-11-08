# app-ads.txt

AdMob, reklam envanterinin gerçekten bu uygulamaya ait olduğunu `app-ads.txt` ile doğrular. Dosya, mağaza kayıtlarındaki geliştirici web sitesinin **alan adı kökünde** olmalı:

- Mağazalardaki web sitesi: `https://hasankaankahraman.github.io/takeapill/`
- AdMob'un aradığı adres: `https://hasankaankahraman.github.io/app-ads.txt` (`/takeapill/` altı **sayılmaz**)

## Adımlar

1. AdMob → Hesap → Ayarlar'dan yayıncı kimliğini (`pub-` ile başlayan 16 hane) alın ve [app-ads.txt](app-ads.txt) içindeki `pub-XXXXXXXXXXXXXXXX` yerine yazın. Satırın son alanı (`f08c47fec0942fa0`) Google'ın sabit TAG kimliğidir, değişmez.
2. GitHub'da **`hasankaankahraman.github.io`** adında herkese açık bir repo açın (kullanıcı sitesi; kökü `hasankaankahraman.github.io` olur ve mevcut `/takeapill/` proje sitesini bozmaz).
3. Dosyayı o reponun köküne `app-ads.txt` adıyla koyun, Settings → Pages'te `main` / root'tan yayınlayın.
4. `curl -s https://hasankaankahraman.github.io/app-ads.txt` dosyayı düz metin döndürmeli.
5. AdMob → Uygulamalar → app-ads.txt sekmesinden "Güncellemeleri kontrol et". Doğrulama 24 saate kadar sürebilir; bu sürede reklam dolumu düşük olabilir.

Mağaza kayıtlarındaki web sitesi alanının dolu olması gerekir: App Store'da Marketing URL, Play'de Store listing → Contact details → Website.
