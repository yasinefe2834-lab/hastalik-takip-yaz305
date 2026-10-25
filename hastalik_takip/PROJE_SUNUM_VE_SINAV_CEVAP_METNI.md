# YAZ305 MOBİL YAZILIM GELİŞTİRME (2026-27) ARA SINAV PROJESİ CEVAP KAĞIDI METNİ

* **Hazırlayan Öğrenciler:** Kayra Oruçoğlu, Yasin Efe Güvenç
* **Danışman / Ders Yürütücüsü:** Şerife Esra Dinçer
* **Kurum:** T.C. İstanbul Gedik Üniversitesi

---

## 1) Yapılan Projenin Sorusu
**PROJE 11 – Hastalık Takip Uygulaması**
* Hastalık girişi
* Doktor ziyaret notları
* İlaç bilgileri
* Gelecek doktor ziyaretlerinin takibi
* Genel raporlama, özet bilgiler
* Veritabanı cihaz üzerinde

---

## 2) Uygulamanın Amacı
Günümüzde bireylerin kendi sağlık verilerini, geçmiş hastalıklarını, doktor muayene notlarını, gelecekteki hastane randevularını ve düzenli kullanmaları gereken ilaç dozlarını takip etmeleri çoğu zaman dağınık notlar veya unutulan kağıt reçeteler nedeniyle zorlaşmaktadır. Özellikle kronik rahatsızlığı olan veya birden fazla ilaç kullanan bireylerde bu durum tedavi aksamalarına ve veri kaybına yol açmaktadır.

Bu projenin temel amacı; bireylerin tüm sağlık geçmişlerini, tanılarını, doktor ziyaret notlarını, gelecek randevularını ve ilaç doz takvimlerini **tek bir mobil uygulama çatısı altında, bulut sunuculara ihtiyaç duymadan tamamen kendi cihazları üzerinde güvenli bir yerel veritabanında** saklayabilmelerini, analiz edebilmelerini ve bir sonraki doktor ziyaretinde hekime **PDF veya özet rapor** olarak hızlıca sunabilmelerini sağlamaktır.

---

## 3) Uygulamanın Özellikleri ve Nasıl Çalıştığını Açıklayan Metin

Uygulama **Flutter** framework'ü ve **Dart** programlama dili kullanılarak **Material Design 3** standartlarına uygun, aydınlık ve karanlık tema (Dark/Light Mode) destekli olarak geliştirilmiştir. Uygulama 5 ana modülden oluşmaktadır:

### A. Cihaz Üzerinde Hibrit Yerel Veritabanı Mimarisi (20 Puanlık Kriter)
Kişisel sağlık verilerinin gizliliğini korumak amacıyla veriler bulut yerine tamamen cihaz üzerinde çalışan hibrit bir yerel veritabanı mimarisinde (`lib/services/database_service.dart`) tutulmaktadır:
1. **SQLite (`sqflite` / `sqflite_common_ffi`):** Hastalıklar (`diseases`), doktor ziyaretleri (`doctor_visits`) ve ilaçlar (`medications`) tablolarında ilişkisel CRUD (Ekleme, Okuma, Güncelleme, Silme) işlemlerini yürütür.
2. **Hive (`hive_flutter`):** Hızlı önbellek (cache) ve NoSQL kutu (`Box`) depolaması sağlar.
3. **SharedPreferences:** Kullanıcı sağlık profili (kan grubu, alerjiler), karanlık/aydınlık mod tercihi ve PIN kilit ayarlarını saklar.
4. **Yerel JSON Yedekleme (`hastalik_takip_yedek.json`):** Veri kaybı riskine karşı tüm kayıtları cihaz içi dosya sistemine JSON formatında yedekler ve dışa aktarır.

### B. Derste İşlenmeyen Yenilikçi Özellikler (20 Puanlık Kriter)
1. **Kamera & Optik Karakter Tanıma (OCR) ile Tıbbi Belge Tarayıcı (`lib/services/ocr_service.dart`):**
   * `google_mlkit_text_recognition` ve `image_picker` kütüphaneleri kullanılarak doktor muayene kağıtları, reçeteler ve ilaç prospektüsleri kameradan veya galeriden taranarak dijital metne dönüştürülür.
   * Geliştirilen tıbbi metin ayrıştırma algoritması; belge içindeki **Hastalık/Tanı adını, Hekim ve Poliklinik bilgisini, İlaç adını, Dozajı ve Kullanım saatlerini** otomatik olarak tespit eder ve tek tuşla ilgili veritabanı tablosuna kaydeder.
2. **Hekim İçin Tek Tuşla PDF Genel Sağlık Raporu Üretimi (`lib/services/pdf_report_service.dart`):**
   * `pdf` ve `printing` paketleri kullanılarak hastanın aktif hastalıkları, ilaç uyum oranı, ilaç listesi ve muayene geçmişi resmi bir **A4 PDF Sağlık Raporu** haline getirilir, önizlenir ve paylaşılır.

### C. Proje 11 Ana Modülleri ve İşleyişi
1. **Hastalık Girişi ve Takibi (`lib/screens/diseases_screen.dart`):**
   * Kullanıcılar hastalık adı, kategorisi (Kronik, Akut, Enfeksiyon, Alerjik vb.), tanı tarihi, güncel durumu (*Aktif, Kontrol Altında, İyileşti*), 1-10 arası şiddet derecesi, belirtiler ve hekim notlarını kaydedebilir; arama ve durum filtreleme yapabilir.
2. **Doktor Ziyaret Notları ve Gelecek Randevu Takibi (`lib/screens/doctor_visits_screen.dart`):**
   * **Gelecek Randevular** sekmesinde hastane, poliklinik, doktor adı, randevuya kalan gün sayısı geri sayımı ve randevu öncesi hazırlık/tahlil notları takip edilir. Randevu gerçekleştiğinde tek tuşla muayene notu girilerek **Geçmiş Muayene Notları** sekmesine aktarılır.
3. **İlaç Bilgileri ve Günlük Doz Takibi (`lib/screens/medications_screen.dart`):**
   * İlaç adı, ilişkili hastalık, dozaj, kullanım sıklığı, saatleri, aç/tok karnına bilgisi ve kalan tablet stoğu takip edilir. Günlük doz alındığında **"Dozu Al"** butonuyla sesli onay bildirimi çalar, günlük ilaç uyum yüzdesi (%) ve kalan stok otomatik güncellenir.
4. **Genel Raporlama ve Grafiksel İstatistikler (`lib/screens/reports_screen.dart`):**
   * Özel çizim (`CustomPainter`) halka grafiği (Donut Chart) ile hastalık durum dağılımı ve sütun çubukları ile hastalık şiddet analizi görselleştirilir.

### D. Ses, Görüntü ve Video Kullanımı (10 Puanlık Kriter)
Uygulamanın çalışma hızını olumlu etkilemek adına tüm medya dosyaları düşük çözünürlüklü ve düşük boyutlu olarak optimize edilmiştir:
* **Ses (`assets/audio/`):** İlaç saati bildirimi (`ilac_bildirim.wav` - 20 KB), randevu uyarısı (`randevu_uyari.wav` - 25 KB) ve işlem onay sesi (`saglik_onay.wav` - 14 KB) `audioplayers` paketi ile çalınmaktadır.
* **Görüntü (`assets/images/`):** Uygulama başlık görseli, örnek reçete/prospektüs OCR görselleri ve 3 adet görsel sağlık rehberi kartı (her biri 6-12 KB PNG) yer almaktadır.
* **Video (`assets/videos/`):** `video_player` paketi ile oynatılan düşük boyutlu sağlık ve uygulama tanıtım videosu (`saglik_tanitim.mp4`) bulunmaktadır.
