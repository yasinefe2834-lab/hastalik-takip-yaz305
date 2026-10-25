import 'package:flutter/material.dart';

import '../models/health_models.dart';
import '../services/database_service.dart';
import '../services/media_service.dart';

/// İlaç bilgilerini, günlük doz saatlerini ve stok durumunu takip eden ekran.
class MedicationsScreen extends StatefulWidget {
  final DatabaseService db;
  final VoidCallback onOpenOcrRequested;

  const MedicationsScreen({
    super.key,
    required this.db,
    required this.onOpenOcrRequested,
  });

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  Future<void> _openMedicationForm({MedicationRecord? existing}) async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            MedicationFormPage(db: widget.db, existingRecord: existing),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meds = widget.db.medications;
    final takenCount = meds.where((m) => m.takenToday).length;
    final progress = meds.isEmpty ? 0.0 : takenCount / meds.length;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          // Üst Günlük İlaç Uyum ve Sesli Hatırlatıcı Kartı
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
                        backgroundColor:
                            Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        child: const Icon(Icons.medication_liquid),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Günlük İlaç ve Doz Takibi',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Bugün ${meds.length} ilaçtan $takenCount tanesi alındı (%${(progress * 100).round()})',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Sesli İlaç Hatırlatma Sesi Çal',
                        onPressed: () async {
                          await MediaService.instance.playMedicationSound();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Sesli İlaç Hatırlatıcı Sesi Çalındı (ilac_bildirim.wav)',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.notifications_active),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 9,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: widget.onOpenOcrRequested,
                        icon: const Icon(Icons.document_scanner, size: 18),
                        label: const Text('OCR ile Prospektüs Tara'),
                      ),
                      Text(
                        takenCount == meds.length && meds.isNotEmpty
                            ? 'Tüm günlük dozlar tamamlandı!'
                            : 'Bekleyen dozlarınızı işaretleyin',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (meds.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    const Icon(Icons.medication_outlined, size: 60),
                    const SizedBox(height: 10),
                    const Text('Henüz kayıtlı ilaç bulunmuyor.'),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: () => _openMedicationForm(),
                      icon: const Icon(Icons.add),
                      label: const Text('İlk İlacı Ekle'),
                    ),
                  ],
                ),
              ),
            )
          else
            ...meds.map((m) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            m.takenToday
                                ? Icons.check_circle
                                : Icons.access_time_filled,
                            color:
                                m.takenToday ? Colors.teal : Colors.orange,
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'İlişkili Hastalık: ${m.diseaseName}',
                                  style:
                                      Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () async {
                              await widget.db.toggleMedicationTakenToday(m.id);
                              await MediaService.instance
                                  .playMedicationSound();
                            },
                            icon: Icon(
                              m.takenToday
                                  ? Icons.done_all
                                  : Icons.check_box_outline_blank,
                              size: 18,
                            ),
                            label: Text(
                              m.takenToday ? 'Alındı' : 'Dozu Al',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Chip(
                            avatar: const Icon(Icons.science, size: 15),
                            label: Text('${m.dosage} • ${m.frequency}'),
                            visualDensity: VisualDensity.compact,
                          ),
                          Chip(
                            avatar: const Icon(Icons.alarm, size: 15),
                            label: Text('Saat: ${m.scheduleTimes}'),
                            visualDensity: VisualDensity.compact,
                          ),
                          Chip(
                            avatar: const Icon(Icons.restaurant, size: 15),
                            label: Text(m.usageInstruction),
                            visualDensity: VisualDensity.compact,
                          ),
                          Chip(
                            avatar: Icon(
                              Icons.inventory_2_outlined,
                              size: 15,
                              color: m.remainingPills <= 5
                                  ? Colors.red
                                  : null,
                            ),
                            label: Text('Kalan Stok: ${m.remainingPills}'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      if (m.notes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Kullanım Notu: ${m.notes}',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () =>
                                _openMedicationForm(existing: m),
                            icon: const Icon(Icons.edit_outlined, size: 17),
                            label: const Text('Düzenle'),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                            ),
                            onPressed: () =>
                                widget.db.deleteMedication(m.id),
                            icon: const Icon(Icons.delete_outline, size: 17),
                            label: const Text('Sil'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openMedicationForm(),
        icon: const Icon(Icons.add),
        label: const Text('İlaç Ekle'),
      ),
    );
  }
}

/// İlaç bilgisi ekleme ve düzenleme ekranı.
class MedicationFormPage extends StatefulWidget {
  final DatabaseService db;
  final MedicationRecord? existingRecord;

  const MedicationFormPage({
    super.key,
    required this.db,
    this.existingRecord,
  });

  @override
  State<MedicationFormPage> createState() => _MedicationFormPageState();
}

class _MedicationFormPageState extends State<MedicationFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _diseaseCtrl;
  late final TextEditingController _dosageCtrl;
  late final TextEditingController _scheduleCtrl;
  late final TextEditingController _remainingCtrl;
  late final TextEditingController _notesCtrl;

  String _frequency = 'Günde 1 Kez';
  String _usageInstruction = 'Tok Karnına';

  static const List<String> _frequencies = [
    'Günde 1 Kez',
    'Günde 2 Kez (12 Saatte Bir)',
    'Günde 3 Kez (8 Saatte Bir)',
    'Haftada 1 Kez',
    'İhtiyaç Halinde',
  ];

  static const List<String> _instructions = [
    'Aç Karnına',
    'Tok Karnına',
    'Yemekle Birlikte',
    'Gece Yatmadan Önce',
    'Fark Etmez',
  ];

  @override
  void initState() {
    super.initState();
    final ex = widget.existingRecord;
    final defaultDisease = widget.db.diseases.isNotEmpty
        ? widget.db.diseases.first.name
        : 'Genel Tedavi';

    _nameCtrl = TextEditingController(text: ex?.name ?? '');
    _diseaseCtrl =
        TextEditingController(text: ex?.diseaseName ?? defaultDisease);
    _dosageCtrl =
        TextEditingController(text: ex?.dosage ?? '1 Tablet');
    _scheduleCtrl =
        TextEditingController(text: ex?.scheduleTimes ?? '09:00');
    _remainingCtrl = TextEditingController(
      text: (ex?.remainingPills ?? 20).toString(),
    );
    _notesCtrl = TextEditingController(text: ex?.notes ?? '');

    if (ex != null) {
      if (_frequencies.contains(ex.frequency)) _frequency = ex.frequency;
      if (_instructions.contains(ex.usageInstruction)) {
        _usageInstruction = ex.usageInstruction;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _diseaseCtrl.dispose();
    _dosageCtrl.dispose();
    _scheduleCtrl.dispose();
    _remainingCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final record = MedicationRecord(
      id: widget.existingRecord?.id ??
          'ilc_${DateTime.now().millisecondsSinceEpoch}',
      diseaseName: _diseaseCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      dosage: _dosageCtrl.text.trim(),
      frequency: _frequency,
      scheduleTimes: _scheduleCtrl.text.trim(),
      usageInstruction: _usageInstruction,
      startDate: widget.existingRecord?.startDate ?? DateTime.now(),
      endDate: widget.existingRecord?.endDate ??
          DateTime.now().add(const Duration(days: 30)),
      remainingPills: int.tryParse(_remainingCtrl.text.trim()) ?? 20,
      takenToday: widget.existingRecord?.takenToday ?? false,
      notes: _notesCtrl.text.trim(),
    );

    await widget.db.saveMedication(record);
    await MediaService.instance.playSuccessSound();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingRecord != null
              ? 'İlaç Bilgisini Düzenle'
              : 'Yeni İlaç Bilgisi Ekle',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'İlaç Adı ve Miligramı *',
                hintText: 'Örn: Ferrosanol Duodenal 100 mg',
                prefixIcon: Icon(Icons.medication_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'İlaç adı zorunludur' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _diseaseCtrl,
              decoration: const InputDecoration(
                labelText: 'İlişkili Hastalık *',
                prefixIcon: Icon(Icons.medical_information_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Zorunlu alan' : null,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _dosageCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tek Seferlik Doz *',
                      hintText: 'Örn: 1 Tablet',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _scheduleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Saat Bilgisi *',
                      hintText: 'Örn: 08:30 - 20:30',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: const InputDecoration(
                labelText: 'Kullanım Sıklığı',
                border: OutlineInputBorder(),
              ),
              items: _frequencies
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _frequency = v);
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _usageInstruction,
                    decoration: const InputDecoration(
                      labelText: 'Kullanım Şekli',
                      border: OutlineInputBorder(),
                    ),
                    items: _instructions
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _usageInstruction = v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _remainingCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Kalan Tablet Sayısı',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Prospektüs / Doktor Kullanım Notları',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('İlaç Bilgisini Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
