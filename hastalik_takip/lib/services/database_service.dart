import 'dart:convert';
import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/health_models.dart';

/// Cihaz üzerinde çalışan Hibrit Yerel Veritabanı Yönetim Servisi.
///
/// TÜBİTAK 2209-A Araştırma Önerisi ve YAZ305 proje kriterleri doğrultusunda:
/// 1. İlişkisel veriler için SQLite (sqflite / sqflite_common_ffi),
/// 2. Hızlı önbellek ve NoSQL kutu yapısı için Hive (hive_flutter),
/// 3. Kullanıcı tercihleri ve gizlilik ayarları için SharedPreferences,
/// 4. Veri kaybını önleyen B Planı kapsamında Yerel JSON Yedekleme mimarisini birleştirir.
class DatabaseService extends ChangeNotifier {
  static final DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();

  Database? _sqliteDb;
  Box<dynamic>? _hiveBox;
  SharedPreferences? _prefs;

  List<DiseaseRecord> _diseases = [];
  List<DoctorVisitRecord> _visits = [];
  List<MedicationRecord> _medications = [];

  bool _isDarkMode = false;
  bool _isPinLockEnabled = false;
  String _pinCode = '1234';
  String _patientName = 'Kayra Oruçoğlu & Yasin Efe Güvenç';
  String _bloodType = 'A Rh(+)';
  String _allergies = 'Penisilin, Polen';
  String _lastBackupInfo = 'Henüz yedek alınmadı';
  String _activeStorageSummary = 'SQLite + Hive + SharedPreferences';

  // Dışarıya açılan salt okunur veri listeleri ve durum bilgileri
  List<DiseaseRecord> get diseases => List.unmodifiable(_diseases);
  List<DoctorVisitRecord> get visits => List.unmodifiable(_visits);
  List<MedicationRecord> get medications => List.unmodifiable(_medications);

  List<DoctorVisitRecord> get upcomingVisits =>
      _visits.where((v) => v.isUpcoming).toList()
        ..sort((a, b) => a.visitDateTime.compareTo(b.visitDateTime));

  List<DoctorVisitRecord> get pastVisits =>
      _visits.where((v) => !v.isUpcoming).toList()
        ..sort((a, b) => b.visitDateTime.compareTo(a.visitDateTime));

  bool get isDarkMode => _isDarkMode;
  bool get isPinLockEnabled => _isPinLockEnabled;
  String get pinCode => _pinCode;
  String get patientName => _patientName;
  String get bloodType => _bloodType;
  String get allergies => _allergies;
  String get lastBackupInfo => _lastBackupInfo;
  String get activeStorageSummary => _activeStorageSummary;

  /// Uygulama başlangıcında tüm yerel veritabanı katmanlarını başlatır.
  Future<void> initialize() async {
    // 1. SharedPreferences katmanını başlat
    _prefs = await SharedPreferences.getInstance();
    _isDarkMode = _prefs?.getBool('is_dark_mode') ?? false;
    _isPinLockEnabled = _prefs?.getBool('is_pin_lock_enabled') ?? false;
    _pinCode = _prefs?.getString('pin_code') ?? '1234';
    _patientName = _prefs?.getString('patient_name') ??
        'Kayra Oruçoğlu & Yasin Efe Güvenç';
    _bloodType = _prefs?.getString('blood_type') ?? 'A Rh(+)';
    _allergies = _prefs?.getString('allergies') ?? 'Mevsimsel Polen';
    _lastBackupInfo =
        _prefs?.getString('last_backup_info') ?? 'Otomatik yerel yedek aktif';

    // 2. Hive NoSQL yerel kutu veritabanını başlat
    await Hive.initFlutter();
    _hiveBox = await Hive.openBox<dynamic>('hastalik_takip_hive_box');

    // 3. SQLite ilişkisel veritabanını başlat (Web dışı tüm cihazlarda)
    if (!kIsWeb) {
      try {
        if (Platform.isWindows || Platform.isLinux) {
          sqfliteFfiInit();
          databaseFactory = databaseFactoryFfi;
        }
        final dbFolder = await getApplicationDocumentsDirectory();
        final dbPath = p.join(dbFolder.path, 'hastalik_takip_yerel.db');
        _sqliteDb = await databaseFactory.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, version) async {
              await _createSqliteTables(db);
            },
          ),
        );
        _activeStorageSummary =
            'SQLite (İlişkisel) + Hive (NoSQL Kutu) + SharedPreferences + JSON';
      } catch (e) {
        // Risk Yönetimi B Planı: SQLite erişiminde sorun yaşanırsa Hive + JSON devreye girer
        _activeStorageSummary =
            'Hive (NoSQL Kutu) + SharedPreferences + Yerel JSON (B Planı Aktif)';
      }
    } else {
      _activeStorageSummary =
          'Hive (Yerel Kutu) + SharedPreferences + JSON Yedekleme';
    }

    // 4. Verileri yükle; eğer ilk kurulumsa örnek sağlık verilerini oluştur
    await _loadAllData();
    final isInitialized = _prefs?.getBool('demo_seeded_v1') ?? false;
    if (!isInitialized &&
        _diseases.isEmpty &&
        _visits.isEmpty &&
        _medications.isEmpty) {
      await seedInitialSampleData();
      await _prefs?.setBool('demo_seeded_v1', true);
    }
  }

  /// SQLite veritabanı tablolarını oluşturur.
  Future<void> _createSqliteTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS diseases (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        diagnosisDate TEXT NOT NULL,
        status TEXT NOT NULL,
        severity INTEGER NOT NULL,
        symptoms TEXT NOT NULL,
        doctorOrClinic TEXT NOT NULL,
        notes TEXT NOT NULL,
        attachmentPath TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS doctor_visits (
        id TEXT PRIMARY KEY,
        diseaseName TEXT NOT NULL,
        hospitalName TEXT NOT NULL,
        department TEXT NOT NULL,
        doctorName TEXT NOT NULL,
        visitDateTime TEXT NOT NULL,
        isUpcoming INTEGER NOT NULL,
        doctorNotes TEXT NOT NULL,
        prescribedTests TEXT NOT NULL,
        reminderEnabled INTEGER NOT NULL,
        ocrRawText TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS medications (
        id TEXT PRIMARY KEY,
        diseaseName TEXT NOT NULL,
        name TEXT NOT NULL,
        dosage TEXT NOT NULL,
        frequency TEXT NOT NULL,
        scheduleTimes TEXT NOT NULL,
        usageInstruction TEXT NOT NULL,
        startDate TEXT NOT NULL,
        endDate TEXT NOT NULL,
        remainingPills INTEGER NOT NULL,
        takenToday INTEGER NOT NULL,
        notes TEXT NOT NULL
      )
    ''');
  }

  /// Kayıtları SQLite ve Hive üzerinden belleğe yükler.
  Future<void> _loadAllData() async {
    bool loadedFromSqlite = false;

    if (_sqliteDb != null) {
      try {
        final dRows = await _sqliteDb!.query('diseases');
        final vRows = await _sqliteDb!.query('doctor_visits');
        final mRows = await _sqliteDb!.query('medications');

        if (dRows.isNotEmpty || vRows.isNotEmpty || mRows.isNotEmpty) {
          _diseases = dRows.map((r) => DiseaseRecord.fromMap(r)).toList();
          _visits = vRows.map((r) => DoctorVisitRecord.fromMap(r)).toList();
          _medications =
              mRows.map((r) => MedicationRecord.fromMap(r)).toList();
          loadedFromSqlite = true;
        }
      } catch (_) {
        loadedFromSqlite = false;
      }
    }

    // SQLite boşsa veya Web ortamındaysak Hive kutusundan oku
    if (!loadedFromSqlite && _hiveBox != null) {
      final rawDiseases = _hiveBox!.get('diseases_list', defaultValue: []);
      final rawVisits = _hiveBox!.get('visits_list', defaultValue: []);
      final rawMeds = _hiveBox!.get('medications_list', defaultValue: []);

      if (rawDiseases is List) {
        _diseases = rawDiseases
            .map((e) => DiseaseRecord.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (rawVisits is List) {
        _visits = rawVisits
            .map((e) => DoctorVisitRecord.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (rawMeds is List) {
        _medications = rawMeds
            .map((e) => MedicationRecord.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
    }

    // Tarihe göre sıralama
    _diseases.sort((a, b) => b.diagnosisDate.compareTo(a.diagnosisDate));
    notifyListeners();
  }

  /// Hem SQLite hem Hive hem de yerel JSON yedeğini senkronize eder.
  Future<void> _syncAllStorages() async {
    // 1. Hive kutusuna hızlı önbellek olarak yaz
    if (_hiveBox != null) {
      await _hiveBox!.put(
        'diseases_list',
        _diseases.map((e) => e.toMap()).toList(),
      );
      await _hiveBox!.put(
        'visits_list',
        _visits.map((e) => e.toMap()).toList(),
      );
      await _hiveBox!.put(
        'medications_list',
        _medications.map((e) => e.toMap()).toList(),
      );
    }

    // 2. SQLite tablolarını senkronize et
    if (_sqliteDb != null) {
      try {
        final batch = _sqliteDb!.batch();
        batch.delete('diseases');
        for (final d in _diseases) {
          batch.insert('diseases', d.toMap());
        }
        batch.delete('doctor_visits');
        for (final v in _visits) {
          batch.insert('doctor_visits', v.toMap());
        }
        batch.delete('medications');
        for (final m in _medications) {
          batch.insert('medications', m.toMap());
        }
        await batch.commit(noResult: true);
      } catch (_) {}
    }

    // 3. Yerel JSON yedeğini güncelle (Risk Yönetimi B Planı)
    await exportToLocalJsonBackup(silent: true);
    notifyListeners();
  }

  // ===========================================================================
  // HASTALIK MODÜLÜ CRUD İŞLEMLERİ
  // ===========================================================================

  /// Yeni bir hastalık kaydı ekler veya mevcut olanı günceller.
  Future<void> saveDisease(DiseaseRecord record) async {
    final idx = _diseases.indexWhere((e) => e.id == record.id);
    if (idx >= 0) {
      _diseases[idx] = record;
    } else {
      _diseases.insert(0, record);
    }
    await _syncAllStorages();
  }

  /// Belirtilen ID'ye sahip hastalık kaydını siler.
  Future<void> deleteDisease(String id) async {
    _diseases.removeWhere((e) => e.id == id);
    await _syncAllStorages();
  }

  // ===========================================================================
  // DOKTOR ZİYARETİ VE GELECEK RANDEVU MODÜLÜ CRUD İŞLEMLERİ
  // ===========================================================================

  /// Doktor ziyareti veya gelecek randevu kaydı ekler/günceller.
  Future<void> saveDoctorVisit(DoctorVisitRecord record) async {
    final idx = _visits.indexWhere((e) => e.id == record.id);
    if (idx >= 0) {
      _visits[idx] = record;
    } else {
      _visits.insert(0, record);
    }
    await _syncAllStorages();
  }

  /// Gelecek bir randevuyu "Tamamlandı (Geçmiş Muayene)" durumuna geçirir.
  Future<void> completeUpcomingVisit(String id, String finalDoctorNotes) async {
    final idx = _visits.indexWhere((e) => e.id == id);
    if (idx >= 0) {
      final current = _visits[idx];
      _visits[idx] = current.copyWith(
        isUpcoming: false,
        doctorNotes: finalDoctorNotes.isNotEmpty
            ? finalDoctorNotes
            : current.doctorNotes,
      );
      await _syncAllStorages();
    }
  }

  /// Doktor ziyareti kaydını siler.
  Future<void> deleteDoctorVisit(String id) async {
    _visits.removeWhere((e) => e.id == id);
    await _syncAllStorages();
  }

  // ===========================================================================
  // İLAÇ BİLGİLERİ VE GÜNLÜK DOZ TAKİP MODÜLÜ CRUD İŞLEMLERİ
  // ===========================================================================

  /// İlaç bilgisini kaydeder veya günceller.
  Future<void> saveMedication(MedicationRecord record) async {
    final idx = _medications.indexWhere((e) => e.id == record.id);
    if (idx >= 0) {
      _medications[idx] = record;
    } else {
      _medications.insert(0, record);
    }
    await _syncAllStorages();
  }

  /// Günlük ilaç dozunun alındığını işaretler ve kalan stok sayısını günceller.
  Future<void> toggleMedicationTakenToday(String id) async {
    final idx = _medications.indexWhere((e) => e.id == id);
    if (idx >= 0) {
      final item = _medications[idx];
      final newTaken = !item.takenToday;
      final newRemaining = newTaken
          ? (item.remainingPills > 0 ? item.remainingPills - 1 : 0)
          : item.remainingPills + 1;
      _medications[idx] = item.copyWith(
        takenToday: newTaken,
        remainingPills: newRemaining,
      );
      await _syncAllStorages();
    }
  }

  /// İlaç kaydını siler.
  Future<void> deleteMedication(String id) async {
    _medications.removeWhere((e) => e.id == id);
    await _syncAllStorages();
  }

  // ===========================================================================
  // KULLANICI AYARLARI, TEMA VE VERİ GİZLİLİĞİ (SharedPreferences & JSON)
  // ===========================================================================

  /// Karanlık / Aydınlık tema modunu değiştirir.
  Future<void> toggleDarkMode(bool value) async {
    _isDarkMode = value;
    await _prefs?.setBool('is_dark_mode', value);
    notifyListeners();
  }

  /// Kişisel sağlık profili ve güvenlik ayarlarını günceller.
  Future<void> updateProfileAndSecurity({
    required String patientName,
    required String bloodType,
    required String allergies,
    required bool isPinLockEnabled,
    required String pinCode,
  }) async {
    _patientName = patientName;
    _bloodType = bloodType;
    _allergies = allergies;
    _isPinLockEnabled = isPinLockEnabled;
    _pinCode = pinCode;

    await _prefs?.setString('patient_name', patientName);
    await _prefs?.setString('blood_type', bloodType);
    await _prefs?.setString('allergies', allergies);
    await _prefs?.setBool('is_pin_lock_enabled', isPinLockEnabled);
    await _prefs?.setString('pin_code', pinCode);
    notifyListeners();
  }

  /// Tüm veritabanını JSON metni olarak dışa aktarır ve cihaz içine yedekler.
  Future<String> exportToLocalJsonBackup({bool silent = false}) async {
    final payload = {
      'backupTimestamp': DateTime.now().toIso8601String(),
      'appVersion': '1.0.0 (YAZ305 Proje 11)',
      'patientProfile': {
        'patientName': _patientName,
        'bloodType': _bloodType,
        'allergies': _allergies,
      },
      'diseases': _diseases.map((e) => e.toMap()).toList(),
      'doctorVisits': _visits.map((e) => e.toMap()).toList(),
      'medications': _medications.map((e) => e.toMap()).toList(),
    };

    final prettyJson = const JsonEncoder.withIndent('  ').convert(payload);

    if (!kIsWeb) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final backupFile = File(p.join(dir.path, 'hastalik_takip_yedek.json'));
        await backupFile.writeAsString(prettyJson);
        final now = DateTime.now();
        _lastBackupInfo =
            '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year} '
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} '
            '(${backupFile.path})';
        await _prefs?.setString('last_backup_info', _lastBackupInfo);
      } catch (_) {}
    } else {
      final now = DateTime.now();
      _lastBackupInfo =
          '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} (Yerel Depolama)';
      await _prefs?.setString('last_backup_info', _lastBackupInfo);
    }

    if (!silent) {
      notifyListeners();
    }
    return prettyJson;
  }

  /// Uygulama ilk açıldığında veya kullanıcı istediğinde örnek verileri yükler.
  Future<void> seedInitialSampleData() async {
    final now = DateTime.now();

    _diseases = [
      DiseaseRecord(
        id: 'hst_1',
        name: 'Demir Eksikliği Anemisi',
        category: 'Kronik',
        diagnosisDate: now.subtract(const Duration(days: 45)),
        status: 'Aktif / Devam Ediyor',
        severity: 6,
        symptoms: ['Halsizlik', 'Baş dönmesi', 'Çabuk yorulma', 'Solgunluk'],
        doctorOrClinic: 'Uzm. Dr. Ahmet Yılmaz - İç Hastalıkları (Dahiliye)',
        notes:
            'Hemoglobin değeri 10.4 g/dL, Ferritin 8 ng/mL ölçüldü. 3 aylık düzenli demir takviyesi ve C vitamini ağırlıklı beslenme önerildi.',
        attachmentPath: 'assets/images/ornek_recete_ocr.png',
      ),
      DiseaseRecord(
        id: 'hst_2',
        name: 'Alerjik Rinit ve Sinüzit',
        category: 'Alerjik',
        diagnosisDate: now.subtract(const Duration(days: 90)),
        status: 'Kontrol Altında',
        severity: 4,
        symptoms: ['Burun tıkanıklığı', 'Hapşırma', 'Baş ağrısı', 'Göz yaşarması'],
        doctorOrClinic: 'Doç. Dr. Selin Kaya - KBB Polikliniği',
        notes:
            'Mevsim geçişlerinde ve polen yoğunluğunda artış gösteriyor. Antihistaminik sprey ve tuzlu su lavajı ile kontrol altında tutuluyor.',
        attachmentPath: null,
      ),
      DiseaseRecord(
        id: 'hst_3',
        name: 'Akut Üst Solunum Yolu Enfeksiyonu',
        category: 'Enfeksiyon',
        diagnosisDate: now.subtract(const Duration(days: 15)),
        status: 'İyileşti',
        severity: 7,
        symptoms: ['Boğaz ağrısı', 'Hafif ateş (37.8°C)', 'Öksürük'],
        doctorOrClinic: 'Dr. Emre Demir - Aile Hekimliği',
        notes:
            '7 günlük antibiyotik ve destek tedavisi tamamlandı. Belirtiler tamamen geçti.',
        attachmentPath: 'assets/images/ornek_prospektus_ocr.png',
      ),
    ];

    _visits = [
      DoctorVisitRecord(
        id: 'zrt_1',
        diseaseName: 'Demir Eksikliği Anemisi',
        hospitalName: 'İstanbul Gedik Üniv. Tıp Merkezi',
        department: 'İç Hastalıkları (Dahiliye)',
        doctorName: 'Uzm. Dr. Ahmet Yılmaz',
        visitDateTime: now.add(const Duration(days: 5, hours: 3)),
        isUpcoming: true,
        doctorNotes:
            '1. ay kontrol muayenesi. Sabah aç karnına hemogram ve ferritin kan tahlili verilecek.',
        prescribedTests: 'Hemogram (Tam Kan Sayımı), Serum Demir, Ferritin, B12',
        reminderEnabled: true,
      ),
      DoctorVisitRecord(
        id: 'zrt_2',
        diseaseName: 'Alerjik Rinit ve Sinüzit',
        hospitalName: 'Kartal Lütfi Kırdar Şehir Hastanesi',
        department: 'Kulak Burun Boğaz (KBB)',
        doctorName: 'Doç. Dr. Selin Kaya',
        visitDateTime: now.add(const Duration(days: 14, hours: 5)),
        isUpcoming: true,
        doctorNotes:
            'Alerji deri prick testi kontrolü ve burun mukozası muayenesi yapılacak.',
        prescribedTests: 'Solunum Paneli Alerji Testi (IgE)',
        reminderEnabled: true,
      ),
      DoctorVisitRecord(
        id: 'zrt_3',
        diseaseName: 'Demir Eksikliği Anemisi',
        hospitalName: 'İstanbul Gedik Üniv. Tıp Merkezi',
        department: 'İç Hastalıkları (Dahiliye)',
        doctorName: 'Uzm. Dr. Ahmet Yılmaz',
        visitDateTime: now.subtract(const Duration(days: 25)),
        isUpcoming: false,
        doctorNotes:
            'Hastada halsizlik ve efor kapasitesinde düşüş mevcut. Hemoglobin 10.4 g/dL saptandı. Ferrosanol Duodenal 100 mg günde 1 kapsül başlandı. Çay ve kahve tüketimi yemeklerden 2 saat sonraya çekilmeli.',
        prescribedTests: 'Tam Kan Sayımı, Biyokimya, Tiroid Fonksiyon Testi (TSH)',
        reminderEnabled: false,
        ocrRawText:
            'T.C. GEDİK ÜNİV. HASTANESİ - MUAYENE NOTU\nTanı: Kronik Demir Eksikliği Anemisi (D50.9)\nTedavi: Ferrosanol 100 mg kapsül günde 1 kez aç karnına.',
      ),
      DoctorVisitRecord(
        id: 'zrt_4',
        diseaseName: 'Akut Üst Solunum Yolu Enfeksiyonu',
        hospitalName: 'Pendik Aile Sağlığı Merkezi',
        department: 'Aile Hekimliği',
        doctorName: 'Dr. Emre Demir',
        visitDateTime: now.subtract(const Duration(days: 15)),
        isUpcoming: false,
        doctorNotes:
            'Orofarenks hiperemik, tonsillerde eksüda mevcut. Bol sıvı alımı, istirahat ve 12 saatte bir antibiyotik tedavisi düzenlendi.',
        prescribedTests: 'Boğaz Kültürü, CRP',
        reminderEnabled: false,
      ),
    ];

    _medications = [
      MedicationRecord(
        id: 'ilc_1',
        diseaseName: 'Demir Eksikliği Anemisi',
        name: 'Ferrosanol Duodenal 100 mg',
        dosage: '1 Kapsül (100 mg)',
        frequency: 'Günde 1 Kez',
        scheduleTimes: '08:00',
        usageInstruction: 'Aç Karnına',
        startDate: now.subtract(const Duration(days: 25)),
        endDate: now.add(const Duration(days: 65)),
        remainingPills: 35,
        takenToday: true,
        notes:
            'Sabah kahvaltıdan 1 saat önce bol su ile alınmalı. Süt ürünleri ve çay ile birlikte içilmemeli.',
      ),
      MedicationRecord(
        id: 'ilc_2',
        diseaseName: 'Demir Eksikliği Anemisi',
        name: 'Redoxon C Vitamini 500 mg',
        dosage: '1 Efervesan Tablet',
        frequency: 'Günde 1 Kez',
        scheduleTimes: '08:15',
        usageInstruction: 'Aç Karnına',
        startDate: now.subtract(const Duration(days: 25)),
        endDate: now.add(const Duration(days: 35)),
        remainingPills: 18,
        takenToday: true,
        notes: 'Demir emilimini artırmak için sabah demir ilacıyla yakın saatte alınır.',
      ),
      MedicationRecord(
        id: 'ilc_3',
        diseaseName: 'Alerjik Rinit ve Sinüzit',
        name: 'Avamys Nazal Burun Spreyi',
        dosage: 'Her Burun Deliğine 2 Puf',
        frequency: 'Günde 1 Kez',
        scheduleTimes: '22:30',
        usageInstruction: 'Fark Etmez',
        startDate: now.subtract(const Duration(days: 40)),
        endDate: now.add(const Duration(days: 20)),
        remainingPills: 24,
        takenToday: false,
        notes: 'Gece yatmadan önce burun temizliğinin ardından uygulanır.',
      ),
      MedicationRecord(
        id: 'ilc_4',
        diseaseName: 'Alerjik Rinit ve Sinüzit',
        name: 'Aerius 5 mg Film Tablet',
        dosage: '1 Tablet (5 mg)',
        frequency: 'Günde 1 Kez',
        scheduleTimes: '21:00',
        usageInstruction: 'Tok Karnına',
        startDate: now.subtract(const Duration(days: 10)),
        endDate: now.add(const Duration(days: 20)),
        remainingPills: 15,
        takenToday: false,
        notes: 'Polen yoğunluğunun arttığı günlerde akşam tok karnına alınır.',
      ),
    ];

    await _syncAllStorages();
  }
}
