import 'package:flutter/material.dart';

import '../models/health_models.dart';
import '../services/database_service.dart';
import '../services/media_service.dart';

/// Hastalık girişi, listeleme, filtreleme, detay görüntüleme ve güncelleme ekranı.
class DiseasesScreen extends StatefulWidget {
  final DatabaseService db;
  final VoidCallback onOpenOcrRequested;

  const DiseasesScreen({
    super.key,
    required this.db,
    required this.onOpenOcrRequested,
  });

  @override
  State<DiseasesScreen> createState() => _DiseasesScreenState();
}

class _DiseasesScreenState extends State<DiseasesScreen> {
  String _searchQuery = '';
  String _selectedStatusFilter = 'Tümü';

  static const List<String> _statusFilters = [
    'Tümü',
    'Aktif / Devam Ediyor',
    'Kontrol Altında',
    'İyileşti',
  ];

  /// Arama metni ve durum filtresine göre hastalık listesini süzer.
  List<DiseaseRecord> get _filteredDiseases {
    return widget.db.diseases.where((d) {
      final matchesStatus = _selectedStatusFilter == 'Tümü' ||
          d.status == _selectedStatusFilter;
      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          d.name.toLowerCase().contains(q) ||
          d.category.toLowerCase().contains(q) ||
          d.doctorOrClinic.toLowerCase().contains(q) ||
          d.symptoms.any((s) => s.toLowerCase().contains(q));
      return matchesStatus && matchesSearch;
    }).toList();
  }

  /// Tarih bilgisini GG.AA.YYYY biçiminde döndürür.
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  /// Hastalık durumuna göre uygun vurgu rengini döndürür.
  Color _statusColor(String status) {
    if (status.contains('Aktif')) return Colors.redAccent;
    if (status.contains('Kontrol')) return Colors.amber.shade800;
    return Colors.teal.shade700;
  }

  /// Yumuşak animasyonlu sayfa geçişi ile hastalık ekleme/düzenleme ekranını açar.
  Future<void> _openDiseaseForm({DiseaseRecord? existing}) async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            DiseaseFormPage(db: widget.db, existingRecord: existing),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final offsetAnim = Tween<Offset>(
            begin: const Offset(0.0, 0.12),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ));
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offsetAnim, child: child),
          );
        },
      ),
    );
  }

  /// Hastalık detaylarını gösteren alt pencereyi açar.
  void _showDiseaseDetails(DiseaseRecord record) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          maxChildSize: 0.92,
          minChildSize: 0.5,
          builder: (_, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          _statusColor(record.status).withValues(alpha: 0.15),
                      child: Icon(
                        Icons.medical_information,
                        color: _statusColor(record.status),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${record.category} • Tanı Tarihi: ${_formatDate(record.diagnosisDate)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: Icon(
                        Icons.flag,
                        size: 16,
                        color: _statusColor(record.status),
                      ),
                      label: Text(record.status),
                    ),
                    Chip(
                      avatar: const Icon(Icons.thermostat, size: 16),
                      label: Text('Şiddet Derecesi: ${record.severity}/10'),
                    ),
                  ],
                ),
                const Divider(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.local_hospital_outlined),
                  title: const Text('Tanı Koyan Doktor / Poliklinik'),
                  subtitle: Text(
                    record.doctorOrClinic.isEmpty
                        ? 'Belirtilmedi'
                        : record.doctorOrClinic,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gözlemlenen Belirtiler (Semptomlar)',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: record.symptoms
                      .map((s) => Chip(
                            label: Text(s),
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
                const SizedBox(height: 14),
                Text(
                  'Hekim ve Hasta Açıklama Notları',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    record.notes.isEmpty
                        ? 'Ek açıklama bulunmuyor.'
                        : record.notes,
                  ),
                ),
                if (record.attachmentPath != null &&
                    record.attachmentPath!.startsWith('assets/')) ...[
                  const SizedBox(height: 16),
                  Text(
                    'İlişkili Muayene / Reçete Görseli (Düşük Boyutlu Medya)',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      record.attachmentPath!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openDiseaseForm(existing: record);
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Kaydı Düzenle'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await widget.db.deleteDisease(record.id);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Kaydı Sil'),
                      ),
                    ),
                  ],
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
    final items = _filteredDiseases;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Üst Bilgilendirme ve Görsel Banner Alanı
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vektörel ve net Medikal Başlık & Hızlı Erişim Kartı (Kırpılma ve bulanıklık olmadan)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.teal.withValues(alpha: 0.22),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.medical_information_outlined,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Kişisel Sağlık & Hastalık Takip Sistemi',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Verileriniz cihaz içi yerel veritabanında güvende tutulur.',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Aktif Tanı: ${widget.db.diseases.where((d) => d.status.contains("Aktif")).length} • '
                                'Randevu: ${widget.db.upcomingVisits.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF0F766E),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: widget.onOpenOcrRequested,
                              icon: const Icon(
                                Icons.document_scanner,
                                size: 16,
                              ),
                              label: const Text(
                                'OCR ile Belge Tara',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Arama Kutusu
                  TextField(
                    decoration: InputDecoration(
                      hintText:
                          'Hastalık adı, belirti veya poliklinik ara...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              onPressed: () =>
                                  setState(() => _searchQuery = ''),
                              icon: const Icon(Icons.clear),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      isDense: true,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                  const SizedBox(height: 10),
                  // Durum Filtre Çipleri
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _statusFilters.map((status) {
                        final selected = _selectedStatusFilter == status;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            selected: selected,
                            label: Text(status),
                            onSelected: (_) {
                              setState(() => _selectedStatusFilter = status);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Hastalık Listesi
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.health_and_safety_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Kriterlere uygun hastalık kaydı bulunamadı.',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () => _openDiseaseForm(),
                        icon: const Icon(Icons.add),
                        label: const Text('Yeni Hastalık Kaydı Ekle'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
              sliver: SliverList.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final d = items[index];
                  final statusColor = _statusColor(d.status);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _showDiseaseDetails(d),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.monitor_heart_outlined,
                                    color: statusColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        d.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${d.category} • Tanı: ${_formatDate(d.diagnosisDate)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    d.status,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (d.doctorOrClinic.isNotEmpty)
                              Row(
                                children: [
                                  const Icon(Icons.person_outline, size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      d.doctorOrClinic,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 8),
                            // Şiddet Çubuğu
                            Row(
                              children: [
                                const Text(
                                  'Şiddet Düzeyi:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: d.severity / 10.0,
                                      minHeight: 7,
                                      backgroundColor:
                                          Colors.grey.withValues(alpha: 0.2),
                                      color: d.severity >= 7
                                          ? Colors.redAccent
                                          : (d.severity >= 4
                                              ? Colors.orange
                                              : Colors.teal),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${d.severity}/10',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (d.symptoms.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: d.symptoms
                                    .take(4)
                                    .map(
                                      (s) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondaryContainer
                                              .withValues(alpha: 0.6),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          s,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openDiseaseForm(),
        icon: const Icon(Icons.add),
        label: const Text('Hastalık Ekle'),
      ),
    );
  }
}

/// Yeni hastalık kaydı ekleme veya mevcut kaydı düzenleme tam ekran formu.
class DiseaseFormPage extends StatefulWidget {
  final DatabaseService db;
  final DiseaseRecord? existingRecord;

  const DiseaseFormPage({
    super.key,
    required this.db,
    this.existingRecord,
  });

  @override
  State<DiseaseFormPage> createState() => _DiseaseFormPageState();
}

class _DiseaseFormPageState extends State<DiseaseFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _symptomsCtrl;
  late final TextEditingController _doctorCtrl;
  late final TextEditingController _notesCtrl;

  String _category = 'Kronik';
  String _status = 'Aktif / Devam Ediyor';
  int _severity = 5;
  DateTime _diagnosisDate = DateTime.now();
  String? _selectedAttachment;

  static const List<String> _categories = [
    'Kronik',
    'Akut',
    'Enfeksiyon',
    'Alerjik',
    'Metabolik',
    'Kas-İskelet',
    'Nörolojik',
    'Diğer',
  ];

  static const List<String> _statuses = [
    'Aktif / Devam Ediyor',
    'Kontrol Altında',
    'İyileşti',
  ];

  @override
  void initState() {
    super.initState();
    final ex = widget.existingRecord;
    _nameCtrl = TextEditingController(text: ex?.name ?? '');
    _symptomsCtrl = TextEditingController(
      text: ex != null ? ex.symptoms.join(', ') : '',
    );
    _doctorCtrl = TextEditingController(text: ex?.doctorOrClinic ?? '');
    _notesCtrl = TextEditingController(text: ex?.notes ?? '');
    if (ex != null) {
      if (_categories.contains(ex.category)) _category = ex.category;
      if (_statuses.contains(ex.status)) _status = ex.status;
      _severity = ex.severity;
      _diagnosisDate = ex.diagnosisDate;
      _selectedAttachment = ex.attachmentPath;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _symptomsCtrl.dispose();
    _doctorCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _diagnosisDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _diagnosisDate = picked);
    }
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    final symptomsList = _symptomsCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final record = DiseaseRecord(
      id: widget.existingRecord?.id ??
          'hst_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      category: _category,
      diagnosisDate: _diagnosisDate,
      status: _status,
      severity: _severity,
      symptoms: symptomsList.isEmpty ? ['Genel Belirti'] : symptomsList,
      doctorOrClinic: _doctorCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      attachmentPath: _selectedAttachment,
    );

    await widget.db.saveDisease(record);
    await MediaService.instance.playSuccessSound();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingRecord != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Hastalık Kaydını Düzenle' : 'Yeni Hastalık Girişi'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Hastalık / Tanı Adı *',
                hintText: 'Örn: Demir Eksikliği Anemisi, Kronik Migren',
                prefixIcon: Icon(Icons.medical_services_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (val) =>
                  (val == null || val.trim().isEmpty) ? 'Hastalık adı zorunludur' : null,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _category = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Güncel Durum',
                      border: OutlineInputBorder(),
                    ),
                    items: _statuses
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _status = val);
                    },
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
              leading: const Icon(Icons.calendar_today),
              title: const Text('Tanı / Başlangıç Tarihi'),
              subtitle: Text(
                '${_diagnosisDate.day.toString().padLeft(2, '0')}.${_diagnosisDate.month.toString().padLeft(2, '0')}.${_diagnosisDate.year}',
              ),
              trailing: TextButton(
                onPressed: _pickDate,
                child: const Text('Tarih Seç'),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Belirti Şiddet Derecesi: $_severity / 10',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Slider(
                      value: _severity.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: '$_severity',
                      onChanged: (val) =>
                          setState(() => _severity = val.round()),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _symptomsCtrl,
              decoration: const InputDecoration(
                labelText: 'Belirtiler (Virgülle ayırarak yazınız)',
                hintText: 'Örn: Halsizlik, Baş dönmesi, Öksürük',
                prefixIcon: Icon(Icons.sick_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _doctorCtrl,
              decoration: const InputDecoration(
                labelText: 'Tanı Koyan Doktor / Poliklinik',
                hintText: 'Örn: Uzm. Dr. Ahmet Yılmaz - Dahiliye',
                prefixIcon: Icon(Icons.local_hospital_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Hekim Notları ve Tedavi Açıklaması',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String?>(
              initialValue: _selectedAttachment,
              decoration: const InputDecoration(
                labelText: 'İlişkili Belge / Rapor Görseli Ekle (Opsiyonel)',
                prefixIcon: Icon(Icons.image_outlined),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Görsel Eklenmedi')),
                DropdownMenuItem(
                  value: 'assets/images/ornek_recete_ocr.png',
                  child: Text('Dahiliye Muayene & Reçete Belgesi'),
                ),
                DropdownMenuItem(
                  value: 'assets/images/ornek_prospektus_ocr.png',
                  child: Text('İlaç Prospektüs & Kutu Görseli'),
                ),
              ],
              onChanged: (val) => setState(() => _selectedAttachment = val),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saveForm,
              icon: const Icon(Icons.save_outlined),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  isEditing
                      ? 'Değişiklikleri Yerel Veritabanına Kaydet'
                      : 'Hastalığı Yerel Veritabanına Kaydet',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
