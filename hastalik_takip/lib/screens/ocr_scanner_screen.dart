import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/health_models.dart';
import '../services/database_service.dart';
import '../services/media_service.dart';
import '../services/ocr_service.dart';

/// Derste işlenmeyen yenilikçi özellik olan Optik Karakter Tanıma (OCR) ile
/// reçete/muayene notu tarama ve düşük boyutlu Ses/Görüntü/Video medya ekranı.
class OcrScannerScreen extends StatefulWidget {
  final DatabaseService db;

  const OcrScannerScreen({super.key, required this.db});

  @override
  State<OcrScannerScreen> createState() => _OcrScannerScreenState();
}

class _OcrScannerScreenState extends State<OcrScannerScreen> {
  bool _isScanning = false;
  ParsedMedicalDocument? _scanResult;

  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _videoError = false;
  int _activeGuideSlide = 0;

  @override
  void initState() {
    super.initState();
    _initVideoPlayer();
    // İlk açılışta örnek reçete taramasını hazır göster
    _runPresetScan('recete');
  }

  /// Düşük çözünürlüklü ve düşük boyutlu yerel MP4 videosunu başlatır.
  Future<void> _initVideoPlayer() async {
    try {
      final ctrl =
          VideoPlayerController.asset('assets/videos/saglik_tanitim.mp4');
      _videoController = ctrl;
      await ctrl.initialize();
      ctrl.setLooping(true);
      if (mounted) {
        setState(() => _videoReady = true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _videoError = true);
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  /// Kamera veya galeriden gerçek fotoğraf seçip OCR taraması başlatır.
  Future<void> _runCameraOrGalleryScan({required bool fromCamera}) async {
    setState(() => _isScanning = true);
    final res = await OcrService.instance.scanFromCameraOrGallery(
      fromCamera: fromCamera,
    );
    if (!mounted) return;
    setState(() {
      _isScanning = false;
      if (res != null) {
        _scanResult = res;
      }
    });
    if (res != null) {
      await MediaService.instance.playSuccessSound();
    }
  }

  /// Uygulama içi düşük boyutlu örnek reçete veya ilaç prospektüsü üzerinde OCR çalıştırır.
  Future<void> _runPresetScan(String key) async {
    setState(() => _isScanning = true);
    final res = await OcrService.instance.scanPresetTemplate(key);
    if (!mounted) return;
    setState(() {
      _isScanning = false;
      _scanResult = res;
    });
  }

  /// OCR sonucundan otomatik olarak yeni bir Hastalık kaydı oluşturur.
  Future<void> _addDetectedDisease(ParsedMedicalDocument doc) async {
    final record = DiseaseRecord(
      id: 'hst_ocr_${DateTime.now().millisecondsSinceEpoch}',
      name: doc.detectedDisease,
      category: 'Kronik',
      diagnosisDate: DateTime.now(),
      status: 'Aktif / Devam Ediyor',
      severity: 6,
      symptoms: const ['OCR Belge Taraması', 'Klinik Muayene Bulgusu'],
      doctorOrClinic: '${doc.detectedDoctor} - ${doc.detectedDepartment}',
      notes: doc.summaryNotes,
      attachmentPath: doc.imageAssetOrPath.startsWith('assets/')
          ? doc.imageAssetOrPath
          : 'assets/images/ornek_recete_ocr.png',
    );
    await widget.db.saveDisease(record);
    await MediaService.instance.playSuccessSound();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${doc.detectedDisease}" hastalık kayıtlarına eklendi!',
          ),
        ),
      );
    }
  }

  /// OCR sonucundan otomatik olarak Doktor Ziyaret Notu oluşturur.
  Future<void> _addDetectedVisit(ParsedMedicalDocument doc) async {
    final record = DoctorVisitRecord(
      id: 'zrt_ocr_${DateTime.now().millisecondsSinceEpoch}',
      diseaseName: doc.detectedDisease,
      hospitalName: doc.detectedHospital,
      department: doc.detectedDepartment,
      doctorName: doc.detectedDoctor,
      visitDateTime: DateTime.now(),
      isUpcoming: false,
      doctorNotes: doc.summaryNotes,
      prescribedTests: 'OCR ile taranan muayene belgesi',
      reminderEnabled: false,
      ocrRawText: doc.rawText,
    );
    await widget.db.saveDoctorVisit(record);
    await MediaService.instance.playSuccessSound();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${doc.detectedDoctor} muayene notu ziyaret geçmişine kaydedildi!',
          ),
        ),
      );
    }
  }

  /// OCR sonucundan otomatik olarak İlaç Bilgisi kaydı oluşturur.
  Future<void> _addDetectedMedication(ParsedMedicalDocument doc) async {
    final record = MedicationRecord(
      id: 'ilc_ocr_${DateTime.now().millisecondsSinceEpoch}',
      diseaseName: doc.detectedDisease,
      name: doc.detectedMedicationName,
      dosage: doc.detectedDosage,
      frequency: doc.detectedFrequency,
      scheduleTimes: doc.detectedSchedule,
      usageInstruction: doc.detectedUsage,
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 30)),
      remainingPills: 28,
      takenToday: false,
      notes: doc.summaryNotes,
    );
    await widget.db.saveMedication(record);
    await MediaService.instance.playMedicationSound();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${doc.detectedMedicationName}" ilaç listesine eklendi!',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = _scanResult;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        // 1. BÖLÜM: OPTİK KARAKTER TANIMA (OCR) AKILLI REÇETE & PROSPEKTÜS TARAYICI
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.document_scanner,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kamera & OCR Tıbbi Belge Tarayıcı',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Derste İşlenmeyen AR-GE Özelliği: Doktor muayene notlarını ve ilaç prospektüslerini tarayıp dijital kayda çevirir.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isScanning
                            ? null
                            : () => _runCameraOrGalleryScan(fromCamera: true),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Kameradan Çek'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isScanning
                            ? null
                            : () => _runCameraOrGalleryScan(fromCamera: false),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Galeriden Seç'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Hızlı Test İçin Örnek Tıbbi Belgeleri Okutun:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.receipt_long, size: 16),
                      label: const Text('Dahiliye Muayene Notu'),
                      onPressed: () => _runPresetScan('recete'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.medication, size: 16),
                      label: const Text('Augmentin İlaç Prospektüsü'),
                      onPressed: () => _runPresetScan('prospektus'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.psychology, size: 16),
                      label: const Text('Nöroloji Migren Raporu'),
                      onPressed: () => _runPresetScan('migren_rapor'),
                    ),
                  ],
                ),
                if (_isScanning) ...[
                  const SizedBox(height: 16),
                  const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text(
                          'Optik Karakter Tanıma (OCR) metni ayrıştırıyor...',
                        ),
                      ],
                    ),
                  ),
                ] else if (doc != null) ...[
                  const Divider(height: 24),
                  if (doc.imageAssetOrPath.startsWith('assets/'))
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        doc.imageAssetOrPath,
                        height: 170,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .secondaryContainer
                          .withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Otomatik Ayrıştırılan Yapısal Sağlık Verisi (${doc.documentType})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('• Tespit Edilen Hastalık/Tanı: ${doc.detectedDisease}'),
                        Text(
                          '• Hekim & Poliklinik: ${doc.detectedDoctor} (${doc.detectedDepartment})',
                        ),
                        Text(
                          '• Tespit Edilen İlaç: ${doc.detectedMedicationName} (${doc.detectedDosage})',
                        ),
                        Text(
                          '• Doz Planı: ${doc.detectedFrequency} | Saat: ${doc.detectedSchedule} (${doc.detectedUsage})',
                        ),
                        Text('• Özet Not: ${doc.summaryNotes}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Taranan Veriyi Tek Tuşla Veritabanına Aktar:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => _addDetectedDisease(doc),
                        icon: const Icon(Icons.add_moderator, size: 18),
                        label: const Text('Hastalıklara Kaydet'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _addDetectedVisit(doc),
                        icon: const Icon(Icons.note_add_outlined, size: 18),
                        label: const Text('Ziyaret Notuna Kaydet'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _addDetectedMedication(doc),
                        icon: const Icon(Icons.medication_liquid, size: 18),
                        label: const Text('İlaç Listesine Kaydet'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2. BÖLÜM: SES, GÖRÜNTÜ VE VİDEO KULLANIMI (10 PUANLIK MEDYA KRİTERİ)
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.teal.withValues(alpha: 0.15),
                      child: const Icon(
                        Icons.perm_media_outlined,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sesli, Görselli ve Videolu Sağlık Rehberi',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Performans için düşük çözünürlüklü ve düşük boyutlu medya dosyaları kullanılmıştır.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Video Oynatıcı Bölümü
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    color: Colors.black87,
                    child: Column(
                      children: [
                        if (_videoReady &&
                            _videoController != null &&
                            !_videoError)
                          AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          )
                        else
                          // Video codec bulunmayan masaüstü ortamları için etkileşimli görsel sunum
                          Image.asset(
                            'assets/images/saglik_rehberi_${_activeGuideSlide + 1}.png',
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.contain,
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Tanıtım & Sağlık Rehberi Videosu (MP4)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    color: Colors.white,
                                    tooltip: 'Oynat / Duraklat',
                                    onPressed: () {
                                      if (_videoReady &&
                                          _videoController != null) {
                                        setState(() {
                                          if (_videoController!
                                              .value.isPlaying) {
                                            _videoController!.pause();
                                          } else {
                                            _videoController!.play();
                                          }
                                        });
                                      } else {
                                        setState(() {
                                          _activeGuideSlide =
                                              (_activeGuideSlide + 1) % 3;
                                        });
                                        MediaService.instance
                                            .playSuccessSound();
                                      }
                                    },
                                    icon: Icon(
                                      (_videoReady &&
                                              _videoController != null &&
                                              _videoController!.value.isPlaying)
                                          ? Icons.pause_circle_filled
                                          : Icons.play_circle_fill,
                                    ),
                                  ),
                                  IconButton(
                                    color: Colors.white,
                                    tooltip: 'Başa Sar / Sonraki Kart',
                                    onPressed: () {
                                      if (_videoReady &&
                                          _videoController != null) {
                                        _videoController!
                                            .seekTo(Duration.zero);
                                      }
                                      setState(() {
                                        _activeGuideSlide =
                                            (_activeGuideSlide + 1) % 3;
                                      });
                                    },
                                    icon: const Icon(Icons.skip_next),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Düşük Boyutlu Bilgilendirici Görsel Kartlar
                const Text(
                  'Düşük Boyutlu (<10 KB) Görsel Sağlık Rehberi Kartları:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 155,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _guideImageCard('assets/images/saglik_rehberi_1.png'),
                      const SizedBox(width: 10),
                      _guideImageCard('assets/images/saglik_rehberi_2.png'),
                      const SizedBox(width: 10),
                      _guideImageCard('assets/images/saglik_rehberi_3.png'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Sesli Yönlendirme ve Bildirim Butonları
                const Text(
                  'Sesli Yönlendirme ve Hatırlatma Sesleri (WAV Medya):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          MediaService.instance.playMedicationSound(),
                      icon: const Icon(Icons.volume_up, size: 18),
                      label: const Text('İlaç Saati Sesi'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          MediaService.instance.playAppointmentSound(),
                      icon: const Icon(Icons.notifications_active, size: 18),
                      label: const Text('Randevu Hatırlatma Sesi'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          MediaService.instance.playSuccessSound(),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Onay Bildirim Sesi'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _guideImageCard(String assetPath) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        assetPath,
        width: 280,
        height: 155,
        fit: BoxFit.cover,
      ),
    );
  }
}
