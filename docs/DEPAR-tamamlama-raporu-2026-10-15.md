# DEPAR eksik tamamlama raporu — 15 Ekim 2026

**En son inceleme — salt okunur güvenlik denetimi:** Yerel kaynakta 6 ayrı sorun testle doğrulandı; 1 tarihsel Storage bulgusu ayrıca ayrıldı. Güncel canlı dağıtım bu tur doğrulanamadı. Ayrıntılar, önkoşullar ve tekrarlanabilir testler [kanıtlı güvenlik raporunda](DEPAR-kanitli-guvenlik-denetimi-2026-10-15.md). Bu denetimde uygulama kaynakları veya canlı ayarlar değiştirilmedi; aşağıdaki eski tamamlanma/test kayıtları bu yeni bulguların düzeltildiği anlamına gelmez.

Kaynak: kullanıcının verdiği `DEPAR-yayin-hazirlik-raporu.html`. HTML'deki öneriler inceleme girdisidir; kullanıcının son talimatı yayın/deploy yapmadan eksik kodları tamamlamaktır. Yayın hedefi iOS'tur. Bu çalışma sırasında canlı Firebase, Google Cloud veya web sitesinde değişiklik yapılmadı; commit/push/mağaza işlemi yapılmadı.

Teknik koordinasyonu `gpt-6-astra` yürüttü. Backend ve Flutter işleri ayrı alt ajanlara verildi; ana oturum yedek araçlarını, CI/dokümantasyonu ve son raporu tamamladı. Yerel hazırlık ile canlıda çalışan özellikler aşağıda ayrıdır.

Sonraki kapsam notu — 15 Ekim 2026: kullanıcı önce eski deploy erteleme talimatını kaldırdı, ardından Google Cloud hesabı açma/yayın yorumu hakkında itiraz etti. Bu sonraki turda yeni hesap, ücretli hizmet, deploy veya canlı veri değişikliği yapılmadı; canlı işlem kapsamı netleştirilene kadar durduruldu. Kullanıcı resmi yayıncı adını **Emir Topaloğlu** olarak bildirdi. Aşağıdaki test ve tamamlanma sonuçları önceki yerel çalışmaya aittir.

Güncel kapsam — Google Cloud sıfır maliyet denetimi: kullanıcı daha sonra ücretsiz, geri alınabilir ve TestFlight işlevini etkilemeyen güvenlik/maliyet ayarlarına açık yetki verdi. Bu yetkiyle ücretsiz Budget API, 0 TL e-posta uyarısı, eski Maps anahtarının API allowlist'i ve açığa çıkan CLI oturumunun iptali yapıldı. Ücretli kaynak veya uygulama deploy'u yapılmadı. Harcama geçmişi erişimi ve kalan riskler [ayrı denetim raporunda](DEPAR-cloud-guvenlik-maliyet-denetimi-2026-10-15.md) kayıtlıdır. Bu yeni sıfır maliyet şartı altında önceki TTL/backup/Functions rollout önerileri otomatik uygulanmamalıdır.

## Bu turda tamamlanan yerel işler

1. **K4 — Google web servis anahtarının uygulama paketinden çıkarılması.** Flutter `.env` yüklemesi ve asset kaydı, dotenv bağımlılığı ve doğrudan Places/Static Maps HTTP çağrıları kaldırıldı. Native iOS Maps SDK anahtarı ayrı yapılandırmasını korur. Eski ignore edilmiş `.env` dosyası silinmedi; yeni pakete girmez. CI'daki kullanılmayan `APP_ENV` adımı da kaldırıldı.
2. **K4 — Kimlik doğrulamalı Places proxy'si.** `placesProxy` search/details/photo/staticMap işlemlerini sabit Google endpointlerine gönderir. Sunucu sırrını veya anahtarlı Google URL'sini istemciye döndürmez. Payload, upstream cevap ve görsel boyut sınırları, timeout, redirect host kontrolü, kullanıcı/işlem başına hız sınırı ve sınırlı concurrency vardır. Fotoğraf ve Google kaynak atıfları korunur. Flutter bellek cache'i ve görünür saha görsellerinin paralelliği sınırlandı; eski Google anahtarlı görsel URL'leri doğrudan yüklenmez.
3. **K4 — E-posta doğrulama ve zorlanan spam kontrolleri.** Ayarlarda doğrulama e-postası gönderme/yeniden gönderme ve token yenileyerek durum kontrolü eklendi. Güvenilir runtime policy açıldığında yeni maç, takip isteği ve yeni davet doğrulanmış e-posta gerektirir. Maç oluşturma 60 saniye, takip isteği 15 saniye kişi başı cooldown ile sınırlanır. İzin kaydı hedef belgeyle atomik yazılır; tek başına izin üretme, silerek sıfırlama ve başka hedefe kullanma reddedilir. Gelen isteği kabul etme, saf kadro düzenleme ve davet kaldırma korunur. Her bildirim türü için genel spam sınırı yapılmış sayılmaz.
4. **O1 — İsteğe bağlı benzersiz kullanıcı adı.** Kullanıcı ayarlardan 3–30 küçük İngilizce harf/sayı/alt çizgi içeren adı bir kez seçebilir. Rezervasyon ve profil alanı sunucu transaction'ıyla birlikte yazılır. Başkasının adı alınamaz, istemci profil yazmasıyla handle değiştirilemez. Tam handle araması ve giriş çözümü e-posta/parola bilgisini açığa çıkarmaz. Görünen ad ve eski e-posta girişi korunur; aynı görünen ad/handle farklı hesaplara denk gelirse rastgele hesap seçilmez. Kullanıcılara otomatik ad atanmadı.
5. **Y6 — İstemciyi aşınca da çalışan metin kontrolü.** Profil/maç metinlerine Firestore tarafında uzunluk, kontrol karakteri ve sınırlı açık sözcük reddi eklendi. Kullanıcı adı servisi de metin kontrolü uygular. Bu, istemcideki filtreyi devre dışı bırakmanın tek başına yeterli olmasını engeller; tüm bağlamları veya Unicode kaçırmalarını anlayan kapsamlı bir dil moderasyonu değildir.
6. **Yeni verinin hesap silmede temizliği.** Kullanıcı adı rezervasyonları ve yeni abuse/proxy/handle sayaçları silme akışına dahil edildi. Sunucuya ait kayıtlar istemciye doğrudan açık değildir.
7. **Yedek doğrulama ve yerel geri yükleme provası.** Gerçek iki JSON yedeğinin checksum ve typed Firestore biçimi doğrulandı. Sadece yapay verilerle ayrı yerel emülatörde belge/alt koleksiyon geri yüklemesi, mevcut belgeyi koruyan create-only önkoşulu ve başarısız commit'in kısmi yazmaması test edildi. [Araçlar ve sonuçlar](backup-recovery.md).

## Kod hazır, canlı etkinleştirme bekliyor

Bu maddeler kullanıcı talimatıyla canlıya gönderilmedi. Yeni kodun varlığı, mevcut canlı uygulamanın bu güvenlikleri uyguladığı anlamına gelmez.

- **Places proxy:** `PLACES_PROXY_READY=true` ve yalnızca sunucuya bağlı ayrı Secret Manager `GOOGLE_MAPS_API_KEY` gerekir. Google API erişimi/kısıtları da doğrulanmalıdır. **Yeni istemci eski backend'e bağlanırsa canlı Google saha araması ve yeni Google görselleri kullanılamaz; açıklayıcı mesaj/placeholder gösterilir. Kayıtlı ve manüel saha akışı kullanılabilir.** Bu istemciyi normal yayına çıkarmadan önce backend ile eşleştirmek gerekir.
- **Kullanıcı adı:** `USERNAMES_READY=true` ve yeni Functions/kural sürümü birlikte gerekir. Capability eksik/kapalıysa UI seçim sunmaz; eski giriş davranışı korunur.
- **Spam policy:** güvenilir `_runtimePolicy/safety.enabled=true`, uyumlu istemci ve yeni Firestore kuralları birlikte gerekir. Policy eksik/kapalıyken mevcut kullanıcılar doğrulama şartıyla aniden kilitlenmez. Tek başına istemci bayrağı koruma sağlamaz.
- **O2 — Fotoğrafı yüklemeden denetleme:** önceki turda hazır olan `uploadProfilePhoto`, `PHOTO_MODERATION_READY=true` + `MODERATION_READY=true` ve doğrudan upload'u kapatan aday Storage kuralları birlikte bekliyor. Mevcut canlı eski upload yolu için ön-denetim açığı kapanmış sayılmaz. Vision hatası/eksik cevap/uygunsuz içerik yeni yerel akışta Storage'a yazılmaz.
- **TTL:** yeni fotoğraf, proxy ve kullanıcı adı limitlerinin expiry/TTL yapılandırması ayrıca gözden geçirilip etkinleştirilmelidir. TTL gecikmesi aktif cooldown kontrolünü kaldırmaz; temizlik ve maliyet takibi ayrı konudur.
- **Eski açığa çıkmış Google anahtarı:** daha önce yayımlanmış paketler veya eski verideki URL'ler bu kod değişikliğiyle geri alınamaz. Eski anahtarın güvenli rotasyonu/kısıtlanması, ayrı sunucu anahtarı ve Google Cloud bütçe/kota uyarıları canlı operasyon olarak bekliyor. Bütçe uyarısı tek başına harcamayı durdurma garantisi değildir.
- **App Check:** SDK/token akışı hazır; gerçek sağlayıcı kaydı, iPhone doğrulaması, izleme ve enforcement kapalı/bekliyor.
- **Web metinleri:** `.release/depar-web` içindeki gizlilik/koşullar kaynakları ve [taşınabilir patch](legal-site-update.patch) hazır. Web commit/push/yayını yapılmadı.

## Bu ortamda tamamlanamayan veya bilgi gerektiren işler

1. **Gerçek iOS build ve cihaz testi.** Windows'ta Mac/Xcode archive, Apple/Google giriş, native harita, doğrulama e-postası, kullanıcı adıyla başarılı giriş/reset, moderasyon ve hesap silmenin gerçek cihaz uçtan uca testi yapılmadı. Yerel testler bunların yerine geçmez. Manuel macOS CI tanımı hazır, bu çalışma uzak CI çalıştırmadı.
2. **Crashlytics dSYM/native doğrulaması.** SDK ve release opt-in hazır; collection varsayılan kapalıdır. CocoaPods sembol yükleme fazı bağlanmadı ve test crash konsolda doğrulanmadı. Okunan [firebase:xcode-project-setup SKILL.md](C:/Users/ONUR/.codex/plugins/cache/openai-curated-remote/firebase/1.0.0/skills/xcode-project-setup/SKILL.md) açıkça “Do not attempt to proceed without Swift” der. Bu ortamda `swift --version` bulunamadığından doğrulanamayan Xcode proje değişikliği yapılmadı. Mac üzerinde Swift/Xcode ile bu adım tamamlanmalıdır.
3. **Gerçek işletmeci bilgileri.** Destek adresi `destekdepar@gmail.com`, moderasyon sorumlusu uygulama sahibidir. Sonraki kullanıcı yanıtıyla resmi yayıncı adı **Emir Topaloğlu** olarak bildirildi. Veri sorumlusu sıfatı, resmi iletişim adresi, saklama ve aktarım kararları henüz doğrulanmadı. Uydurulmadı; yasal metinlerin tamamlandığı veya tam KVKK uyumu iddia edilmez. [Metin hazırlığı](legal-publication-copy.md).
4. **Tam proje kurtarma.** Yönetilen Firestore export, düzenli yedek/PITR, bütün Storage dosyaları ve gerçek yedeğin izole ortamda tam geri yükleme testi eksik. Yerel JSON ve yapay veri provası, Auth/IAM/sırlar/indexler/fotoğraf bytes dahil tam proje yedeği değildir.
5. **Üç Auth'suz eski profil.** Önceki migration'da 25 mevcut profil sürüm 2'ye taşındı; Auth hesabı olmayan üç eski profil korunuyor. Bunları başka kullanıcıya bağlama/silme için kanıt yok, veri kaybına yol açacak işlem yapılmadı.
6. **Genel sosyal dizin politikası.** Arkadaş/takipçi/takip edilen listeleri kullanıcı seçimine göre sahibi ve karşılıklı arkadaşlarıyla sınırlıdır. Genel sürüm-2 profil ve maç keşfi oturum açan kullanıcılar için korunur; bütün kullanıcı dizininin görünürlüğü kapatılmadı. Mevcut ürünün keşif akışını değiştirecek yeni karar verilmedi.
7. **İmzalama/mağaza.** Kullanıcı bu adımları erteledi. Apple Developer, imzalı archive, TestFlight ve App Store yayını yapılmadı. K1 Android release anahtarı, yalnızca iOS hedefinin dışındadır; yeni Android anahtarı oluşturulmadı.

## Önceki turlarda kapanan rapor maddeleri

- **K2:** hesap silme, şikayet/moderasyon ve özel giriş backend'i önceki açık izinlerle canlıya alındı; sahibin onayladığı uygulama hesabına moderator claim verildi. Başarılı gerçek kullanıcı uçtan uca testi hâlâ ayrı gerekir.
- **K3:** canlı kurallar daha önce okunup karşılaştırıldı; rapordaki “muhtemelen herkese açık” varsayımı doğrulanmadı. Sosyal liste görünürlüğü kullanıcı tercihine göre daraltıldı. Yeni yerel kurallar henüz canlı değil.
- **Y1/Y3:** yedekli/önkoşullu profil migration'ı ve mevcut altı composite index'in READY olması önceki canlı işlem kaydındadır. Üç Auth'suz profil istisnası yukarıdadır.
- **Y2/Y4/Y5:** sınırlı/tarih sıralı maç sorguları, oturum değişiminde stream iptali ve eski async sonuçların engellenmesi, profil hatasında kurulumun atlanmaması ve kısmi kayıt kurtarması düzeltildi.
- **Y6:** profil düzenleme dahil istemci filtreleri ve hukuki taslak önceki turda hazırlandı; bu tur zorunlu kural kontrolü eklendi. Son kullanıcı teyidiyle resmi yayıncı Emir Topaloğlu ve destek adresi gizlilik/koşullar HTML taslaklarına eklendi. Web yayını ve henüz verilmemiş hukuki işletme ayrıntıları bekliyor.
- **Y7/Y8:** PrivacyInfo/entitlement/plist yapılandırması düzeltildi; ayrı `com.depar.app` kısıtlı native iOS Maps anahtarı yerelde bağlandı. İmza/Xcode privacy report/gerçek iPhone sonucu doğrulanmadı.
- **Y9:** kilitli bağımlılıklar, tek manuel/pinlenmiş macOS build workflow'u ve yerel yapılandırma kontrolü hazır. Temiz Mac build veya uzak CI başarı iddiası yok.
- **O2/O3/O4:** fail-closed fotoğraf kodu, sosyal liste gizliliği, eksik snapshot/ağ hatası yakalama, profil kaydı başarısızsa yerel ekranın korunması ve iPad paylaşım origin düzeltmeleri hazır. Fotoğraf pre-scan'in canlıya geçişi ve Crashlytics doğrulaması bekliyor.

## Doğrulama

- Flutter: **93/93** test geçti. `dart analyze lib test`: **0 hata, 0 uyarı, 60 bilgi bildirimi, 0 deprecated_member_use**.
- Functions: **56/56** birim testi geçti. Gerçek Firebase SDK discovery testi, proxy kapalıyken yeni Maps sırrının tanımlanmadığını/bağlanmadığını ve açıkken sırrın değerinin discovery sırasında okunmadığını doğruladı.
- Firestore/Auth emülatörleri: **77/77** test geçti. Dağılım: metadata 10, profil 7, cooldown 4, özel giriş/kullanıcı adı/hesap silme entegrasyonu 24, son maç/sosyal ilişki/silme kuralları regresyonu 32. Kullanıcı adı yarışında tek kazanan, atomik rezervasyon, doğrudan handle yazma reddi, yoğun kadro, doğrulanmamış davet, cooldown aşma girişimi ve hesap silme temizliği kapsandı.
- Yedek doğrulayıcı: **3/3** test; gerçek iki dosyada SHA-256 ve 188/28 belge biçimi doğrulaması geçti.
- Yerel restore provası: iki yapay belge/alt koleksiyon, typed round-trip, çakışmada üzerine yazmama ve atomiklik geçti.
- iOS statik yapılandırma kontrolü geçti; workflow YAML parse kontrolü geçti. Bunlar Mac derlemesi değildir.
- Mobil ve ayrı hukuki web deposunun `git diff --check` kontrolü geçti. Değişiklikler commit edilmedi.

Son kural koşusunun yerel logu `%TEMP%\depar-final-remaining-rules-2026-10-15.log` dosyasındadır. Beklenen saldırı/red senaryoları emülatör loguna permission-denied değerlendirme mesajları yazabilir; test runner sonucu 32 başarılı, 0 başarısızdır.
