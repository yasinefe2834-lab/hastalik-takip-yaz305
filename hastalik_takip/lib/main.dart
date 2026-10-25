import 'package:flutter/material.dart';

import 'screens/diseases_screen.dart';
import 'screens/doctor_visits_screen.dart';
import 'screens/medications_screen.dart';
import 'screens/ocr_scanner_screen.dart';
import 'screens/reports_screen.dart';
import 'services/database_service.dart';
import 'services/media_service.dart';

/// Uygulamanın ana başlangıç noktası.
/// Cihaz üzerindeki hibrit yerel veritabanı mimarisini başlatır ve arayüzü yükler.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.initialize();
  runApp(const HastalikTakipApp());
}

/// YAZ305 Mobil Yazılım Geliştirme - Proje 11: Hastalık Takip Uygulaması.
class HastalikTakipApp extends StatefulWidget {
  const HastalikTakipApp({super.key});

  @override
  State<HastalikTakipApp> createState() => _HastalikTakipAppState();
}

class _HastalikTakipAppState extends State<HastalikTakipApp> {
  final DatabaseService _db = DatabaseService.instance;

  @override
  void initState() {
    super.initState();
    _db.addListener(_onDatabaseChanged);
  }

  @override
  void dispose() {
    _db.removeListener(_onDatabaseChanged);
    super.dispose();
  }

  void _onDatabaseChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorSeed = const Color(0xFF0D9488); // Medikal Turkuaz / Zümrüt Yeşili

    return MaterialApp(
      title: 'Hastalık Takip - YAZ305 Proje 11',
      debugShowCheckedModeBanner: false,
      themeMode: _db.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: colorSeed,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: colorSeed,
          brightness: Brightness.dark,
        ),
      ),
      home: MainShellScreen(db: _db),
    );
  }
}

/// Alt navigasyon çubuğu, sayfa geçiş animasyonları ve PIN gizlilik kilidini
/// barındıran ana çerçeve ekranı.
class MainShellScreen extends StatefulWidget {
  final DatabaseService db;

  const MainShellScreen({super.key, required this.db});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;
  bool _isUnlocked = false;
  final TextEditingController _pinInputCtrl = TextEditingController();
  String? _pinError;

  static const List<String> _pageTitles = [
    'Hastalık Takip & Kayıtlar',
    'Doktor Ziyaretleri & Randevular',
    'İlaç Bilgileri & Doz Takibi',
    'OCR Belge Tarayıcı & Medya',
    'Genel Raporlama & Veritabanı',
  ];

  @override
  void dispose() {
    _pinInputCtrl.dispose();
    super.dispose();
  }

  /// Sunum sırasında proje özelliklerini ve değerlendirme kriterlerini özetleyen bilgi penceresi.
  void _showProjectAboutDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.verified_outlined, color: Colors.teal),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'YAZ305 Proje 11: Hastalık Takip',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Hazırlayanlar: Kayra Oruçoğlu, Yasin Efe Güvenç\n'
                  'Danışman: Şerife Esra Dinçer\n'
                  'Kurum: T.C. İstanbul Gedik Üniversitesi',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                ),
                Divider(height: 20),
                Text(
                  'Uygulanan Sınav Değerlendirme Kriterleri:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                SizedBox(height: 6),
                Text(
                  '• Derste İşlenmeyen Özellik (20p): Kamera & Optik Karakter Tanıma (OCR) ile reçete/prospektüs tarama + Hekim için PDF Genel Sağlık Raporu üretimi.\n'
                  '• Cihaz Üzerinde Veritabanı (20p): Hibrit yerel mimari (SQLite + Hive + SharedPreferences + Yerel JSON Yedekleme).\n'
                  '• Ses, Görüntü ve Video (10p): Düşük boyutlu WAV sesli bildirimler, PNG tıbbi kartlar ve MP4 tanıtım/rehber videosu.\n'
                  '• Sayfalar Arası Uyumlu Geçişler (10p): AnimatedSwitcher, PageRouteBuilder (Slide + Fade) ve alt sekme geçişleri.\n'
                  '• Proje 11 Modülleri (10p): Hastalık girişi, Doktor ziyaret notları, İlaç bilgileri, Gelecek doktor ziyaretlerinin takibi ve Genel raporlama.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tamam'),
            ),
          ],
        );
      },
    );
  }

  /// PIN kilidi aktifse kullanıcı doğrulama ekranını oluşturur.
  Widget _buildPinLockScreen() {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Card(
            margin: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    child: Icon(Icons.lock_person_outlined, size: 32),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Kişisel Sağlık Veri Gizliliği Kilidi',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Cihaz içi sağlık verilerinize erişmek için 4 haneli güvenlik PIN kodunuzu giriniz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pinInputCtrl,
                    obscureText: true,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'PIN Kodu (Varsayılan: ${widget.db.pinCode})',
                      errorText: _pinError,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        if (_pinInputCtrl.text.trim() == widget.db.pinCode) {
                          MediaService.instance.playSuccessSound();
                          setState(() {
                            _isUnlocked = true;
                            _pinError = null;
                          });
                        } else {
                          setState(() => _pinError = 'Hatalı PIN kodu girdiniz');
                        }
                      },
                      icon: const Icon(Icons.lock_open),
                      label: const Text('Kilidi Aç'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.db.isPinLockEnabled && !_isUnlocked) {
      return _buildPinLockScreen();
    }

    final pages = <Widget>[
      DiseasesScreen(
        key: const ValueKey('page_diseases'),
        db: widget.db,
        onOpenOcrRequested: () => setState(() => _selectedIndex = 3),
      ),
      DoctorVisitsScreen(
        key: const ValueKey('page_visits'),
        db: widget.db,
        onOpenOcrRequested: () => setState(() => _selectedIndex = 3),
      ),
      MedicationsScreen(
        key: const ValueKey('page_meds'),
        db: widget.db,
        onOpenOcrRequested: () => setState(() => _selectedIndex = 3),
      ),
      OcrScannerScreen(
        key: const ValueKey('page_ocr'),
        db: widget.db,
      ),
      ReportsScreen(
        key: const ValueKey('page_reports'),
        db: widget.db,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Icon(Icons.health_and_safety, color: Colors.teal, size: 28),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _pageTitles[_selectedIndex],
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Cihaz İçi Güvenli Veritabanı • ${widget.db.diseases.length} Hastalık, ${widget.db.medications.length} İlaç',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip:
                MediaService.instance.soundEnabled ? 'Sesi Kapat' : 'Sesi Aç',
            onPressed: () {
              setState(() {
                MediaService.instance
                    .toggleSound(!MediaService.instance.soundEnabled);
              });
            },
            icon: Icon(
              MediaService.instance.soundEnabled
                  ? Icons.volume_up_outlined
                  : Icons.volume_off_outlined,
            ),
          ),
          IconButton(
            tooltip: widget.db.isDarkMode ? 'Aydınlık Mod' : 'Karanlık Mod',
            onPressed: () =>
                widget.db.toggleDarkMode(!widget.db.isDarkMode),
            icon: Icon(
              widget.db.isDarkMode
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Proje Bilgisi ve Kriterler',
            onPressed: _showProjectAboutDialog,
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: pages[_selectedIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) {
          setState(() => _selectedIndex = idx);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.coronavirus_outlined),
            selectedIcon: Icon(Icons.coronavirus),
            label: 'Hastalıklar',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: widget.db.upcomingVisits.isNotEmpty,
              label: Text('${widget.db.upcomingVisits.length}'),
              child: const Icon(Icons.calendar_month_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: widget.db.upcomingVisits.isNotEmpty,
              label: Text('${widget.db.upcomingVisits.length}'),
              child: const Icon(Icons.calendar_month),
            ),
            label: 'Ziyaretler',
          ),
          const NavigationDestination(
            icon: Icon(Icons.medication_outlined),
            selectedIcon: Icon(Icons.medication),
            label: 'İlaçlar',
          ),
          const NavigationDestination(
            icon: Icon(Icons.document_scanner_outlined),
            selectedIcon: Icon(Icons.document_scanner),
            label: 'OCR & Medya',
          ),
          const NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Raporlama',
          ),
        ],
      ),
    );
  }
}
