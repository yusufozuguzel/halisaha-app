# Yerel yedek doğrulama ve geri yükleme provası

15 Ekim 2026. Bu araçlar canlı projeye erişmez. Gerçek yedek doğrulayıcı yalnızca dosya okur; geri yükleme provası yalnızca sabit yerel `demo-depar-recovery` emülatörüne yapay veri yazar. Gerçek kullanıcı belgeleri emülatöre taşınmadı.

## Mevcut yedeklerin kontrolü

`tool/verify_firestore_backup.py`, Firestore REST veya Firebase MCP JSON biçimindeki belge listesini denetler. Beklenen proje/veritabanı, belge yolları, yinelenen kayıtlar, Firestore değer türleri, boyut/nesting sınırları ve varsa tamamlanmamış pagination kontrol edilir. Önceden kaydedilmiş SHA-256 ile dosya bütünlüğü doğrulanır. Belge adları veya içerikleri loglanmaz.

```powershell
python tool/verify_firestore_backup.py "$env:LOCALAPPDATA\DEPAR\Backups\2026-10-12-2118\firestore-page-001.json" --project halisaha-app-d9ea1 --sha256 9667A0E53AD3EEB9A64392C9FCEA8D21C53E8E108F67CC1515C50A68754F10B6
python tool/verify_firestore_backup.py "$env:LOCALAPPDATA\DEPAR\Backups\2026-10-12-avatar-profile-transition\firestore-page-001.json" --project halisaha-app-d9ea1 --sha256 D2F466628E37EE9F0129147C028D56F89294EE26658A578547379B409C612D12
python -m unittest discover -s tool -p test_verify_firestore_backup.py
```

Bu çalışmada iki kontrol de geçti: ilk dosyada 188 belge, ikinci dosyada 28 profil belgesi; checksum kayıtları eşleşti. Üç yerel test geçerli REST/MCP verisini, yanlış proje/yinelenen/eksik sayfa verisini ve bozuk tür/nesting verisini kontrol eder. Yedekteki belgelerin biçimsel doğruluğu ve checksum eşleşmesi, canlı veritabanındaki bütün kayıtların yedeklendiğini tek başına kanıtlamaz; ikinci dosya zaten yalnızca profil geçişi yedeğidir. İlk alımdaki tutarlı readTime önceki işlem kaydındadır, bu araç onu yeniden canlıdan doğrulamaz.

## Yapay veriyle geri yükleme provası

```powershell
& security-tests/node_modules/.bin/firebase.cmd emulators:exec --config tool/recovery.emulator.json --only firestore --project demo-depar-recovery 'python tool/firestore_recovery_drill.py'
```

Prova ayrı 8188 portunda çalışır; normal güvenlik testlerinin 8088 portunu kullanmaz. Emülatör kuralları istemci erişimini reddeder; prova sabit yerel admin REST erişimi kullanır. HTTP proxy yönlendirmesi kapalıdır, hedef URL değiştirilemez, üretim kimlik bilgisi veya gerçek yedek girdisi kabul edilmez. Her çalıştırma yeni bir emülatör süreci gerektirir; mevcut fixture üzerine yazılmaz.

Bu çalışmada prova geçti: Timestamp, int64, bytes, referans, geopoint, array/map içeren belge ve alt koleksiyon okuma/yazma turunda korundu. `currentDocument.exists=false` önkoşulu çakışan belgeyi korudu; aynı başarısız commit içindeki diğer yeni belge de oluşmadı. Firestore'un belgeleri atomik commit içinde yazması ve typed REST değer biçimi [resmi commit dokümanında](https://docs.cloud.google.com/firestore/docs/reference/rest/v1/projects.databases.documents/commit) ve [Value tanımında](https://docs.cloud.google.com/firestore/docs/reference/rest/v1/Value) açıklanır.

## Hâlâ gerekenler

Yönetilen Cloud export, planlı yedekleme/PITR, Storage dosyalarının tam yedeği ve gerçek yedeğin izole ortamda tam geri yükleme provası henüz yapılmadı. Bunlar canlı yapılandırma, uygun yedek bucket/erişim/saklama kararları ve ayrı operasyon gerektirir. Kullanıcının yayın/deploy erteleme talimatıyla bu işlemlere geçilmedi. Yerel JSON belgeleri Auth kullanıcıları, IAM, sırlar, indexler veya Storage bytes için tam proje yedeği değildir.
