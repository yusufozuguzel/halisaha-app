# DEPAR — Google Cloud güvenlik ve sıfır maliyet denetimi

15 Ekim 2026, Türkiye saati. Proje: `halisaha-app-d9ea1` / `2273283642`. Denetim, kullanıcının ücretsiz ve işlevi etkilemeyen önlemleri uygulama yetkisiyle yürütüldü. Ücretli kaynak, yeni proje, abonelik, build, Function veya veri yedeği oluşturulmadı. Faturalandırma, proje, veriler ve çalışan API'ler kapatılmadı. TestFlight paketi değiştirilmedi veya cihazda çalıştırılmadı.

## 1. Şu anda ücret yansıyor mu?

**Faturalandırma bağlantısı açık; mevcut/geçmiş borç tutarı doğrulanamadı.** `projects/halisaha-app-d9ea1/billingInfo` canlı yanıtı `billingEnabled: true` ve bağlı hesabı `018DB4-68DDEC-7F3FA0` olarak döndürdü. Bu bilgi ücretlenebilir kullanımın mümkün olduğunu kanıtlar; pozitif bir faturanın varlığını ya da tutarını kanıtlamaz. Krediler, deneme bakiyesi, ödeme sahibi ve tahsilatlar görülemedi.

`recepdr1906@gmail.com` ile bir erişilebilir proje listelendi. Bu oturum proje Owner yetkisine sahip. Faturalandırma hesaplarını listeleme boş döndü; bağlı hesabı doğrudan okumak HTTP 403 verdi. Dolayısıyla “hesap yok” veya “harcama 0 TL” sonucu çıkarılamaz. Projede erişilebilir BigQuery dataset listesi de boş; harcama analizi için ücret oluşturabilecek export/dataset/query kurulmadı.

Eksik erişim: bağlı faturalandırma hesabında `recepdr1906@gmail.com` için **Billing Account Viewer (`roles/billing.viewer`)**. Kullanıcı yöneticiden bu okuma yetkisini isteyeceğini bildirdi; verildiği henüz doğrulanmadı. Fatura hesabı audit logları için ayrıca uygun log okuma yetkisi gerekebilir. Sonraki okuma için CLI'a yeniden giriş de gerekir; aşağıdaki güvenlik notuna bakın.

## 2. Hangi servisler ücret oluşturabilir?

Başlangıç canlı envanterinde 61 etkin API vardı; ücretsiz Cloud Billing Budget API eklenince sayı 62 oldu. API'nin etkin olması tek başına o serviste ücretli kaynak çalıştığını göstermez. Tam liste, bu raporla birlikte `depar-cloud-api-inventory-2026-10-15.json` dosyasında bulunur.

- **Maps:** standart native Maps SDK SKU'sunda sınırsız ücretsiz kullanım bulunur; buna rağmen faturalandırma bağlantısı gerekir. Dynamic Maps/Street View gibi ayrı SKU'lar ve REST servisleri aynı kabul edilmemelidir. Kodda native GoogleMap var; cloud map ID veya Street View kullanımı bulunmadı. TestFlight binary'si ayrıca doğrulanmadı. [iOS Maps kullanım/faturalandırma](https://developers.google.com/maps/documentation/ios-sdk/usage-and-billing).
- **Places ve Static Maps:** güncel aylık ücretsiz miktarlar Static Maps 10.000; Legacy Text Search 5.000; Legacy Place Details 5.000; Legacy Photo 1.000 istek. Bunlar otomatik durdurma limitleri değildir. Ek alan/SKU kullanımı ve aynı fatura hesabının diğer projeleri değerlendirilmelidir. [Güncel Maps fiyatları](https://developers.google.com/maps/billing-and-pricing/pricing).
- **Firestore:** `(default)` veritabanı canlıda STANDARD, eur3 ve `freeTier: true`. Ücretsiz miktarlar 1 GiB depolama, günde 50.000 okuma/20.000 yazma/20.000 normal silme ve ayda 10 GiB çıkış. Bunların aşımı ücretlenebilir. **TTL silme, PITR, yedekleme ve restore ücretsiz kullanıma dahil değildir.** [Firestore fiyatları](https://firebase.google.com/docs/firestore/pricing#free-quota).
- **Cloud Functions / Cloud Run:** europe-west1'de 15 etkin Gen 2 Function var. Min instance alanı yok (varsayılan sıfır); bu, sıfır toplam maliyet garantisi değildir. İstek, işlem, ağ ve destek altyapısı ücretlenebilir. İstek bazlı Cloud Run ücretsiz aylık miktarları 2 milyon istek, 180.000 vCPU-s ve 360.000 GiB-s'dir; hesap genelinde paylaşılır. Avrupa internet çıkışı için Kuzey Amerika ücretsiz çıkışını varsaymadım. [Cloud Run fiyatları](https://cloud.google.com/run/pricing).
- **Vision SafeSearch:** ayda ilk 1.000 birim ücretsiz; bağımsız SafeSearch sonraki kademede ücretlidir. Mevcut görsel moderasyonu bunu kullanıyor. [Vision fiyatları](https://cloud.google.com/vision/pricing).
- **Storage:** yapılandırılmış bucket `halisaha-app-d9ea1.firebasestorage.app`; eski `appspot.com` ücretsiz koşulları uygulanmış kabul edilemez. Yeni bucket'larda GCS fiyatlandırması ve konum şartları vardır. Bucket konumu/byte kullanımı bu denetimde ücretli Storage okuma/listeme işlemi oluşturulmaması için yeniden okunmadı. [Firebase Storage koşulları](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024), [GCS fiyatları](https://cloud.google.com/storage/pricing).
- **Diğer potansiyel kalemler:** Cloud Build, Artifact Registry, Secret Manager, Eventarc/PubSub, veri transferi, ücretli gözlemleme ve varsa SMS/Identity Platform kullanımı ayrıca ücret doğurabilir. Bunları “etkin API = kesin harcama” diye raporlamıyorum. Temel Auth e-posta girişi ve e-posta enumeration koruması açık görüldü; sağlayıcılar değiştirilmedi.

### Canlı kota gözlemleri

Legacy Places günlük billable kota efektif olarak sınırsız, dakika kotası 6.000. Static Maps ana günlük kota efektif olarak sınırsız, dakika kotası 30.000; ayrı unsigned bucket kotası 25.000/gün ve imzalama koşuluna bağlıdır. Vision SafeSearch 1.800/dakika. Bu değerler ücretsiz aylık miktarları koruyan bir maliyet sınırı değildir. Kotalar değiştirilmedi: düşürmek arama/görsel/moderasyon isteklerini reddettirebilir.

## 3. Bütçeleri kim oluşturmuş?

Denetim başında projeye ait bir bütçe görüldü:

- Adı: `Firebase Project halisaha-app-d9ea1`.
- Aylık tutar: **50 TRY**.
- Uyarılar: %50, %90, %100 gerçekleşen harcama.
- Krediler dahil; kaynak adı sonu `32a7283a-4d14-4e31-9646-3c5f33430e84`.
- **Oluşturan kişi ve oluşturulma tarihi tespit edilemedi.** Budget yanıtında bu alanlar yok. Fatura hesabının denetim logları 403 ile reddedildi. Proje loglarının ilk araması yazar bilgisi sağlamadı ve pagination tamamlanmadı; kayıt bulunmadığı iddia edilmez. `etag` bir tarih olarak yorumlanmadı. Bütçe adı, onu Firebase'in veya belirli bir kişinin oluşturduğunun kanıtı sayılmadı.

Bu çalışmada eklenen bütçe:

- Adı: `DEPAR sifir maliyet uyarisi (0 TL)`; aylık **0 TRY**, yalnızca e-posta uyarısı.
- Kaynak adı sonu `66c08077-ca03-4014-926d-84e0af6fd5a5`.
- Oturum/işlemi yapan: `recepdr1906@gmail.com`; bu denetimde oluşturuldu, 15 Ekim 2026 11:31 Türkiye saatinde yeniden okunarak doğrulandı.
- Gerçekleşen kullanım uyarısı; krediler hariçtir, böylece krediyle karşılanan ücretlenebilir tüketim de uyarıda gizlenmez. Faturanın net tutarıyla aynı ölçüm değildir.
- Varsayılan fatura yöneticileri ve proje düzeyi alıcıları etkin. Destek e-postası için ek ücretli bildirim altyapısı kurulmadı. Pub/Sub topic, Cloud Function veya Monitoring alert policy oluşturulmadı.
- **Harcama sınırı, servis durdurma veya 0 TL garantisi değildir.** Önceki 50 TL bütçe korunmuştur. Bildirim gecikmesi olabilir.

Cloud Billing API'leri ve normal bütçe uyarıları ücretsizdir; Pub/Sub ve BigQuery gibi ek araçlar ayrıca ücretlenebilir. Bu nedenle yalnızca ücretsiz yönetim API'si ve e-posta bütçesi kullanıldı. [Cloud Billing fiyatları](https://cloud.google.com/billing/v1/pricing).

## 4. Uygulanan güvenlik ve maliyet önlemleri

1. Ücretsiz **Cloud Billing Budget API** açıldı; 0 TL hedefli yukarıdaki uyarı kuruldu ve yeniden okundu.
2. Tamamen kısıtsız `New API key 4`, değeri gösterilmeden bulut/yerel karşılaştırmayla `.env` ve Android Maps anahtarı olarak eşleştirildi. Firebase Auth anahtarlarından farklı olduğu doğrulandı. Aynı anahtar değeri korunarak yalnızca şu etkin Maps API'lerine izin verildi: Maps SDK Android, Maps SDK iOS, Places Legacy, Places New ve Maps Static. Etiket/değer/kota/uygulama kısıtı değiştirilmedi; önceki metadata geri dönüş incelemesi için yerelde saklandı. Sonuç ve anahtar değerinin aynı kaldığı yeniden okumayla doğrulandı. Bu işlem diğer API'lerde kullanımı sınırlar; izin verilen Maps API'lerinde kota üstü harcama riskini kaldırmaz.
3. Ayrı `DEPAR iOS Maps` anahtarı zaten yalnızca `com.depar.app` ve `maps-ios-backend.googleapis.com` ile sınırlıydı; bu kısıt korundu. Üç Firebase istemci anahtarının mevcut API kısıtlarına dokunulmadı. [Firebase istemci anahtarları hakkında](https://firebase.google.com/docs/projects/api-keys).
4. Önceki çıktıya düşen Firebase CLI yönetici oturumunun OAuth izni iptal edildi. Tekrar token yenileme isteği `invalid_grant` verdi; yerel CLI kimlik bilgileri kaldırıldı. Bu işlem Firebase uygulama kullanıcılarını, onların oturumlarını veya backend servis hesaplarını değiştirmez.
5. Denetim dosyaları `.release/cloud-audit/` altında Git dışında tutuldu. Ham anahtarlar rapor/envanter dosyalarına yazılmadı. Auth yanıtının hassas kısmı yerel denetim dosyasından çıkarıldı; aşağıdaki olay notu geçerlidir.

### Kod ve kimlik denetimi sonuçları

- Çalışma dosyalarında 12 Google API anahtarı geçişi / 5 farklı değer bulundu. Dokuz geçiş public Firebase yapılandırmalarında, üçü ignore edilen Maps/env dosyalarında. `.env` güncel Flutter paketinde asset değil; doğrudan web-servis anahtarı kullanımı kaldırılmış. Bu, eski TestFlight paketinin de aynı sürüm olduğunu kanıtlamaz.
- Erişilebilir Git geçmişinde 161 commit ve 575 metin blob sürümü tarandı; üç Firebase public anahtarının 28 geçişi bulundu. İncelenen özel anahtar/AWS/GitHub/Slack/Stripe secret ve gizli atama kalıpları eşleşmedi. 95 binary/metin dışı sürüm, unreachable/reflog-only geçmiş ve üretilmiş dosyalar kapsam dışıdır; her olası secret biçiminin bulunmadığı garanti edilmez. Yerel snapshot fixture eşleşmeleri gerçek kimlik bilgisi olarak raporlanmadı.
- Android applicationId/namespace `com.depar.app`. Üç yerel OAuth SHA-1 kaydı dağıtılan sürümün imzası kabul edilmedi. Yerel debug sertifikası SHA-1: `88:F6:7F:1C:94:58:A5:95:B1:A7:9B:03:4A:98:7C:E4:4C:FA:A2:EC`. Bu, yerel üç kayıtla eşleşmiyor; buluttaki tüm kayıtları veya release sertifikasını kanıtlamaz. Repo içinde release keystore/key.properties bulunmadı. Anahtara yanlış sertifika kısıtı uygulanmadı.
- Üç mevcut servis hesabının USER_MANAGED key listesi boş. Projede üç insan Owner ve bir insan Editor var; erişimler kaldırılmadı. Gerekli olmayan geniş yetkiler ayrıca gözden geçirilmeli.
- Canlı Firestore/Storage kural kaynakları alındı: koşulsuz `allow ... if true` eşleşmesi yok, auth ve hesap silme bariyerleri var. Bu temel kontrol tam bir bypass denetimi veya maliyet garantisi değildir. Kurallar değiştirilmedi.

### Hassas çıktı olayı ve kalan işlem

Auth config sorgusunda `signIn` altındaki output-only parola hash yapılandırması istemeden komut çıktısına girdi. Bu bir denetim hatasıdır. Kullanıcı parolaları veya kullanıcı parola hash kayıtları dışa aktarılmadı; yapılandırma yeniden gösterilmiyor ve yerel kayıttan çıkarıldı. Sonraki sorgu/kayıt kodu sadece izin verilen boolean alanları seçer. Yönetici CLI token'ının iptali, **bu hash yapılandırma anahtarını yenilemez**. Önceki ham komut çıktıları kamuya paylaşılmamalıdır; bu anahtarın yenilenmesi için desteklenen prosedür Firebase desteğiyle değerlendirilmelidir. Authentication'ı bozabilecek bir hash ayarı/parola toplu değişikliği yapılmadı. [Hash parametreleri resmi referansı](https://firebase.google.com/docs/cli/auth).

## 5. Devam eden riskler ve onaysız yapılmayanlar

- Eski paylaşılan Maps anahtarında artık API allowlist var; aynı anahtar hem Android hem REST kullanımına ait olduğu için yalnızca iOS bundle veya tek Android sertifikasına kısıtlamak mevcut çağrıları bozabilir. Anahtar bölme/rotasyon ve uyumlu TestFlight sürümü ayrı onay/cihaz kontrolü gerektirir.
- Aylık ücretsiz limit aşıldığında ücretlenebilir kullanım halen mümkündür. Kotalar ve instance üst sınırı bir para limiti değildir; başka projeler aynı fatura hesabındaki ücretsiz hakları tüketebilir.
- `_loginLimits.expiresAt` TTL politikası canlıda **ACTIVE**. TTL silmeleri ücretsiz değildir. Kapatmak süresi geçen sayaçların otomatik temizliğini durdurur ve depolamayı artırabilir; bu tradeoff nedeniyle onaysız değiştirilmedi. Yeni photo TTL/PITR/managed backup/restore etkinleştirilmedi; ücretli kurtarma provası yapılmadı.
- Yeni proxy, pre-upload moderasyon ve benzeri yerel Functions değişiklikleri deploy edilmedi; deploy/build/çalıştırma ek maliyet yaratabilir. Mevcut 15 Function kapatılmadı.
- App Check yönetim API'si kapalı yanıtı verdi; mevcut callable enforcement kapalı. Doğru sağlayıcı ve gerçek cihaz doğrulaması olmadan enforcement açılmadı.
- Firestore, fotoğraf bytes, kullanıcılar ve ilişkiler silinmedi; faturalandırma hesabı ayrılmadı; API veya servis kapatılmadı. Görüntüleme sorgularının ücret yaratabileceği Storage nesne listesi, Monitoring timeseries sorgusu, Vision deneme isteği ve Maps ücretli test çağrısı çalıştırılmadı.
- TestFlight uygulamasını cihazda kullanarak harita/giriş doğrulaması yapılmadı. Harita API izinlerinin ve Firebase anahtarlarının korunduğu yapılandırmadan doğrulandı; cihaz testinin yerine geçmez.

## 6. Aylık sıfır maliyet hedefi için gereken karar

**Bu mevcut mimaride, faturalandırma açık ve ücretlenebilir özellikler çalışırken her koşulda 0 TL fatura garantisi verilemez.** Harcama tutarı henüz bilinmiyor; geçmiş/tahakkuk etmiş maliyetler yeni ayarlarla silinmez.

Güncel Google Cloud/Firebase belgelerinde seçili servisler için 0 tutarına izin veren spend-cap bütçeleri vardır. Ancak Maps/Firestore/Storage/Vision kapsam dışıdır; uygulama gecikebilir ve aşım/fixed maliyetler ücretlenebilir. Cloud Run/Functions için uygulamak yeni istekleri durdurup giriş/şikayet/silme gibi callable özelliklerini bozabilir. Dolayısıyla bu limitler otomatik uygulanmadı. [Spend-cap kapsam ve sınırlamaları](https://docs.cloud.google.com/billing/docs/how-to/budgets-spend-caps), [0 tutar API tanımı](https://docs.cloud.google.com/billing/docs/reference/budget/rest/v1/billingAccounts.budgets#BudgetAmount).

İzlenecek sıra:

1. Yönetici Billing Account Viewer okuma yetkisini versin; CLI yeniden girişinden sonra gerçek maliyet/geçmiş/krediler ve bütçe logları doğrulansın. Önce bu bilgi olmadan “0 TL” sonucu verilmez.
2. Maps REST kotaları ve anahtar ayrıştırması için TestFlight uyumluluğu doğrulansın. Gerekirse limit aşıldığında arama/fotoğrafın geçici kapanacağı açıkça kabul edilerek daha düşük kotalar seçilsin. Native harita ve REST ücretleri ayrı ele alınsın.
3. TTL, Avrupa depolama/çıkış, Vision ve Functions gibi ücretlenebilir yollar için sıfır maliyetli mimari/özellik kapsamı belirlensin. Sadece bütçe uyarısı veya düşük trafik bunu garanti etmez.
4. Mutlak ücret riski kabul edilmiyorsa ücretlenebilir tüketimi kaldıran plan/altyapı değişikliği gerekir. Faturalandırmayı kapatmak bu projedeki Maps/Functions/Storage özelliklerini bozabilir; kullanıcı verileri ve mağaza gereklilikleri düşünülerek ayrı onayla planlanmalıdır.

Bu rapor tamamlanan ücretsiz önlemleri ve erişim/uyumluluk nedeniyle tamamlanamayan kontrolleri ayırır. Yetki verilmesi veya CLI'a yeniden giriş yapılması henüz gerçekleşmiş kabul edilmez.

### Yerel rapor doğrulaması

API envanteri 61 başlangıç servisi ve eklenen Budget API ile 62 benzersiz servis içerir. Rapor, paylaşılabilir JSON ve görsel panel için Google API anahtarı/private key/OAuth token kalıpları kontrol edildi; eşleşme yok. Düzeltilmiş yerel Auth kaydında hassas hash/token alan adları bulunmuyor. `git diff --check` temiz. Görsel panelin bağımsız TypeScript kontrolü IDE'ye özel `cursor/canvas` ve JSX tiplerini çözemedi; panelin IDE içinde derlenip görsel olarak doğrulandığı iddia edilmez. Bu çalışma uygulama kodunu veya TestFlight paketini değiştirmediği için mobil testler tekrar çalıştırılmadı.
