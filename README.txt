MAIL ALARM - Kurulum ve Kullanım Notları
=========================================

Belirli bir gönderenden gelen ve konu/içeriğinde anahtar kelime geçen e-postalar
için ekranda kırmızı, her zaman üstte bir alarm penceresi gösterir.

1) DERLEME (Delphi 10.4 Sydney)
-------------------------------
- File > Open Project... ile MailAlarm.dpr dosyasını açın. Delphi otomatik olarak
  MailAlarm.dproj ve MailAlarm.res dosyalarını oluşturur (sorarsa "Evet" deyin).
- Platform: Windows 32-bit veya 64-bit.
- Project > Build MailAlarm (Shift+F9).
- Indy 10 Delphi ile birlikte gelir; ek paket gerekmez.

2) OPENSSL DLL KURULUMU (SSL/TLS için ZORUNLU)
---------------------------------------------
Indy, OpenSSL 1.0.2 DLL'lerini kullanır: ssleay32.dll ve libeay32.dll
- İndirme: https://github.com/IndySockets/OpenSSL-Binaries
  (ör. openssl-1.0.2u-i386-win32.zip  -> 32-bit derleme için
       openssl-1.0.2u-x64_86-win64.zip -> 64-bit derleme için)
- İki DLL'i MailAlarm.exe ile AYNI klasöre kopyalayın
  (ör. Win32\Debug veya Win32\Release klasörü).
- DLL mimarisi exe ile aynı olmalı (32-bit exe -> 32-bit DLL).
- DLL yoksa MailAlarm.log içinde "Could not load SSL library" hatası görülür.
- OpenSSL 1.1/3.x DLL'leri (libssl-*.dll) standart Indy ile ÇALIŞMAZ.

3) GMAIL UYGULAMA ŞİFRESİ (App Password)
---------------------------------------
Gmail normal şifreyle IMAP girişine izin vermez.
1. https://myaccount.google.com > Güvenlik > "2 Adımlı Doğrulama"yı açın.
2. https://myaccount.google.com/apppasswords adresine gidin.
3. Uygulama adı olarak "MailAlarm" yazıp "Oluştur"a basın.
4. Verilen 16 haneli şifreyi (boşluksuz) INI'deki Password alanına yazın.
5. Gmail Ayarlar > "Yönlendirme ve POP/IMAP" bölümünde POP'un açık olduğunu
   kontrol edin.

4) MailAlarm.ini AYARLARI
-------------------------
Dosya exe ile aynı klasörde olmalı. Yoksa ilk açılışta örnek dosya oluşturulur.
UTF-8 olarak kaydedin (Türkçe karakterli anahtar kelimeler için).

[POP3]
  Server        POP3 sunucusu (Gmail: pop.gmail.com)
  Port          995 (SSL/TLS) veya 110 (STARTTLS / şifresiz)
  UseSSL        0 = şifresiz, 1 = SSL/TLS (995), 2 = STARTTLS (110)
  Username      Tam e-posta adresi
  Password      Şifre / Gmail uygulama şifresi (dosyada düz metin tutulur,
                klasör erişimini kısıtlayın)

[Filter]
  SenderAddress İsteğe bağlı gönderici filtresi. Boş veya * ise tüm gönderenler
                izlenir; birden fazla adres virgül veya noktalı virgülle ayrılabilir.
  Keywords      Virgülle ayrılmış anahtar kelimeler; konu VEYA içerikte geçerse
                alarm üretilir (büyük/küçük harf duyarsız)
  CheckIntervalSeconds  Kontrol aralığı (saniye, en az 10)

[App]
  PlaySound      1 = alarmda sistem sesi çal, 0 = sessiz
  StartMinimized 1 = sistem tepsisinde gizli başla

INI değiştirildikten sonra yeniden derleme gerekmez: ana penceredeki
"Ayarları Yükle" butonu veya tepsi menüsündeki "Ayarları Yeniden Yükle" yeterlidir.

5) ÇALIŞMA MANTIĞI
------------------
- Her N saniyede POP3 posta kutusundaki gönderen adresi eşleşen mailler aranır
  (arka plan iş parçacığında; arayüz donmaz). POP3 UIDL kimliği sayesinde
  uygulama aynı iletiyi yalnızca bir kez işler.
- Mailler "okundu" olarak işaretlenmez (PEEK ile okunur).
- İşlenen her mailin UID'si ile aktif gönderici/keyword kuralı seen_uids.dat
  dosyasına yazılır; aynı mail tekrar alarm üretmez. Filtre veya keyword değişince
  mevcut iletiler yeni kuralla bir kez yeniden değerlendirilir.
- Birden fazla alarm varsa sırayla gösterilir; her biri "Tamam" ile kapatılır.
- Pencere kapatma/küçültme uygulamayı sistem tepsisine gizler. Tepsi simgesine
  çift tıklayın veya sağ tık > "Göster". Tamamen kapatmak için sağ tık > "Çık".
- Hatalar (bağlantı kopması, şifre hatası vb.) MailAlarm.log dosyasına yazılır ve
  bir sonraki döngüde tekrar denenir.
- Uygulama tek örnek çalışır.

6) WINDOWS İLE BAŞLATMA (isteğe bağlı)
--------------------------------------
Win+R > shell:startup  klasörüne MailAlarm.exe için bir kısayol koyun.
