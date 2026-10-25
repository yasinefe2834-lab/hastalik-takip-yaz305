import 'package:flutter/material.dart';

import '../models/health_models.dart';
import '../services/database_service.dart';
import '../services/media_service.dart';

/// Doktor ziyaret notlarını ve gelecek doktor randevularının takibini yöneten ekran.
class DoctorVisitsScreen extends StatefulWidget {
  final DatabaseService db;
  final VoidCallback onOpenOcrRequested;

  const DoctorVisitsScreen({
    super.key,
    required this.db,
    required this.onOpenOcrRequested,
  });

  @override
  State<DoctorVisitsScreen> createState() => _DoctorVisitsScreenState();
}

class _DoctorVisitsScreenState extends State<DoctorVisitsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Tarih ve saat bilgisini GG.AA.YYYY SS:DD formatında döndürür.
  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.$y • $hh:$mm';
  }

  /// Gelecek randevuya kalan gün sayısını hesaplayıp açıklayıcı metin döndürür.
  String _remainingDaysText(DateTime dt) {
    final diff = dt.difference(DateTime.now());
    if (diff.isNegative) return 'Randevu Zamanı Geldi';
    if (diff.inDays == 0) return 'Bugün (${diff.inHours} saat kaldı)';
    return '${diff.inDays} Gün Kaldı';
  }

  /// Animasyonlu sayfa geçişi ile yeni doktor ziyareti / randevu formunu açar.
  Future<void> _openVisitForm({
    DoctorVisitRecord? existing,
    bool defaultUpcoming = true,
  }) async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            DoctorVisitFormPage(
          db: widget.db,
          existingRecord: existing,
          defaultUpcoming: defaultUpcoming,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.1, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
      ),
    );
  }

  /// Gelecek randevuyu tamamlayıp doktor muayene notu girilmesini sağlayan diyalog.
  Future<void> _showCompleteVisitDialog(DoctorVisitRecord visit) async {
    final notesCtrl = TextEditingController(text: visit.doctorNotes);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Randevuyu Tamamla & Muayene Notu Kaydet'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${visit.hospitalName} - ${visit.doctorName}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Doktor Muayene Notları ve Bulgular',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await widget.db.completeUpcomingVisit(
                  visit.id,
                  notesCtrl.text.trim(),
                );
                await MediaService.instance.playSuccessSound();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Geçmiş Muayenelere Aktar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = widget.db.upcomingVisits;
    final past = widget.db.pastVisits;

    return Scaffold(
      body: Column(
        children: [
          // Sekme Başlığı (Gelecek Randevular & Geçmiş Muayene Notları)
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  icon: const Icon(Icons.event_available_outlined),
                  text: 'Gelecek Randevular (${upcoming.length})',
                ),
                Tab(
                  icon: const Icon(Icons.assignment_turned_in_outlined),
                  text: 'Muayene Notları (${past.length})',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Sekme: Gelecek Doktor Ziyaretlerinin Takibi
                _buildVisitList(
                  records: upcoming,
                  isUpcomingTab: true,
                ),
                // 2. Sekme: Geçmiş Doktor Ziyaret Notları
                _buildVisitList(
                  records: past,
                  isUpcomingTab: false,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openVisitForm(
          defaultUpcoming: _tabController.index == 0,
        ),
        icon: const Icon(Icons.add_alarm),
        label: const Text('Ziyaret / Randevu Ekle'),
      ),
    );
  }

  Widget _buildVisitList({
    required List<DoctorVisitRecord> records,
    required bool isUpcomingTab,
  }) {
    if (records.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isUpcomingTab
                    ? Icons.calendar_month_outlined
                    : Icons.folder_shared_outlined,
                size: 60,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                isUpcomingTab
                    ? 'Planlanmış gelecek doktor randevusu bulunmuyor.'
                    : 'Henüz kayıtlı geçmiş doktor muayene notu yok.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () =>
                        _openVisitForm(defaultUpcoming: isUpcomingTab),
                    icon: const Icon(Icons.add),
                    label: Text(
                      isUpcomingTab ? 'Randevu Planla' : 'Muayene Notu Ekle',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onOpenOcrRequested,
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: const Text('OCR ile Muayene Kağıdı Tara'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final v = records[index];
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: isUpcomingTab
                          ? Colors.blue.withValues(alpha: 0.15)
                          : Colors.teal.withValues(alpha: 0.15),
                      child: Icon(
                        isUpcomingTab
                            ? Icons.notifications_active_outlined
                            : Icons.medical_information_outlined,
                        color: isUpcomingTab ? Colors.blue : Colors.teal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${v.hospitalName} • ${v.department}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${v.doctorName} (${v.diseaseName})',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.schedule, size: 15),
                              const SizedBox(width: 4),
                              Text(
                                _formatDateTime(v.visitDateTime),
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
                    if (isUpcomingTab)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _remainingDaysText(v.visitDateTime),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                  ],
                ),
                const Divider(height: 20),
                Text(
                  isUpcomingTab
                      ? 'Randevu Hazırlık Notu:'
                      : 'Doktor Muayene Bulguları ve Notları:',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(v.doctorNotes),
                if (v.prescribedTests.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'İstenen Tetkikler / Tahliller: ${v.prescribedTests}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
                if (v.ocrRawText != null && v.ocrRawText!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    leading: const Icon(Icons.document_scanner, size: 18),
                    title: const Text(
                      'OCR ile Taranan Belge Metnini Gör',
                      style: TextStyle(fontSize: 12),
                    ),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        color: Colors.black12,
                        child: Text(
                          v.ocrRawText!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  children: [
                    if (isUpcomingTab) ...[
                      OutlinedButton.icon(
                        onPressed: () async {
                          await MediaService.instance.playAppointmentSound();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Sesli Randevu Hatırlatması: ${v.doctorName} (${_formatDateTime(v.visitDateTime)})',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.volume_up_outlined, size: 17),
                        label: const Text('Sesli Uyarı Testi'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _showCompleteVisitDialog(v),
                        icon: const Icon(Icons.check, size: 17),
                        label: const Text('Muayene Tamamlandı'),
                      ),
                    ],
                    IconButton(
                      tooltip: 'Düzenle',
                      onPressed: () => _openVisitForm(existing: v),
                      icon: const Icon(Icons.edit_outlined, size: 20),
                    ),
                    IconButton(
                      tooltip: 'Sil',
                      onPressed: () => widget.db.deleteDoctorVisit(v.id),
                      icon: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.red.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Doktor ziyareti veya gelecek randevu ekleme/düzenleme sayfası.
class DoctorVisitFormPage extends StatefulWidget {
  final DatabaseService db;
  final DoctorVisitRecord? existingRecord;
  final bool defaultUpcoming;

  const DoctorVisitFormPage({
    super.key,
    required this.db,
    this.existingRecord,
    required this.defaultUpcoming,
  });

  @override
  State<DoctorVisitFormPage> createState() => _DoctorVisitFormPageState();
}

class _DoctorVisitFormPageState extends State<DoctorVisitFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _diseaseCtrl;
  late final TextEditingController _hospitalCtrl;
  late final TextEditingController _deptCtrl;
  late final TextEditingController _doctorCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _testsCtrl;

  late bool _isUpcoming;
  bool _reminderEnabled = true;
  DateTime _visitDateTime = DateTime.now().add(const Duration(days: 3));

  @override
  void initState() {
    super.initState();
    final ex = widget.existingRecord;
    _isUpcoming = ex?.isUpcoming ?? widget.defaultUpcoming;
    _reminderEnabled = ex?.reminderEnabled ?? true;
    _visitDateTime = ex?.visitDateTime ??
        (_isUpcoming
            ? DateTime.now().add(const Duration(days: 3))
            : DateTime.now());

    final firstDisease = widget.db.diseases.isNotEmpty
        ? widget.db.diseases.first.name
        : 'Genel Kontrol';

    _diseaseCtrl =
        TextEditingController(text: ex?.diseaseName ?? firstDisease);
    _hospitalCtrl = TextEditingController(
      text: ex?.hospitalName ?? 'İstanbul Gedik Üniv. Tıp Merkezi',
    );
    _deptCtrl = TextEditingController(
      text: ex?.department ?? 'İç Hastalıkları (Dahiliye)',
    );
    _doctorCtrl = TextEditingController(text: ex?.doctorName ?? '');
    _notesCtrl = TextEditingController(text: ex?.doctorNotes ?? '');
    _testsCtrl = TextEditingController(text: ex?.prescribedTests ?? '');
  }

  @override
  void dispose() {
    _diseaseCtrl.dispose();
    _hospitalCtrl.dispose();
    _deptCtrl.dispose();
    _doctorCtrl.dispose();
    _notesCtrl.dispose();
    _testsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _visitDateTime,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_visitDateTime),
    );
    if (time == null) return;

    setState(() {
      _visitDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final record = DoctorVisitRecord(
      id: widget.existingRecord?.id ??
          'zrt_${DateTime.now().millisecondsSinceEpoch}',
      diseaseName: _diseaseCtrl.text.trim(),
      hospitalName: _hospitalCtrl.text.trim(),
      department: _deptCtrl.text.trim(),
      doctorName: _doctorCtrl.text.trim(),
      visitDateTime: _visitDateTime,
      isUpcoming: _isUpcoming,
      doctorNotes: _notesCtrl.text.trim(),
      prescribedTests: _testsCtrl.text.trim(),
      reminderEnabled: _reminderEnabled,
      ocrRawText: widget.existingRecord?.ocrRawText,
    );

    await widget.db.saveDoctorVisit(record);
    await MediaService.instance.playSuccessSound();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingRecord != null
              ? 'Doktor Ziyaretini Düzenle'
              : 'Doktor Ziyareti / Randevu Ekle',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.upcoming_outlined),
                  label: Text('Gelecek Randevu'),
                ),
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.history_edu_outlined),
                  label: Text('Geçmiş Muayene Notu'),
                ),
              ],
              selected: {_isUpcoming},
              onSelectionChanged: (s) =>
                  setState(() => _isUpcoming = s.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _diseaseCtrl,
              decoration: const InputDecoration(
                labelText: 'İlişkili Hastalık / Şikayet *',
                prefixIcon: Icon(Icons.coronavirus_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Zorunlu alan' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _hospitalCtrl,
              decoration: const InputDecoration(
                labelText: 'Hastane / Sağlık Kurumu *',
                prefixIcon: Icon(Icons.local_hospital_outlined),
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
                    controller: _deptCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Poliklinik / Bölüm *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Zorunlu alan' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _doctorCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Hekim Adı Soyadı *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Zorunlu alan' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ListTile(
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              leading: const Icon(Icons.event),
              title: const Text('Ziyaret / Randevu Tarihi ve Saati'),
              subtitle: Text(
                '${_visitDateTime.day.toString().padLeft(2, '0')}.${_visitDateTime.month.toString().padLeft(2, '0')}.${_visitDateTime.year} - '
                '${_visitDateTime.hour.toString().padLeft(2, '0')}:${_visitDateTime.minute.toString().padLeft(2, '0')}',
              ),
              trailing: TextButton(
                onPressed: _pickDateTime,
                child: const Text('Değiştir'),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: _isUpcoming
                    ? 'Randevu Öncesi Sorulacaklar / Hazırlık Notu *'
                    : 'Doktor Muayene Notları ve Tavsiyeler *',
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Not alanı zorunludur' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _testsCtrl,
              decoration: const InputDecoration(
                labelText: 'İstenen Tahliller / Tetkik Sonuçları',
                hintText: 'Örn: Hemogram, Ferritin, MR, Röntgen',
                prefixIcon: Icon(Icons.science_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            if (_isUpcoming)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sesli ve Görsel Randevu Hatırlatıcısı'),
                subtitle: const Text(
                    'Randevu yaklaştığında uygulama içi sesli bildirim gönderir'),
                value: _reminderEnabled,
                onChanged: (v) => setState(() => _reminderEnabled = v),
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Doktor Ziyaretini Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
