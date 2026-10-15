# DEPAR — kanıtlı güvenlik denetimi

15 Ekim 2026. İstek: gerçek, tekrarlanabilir açıkları bulmak; varsayımı veya yapay test sayılarını canlı veri gibi sunmamak.

## Sonuç ve kapsam

**Yerel kaynakta 6 ayrı sorun testle doğrulandı.** Bildirimlerdeki üç farklı saldırı aynı kök nedene sahip olduğu için tek bulgu sayıldı. Ayrıca önceki canlı Storage sürümüyle SHA-256 eşleşen kaynakta bir tarihsel zayıflık doğrulandı; güncel aday kurallarda bu yol kapalı.

Bu çalışma yalnız denetimdir. Uygulama kaynakları, güvenlik kuralları, Firebase/Cloud ayarları, API anahtarları, bütçeler ve kullanıcı verileri değiştirilmedi. Yeni testler/raporlar yerelde oluşturuldu. Canlı projeye saldırı isteği gönderilmedi, ücretli API deneme çağrısı yapılmadı.

**Önemli sınır:** Firebase CLI oturumu yok. TestFlight binary'si ve güncel canlı Firestore/Functions kaynağı alınamadı. Bu nedenle aşağıdaki altı bulgu, incelenen yerel kod/aday kurallar için kanıtlıdır; tamamının şu anda canlıda bulunduğu iddia edilmez. Önceki Cloud denetiminde saklanan Firestore kaynak hash'i yerel Git sürümleriyle eşleştirilemedi. Erişilemeyen canlı durum, fatura veya saldırgan faaliyeti hakkında sonuç uydurulmadı.

Testlerde Alice/Bob gibi hesaplar, adresler ve sayılar **açıkça yapay yerel test verileridir**. Gerçek müşteri kaydı, şifre, token veya gerçek harcama verisi değildir. Testler gerçek uygulama işlevlerini veya gerçek Firebase emulator kural değerlendirmesini kullanır; yalnızca üretim verisi yerine güvenli test kayıtları konmuştur.

## F6 — Hesap değiştiğinde yanlış hesap için silme isteği gönderilebiliyor

**Önem: Orta. Etki: yanlış hesabın veri silme sürecine alınması. Öncelik: ilk düzeltileceklerden.**

- Kaynak: [silme akışı](../lib/core/services/account_deletion.dart#L39), [dinamik token seçimi](../lib/core/services/safety_api.dart#L54), [silme çağrıları](../lib/core/services/firebase_account_deletion.dart#L10), [ayarlar akışı](../lib/modules/settings/controllers/settings_controller.dart#L165), [kapatılabilir alt ekran](../lib/modules/settings/views/settings_view.dart#L328).
- A hesabıyla silme onayı/yeniden doğrulama başlıyor. `prepareAccountDeletion` yanıtı beklerken alt ekran kapatılabiliyor; çıkış yapılıp B hesabına giriş yapılabiliyor. Akış iptal edilmiyor ve beklenen UID saklanmıyor. Sonraki `requestAccountDeletion` çağrısı A yerine o anda açık B'nin token'ını alıyor.
- Sunucu her çağrının kendi kullanıcısını kontrol ediyor; yeni giriş yapılmış B, yakın zamanlı kimlik şartını karşılıyor. Önceki onayın hangi kullanıcıya ait olduğu sonraki çağrıya bağlı değil.
- **Kanıt:** `AccountDeletion` + `FirebaseAccountDeletion` + `SafetyApi` gerçek sınıflarıyla, HTTP ve token kaynağı mock edilerek test edildi. Hazırlık çağrısı `alice`, silme çağrısı `bob` adına oluştu ve akış başarılı döndü. Ana ajan testi ayrıca yeniden çalıştırdı: 1/1 geçti.
- **Sınır:** Aynı cihaz/uygulama oturumunda hesap değiştirme ve bekleyen istek gerektirir. Uzaktan, rastgele başka UID vererek hesap silme veya hesap ele geçirme kanıtı değildir. Sunucu silme işinin canlıda çalışması bu tur test edilmedi.
- **Öneri:** Akışı başlatan UID'yi her adımda sabitlemek; değişiklikte iptal; silme isteklerinde aynı hesabın token'ını kullanmak; işlem sürerken çıkış/ekran kapatma ile yarım akışın devamını engellemek. Yalnız modalı kilitlemek yerine sunucu/istemci hesap bağı da korunmalı.
- Tekrar: `flutter test --no-pub .release/security-audit/account_delete_session_test.dart`.

## F1 — Fotoğraf denetimi profil alanından aşılabiliyor

**Önem: Orta. Etki: denetlenmemiş görüntü ve dış sunucuya istek.**

- Kaynak: [profil doğrulaması](../functions/rules/profile.fragment.rules#L18), [sahibin güncelleme izni](../functions/rules/profile.fragment.rules#L47), [profil görüntüleme](../lib/modules/home/views/profile_view.dart#L114), [arkadaş avatarı](../lib/modules/friends/views/friends_view.dart#L782).
- `avatarUrl` yalnızca metin/uzunluk açısından kontrol ediliyor. Normal kullanıcı, fotoğraf yükleme endpoint'ini kullanmadan kendi profilindeki alanı dış bir HTTPS görüntü adresine değiştirebiliyor. Diğer kullanıcı bu değeri okuyabiliyor ve istemci görüntü bileşenleri adresi doğrudan kullanıyor.
- **Kanıt:** Gerçek tam aday Firestore kuralları emulator'a yüklendi. Normal Alice profilini `https://audit-image.invalid/unscanned.jpg` adresine güncelledi; Bob profili okuyup aynı değeri aldı. Bu `.invalid` adresine ağ isteği gönderilmedi; kabul/read yolu emulator'da, otomatik görüntü kullanımı uygulama kodunda doğrulandı.
- **Sonuç:** Yeni Storage aday kuralının doğrudan dosya yüklemeyi kapatması bu profil yazma yolunu kapatmıyor. Dış sunucuya gerçek istemci isteği oluşursa IP/zaman gibi istek bilgileri açığa çıkabilir; gerçek kullanıcı verisinin dışarı gönderildiği iddia edilmiyor.
- **Öneri:** Avatar yayınlama yetkisini denetlenen sunucu akışına bağlamak; istemcinin `avatarUrl` alanını keyfi değiştirmesine izin vermemek. Yalnız URL alan adı kontrolü, o nesnenin gerçekten denetlendiğinin kanıtı değildir. Eski fotoğraflar uyumlu taşınmalı.
- Test: `rules-poc.test.cjs` / `F1`.

## F2 — Başka kullanıcıların engelleme listesi okunabiliyor

**Önem: Orta. Etki: özel ilişki bilgisinin açığa çıkması.**

- Kaynak: [public profil alanları](../functions/rules/profile.fragment.rules#L7), [get/list izni](../functions/rules/profile.fragment.rules#L38), [engelleme verisi](../lib/modules/friends/controllers/block_controller.dart#L54).
- `blockedUsers`, tüm oturum açmış kullanıcıların okuyabildiği v2 profil belgesinde saklanıyor. Firestore belgeyi alan alan sansürlemiyor; get/list izni belgenin tamamını döndürüyor.
- **Kanıt:** Alice Bob'u engelledi. Hem engellenmiş Bob profilin `blockedUsers` dizisini alabildi, hem ilgisiz Mallory `profileVersion == 2`, `limit(50)` sorgusunda aynı diziyi okuyabildi.
- **Sınır:** Bu test arkadaş/takipçi listelerinin herkese açık olduğunu göstermiyor. Ayrı negatif testte tek taraflı sahte arkadaşlık ile liste okunamadı; gerçek engelleme batch'i karşılıklı arkadaşlığı sildiğinde sosyal liste erişimi kesildi.
- **Öneri:** Engelleme verisini sahibi dışına kapalı ayrı belgeye taşımak; kurallardaki engelleme denetimlerini bu güvenilir belgeye göre uyarlamak. Yalnız arayüzde alanı gizlemek yeterli değil. [Firestore belge seviyesinde okuma açıklaması](https://firebase.google.com/docs/firestore/security/rules-fields).
- Test: `rules-poc.test.cjs` / `F2`.

## F3 — Tek işlemden çok sayıda bildirim üretilerek spam yapılabiliyor

**Önem: Orta. Etki: bildirim kutusunu doldurma ve ek okuma/yazma maliyeti.**

- Kaynak: [followNotice](../functions/rules/social.fragment.rules#L67), [matchNotice](../functions/rules/social.fragment.rules#L79), [profil bildirim create izni](../functions/rules/social.fragment.rules#L89), [formationInvite](../functions/rules/social.fragment.rules#L110).
- Kural bir ilişki/maç durumunun varlığını kontrol ediyor; bu olaydan yalnızca bir bildirim üretildiğini veya `noticeId`'nin o olaya ait sabit kimlik olduğunu zorlamıyor. İstemcinin tekrar kontrolü doğrudan SDK/REST yazısını durdurmuyor.
- **Kanıt, koruma politikası açıkken:** Aynı gelecek maç için farklı kimliklerle 5 profil davet bildirimi; tek follow-request + tek cooldown izninden aynı batch içinde 5 takip bildirimi; mevcut tek bekleyen pozisyondan maç değiştirilmeden 3 kadro davet bildirimi kabul edildi.
- Bunlar üç ayrı kritik açık değil, aynı tekrar/fanout sorununun üç yolu. Testteki 5/5/3 sayıları yerel denemelerdir; canlı spam veya harcama miktarı değildir.
- **Önkoşul:** Oturum açmış uygun kullanıcı, ilgili hedef/maç ve gerektiğinde doğrulanmış e-posta. Engellenmiş gönderici ve doğrulanmamış davet için negatif testler reddedildi.
- **Öneri:** Bildirim kimliğini olay/gönderen/alıcı ile deterministik bağlamak; gerçek durum geçişiyle aynı atomik işlemde yalnız bir oluşturma; gerekli hız ve toplam sınırlarını sunucuda uygulamak. Yalnız arayüzde dedupe eklemek yeterli değil.
- Testler: `rules-poc.test.cjs` / `F3a`, `F3b`, `F3c`.

## F5 — Hesap silme işi tüm veritabanını tarayarak maliyeti büyütebiliyor

**Önem: Orta. Etki: kaynak/maliyet büyütme ve silme kuyruğunu yavaşlatma.**

- Kaynak: [iş oluşturma](../functions/src/safety.cjs#L36), [sayfalama](../functions/src/safety.cjs#L135), [maç taraması](../functions/src/safety.cjs#L150), [kullanıcı taraması](../functions/src/safety.cjs#L169), [şikayet taraması](../functions/src/safety.cjs#L190), [trigger](../functions/src/index.cjs#L120).
- Yakın zamanda giriş yapmış hesap kendi silme işini oluşturabiliyor; profil varlığı şart değil. Temizleyici, yalnız ilgili UID'nin kayıtlarını sorgulamak yerine maçlar, profiller, beş ilişki koleksiyonu grubu ve raporları tarıyor. İlgisiz kayıtlar da okunuyor/transaction içinde tekrar okunuyor.
- Tek UID'de işin tekrar oluşturulmaması doğru çalışıyor; ancak yeni UID'lerle bu tarama yeniden tetiklenebiliyor. Kuyruk kabulünde IP/genel sınır yok. İş maliyeti, yalnız silinen hesabın verisi yerine toplam veri büyüklüğüyle artıyor.
- **Kanıt:** Gerçek `createSafetyService` işlevi, yerel sentetik DB ile çalıştırıldı. Toplam 750 ilgisiz yapay belge ve profili olmayan 5 yakın-giriş kimliği için 3.750 sorgu sonuç belge okuması, 3.765 transaction okuması ve 90 sorgu sayfası gözlendi. Bunlar gerçek Firebase okuma faturası veya canlı kayıt sayısı değildir. Ana ajan testi ayrıca yeniden çalıştırdı: 1/1 geçti.
- **Önkoşul:** İncelenen temizleyicinin deploy edilmesi ve silme özelliğinin açık olması. Önceki denetimde özellik açık görünse de dağıtılmış kaynak bu kodla eşleştirilemedi; canlı sürümde bu algoritmanın çalıştığı kesinleştirilmedi.
- **Öneri:** UID'ye hedefli indeksli sorgular ve ters ilişki indeksleri; ilişkili kayıtların sayfalı temizliği; tekrar güvenli iş yönetimi ve uygun kötüye kullanım denetimi. Meşru hesap silmeyi kapatmak çözüm değildir.
- Tekrar: `node --test .release/security-audit/deletion-cost.test.cjs`.

## F4 — Kapasite değişikliği oyuncuları tutarsız kadroda bırakabiliyor

**Önem: Düşük. Etki: iş mantığı/veri tutarlılığı; oyuncunun normal ayrılma işleminin reddi.**

- Kaynak: [ownerMatchUpdate](../functions/rules/match-participation.fragment.rules#L80), [update izni](../functions/rules/match-participation.fragment.rules#L110), [istemcinin kapasite denetimi](../lib/core/services/match_participation.dart#L145).
- Maç sahibi yalnız metadata/`maxPlayers` değiştirirse yeni kadronun tutarlılığı her durumda denetlenmiyor. İstemcideki kapasite kontrolü atlanarak doğrudan yazılabiliyor.
- **Kanıt:** 14 kapasiteli, 12 oyunculu yerel maçta sahibin kapasiteyi 10'a indirmesi kabul edildi. Bir oyuncu ayrılmaya çalışınca kalan 11 kişi hâlâ 10 sınırını geçtiği için yazı reddedildi. Kapasite tekrar 14 yapılınca aynı ayrılma yazısı başarılı oldu.
- **Sınır:** Maç sahibi olmak gerekir; rastgele başka birinin maçını düzenleme izni bulunmadı. Bu nedenle uzaktan yetki yükseltme veya kritik veri silme olarak derecelendirilmedi.
- **Öneri:** Kapasite değiştiğinde de tam yeni roster/slot bütünlüğünü doğrulamak; azaltmayı yalnız tutarlı kadro geçişiyle kabul etmek.
- Test: `rules-poc.test.cjs` / `F4`.

## H1 — Önceki Storage sürümü yalnız beyan edilen MIME'a güveniyor

**Tarihsel bulgu; güncel aday Storage kurallarında kapalı.**

- Önceki canlı denetimde saklanan kaynak SHA-256: `1e223e061a0cacff01a115dec314e4cf342f0b4688617b47d3ef1bf29b1ba5c5`.
- Git nesnesi `5741e55e8615eab5c87d96fec7a1a87156e5c2b2`, CRLF normalizasyonundan sonra bu hash ile birebir eşleşti. Dosya: `.release/security-audit/historical-deployed.storage.rules`. Güncel canlı kurallar bu tur tekrar alınmadı.
- Emulator'da bu tarihsel kurallar ile normal kullanıcı, JPEG olmayan yapay baytları `image/jpeg` metadata'sıyla kendi `profile_images/{uid}.jpg` yoluna yükleyebildi. Başka oturumlu kullanıcı aynı baytları okuyabildi.
- Kanıt yalnız Storage kabulü ve SDK okumasıdır. Gerçek Vision sonucu, tetikleyici sonrası kalıcı durum, tarayıcıda kod çalıştırma veya canlı zararlı dosya yüklenmesi iddia edilmez. Metadata'daki MIME, gerçek dosya içeriği/ön denetim kanıtı değildir.
- Güncel aday kurallarda istemcinin create/update yolu reddediliyor; aynı testte bu negatif kontroller geçti. Ancak aday kuralları tek başına deploy etmek eski TestFlight yükleme akışını bozabilir; bu çalışma deploy yapmadı.
- Test: `rules-poc.test.cjs` / `H1`.

## Test kayıtları ve tekrar

- Mevcut Functions birim testleri: **56 geçti, 0 başarısız**.
- Yeni bağımsız Firestore/Storage emulator testleri: **11 geçti, 0 başarısız**. Dört yerel kural bulgusu, üç bildirim yolu, negatif kontroller ve bir tarihsel Storage testi içerir. Proje `demo-depar-audit`, yalnız `127.0.0.1:8189/9199`.
- Yeni silme oturum testi: **1 geçti**; ana ajan ayrıca tekrar çalıştırdı.
- Yeni maliyet büyütme testi: **1 geçti**; ana ajan ayrıca tekrar çalıştırdı.
- Functions üretim bağımlılıkları `npm audit --omit=dev --json`: denetim anında **0 bilinen advisory** döndü. Bu, kaynak kodda veya tüm bağımlılıklarda açık bulunmadığının garantisi değildir; mobil/CI bağımlılıklarının tamamına ait CVE raporu değildir.
- Emulator testindeki kural kopyaları güncel tam aday dosyalarla birebir karşılaştırıldı ve eşleşti. Tarihsel Storage hash'i ayrıca ana ajan tarafından doğrulandı. Emulator kapandı; canlı hedef kullanılmadı.

Dosyalar:

- `.release/security-audit/rules-poc.test.cjs`
- `.release/security-audit/rules-poc-output.txt` (PowerShell UTF-16LE çıktı; 11/11)
- `.release/security-audit/account_delete_session_test.dart`
- `.release/security-audit/account_delete_session_test.log`
- `.release/security-audit/deletion-cost.test.cjs`
- `.release/security-audit/firebase.json`

Windows PowerShell'de yerel kural testini tekrar çalıştırmak için:

```powershell
.\security-tests\node_modules\.bin\firebase.cmd emulators:exec --config .release/security-audit/firebase.json --only firestore,storage --project demo-depar-audit "node --test --test-concurrency=1 .release/security-audit/rules-poc.test.cjs"
```

## Doğrulanmayan iddialar ve açık kalan kapsam

Bu çalışmada uzaktan hesap ele geçirme, moderatör yetkisi kazanma, başka kullanıcı profiline izinsiz yazma, arkadaşlık sahteleme, keyfi sunucu URL'sine SSRF veya şifre sıfırlama sayfasında XSS kanıtı elde edilmedi. Negatif testlerde anonim profil okuma, yabancı profil güncelleme, profil alanından `moderator` ekleme, maç sahipliği devralma, arkadaşlık sahteleme, engellenmiş takip ve doğrulanmamış davet reddedildi. Bunlar test edilen yollarla sınırlıdır.

Önceki denetimdeki API anahtarı/kota/App Check gözlemleri ve hassas Auth hash yapılandırmasının yanlışlıkla komut çıktısına girmesi olayı [Cloud denetim raporunda](DEPAR-cloud-guvenlik-maliyet-denetimi-2026-10-15.md) kayıtlıdır. CLI oturumunun iptal edildiği makbuz mevcut; bu işlem hash yapılandırma anahtarının yenilendiğinin kanıtı değildir. Bu olay kamuya veri sızdığı veya hesapların ele geçirildiği iddiasına dönüştürülmedi ve yeni kod açığı sayısına eklenmedi.

Güncel canlı kurallar/Functions kaynakları, IAM değişiklik geçmişi, dağıtılmış TestFlight paketi, ağ trafiği ve gerçek kullanım/harcama kayıtları erişim sağlanınca ayrıca doğrulanmalıdır. Buradaki sonuç “uygulamadaki bütün açıklar kesinlikle bulundu” anlamına gelmez. Öncelik: yanlış hesap silme ve denetlenmemiş avatar yolunu kapatmak; ardından engelleme gizliliği, bildirim spam'i ve temizleme maliyeti; kapasite bütünlüğünü aynı güvenli düzeltme sürecinde ele almak. Bu rapor kapsamında düzeltme veya deploy yapılmadı.
