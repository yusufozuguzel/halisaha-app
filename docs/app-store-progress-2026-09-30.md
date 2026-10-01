# DEPAR — 30 Eylül ilerlemesi

Henüz App Store gönderimine hazır değil. Üretim verisi/ayarları değiştirilmedi; dağıtım, commit, push veya PR yapılmadı.

### Gerçek Storage kuralları alındı

- Kullanıcının son paylaştığı `service firebase.storage` metni, giriş yapan herkese tüm dosyalarda okuma/yazma/silme yetkisi veriyor. Normalize edilmiş hali yalnızca güvensiz test fixture'ı olarak saklandı.
- Tam aday Storage politikası eklendi: yalnızca kendi `profile_images/{uid}.jpg` dosyasına yazma/silme, 5 MB sınırı, JPEG/PNG/WebP MIME kontrolü, oturumsuz SDK erişimi ve listelemeyi reddetme, silme/kısıtlama bariyerleri. Bilinmeyen yollar kapalı. Eski paylaşılan indirme token URL'lerinin gizli hale geldiği iddia edilmiyor.
- Flutter'ın iki fotoğraf yükleme yolu ortak boyut/biçim kontrolünü ve açık MIME metadata'sını kullanıyor. Profil dosyası yolu değiştirilmedi; mevcut silme/moderasyon işçileriyle aynı yolu kullanıyor.
- Yalnızca yerel emülatör yapılandırması güncellendi. Canlıya geçmeden gerçek bucket envanteri, eski istemciler, Firestore çapraz erişim izni ve tetikleyiciler staging'de doğrulanmalı. Ayrıntılar: [Storage kılavuzu](../functions/rules/STORAGE.md). Aşağıdaki “Storage kuralları bekleniyor” ifadeleri önceki aşamalara aittir.
- Doğrulama: tam Firestore/Storage adaylarıyla **6 Storage güvenlik testi** ve eski açığı yeniden üreten **1 ayrı baseline testi** geçti. Flutter fotoğraf biçim/boyut kontrolünün **3 testi** geçti; değişen üç Dart dosyasının analizinde sorun yok. Canlı veri veya kural değiştirilmedi.

### Destek adresi alındı

- Kullanıcı `depardestek@gmail.com` adresini açtığını bildirdi. Adres Ayarlar ve giriş/kayıt ekranından erişilen destek/itiraz iletişimine eklendi. E-posta uygulamasını açma ve adresi kopyalama seçenekleri var; uygulama açılamazsa adres görünür kalır. Kısıtlama açıklamasında da bu adres bulunur. E-posta gönderilmedi; teslimat veya gelen kutusu takibi doğrulanmadı.
- “Storage kuralları” adıyla yeniden gönderilen metin `service cloud.firestore` içeriyor; önceki Firestore metni. Gerçek `service firebase.storage` kuralları hâlâ bekleniyor. Bu metin Storage dosyasına uygulanmadı ve canlıya dağıtılmadı.
- Şikayet/itirazları kimin takip edeceği ve operasyonel yanıt süreci henüz teyit edilmedi. Aşağıdaki eski bölümlerde “destek adresi bekleniyor” ifadeleri tarihseldir.

### Son aşama: engel görünürlüğü ve gerçek moderasyon işlemleri

- Keşfet, arkadaşlar/arama, aktiviteler, bildirimler ve okunmamış sayacı ortak engel akışını kullanıyor. Engel kalkınca listeler yeniden hesaplanıyor; geciken sorgu sonucu veya geri alma gizlenen kişiyi geri getirmiyor. Dinleyiciler kapanırken temizleniyor. Aktivite akışı maç ve profil değişikliklerini canlı izliyor; silinen/temizlenen içeriği önbellekte tutmuyor. Bu, profil okumasını gizli yapan bir güvenlik kuralı değildir.
- Moderatör artık içerik önizlemesinden maç kaldırabilir, hesap yazmalarını kısıtlayabilir, profil/fotoğraf temizleyebilir ve kısıtlamayı kaldırabilir. İçeriğin sürümü değişmişse işlem reddedilir. Sahte “işlem uygulandı” kapatma kaldırıldı. Liste sayfalı; ilk 50 kayıttan sonrası erişilebilir.
- Profil/fotoğraf ve bildirim kopyaları sayfalı sunucu işiyle temizlenir. Hata halinde yeniden deneme ve kaldığı yerden devam vardır. Temizlik bitmeden kısıtlama kaldırılamaz. Kısıtlama giriş/okuma/şikayet/hesap silmeyi kapatmaz; ekranda açıklama gösterilir. Eski ID token ile yazma da kurallarda reddedilir. Storage kısmı hâlâ gerçek üretim kurallarına uygulanmayı bekleyen yardımcıdır.
- Hesap silme yeni moderasyon kayıtlarıyla uyumlu hale getirildi. Ayrıntılar ve canlı geçiş sınırları: [moderasyon kılavuzu](../functions/MODERATION.md).
- Doğrulama: **50 Flutter testi**, **33 birleşik kural testi**, **12 sosyal kural testi**, **21 moderasyon/backend/Storage testi**, **2 gerçek Functions uçtan uca testi** ve **2 sunucu politika testi** geçti. Analiz: **0 hata, 0 uyarı, 215 bilgi bildirimi**. iOS yapısal denetimi geçti. Android debug APK derlendi; ilk denemedeki Google artifact erişim hatası ayrı Gradle süreciyle yeniden çalıştırılarak giderildi. Bu bir release imzası veya gerçek iPhone testi değildir.
- Kapatılmış şikayetten sonra içerik değişirse yeni sürüm yeniden şikayet edilebilir; aynı sürüm tekrarları tek kayıt kalır ve hız sınırı korunur. Profil kurulumundan da hesap ayarlarına/silmeye ulaşılabilir.
- Sırada gerçek Storage kuralları ve destek/itiraz adresi, moderatör sorumlusu, staging/üretim yapılandırması, eski veri geçişi ve indeks doğrulaması, bağımlılık bulgularının değerlendirilmesi, Apple/Firebase ayarları ve gerçek iPhone/release testleri var. Önceki bölümler tarihsel aşamalardır; burada tamamlanan işleri yeniden bekleyen iş olarak yorumlamayın.

**Son güncelleme:** Kullanıcı Firestore kurallarını paylaştı. Aşağıdaki eski “kurallar bekleniyor” maddesi artık yalnızca Storage kuralları ve Firestore'un güvenli biçimde yeniden düzenlenmesi/doğrulanması için geçerlidir. Paylaşılan metin canlı projeden araçla doğrulanmadı ve değiştirilmedi.

`npm run test:provided-rules` ile ayrı demo emülatör projesinde dört açık yeniden üretildi: oturumsuz profil/e-posta okuma; başka kullanıcı adına sosyal kayıt/bildirim yazma; maç sahipliğini değiştirerek silme; silme kilidi varken yazmaya devam etme. Bu testlerin geçmesi **açıkların varlığını doğrular**, güvenli kural testi değildir. Dosya yalnızca test fixture'ıdır; deploy yapılandırmasına bağlanmadı. Baştaki genel deny geniş allow'ları iptal etmez ([Firebase](https://firebase.google.com/docs/firestore/security/rules-structure#overlapping_match_statements)).

Apple giriş/kayıt butonu ortak `AppleSignInButton` bileşenine alındı. Üç platform varyantı testi geçti: iOS'ta görünür ve callback çalışır; Android/Windows'ta mevcut tasarım gereği gizlidir. Gerçek Apple OAuth/capability yapılandırması veya cihaz girişi doğrulanmış değildir. Kullanıcı adıyla girişin eski anonim profil okuma bağımlılığı aşağıdaki yeni yerel aşamada kaldırıldı; canlı geçiş henüz yapılmadı.

## Eklenenler

### Hesap bazlı silme kilidi

- Yeni yerel uygulamada genel `_safetyLocks/accountDeletion` kilidi kullanılmıyor. `accountDeletionJobs/{uid}` yalnızca ilgili hesabın yazmalarını durduruyor. Diğer profiller, maçlar, arkadaşlık işlemleri ve şikayetler devam ediyor. Farklı hesaplar bağımsız silme talebi verebiliyor; aynı hesaba tekrarlanan talep aynı işi kullanıyor.
- Silinen hesaba yeni arkadaşlık/davet/engel listesi kaydı eklenmesi engelleniyor; silinen kurucunun maçları temizlenene kadar güncellemeye kapalı. Engel listesine bir işlemde en fazla bir aktif/mevcut kullanıcı eklenebilir; kaldırma serbest. Sunucudaki şikayet oluşturma ve inceleme de ilgili hesap/maç sahibinin silme durumunu kontrol ediyor.
- Ortak maç ve şikayet temizliği güncel belgeyi transaction içinde okuyor. Tarama başladıktan sonra gelen oyuncunun kaydı ezilmiyor; iki ayrı silme işi aynı maçı temizlese de kalan oyuncular korunuyor. Dosya silme hatasında sadece o hesabın işi bekliyor ve kaldığı yerden sürdürülebiliyor. Auth yine ana veri temizliğinden sonra siliniyor.
- Silinen kurucunun maç kimliği `_retiredMatches/{matchId}` ile tekrar kullanıma kapatılıyor. Böylece gecikmiş temizlik aynı kimlikle kurulmuş başka maçı etkileyemiyor. İş ve maç işaretlerinin saklama politikası ayrıca belirlenmeli; bunlar istemciye kapalı.
- Geç tamamlanan profil fotoğrafı yüklemeleri için Storage finalized tetikleyicisi eklendi. Bekleyen/tamamlanmış silme işi varsa yalnızca ilgili bucket, tam dosya yolu ve o nesil silinir; başka kullanıcı dosyasına dokunulmaz. Bu asenkron ek korumadır, servisler arasında atomik silme iddiası değildir.
- **33 birleşik Firestore kural testi, 8 sunucu testi + 1 gerçek Storage kural entegrasyon testi ve 2 backend politika testi geçti.** Sunucu testleri Storage hata enjeksiyonunda taklit adaptör kullanır; ayrı Storage testi gerçek yerel emülatörün Firestore kontrolünü kullanır. Flutter kodu bu aşamada değişmedi; önceki 48 test sonucu geçerlidir.
- Gerçek yerel Functions/Auth/Firestore/Storage emülatörleriyle **1 uçtan uca test** de geçti: callable talebi, hesabın/fotoğrafın/Auth kaydının temizlenmesi ve iş bittikten sonra gelen fotoğrafın Storage tetikleyicisiyle yeniden temizlenmesi.
- **Canlıya dağıtım yapılmadı; silme hazırlık bayrağı kapalı.** Gerçek Storage kuralları henüz gelmedi. Storage testindeki izinler sadece sahibinin dosyasına yazabildiği bir fixture; üretim politikası olduğu iddia edilmiyor. Gerçek bucket/region, Storage kuralları ve Admin yazıcıları birlikte doğrulanmadan özellik açılmamalı.

### Saha / maç doğrulaması ve birleşik Firestore adayı

- `functions/rules/firestore.candidate.rules` tüm bilinen Firestore yollarını tek dosyada birleştiriyor: profil, arkadaşlık, bildirim, maç, saha ve sunucu iç kayıtları. Bilinmeyen yollar kapalı. Parçalardan yeniden üretilebilir; testler eski üretilmiş dosyayla çalışmayı reddeder. `firebase.emulator.json` yalnızca yerel test yapılandırmasıdır; üretim `firebase.json` kurallara bağlanmadı.
- Maç başlığı/alan uzunlukları, ücret, koordinat çifti, tarih/süre, durum, kapasite ve diziliş sunucu kurallarında doğrulanıyor. Kurucu bile bilinmeyen alan, negatif/NaN ücret veya bozuk konum yazamıyor. Yeni maçta sunucu zamanı zorunlu; düzenleme maçı geçmişe taşıyamıyor. Eksik isteğe bağlı alanlar eski minimal `MatchService` biçimi için destekleniyor.
- Flutter aynı doğrulamaları kullanıcıya açıklayıcı mesaj vermek için kullanıyor. Hatalı ücret artık sıfıra çevrilmiyor; ondalık virgül destekleniyor. Takım büyüklüğü değişince diziliş uyarlanıyor, kadro korunuyor. Geçersiz diziliş davetler yazılmadan reddediliyor.
- Ortak saha kataloğu istemciler için salt okunur. Google/elle saha seçimi devam ediyor, seçilen bilgi yalnızca maçta saklanıyor. Ortak `venues` belgesini istemciden üzerine yazma kaldırıldı. Saha listesi yüklenemezse örnek kayıtlar gerçek saha gibi gösterilmiyor.
- İlk test 22 kişilik pozisyon değişiminde 1.000 değerlendirme sınırını yakaladı. Değişmeyen metadata tekrar doğrulanmıyor; izin verilen pozisyon listesi bir kez hesaplanıyor. Yetki/kapasite kontrolleri korunarak yoğun kadro, maç düzenleme, davet ve kabul sınır testleri geçti.
- **48 Flutter testi ve birleşik kuralların 28 emülatör testi geçti.** Son analiz: **0 hata, 0 uyarı, 216 bilgi bildirimi**. Canlı veri/ayar değişikliği veya dağıtım yapılmadı.
- Bildirim kabulündeki `isRead` alanının bozuk türde yazılması da kapatıldı; ayrı sosyal kuralların **12 testi** yeniden geçti. `git diff --check` temiz.
- Üretim öncesi hâlâ profil/eski veri geçişi, hesap bazlı silme kilidi, Storage kuralları, Admin yazıcılarının kontrolü ve gerçek cihaz/staging testleri gerekiyor. Birleşik dosya hazır olması uygulamanın yayına hazır olduğu anlamına gelmiyor. Ayrıntılar: [kurallar kılavuzu](../functions/rules/README.md).

### Kullanıcı adı girişi ve profil e-posta gizliliği

- Flutter oturum açmadan Firestore'dan e-posta aramıyor. Kullanıcı adı/parola sunucuda Firebase Auth ile doğrulanıyor; yalnızca doğru parola sahibine kendi e-postası dönüyor ve standart Firebase parola oturumu açılıyor. Özel token üreterek kimlik kontrolünü atlayan bir akış yok. Doğrudan e-posta girişi mevcut Firebase Auth yolunu kullanıyor. Parola artık kırpılmıyor.
- Kullanıcı adıyla şifre sıfırlama sunucuda e-posta gönderir; var/yok/çakışan/pasif hesaplar aynı genel yanıtı alır, e-posta/link dönmez. İsimler hâlâ eski `fullName`, ardından `name` eşleşmesidir; benzersiz kullanıcı adı sistemi iddiası yok. Çakışmada e-posta ile giriş gerekir.
- İsim ve IP başına transaction ile ortak deneme sınırı eklendi. Sayaçlarda ham isim/IP/parola yok; HMAC kimliği ve süre var. Üretim proxy/IP doğrulaması, TTL saklama ayarı ve kötüye kullanım izlemesi canlı geçiş gereksinimi.
- Yeni kayıt ve sosyal giriş profilleri e-posta yazmıyor. Profil kuralları oturumsuz okumayı, e-posta/telefon/yetki alanı eklemeyi ve doğrudan profil silmeyi reddeder. Eski profiller geçişe kadar yalnızca sahibi tarafından okunur. Arama yalnızca `profileVersion:2` kayıtlarını, sınırlı sorguyla okur; aday indeks eklendi.
- Geçiş aracı sayfalı ve varsayılan salt okunur. E-postayı Firebase Auth'ta bırakır; profil kopyasını kaldırıp sürümü aynı işlemde işaretler. Bilinmeyen alanları silmez, eski kayıt şekillerini inceleme için sayar; eşzamanlı düzenlemeyi ezmez. CLI yazması yalnızca yerel demo emülatörlerinde mümkün. **Gerçek veriler okunmadı veya değiştirilmedi.**
- `PRIVATE_LOGIN_READY` varsayılan kapalı; sunucuya gerçek yapılandırma eklenmedi. Yeni uygulamada kullanıcı adı girişi için bu servisin hazırlanıp yayımlanması gerekiyor; o zamana kadar e-postayla giriş kullanılabilir. Eski uygulamalar için kontrollü sürüm geçişi gerekli. Ayrıntılar: [giriş ve geçiş kılavuzu](../functions/PRIVATE_LOGIN.md).
- Doğrulama: **44 Flutter testi**, **8 Auth/Firestore sunucu testi**, **6 profil kural testi**, profil kurallarıyla yeniden çalıştırılan **14 maç + 12 sosyal test**, **2 backend politika testi** geçti. Son analiz: **0 hata, 0 uyarı, 216 bilgi bildirimi**. Canlıya dağıtım yapılmadı.
- Ayrıca **1 gerçek Functions uçtan uca testi** geçti: oturumsuz callable isteğinde doğru parolayı doğrulama, yanlış parolayı reddetme ve hesap varlığını yanıtta belirtmeden sıfırlama. Windows emülatörünün named-pipe bağlantısında IP bulunmadığı için sadece demo/localhost koşullarında ortak bir yerel IP kovası kullanılır; üretimde IP eksikse işlem reddedilir.
- Sonraki işler: saha ve maç metadata alan doğrulamasıyla tam kural birleşimi, hesap bazlı silme kilidi, moderasyonun gerçek kaldırma/askıya alma işlemleri, keşfet/aktivite engel görünürlüğü, Storage kuralları, gerçek iOS/Apple testleri ve destek adresi.

### Maç katılımı ve pozisyon aşaması

- `MatchParticipation` güncel belgeyi transaction içinde okuyarak katılma, ayrılma, pozisyon değişikliği, oyuncu çıkarma, davet yanıtı ve kurucu düzenlemesini yönetiyor. Keşif, Maçlarım, maç detayı, diziliş, bildirim ve eski maç servisi bu akışa bağlandı. İşlem kaydedilmeden katılım/ayrılma başarısı gösterilmiyor; eski üç saniyelik ayrılmayı geri alma davranışı kaldırıldı.
- Eski ekran görüntüsünden bütün pozisyon haritasını yazan kaydetme ve otomatik oyuncu yerleştirme kaldırıldı. Kadro anlık senkronize oluyor; yeni katılımcı boş pozisyonunu kendisi seçiyor. Kaydet yalnızca diziliş ve değiştirilen davetleri işler. Davetler ayrı transaction'larda olduğundan kısmi başarı mümkün; mesajda belirtilir, tekrar kaydetme tamamlanmış daveti çoğaltmaz.
- Yeni maç kuralları katılımcıyı kendi değişiklikleriyle sınırlar; kurucu bilgileri korunur, kontenjan/tekil pozisyon/ayrılmış pozisyon kontrol edilir. Kurucu başkasını çıkarabilir ama zorla kadroya ekleyemez. Kurucunun ayrılması yerine maç iptali gerekir. Geçmiş/kapalı maça katılım ve yer değiştirme reddedilir; engelden sonra ayrılma/davet reddi mümkün kalır.
- `slotChange` ve `inviteSlot` yalnızca pozisyon anahtarlarından oluşan işlem tarifleridir; yetkiyi sağlamazlar, kural gerçek oturum ve önceki kayıtla doğrular. 5x5–11x11 biçimleri desteklenir. Eski tutarsız kadro/davet kayıtları canlı geçiş öncesi ayrıca incelenmeli; otomatik üretim veri değişikliği yapılmadı.
- Bu aşamada **42 Flutter testi** geçti. Gerçek Firestore emülatöründe eşzamanlı son kontenjan ve aynı boş pozisyon yarışları da test edildi. Son Flutter analizi: **0 hata, 0 uyarı, 217 bilgi bildirimi**. Sosyal kuralların **12 testi** yeniden geçti. Profil gizliliği, saha politikası, Storage ve hesap bazlı silme kilidi hâlâ ayrı kalan işlerdir.
- Yerel kural parçaları canlıya yüklenmedi. Eski geniş match izinleriyle birlikte eklenmemeli; ilgili izinlerin yerini almalı. Ayrıntılar: [kurallar kılavuzu](../functions/rules/README.md).
- Yeni birleşik maç/davet kurallarının **14 emülatör testi geçti**; sahte işlem tarifleri, 22 oyunculu sınır, kapalı maçta kurucu hareketi, doluluk yarışı, pozisyon yarışı ve kendi başarı bildirimi dahil. `git diff --check` geçti. Gerçek cihaz/üretim kuralları testi yapılmadı.

### Daraltılmış planın ilk uygulama aşaması

- `functions/rules/social.fragment.rules` eklendi. Arkadaşlık isteğinde oturum göndereni, kabulde gerçek alıcı/bekleyen istek, çift yönlü arkadaşlık kaydı ve isteğin kaldırılması doğrulanıyor. Engelleme aynı transaction'ın SON durumuyla kontrol ediliyor. Başkasının sosyal kayıtlarını yazma/silme ve sahte profil kopyaları reddediliyor.
- Kullanıcı altındaki ve kökteki bildirimler ayrı kurallarla doğrulanıyor. Ana koleksiyondaki maç davetleri gerçek kurucu ve kaydedilen davet pozisyonuyla eşleşmeli; kabul eden alıcı olmalı. Bildirim kimliği/içeriği sonradan değiştirilemiyor; okundu/durum işlemleri sınırlı.
- `match-ownership.fragment.rules`: oluştururken gerçek sahip, güncellemede değiştirilemeyen `createdBy`/`creatorId`, silmede sahip kontrolü. **Bu henüz tam maç politikası değildir:** katılım, pozisyon ve kurucuya özel diğer alanların doğrulanması ayrı açık iştir.
- Eski `MatchService` oluşturma yolu gerçek oturum sahipliğini yazıyor; ayrılma yolundaki `temp_user_id` kaldırıldı. Ana maç oluşturma ekranı zaten iki sahiplik alanını yazıyordu.
- Giriş ve şifre sıfırlama ortak `LoginIdentifier` çözümleyicisine bağlandı: önce `fullName`, bulunmazsa eski `name`. Aynı isimde birden fazla kayıt varsa rastgele hesap seçilmez, e-posta ile işlem istenir. **Bu uyumluluk düzeltmesi e-posta gizliliğini çözmez**; mevcut anonim profil okuma bağımlılığı devam eder.
- Son doğrulama: **35 Flutter testi**, **12 yeni emülatör kural testi** geçti. Gerçek kuralların ilgili parçaları emülatöre yüklenir; normal akış ve kötüye kullanım birlikte test edilir.
- **Canlıya yayınlanmadı, root `firebase.json` üretim kurallarıyla bağlanmadı.** Eski geniş `allow` bloklarıyla yan yana eklemek güvenli değildir; bunların yerini almalıdır. Tam birleştirme, profil gizliliği/kullanıcı adı geçişi, maç katılım/pozisyon politikası, saha yazmaları ve Storage doğrulaması tamamlanmadan kullanılmamalı. Ayrıntı: [kural entegrasyon notları](../functions/rules/README.md).

- `functions/` altında callable servisler ve yeniden çalıştırılabilir hesap silme worker'ı. UID doğrulanmış oturumdan alınır; yakın zamanda giriş zorunludur. Sayfalama/cursor ve worker lease kullanılır; Storage hataları gizlenmez, Auth en son silinir.
- Flutter `SafetyApi` ile sunucu bağlantısı. Silme sırası: yeniden doğrulama, backend hazırlık kontrolü, gerekiyorsa Apple token iptali, silme talebi. Kabulden sonra oturum kapanır; kullanıcıya silmenin tamamlandığı değil, talebin alındığı söylenir. Formun bu sırada dispose edilmesi düzeltildi.
- Şikayetler doğrudan istemciden Firestore'a yazılmıyor. Sunucu hedefi/nedeni doğrular, kimlik/zaman/durumu belirler. SHA-256 ile tekrar kayıt önlenir; yeni raporlar dakikada birle sınırlıdır. Eski `REPORTING_RULES_VERIFIED` Dart bayrağı kaldırıldı.
- `moderator` custom claim sahibi için Ayarlar'da inceleme ekranı; yetki ve recent-auth sunucuda da kontrol edilir. Sonuçlandırma düğmesi **içerik kaldırmaz veya hesap askıya almaz**; ayrı işlemin uygulandığını teyit eder.
- Gizlilik manifestine şikayet/müşteri desteği kategorisi eklendi. Önceki iOS izin, Apple giriş, Firebase başlangıcı, Maps fallback ve paylaşım düzeltmeleri korundu.

## Etkinleştirme sınırı

Sunucuda `DELETION_RULES_VERIFIED` ve `MODERATION_READY` varsayılan false; servis dağıtılmadı. Gerçek kurallar görülmeden açılmamalı. `firebase.json` yalnızca yerel Functions codebase kaydını içeriyor. Test kuralları üretimin yerine geçirilemez.

Güncel yerel silme yaklaşımı **hesap bazlıdır**; önceki aşamalardaki genel kilit açıklamaları tarihsel durumdur. Silinen hesabın ve yeni ilişki hedeflerinin kontrolü bütün Firestore/Storage yazıcılarında korunmalı; diğer Admin yazıcıları da uymalıdır. Hata yalnızca ilgili hesabın işini bekletir. Ayrıntılı kapsam ve kurtarma: [backend kılavuzu](../functions/README.md).

Tamamlanan işler UID/durum/zaman saklar; saklama politikası ayrıca belirlenmeli. Bilinmeyen üretim alanları, başka Storage yolları, yedekler ve dış sağlayıcı verileri için tam silme iddiası yapılmıyor.

## Testler

- Flutter: **21 geçti**; son analiz **0 hata, 0 uyarı, önceki 224 bilgi bildirimi**. Yeni analiz bulgusu yok.
- Backend politika: **2 geçti**. Firestore kuralları: **5 geçti**. Firestore/Auth servis testleri: **4 geçti**, 510 bildirim üzerinde sayfalama ve Storage hata/kurtarma senaryosu dahil. Bu servis testlerinde Storage adaptörü taklittir.
- iOS plist/entitlement/kaynak üyeliği yapısal kontrolü geçti; gerçek `.app` doğrulaması değildir.
- Node 24 yerel ortam; üretim hedefi Node 22. Firebase CLI 13 / Functions SDK 7 uyumsuzluğu nedeniyle yalnızca test aracı CLI 14.27.0'a yükseltildi.
- Functions/Auth/Firestore/Storage emülatörleriyle **1 gerçek uçtan uca test geçti**: callable kimlik kontrolü, sahte UID reddi, talep kabulü, gerçek Firestore tetikleyicisiyle profil/fotoğraf/Auth temizliği. Üretim veya iPhone testi değildir.
- npm denetimi sunucuda 2 orta düzey geçişli bulgu (`gaxios` / `uuid`), test araçlarında 19 bulgu (16 orta, 2 yüksek, 1 kritik) bildirdi. Sunucuda `npm audit fix --ignore-scripts` denendi; uyumlu aralıkta çözüm üretmedi, 2 bulgu kaldı. Zorlayıcı toplu güncelleme yapılmadı. Test araçları uygulamaya paketlenmez; bağımlılık güncellemesi ayrıca gereklidir.

## Kalanlar

### İkinci yerel düzeltme turu

- Arkadaşlık isteği gönderme/kabul etme, bildirimden geri takip/kabul ve Arkadaşlar ekranındaki maç daveti `SocialInteractions` üzerinden transaction kullanıyor. Her iki profil aynı transaction'da okunuyor; iki taraftan birinin engeli varsa işlem duruyor. Eski/iptal edilmiş veya başka kişiye ait bildirimle gelen istek kabul edilmiyor.
- İstek ve bildirimi birlikte kaydetme, tekrar istekte ek bildirim üretmeme, karşılıklı istekleri kabul sonrası temizleme eklendi. Maç davetinde güncel sahip/tarih kontrolü var; aynı maç/gönderen/alıcı için tek bildirim yazılıyor. Önceki çift bildirim kaldırıldı, gönderim sırasında tekrar tıklama önlendi.
- İki engelleme giriş noktası aynı temizliği yapıyor: iki yönlü arkadaşlık ve bekleyen istek kayıtları, tek taraflı kalıntılar dahil kaldırılıyor. Engellenenler listesi canlı dinleniyor; logout sırasında controller/dinleyici temizleniyor.
- **28 Flutter testi geçti** (önceki 21 + 7 yeni). Yeni testler bellekte transaction sözleşmesini taklit eder; gerçek Firestore eşzamanlılık/rules testi değildir. Başarısız committe kısmi kayıt oluşmaması, iki yönlü engel, geçersiz/eski istek, bildirim eşleşmesi ve davet tekrarı kapsanır.
- Son statik analiz: **0 hata, 0 uyarı, 221 bilgi bildirimi**; yeni dosyalarda bulgu yok. `git diff --check` geçti. Backend değişmediğinden önceki emülatör testleri yeniden çalıştırılmadı.
- Bu çalışma **istemci davranışıdır; sunucu yetkilendirmesi tamamlandı anlamına gelmez**. Gerçek kurallarda her işlem için aynı yetki/engel/şema kontrolleri gerekir. Keşif/aktivite görünürlüğü ve maç kadrosu/pozisyon daveti-kabul yolları ayrıca ele alınmalı. İçerik filtrelemesi ve küresel silme kilidi değişmedi; canlı bayraklar açılmadı.

### Açık işler

1. Gerçek Firestore/Storage kurallarını, tam şemayı ve diğer Admin yazıcılarını doğrulama; gerçek destek adresi. Kullanıcının isteğiyle en sona bırakıldı.
2. İçerik filtreleme, bütün sosyal/maç yollarında sunucu destekli engelleme, gerçek moderasyon sorumlusu/yanıt süresi ve kaldırma/askıya alma işlemleri.
3. Apple/Firebase hesap ayarları, provisioning, iOS Maps anahtarı; Mac üzerinde archive/Privacy Report ve gerçek iPhone giriş/izin/silme testleri; Android cihaz regresyonu.
4. Node 22 staging, izleme/retry/kilit kurtarma, saklama politikası ve bağımlılık denetimi bulgularının giderilmesi.
