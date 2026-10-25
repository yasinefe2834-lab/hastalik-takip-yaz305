import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/health_models.dart';
import '../services/database_service.dart';
import '../services/media_service.dart';
import '../services/pdf_report_service.dart';

/// Genel raporlama, özet bilgiler, grafiksel istatistikler, PDF sağlık raporu
/// üretimi ve Cihaz İçi Hibrit Veritabanı yönetim ekranı.
class ReportsScreen extends StatefulWidget {
  final DatabaseService db;

  const ReportsScreen({super.key, required this.db});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isGeneratingPdf = false;

  /// Doktor ziyareti öncesinde hekime hızlı bilgi aktarımı sağlayan metin özetini üretir.
  String _buildDoctorExecutiveSummary() {
    final db = widget.db;
    final activeDiseases = db.diseases
        .where((d) => !d.status.toLowerCase().contains('iyileşti'))
        .toList();
    final meds = db.medications;
    final upcoming = db.upcomingVisits;

    final sb = StringBuffer();
    sb.writeln('=== KİŞİSEL SAĞLIK VE HASTALIK TAKİP ÖZET RAPORU ===');
    sb.writeln('Hasta Adı: ${db.patientName}');
    sb.writeln('Kan Grubu: ${db.bloodType} | Bilinen Alerjiler: ${db.allergies}');
    sb.writeln('----------------------------------------------------');
    sb.writeln('1. AKTİF VE TAKİP EDİLEN HASTALIKLAR (${activeDiseases.length}):');
    for (final d in activeDiseases) {
      sb.writeln(
        ' • ${d.name} (${d.category}) - Durum: ${d.status}, Şiddet: ${d.severity}/10 | Belirtiler: ${d.symptoms.join(", ")}',
      );
    }
    sb.writeln('2. GÜNLÜK KULLANILAN İLAÇLAR (${meds.length}):');
    for (final m in meds) {
      sb.writeln(
        ' • ${m.name}: ${m.dosage}, ${m.frequency} (${m.scheduleTimes} - ${m.usageInstruction})',
      );
    }
    sb.writeln('3. PLANLANAN GELECEK DOKTOR ZİYARETLERİ (${upcoming.length}):');
    for (final v in upcoming) {
      sb.writeln(
        ' • ${v.hospitalName} (${v.department}) - ${v.doctorName} | Hazırlık: ${v.doctorNotes}',
      );
    }
    return sb.toString().trim();
  }

  /// Yerel JSON yedeğini oluşturup içeriğini diyalog penceresinde gösterir.
  Future<void> _showJsonBackupDialog() async {
    final jsonContent = await widget.db.exportToLocalJsonBackup();
    await MediaService.instance.playSuccessSound();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Cihaz İçi Yerel JSON Yedeği Oluşturuldu'),
          content: SizedBox(
            width: 520,
            height: 340,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yedek Konumu / Zamanı: ${widget.db.lastBackupInfo}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        jsonContent,
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: jsonContent));
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('JSON veritabanı yedeği panoya kopyalandı!'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Panoya Kopyala'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  /// Kişisel sağlık profili ve PIN veri gizliliği ayarlarını düzenleme penceresi.
  Future<void> _showProfileSecurityDialog() async {
    final db = widget.db;
    final nameCtrl = TextEditingController(text: db.patientName);
    final bloodCtrl = TextEditingController(text: db.bloodType);
    final allergyCtrl = TextEditingController(text: db.allergies);
    final pinCtrl = TextEditingController(text: db.pinCode);
    bool pinEnabled = db.isPinLockEnabled;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Hasta Profili & Veri Gizliliği Ayarları'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Hasta Adı Soyadı',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: bloodCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Kan Grubu',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: allergyCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Alerjiler',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Uygulama Girişinde PIN Kilidi'),
                      subtitle: const Text(
                        'Kişisel sağlık verilerinin gizliliği için PIN koruması',
                      ),
                      value: pinEnabled,
                      onChanged: (v) => setDialogState(() => pinEnabled = v),
                    ),
                    if (pinEnabled)
                      TextField(
                        controller: pinCtrl,
                        maxLength: 4,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '4 Haneli Güvenlik PIN Kodu',
                          border: OutlineInputBorder(),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('İptal'),
                ),
                FilledButton(
                  onPressed: () async {
                    await db.updateProfileAndSecurity(
                      patientName: nameCtrl.text.trim(),
                      bloodType: bloodCtrl.text.trim(),
                      allergies: allergyCtrl.text.trim(),
                      isPinLockEnabled: pinEnabled,
                      pinCode: pinCtrl.text.trim().isEmpty
                          ? '1234'
                          : pinCtrl.text.trim(),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = widget.db;
    final diseases = db.diseases;
    final meds = db.medications;
    final upcoming = db.upcomingVisits;
    final past = db.pastVisits;

    final int activeCount =
        diseases.where((d) => d.status.contains('Aktif')).length;
    final int controlledCount =
        diseases.where((d) => d.status.contains('Kontrol')).length;
    final int recoveredCount =
        diseases.where((d) => d.status.contains('İyileşti')).length;

    final int takenMeds = meds.where((m) => m.takenToday).length;
    final int adherenceRate =
        meds.isEmpty ? 100 : ((takenMeds / meds.length) * 100).round();

    final summaryText = _buildDoctorExecutiveSummary();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        // 1. Kişisel Sağlık Profili ve PDF Rapor Üretici Kartı
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
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
                      radius: 24,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      child: const Icon(Icons.analytics_outlined),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            db.patientName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Kan Grubu: ${db.bloodType} • Alerjiler: ${db.allergies}',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Profili ve Gizliliği Düzenle',
                      onPressed: _showProfileSecurityDialog,
                      icon: const Icon(Icons.manage_accounts_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isGeneratingPdf
                            ? null
                            : () async {
                                setState(() => _isGeneratingPdf = true);
                                try {
                                  await PdfReportService.instance
                                      .previewAndPrintReport(db);
                                  await MediaService.instance
                                      .playSuccessSound();
                                } finally {
                                  if (mounted) {
                                    setState(() => _isGeneratingPdf = false);
                                  }
                                }
                              },
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: Text(
                          _isGeneratingPdf
                              ? 'PDF Hazırlanıyor...'
                              : 'Hekim İçin PDF Sağlık Raporu Oluştur',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 2. Sayısal Özet Göstergeleri (4'lü İstatistik Kartları)
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.5,
          children: [
            _metricTile(
              icon: Icons.coronavirus_outlined,
              color: Colors.redAccent,
              title: 'Toplam Hastalık',
              value: '${diseases.length} Kayıt',
              subtitle: '$activeCount Aktif • $recoveredCount İyileşti',
            ),
            _metricTile(
              icon: Icons.medication_outlined,
              color: Colors.teal,
              title: 'İlaç Uyum Oranı',
              value: '%$adherenceRate',
              subtitle: 'Bugün $takenMeds/${meds.length} doz alındı',
            ),
            _metricTile(
              icon: Icons.event_available_outlined,
              color: Colors.blue,
              title: 'Gelecek Randevu',
              value: '${upcoming.length} Randevu',
              subtitle: 'Takip ve hatırlatma aktif',
            ),
            _metricTile(
              icon: Icons.assignment_turned_in_outlined,
              color: Colors.purple,
              title: 'Geçmiş Muayene',
              value: '${past.length} Ziyaret',
              subtitle: 'Hekim notları kayıtlı',
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 3. Grafiksel Gösterimler (Halka Grafiği & Hastalık Şiddet Sütun Grafiği)
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grafiksel Sağlık İstatistikleri',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Hastalık durum dağılımı ve tanı şiddet düzeylerinin karşılaştırmalı analizi',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(
                      width: 125,
                      height: 125,
                      child: CustomPaint(
                        painter: _DonutChartPainter(
                          active: activeCount,
                          controlled: controlledCount,
                          recovered: recoveredCount,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${diseases.length}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'Tanı',
                                style: TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _legendRow(
                            Colors.redAccent,
                            'Aktif / Devam Ediyor ($activeCount)',
                          ),
                          const SizedBox(height: 8),
                          _legendRow(
                            Colors.amber.shade700,
                            'Kontrol Altında ($controlledCount)',
                          ),
                          const SizedBox(height: 8),
                          _legendRow(
                            Colors.teal,
                            'İyileşti / Tamamlandı ($recoveredCount)',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                const Text(
                  'Hastalıklara Göre Şiddet Derecesi Analizi (1 - 10):',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ...diseases.map((DiseaseRecord d) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${d.name} (${d.category})',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${d.severity}/10',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: d.severity / 10.0,
                            minHeight: 8,
                            color: d.severity >= 7
                                ? Colors.redAccent
                                : (d.severity >= 5 ? Colors.orange : Colors.teal),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 4. Hekime Aktarılacak Genel Sağlık Özeti Metni
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Hekim Ziyareti İçin Genel Rapor Özeti',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      tooltip: 'Özeti Kopyala',
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: summaryText),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Genel sağlık raporu özeti panoya kopyalandı!',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_all_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    summaryText,
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 5. Cihaz İçi Hibrit Veritabanı & Veri Gizliliği Merkezi (20 Puanlık Kriter)
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
                    const Icon(Icons.storage_rounded, color: Colors.teal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cihaz Üzerinde Hibrit Yerel Veritabanı Merkezi',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Aktif Mimari: ${db.activeStorageSummary}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Son Yerel JSON Yedeği: ${db.lastBackupInfo}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _showJsonBackupDialog,
                      icon: const Icon(Icons.backup_outlined, size: 18),
                      label: const Text('Yerel JSON Yedeği Al & İncele'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await db.seedInitialSampleData();
                        await MediaService.instance.playSuccessSound();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Örnek sağlık verileri yerel veritabanına yeniden yüklendi.',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.restore, size: 18),
                      label: const Text('Örnek Verileri Yenile'),
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

  Widget _metricTile({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10.5),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendRow(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
      ],
    );
  }
}

/// Hastalık durum dağılımını çizen özel Halka Grafiği (Donut Chart) sınıfı.
class _DonutChartPainter extends CustomPainter {
  final int active;
  final int controlled;
  final int recovered;

  _DonutChartPainter({
    required this.active,
    required this.controlled,
    required this.recovered,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = active + controlled + recovered;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.butt;

    if (total == 0) {
      paint.color = Colors.grey.shade300;
      canvas.drawArc(rect.deflate(10), 0, 2 * math.pi, false, paint);
      return;
    }

    double startAngle = -math.pi / 2;
    final segments = [
      MapEntry(active, Colors.redAccent),
      MapEntry(controlled, Colors.amber.shade700),
      MapEntry(recovered, Colors.teal),
    ];

    for (final seg in segments) {
      if (seg.key <= 0) continue;
      final sweep = (seg.key / total) * 2 * math.pi;
      paint.color = seg.value;
      canvas.drawArc(rect.deflate(10), startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.active != active ||
        oldDelegate.controlled != controlled ||
        oldDelegate.recovered != recovered;
  }
}
