# DEPAR — Firebase, Maps ve bütçe incelemesi

15 Ekim 2026. Proje: `halisaha-app-d9ea1` (`2273283642`). Bu yeni incelemede hiçbir bulut ayarı, API, anahtar, bütçe, ödeme, kullanıcı verisi veya uygulama kodu değiştirilmedi. Yalnızca yerel rapor dosyaları hazırlandı.

## Kanıt ve erişim sınırı

Bu tur depo kodu, önceki denetimin seçilmiş JSON kayıtları ve güncel resmi fiyatlandırma belgeleri incelendi. Mevcut Firebase CLI oturumunda kullanıcı/token bulunmuyor; bağlı tarayıcı da yok. Dolayısıyla aşağıdaki canlı yapılandırma bilgileri **önceki 15 Ekim denetiminin kayıtlarıdır; bu tur yeniden okunmuş güncel durum değildir.** Önceki proje envanteri 11:24 Türkiye saatiyle alınmış, son önlem 11:39'da doğrulanmıştır. Fatura hesabını ve hesap loglarını okuma girişimleri o denetimde HTTP 403 vermiştir. Billing Account Viewer yetkisinin verildiği henüz doğrulanmamıştır.

## 1. Hangi Firebase servisleri kullanılıyor?

- **Authentication:** e-posta/parola, kullanıcı adıyla giriş akışı, Google ve Apple giriş kodu bulunuyor. Yerel kullanıcı adı akışı backend callable üzerinden de çalışabiliyor. SMS/telefon giriş kodu bulunmadı. Önceki canlı kontrolde e-posta girişi ve e-posta enumeration koruması açıktı. Google/Apple sağlayıcısının canlı durumu ve Identity Platform yükseltmesi bu tur doğrulanamadı.
- **Cloud Firestore:** profiller, maçlar, sosyal ilişkiler, uygulama içi bildirimler, rapor/moderasyon ve sunucu limit kayıtları için kullanılıyor. Önceki kayıtta `(default)` STANDARD, `eur3`, `freeTier: true`. Bu son alan tüm veritabanının ücretsiz planla sınırlı olduğunu göstermez.
- **Cloud Storage for Firebase:** profil fotoğrafları ve yükleme/silme/moderasyon akışları. Yapılandırılmış bucket `halisaha-app-d9ea1.firebasestorage.app`. Bucket konumu ve toplam tüketim bu tur okunamadı.
- **Cloud Functions / Cloud Run:** hesap silme, içerik şikayeti/moderasyon, kullanıcı adıyla giriş ve görsel denetimi. Önceki envanterde `europe-west1` içinde 15 etkin Gen 2 Function vardı. Yereldeki yeni Places proxy, kullanıcı adı rezervasyonu ve fotoğraf ön denetimi kodunun tamamı canlıya çıkmış kabul edilemez.
- **App Check:** SDK ve başlatma kodu var; `APP_CHECK_ENABLED` derleme bayrağına bağlı. Önceki canlı Function kayıtlarında enforcement kapalıydı. SDK'nın bulunması korumanın canlıda çalıştığını kanıtlamaz.
- **Crashlytics:** SDK/kod var; release modunda ayrıca `CRASHLYTICS_ENABLED` bayrağı gerekiyor. TestFlight paketinin bu bayrakla derlendiği doğrulanmadı.

Google Cloud tarafında ayrıca Vision SafeSearch, Secret Manager ve Gen 2 Functions'ın Build/Registry/Eventarc gibi destek servisleri önemlidir. Etkin API envanterindeki her servis uygulamada aktif kullanılıyor demek değildir. Realtime Database, FCM push, Analytics ve Remote Config için etkin API bulunması kullanım kanıtı sayılmadı; uygulama içi bildirimler tek başına FCM değildir.

Kod kanıtları: `pubspec.yaml`, `lib/main.dart`, `lib/modules/auth/controllers/auth_controller.dart`, `lib/core/services/`, `functions/src/index.cjs`, `functions/src/places-proxy.cjs`, `firebase.json`. Canlı kanıtlar önceki denetimde Git dışında saklanan seçilmiş envanterlerdir; ham kimlik bilgileri rapora alınmadı.

## 2. Hangi Google Maps API'leri kullanılıyor?

- **Maps SDK for iOS / Android:** Flutter native harita gösterimi (`google_maps_flutter`). iOS bundle `com.depar.app`; Android paket de `com.depar.app`.
- **Places API Legacy:** saha araması (`place/textsearch`), saha ayrıntıları (`place/details`) ve fotoğraf (`place/photo`) için yerel backend kodu var.
- **Maps Static API:** saha kartlarında statik harita görseli (`staticmap`) için kod var.
- **Places API New:** önceki bulut kaydında etkin ve anahtar izin listesinde bulunuyor. Ancak mevcut kodda `places.googleapis.com` çağrısı doğrulanmadı; etkin olması kullanıldığı veya ücret oluştuğu anlamına gelmez.

Directions, Routes, Geocoding ve Street View çağrısı bu incelemede saptanmadı. TestFlight binary'si okunmadığı için depodaki sürümle aynı API çağrılarını yaptığı kesinleştirilemez. Yeni proxy'nin yerelde bulunması, canlıda hazır olduğunun kanıtı değildir.

## 3. Spark mı, Blaze mı?

**Son doğrulanan billing bağlantısı Blaze ile uyumludur; Spark olarak kabul edilemez.** Önceki canlı yanıtta `billingEnabled: true` ve bağlı billing hesabı vardı. Firebase'in resmi açıklamasına göre projeye Cloud Billing hesabı bağlanması otomatik olarak Blaze planına yükseltir. Bu, aylık sabit abonelik veya her ay zorunlu 10/20 dolar ödeme demek değildir; ücretli tüketim mümkün olur. Bu tur Firebase konsolundaki güncel plan etiketi doğrudan okunmadı. [Firebase planları](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans).

## 4. Billing hesabı aktif mi ve bağlı mı?

Önceki canlı kayıtta proje, `018DB4-68DDEC-7F3FA0` hesabına bağlı ve proje faturalandırması açıktı. Hesabın `open` durumu, ödeme yöntemi, kredi/deneme bakiyesi ve tahsilat durumu ayrıca doğrulanamadı. Bu yüzden “bağlantı açıktı” ile “bugün hesabın tüm ödeme ayrıntıları kontrol edildi” aynı iddia değildir. Başka projeler/hesaplar için tam erişim yok.

## 5. 10 veya 20 dolarlık bütçe var mı? Neden oluşturulmuş?

**Erişilebilen kayıtlarda 10 USD veya 20 USD bütçe bulunmadı.** Görülenler:

1. `Firebase Project halisaha-app-d9ea1`: aylık **50 TRY**, projenin tamamı. `services` filtresi yok; yalnız Firebase veya yalnız Maps'e ayrılmış değil. Krediler dahil, %50/%90/%100 gerçekleşen harcama uyarıları var. Oluşturan kişi, tarih ve oluşturulma nedeni doğrulanamadı. Adında Firebase geçmesi, hangi ekranın veya kişinin oluşturduğunu kanıtlamaz.
2. `DEPAR sifir maliyet uyarisi (0 TL)`: aylık **0 TRY**, yine projenin tamamı; servis filtresi yok. **Önceki denetimde ben oluşturdum**, `recepdr1906@gmail.com` oturumuyla; 15 Ekim 11:31'de yeniden okunarak doğrulandı. Amaç krediyle karşılananlar dahil ücretlenebilir tüketimi uyarmaktı. Bu yeni salt okunur incelemede oluşturulmadı veya değiştirilmedi.

Bu liste yalnız önceki oturumun görebildiği proje bütçeleridir. Hesap genelindeki tüm bütçeler, başka projeler, silinmiş bütçeler ve geçmiş ekran önerileri taranamadı. Dolayısıyla “hiçbir zaman 10/20 dolar seçilmedi” denemez. Hatırlanan ekranın bütçe uyarısı, maliyet tahmini veya başka bir ürün ekranı olduğu mevcut kanıtla belirlenemiyor. Böyle bir tutar teklif edilmiş olması bütçenin kaydedildiğini ya da para çekildiğini göstermez.

## 6. Gerçek ödeme sınırı mı, uyarı mı?

Görülen **50 TRY ve 0 TRY bütçeler yalnız uyarı**. Hizmetleri kapatmıyor, kullanımı durdurmuyor ve ödenecek tutarı sınırlamıyor. 0 TL uyarısı, 0 TL fatura garantisi değildir. Bütçe tutarı ön ödeme veya abonelik ücreti değildir. [Bütçe uyarılarının sınırı](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans).

Google'ın ayrıca seçili servisler için otomatik spend-cap özelliği var. Bunun bu iki bütçede etkin olduğuna ilişkin kayıt yok. Kapsamı tüm projeyi korumaz; gecikmeler/aşımlar olabilir ve bazı uygulama isteklerini durdurabilir. [Spend-cap kapsam ve sınırlamaları](https://docs.cloud.google.com/billing/docs/how-to/budgets-spend-caps).

## 7. Şimdiye kadar ücret oluştu mu? Hangi servis?

**Bilinmiyor.** Mevcut/geçmiş kullanım bedeli, net fatura, krediyle karşılanan tutar, borç veya tahsilat okunamadı. Etkin API listesi, bütçe hedefi ve billing bağlantısı tutar kanıtı değildir. Belirli bir servise gerçek ücret atfedemem. Gerçek tüketim, krediler ve net maliyet servis/SKU bazında Billing Reports/Cost Table üzerinden incelenmeli. Bu tur ücretli export/dataset/query kurulmadı.

## 8. Ücretsiz sınırlar içinde kullanabilir miyim?

- **Authentication:** temel e-posta/parola ve sosyal girişler ücretsiz kullanılabilir. SMS ve Identity Platform'un ilgili kullanım kademeleri farklıdır. Uygulamada SMS akışı bulunmadı; Identity Platform'un canlı durumunu doğrulamadan sınırsız ücretsiz denemez.
- **Firestore:** günlük 50.000 okuma, 20.000 yazma, 20.000 normal silme; 1 GiB depolama ve aylık 10 GiB çıkış ücretsiz miktarları vardır. Blaze'de aşım ücretlenebilir. TTL silmeleri normal ücretsiz silme kotasına dahil değildir. Önceki kayıtta `_loginLimits.expiresAt` TTL politikası ACTIVE olduğundan, tüm uygulamanın yalnız ücretsiz işlemler kullandığı varsayılamaz. [Firebase fiyatları](https://firebase.google.com/pricing), [Firestore TTL fiyatı](https://cloud.google.com/firestore/pricing).
- **Native Maps:** standart Maps SDK SKU'su sınırsız ücretsiz gösterim içerir. Places aramaları/fotoğraflar ve statik haritalar ayrı SKU'lardır: Legacy Text Search 5.000/ay, Details 5.000/ay, Photo 1.000/ay; Static Maps 10.000/ay ücretsiz miktar. Alanlar/ek SKU'lar ayrıca etkileyebilir; ücretsiz miktar otomatik durdurma sınırı değildir. [Maps fiyatları](https://developers.google.com/maps/billing-and-pricing/pricing).
- **Storage:** yeni `.firebasestorage.app` bucket GCS fiyatlandırmasına tabidir; ücretsiz depolama/işlem koşulları konuma bağlıdır. Bucket konumu bilinmeden ücretsiz kabul edilemez. [Storage koşulları](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024).
- **Functions/Cloud Run:** ücretsiz kullanım miktarları vardır, aşım ve build, registry, ağ gibi destek maliyetleri ayrıca değerlendirilmeli. Düşük trafik toplam faturanın mutlaka sıfır olmasını sağlamaz. [Cloud Run fiyatları](https://cloud.google.com/run/pricing).
- **Vision SafeSearch:** ilk 1.000 birim/ay ücretsiz; sonraki kullanım ücretlenebilir. [Vision fiyatları](https://cloud.google.com/vision/pricing).
- **App Check / Crashlytics:** ürünlerin kendisi ücretsizdir; kullanılan attestation/diğer altyapı veya ürünlere bunun otomatik olarak uygulanacağı varsayılmamalı. [Firebase fiyatları](https://firebase.google.com/pricing).

Birçok özellik ücretsiz miktarlar içinde kalabilir. Ancak mevcut Functions, Storage, Vision ve TTL içeren mimari için **her koşulda 0 TL ve kesintisiz çalışma garantisini birlikte veremem**. Tüketim ve konum verileri eksik; hiçbir özellik bu tur kapatılmadı.

## 9. Kötüye kullanıma karşı gereken güvenlik ayarları

**Mevcut kayıt:** ayrı iOS Maps anahtarı `com.depar.app` ve yalnız iOS Maps API'sine sınırlıydı. Eski ortak Android/REST anahtarında önceki denetimde beş Maps API'sine izin listesi uygulanmıştı; uygulama kısıtı hâlâ yoktu. Üç Firebase istemci anahtarı farklıydı. Bunlar bu tur yeniden okunmadı.

Birlikte değerlendirilecek önlemler; bu tur uygulanmadı:

1. iOS, Android ve sunucu REST kullanımı için ayrı anahtarlar; her birinde yalnız gereken API'ler. Android uygulama kısıtında gerçek dağıtım sertifikası kullanılmalı; yerel debug sertifikası release sertifikası değildir.
2. REST anahtarını mobil pakete koymadan kimlik doğrulamalı, izin verilen işlemlerle sınırlı sunucu proxy'si; kullanıcı/uygulama bazında limit ve gerekiyorsa sunucu anahtarına uyumlu kısıtlar. Proxy'nin kendisi de ücretlenebilir ve kötüye kullanım sınırları gerekir. Yerel yeni kod canlı kabul edilmemeli.
3. Gerçek cihazda App Check doğrulaması sonrası uygun servislerde enforcement; Firestore/Storage'da sahiplik/yetki/boyut kuralları; endpoint bazında hız sınırı. Firebase API anahtarını gizlemek tek başına veri veya maliyet koruması değildir.
4. Places/Static Maps/Vision kotalarını gerçek ihtiyaç ve ücretsiz miktara göre değerlendirmek. Günlük/dakikalık kota aylık TL limiti değildir; aylık toplamlar ve ortak fatura hesabı dikkate alınmalı. Limit dolması özellikleri durdurabilir.
5. IAM'de gereksiz Owner/Editor yetkilerini azaltmak, yönetici hesaplarını MFA ile korumak, sızan gerçek gizli kimlik bilgilerini desteklenen yöntemle yenilemek. Önceki denetimdeki Auth hash yapılandırmasının yanlışlıkla çıktıya girmesi olayı ayrıca çözülmüş sayılmamalı; CLI iptali hash anahtarını yenilemez. Kullanıcı hash kayıtları/parolaları dışa aktarılmamıştır.

[Google Maps güvenlik rehberi](https://developers.google.com/maps/api-security-best-practices). Anahtar kısıtları ve App Check riski azaltır; izin verilen ücretli işlemlerin tüm maliyetini matematiksel olarak sıfırlamaz.

## Eksik erişim ve sonraki karar

Bağlı billing hesabında `recepdr1906@gmail.com` için **Billing Account Viewer (`roles/billing.viewer`)**, hesap logları için ayrıca gerekli okuma yetkisi ve yeniden CLI girişi veya bağlı tarayıcı gerekiyor. Şifre, kart veya anahtar paylaşılmamalı. Bu erişim sağlanınca önce yalnız okuma ile gerçek tutarlar ve hesap genelindeki bütçe/geçmiş incelenebilir. Hangi bütçe/anahtar/kota/servis değişikliğinin yapılacağına bundan sonra birlikte karar verilecek; önceki uygulama yetkileri bu yeni salt okunur talimatı geçersiz kılmaz.
