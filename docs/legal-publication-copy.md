# DEPAR yasal sayfalarına eklenecek metinler

13 Ekim 2026. Bu dosya yayımlanmamış metin taslağıdır; yayın hedefi iOS / App Store'dur. Kullanıcının verdiği `C:\Users\ONUR\halisaha_app` yolu mobil uygulama deposudur. Uygulamanın bağlandığı ayrı `depar-web` deposu, kaynak commit `7de4458d484237299cba46313820a15b4c890768` üzerinden `.release/depar-web` klasörüne alındı; bu klasör bağımsız Git deposudur ve mobil depoda ignore edilir. Mevcut canlı gizlilik ve koşullar sayfaları HTTP 200 ile erişilebilir ve doğru destek adresini içeriyor; canlı içerik halen 2 Mayıs 2026 tarihli. Görünürlük, moderasyon/itiraz ve gerçek silme istisnaları için HTML değişiklikleri ayrı depoda hazırlanır. Veri sorumlusunun kimliği, doğrulanmış iletişim adresi, saklama süreleri ve yurt dışı aktarım dayanağı işletmeci tarafından tamamlanmadan tam bir KVKK aydınlatma metni olarak yayımlanamaz.

İletişim adresi kullanıcı tarafından `destekdepar@gmail.com` olarak doğrulandı. Gelen kutusu ve moderasyon takibini uygulama sahibi yürütecek.

15 Ekim 2026 ek bilgi: kullanıcı resmi yayıncıyı **Emir Topaloğlu**, destek/iletişim e-postasını **destekdepar@gmail.com** olarak teyit etti. Bu iki bilgi gizlilik ve kullanım koşulları HTML taslaklarına eklendi; taslak tarihleri 15.10.2026 olarak güncellendi. Yayıncı adı ve destek e-postası tekrar istenmez. Kişinin veri sorumlusu sıfatı, posta adresi, saklama ve aktarım kararları hakkında verilmemiş bilgiler tahmin edilmedi. Bu yerel değişiklik herhangi bir web yayını veya hesap açma işlemi değildir.

HTML düzeltmeleri `.release/depar-web/gizlilik.html` ve `.release/depar-web/kosullar.html` dosyalarında hazır. CSS değiştirilmedi; UTF-8, HTML parse ve diff kontrolleri geçti. Ayrı kopyanın kaybolmasına karşı değişiklikler mobil depoda `docs/legal-site-update.patch` olarak da saklanır. Bu patch, yukarıdaki kaynak commit'e uygulanmak üzere hazırlanmıştır; yalnızca aynı dosyaların güncel revizyonuyla karşılaştırıldıktan sonra kullanılmalıdır. Henüz commit, push veya yayın yapılmadı. Önceki taslakta DEPAR ve doğrulanmış destek adresi kullanılmıştı; son teyitle Emir Topaloğlu yayıncı olarak eklendi. Adres, hukuki dayanak veya kesin saklama süresi uydurulmadı. Bunlar kod düzeltmeleri için engel sayılmaz; tam hukuki bildirim iddiası da yapılmaz.

## Kullanım koşulları: topluluk kuralları

DEPAR'da taciz, tehdit, nefret söylemi, ayrımcılık, cinsel istismar, pornografik içerik, dolandırıcılık ve başkasının kişisel bilgilerinin izinsiz paylaşılması yasaktır. Bu içeriklere ve davranışlara sıfır tolerans uygulanır. Kullanıcılar yalnızca paylaşmaya yetkili oldukları metin ve görselleri yüklemelidir.

Uygunsuz profil ve maçları uygulamadaki Şikayet Et seçeneğinden bildirebilir, kullanıcıları engelleyebilirsiniz. Şikayetler yetkili moderatör tarafından incelenir; ihlalin niteliğine göre içerik kaldırılabilir veya hesap kısıtlanabilir. Kararlara uygulamanın Destek ve İtiraz bölümündeki iletişim adresinden itiraz edebilirsiniz.

Moderasyon sorumlusu ve gelen kutusu takibi kullanıcı tarafından üstlenildi. Yayımdan önce uygulanabilir yanıt hedefi belirlenmelidir. İşletilemeyen bir yanıt süresi kullanıcıya vaat edilmemelidir.

## Gizlilik politikası: veri ve görünürlük

Hesap açma ve oturum yönetimi için Firebase Authentication kullanılır. Google veya Apple ile giriş seçildiğinde ilgili sağlayıcı kimlik doğrulamasına katılır. E-posta adresi, herkese açık profil alanlarından ayrı tutulur.

Profil adı, mevki, şehir, avatar ve oluşturduğunuz veya katıldığınız maçların saha, tarih ve katılımcı bilgileri uygulamanın ilgili ekranlarında diğer oturum açmış kullanıcılara görünür. Arkadaş, takipçi ve takip edilen kişi listeleri hesap sahibi ve arkadaşları ile sınırlandırılır. Profil görsellerinin daha önce paylaşılmış indirme bağlantılarına sahip kişiler görsele erişebilir; eski bağlantıların geri alınması ayrıca yönetilir.

Konum izni, yakındaki sahaları bulmak ve harita işlevlerini kullanmak için istenir. Saha ve yer aramalarında Google Maps/Places hizmetleri kullanılır. Kamera ve galeri yalnızca kullanıcının fotoğraf seçimi için kullanılır; telefon rehberine erişilmez.

Google Maps/Places özellikleri ayrıca [Google Maps/Google Earth Ek Hizmet Şartları](https://maps.google.com/help/terms_maps/) ve [Google Gizlilik Politikası](https://policies.google.com/privacy) kapsamında sunulur. Uygulama bu hizmetlerden gelen gerekli Google Maps ve fotoğraf sağlayıcı atıflarını ilgili içerikle birlikte gösterir; bu cümle yalnızca atıf düzeltmelerini içeren sürüm yayımlandığında kullanılmalıdır.

Kullanıcı profilleri, maçlar, sosyal ilişkiler ve şikayetler Firebase/Google Cloud hizmetlerinde işlenir. Görsel içerik denetimi etkinleştirildiğinde profil görselleri Google Cloud Vision ile değerlendirilir. Şikayet kayıtları moderasyon ve itirazların ele alınması için kullanılır.

Firebase App Check etkinleştirildiğinde uygulama/cihaz doğrulama sinyalleri kötüye kullanımı azaltmak için işlenir. Firebase Crashlytics etkinleştirildiğinde uygulama hataları ve teknik tanı bilgileri hata giderme amacıyla işlenir. Bu sürümde her ikisi de ayrı yayın yapılandırmasıyla etkinleştirilir; yayımlanan politika ve mağaza beyanları kullanılan gerçek yapılandırmayla eşleşmelidir.

## Hesap silme web sayfası

DEPAR hesabınızı uygulamada Ayarlar > Hesabı Sil seçeneğinden silme talebinde bulunabilirsiniz. İşlemden önce kimliğiniz yeniden doğrulanır. Talep kabul edildiğinde oturumunuz kapatılır ve ilişkili hesap verilerinin temizlenmesi sunucuda yürütülür.

Uygulamaya erişemiyorsanız `destekdepar@gmail.com` adresine hesap silme talebinizi iletin. Şifrenizi veya giriş kodlarınızı göndermeyin. Hesabın size ait olduğunu doğrulamak için güvenli bir doğrulama işlemi uygulanır.

Yayımlanacak web sayfası, destek adresini açıkça göstermeli; silinen veri türlerini, gerçekten tutulan istisna kayıtlarını ve bunların saklama sürelerini belirtmelidir. Yedekler, moderasyon kayıtları ve dış sağlayıcı verileri için henüz doğrulanmamış bir tam silme veya süre garantisi verilmemelidir.

## Yayın kaynakları

- [Apple kullanıcı içeriği şartları](https://developer.apple.com/app-store/review/guidelines/#user-generated-content): filtreleme, şikayet, engelleme ve yayımlanmış iletişim bilgisi gerekir. Rapordaki kesin “24 saat” iddiası bu maddede belirtilmez; zamanında yanıt verilmesi istenir.
- [Google Play hesap silme şartları](https://support.google.com/googleplay/android-developer/answer/13327111): uygulama içi yolun yanında uygulama dışında erişilebilen silme talebi web bağlantısı gerekir.
