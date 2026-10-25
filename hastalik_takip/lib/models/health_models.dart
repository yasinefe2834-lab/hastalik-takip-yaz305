import 'dart:convert';

/// Hastalık bilgilerini temsil eden veri modeli sınıfı.
/// SQLite, Hive ve yerel JSON yedekleme katmanları ile tam uyumludur.
class DiseaseRecord {
  final String id;
  final String name;
  final String category;
  final DateTime diagnosisDate;
  final String status;
  final int severity;
  final List<String> symptoms;
  final String doctorOrClinic;
  final String notes;
  final String? attachmentPath;

  const DiseaseRecord({
    required this.id,
    required this.name,
    required this.category,
    required this.diagnosisDate,
    required this.status,
    required this.severity,
    required this.symptoms,
    required this.doctorOrClinic,
    required this.notes,
    this.attachmentPath,
  });

  /// Mevcut nesnenin belirli alanlarını güncelleyerek yeni bir kopya döndürür.
  DiseaseRecord copyWith({
    String? id,
    String? name,
    String? category,
    DateTime? diagnosisDate,
    String? status,
    int? severity,
    List<String>? symptoms,
    String? doctorOrClinic,
    String? notes,
    String? attachmentPath,
  }) {
    return DiseaseRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      diagnosisDate: diagnosisDate ?? this.diagnosisDate,
      status: status ?? this.status,
      severity: severity ?? this.severity,
      symptoms: symptoms ?? this.symptoms,
      doctorOrClinic: doctorOrClinic ?? this.doctorOrClinic,
      notes: notes ?? this.notes,
      attachmentPath: attachmentPath ?? this.attachmentPath,
    );
  }

  /// Veritabanı (SQLite / Hive) ve JSON dönüşümü için Map yapısına çevirir.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'diagnosisDate': diagnosisDate.toIso8601String(),
      'status': status,
      'severity': severity,
      'symptoms': jsonEncode(symptoms),
      'doctorOrClinic': doctorOrClinic,
      'notes': notes,
      'attachmentPath': attachmentPath,
    };
  }

  /// Veritabanından veya JSON dosyasından gelen Map verisini nesneye dönüştürür.
  factory DiseaseRecord.fromMap(Map<String, dynamic> map) {
    List<String> parsedSymptoms = [];
    final rawSymptoms = map['symptoms'];
    if (rawSymptoms is String && rawSymptoms.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawSymptoms);
        if (decoded is List) {
          parsedSymptoms = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        parsedSymptoms = rawSymptoms
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    } else if (rawSymptoms is List) {
      parsedSymptoms = rawSymptoms.map((e) => e.toString()).toList();
    }

    return DiseaseRecord(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      category: map['category']?.toString() ?? 'Genel',
      diagnosisDate: DateTime.tryParse(map['diagnosisDate']?.toString() ?? '') ??
          DateTime.now(),
      status: map['status']?.toString() ?? 'Aktif / Devam Ediyor',
      severity: int.tryParse(map['severity']?.toString() ?? '5') ?? 5,
      symptoms: parsedSymptoms,
      doctorOrClinic: map['doctorOrClinic']?.toString() ?? '',
      notes: map['notes']?.toString() ?? '',
      attachmentPath: map['attachmentPath']?.toString(),
    );
  }
}

/// Doktor ziyaret notlarını ve gelecek doktor randevularını temsil eden veri modeli.
class DoctorVisitRecord {
  final String id;
  final String diseaseName;
  final String hospitalName;
  final String department;
  final String doctorName;
  final DateTime visitDateTime;
  final bool isUpcoming;
  final String doctorNotes;
  final String prescribedTests;
  final bool reminderEnabled;
  final String? ocrRawText;

  const DoctorVisitRecord({
    required this.id,
    required this.diseaseName,
    required this.hospitalName,
    required this.department,
    required this.doctorName,
    required this.visitDateTime,
    required this.isUpcoming,
    required this.doctorNotes,
    required this.prescribedTests,
    required this.reminderEnabled,
    this.ocrRawText,
  });

  /// Güncellenmiş alanlarla yeni bir Doktor Ziyareti nesnesi üretir.
  DoctorVisitRecord copyWith({
    String? id,
    String? diseaseName,
    String? hospitalName,
    String? department,
    String? doctorName,
    DateTime? visitDateTime,
    bool? isUpcoming,
    String? doctorNotes,
    String? prescribedTests,
    bool? reminderEnabled,
    String? ocrRawText,
  }) {
    return DoctorVisitRecord(
      id: id ?? this.id,
      diseaseName: diseaseName ?? this.diseaseName,
      hospitalName: hospitalName ?? this.hospitalName,
      department: department ?? this.department,
      doctorName: doctorName ?? this.doctorName,
      visitDateTime: visitDateTime ?? this.visitDateTime,
      isUpcoming: isUpcoming ?? this.isUpcoming,
      doctorNotes: doctorNotes ?? this.doctorNotes,
      prescribedTests: prescribedTests ?? this.prescribedTests,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      ocrRawText: ocrRawText ?? this.ocrRawText,
    );
  }

  /// SQLite, Hive ve JSON kaydı için nesneyi Map yapısına dönüştürür.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'diseaseName': diseaseName,
      'hospitalName': hospitalName,
      'department': department,
      'doctorName': doctorName,
      'visitDateTime': visitDateTime.toIso8601String(),
      'isUpcoming': isUpcoming ? 1 : 0,
      'doctorNotes': doctorNotes,
      'prescribedTests': prescribedTests,
      'reminderEnabled': reminderEnabled ? 1 : 0,
      'ocrRawText': ocrRawText,
    };
  }

  /// Veritabanından okunan Map verisini DoctorVisitRecord nesnesine dönüştürür.
  factory DoctorVisitRecord.fromMap(Map<String, dynamic> map) {
    final upcomingVal = map['isUpcoming'];
    final reminderVal = map['reminderEnabled'];

    return DoctorVisitRecord(
      id: map['id']?.toString() ?? '',
      diseaseName: map['diseaseName']?.toString() ?? '',
      hospitalName: map['hospitalName']?.toString() ?? '',
      department: map['department']?.toString() ?? '',
      doctorName: map['doctorName']?.toString() ?? '',
      visitDateTime:
          DateTime.tryParse(map['visitDateTime']?.toString() ?? '') ??
              DateTime.now(),
      isUpcoming: upcomingVal == 1 || upcomingVal == true,
      doctorNotes: map['doctorNotes']?.toString() ?? '',
      prescribedTests: map['prescribedTests']?.toString() ?? '',
      reminderEnabled: reminderVal == 1 || reminderVal == true,
      ocrRawText: map['ocrRawText']?.toString(),
    );
  }
}

/// Kullanılan ilaç bilgilerini, dozaj ve günlük alım durumunu temsil eden veri modeli.
class MedicationRecord {
  final String id;
  final String diseaseName;
  final String name;
  final String dosage;
  final String frequency;
  final String scheduleTimes;
  final String usageInstruction;
  final DateTime startDate;
  final DateTime endDate;
  final int remainingPills;
  final bool takenToday;
  final String notes;

  const MedicationRecord({
    required this.id,
    required this.diseaseName,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.scheduleTimes,
    required this.usageInstruction,
    required this.startDate,
    required this.endDate,
    required this.remainingPills,
    required this.takenToday,
    required this.notes,
  });

  /// Mevcut ilaç kaydının seçili özelliklerini güncelleyerek kopyasını oluşturur.
  MedicationRecord copyWith({
    String? id,
    String? diseaseName,
    String? name,
    String? dosage,
    String? frequency,
    String? scheduleTimes,
    String? usageInstruction,
    DateTime? startDate,
    DateTime? endDate,
    int? remainingPills,
    bool? takenToday,
    String? notes,
  }) {
    return MedicationRecord(
      id: id ?? this.id,
      diseaseName: diseaseName ?? this.diseaseName,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      scheduleTimes: scheduleTimes ?? this.scheduleTimes,
      usageInstruction: usageInstruction ?? this.usageInstruction,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      remainingPills: remainingPills ?? this.remainingPills,
      takenToday: takenToday ?? this.takenToday,
      notes: notes ?? this.notes,
    );
  }

  /// SQLite, Hive ve JSON kaydı için nesneyi Map yapısına dönüştürür.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'diseaseName': diseaseName,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'scheduleTimes': scheduleTimes,
      'usageInstruction': usageInstruction,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'remainingPills': remainingPills,
      'takenToday': takenToday ? 1 : 0,
      'notes': notes,
    };
  }

  /// Veritabanından okunan Map verisini MedicationRecord nesnesine dönüştürür.
  factory MedicationRecord.fromMap(Map<String, dynamic> map) {
    final takenVal = map['takenToday'];
    return MedicationRecord(
      id: map['id']?.toString() ?? '',
      diseaseName: map['diseaseName']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      dosage: map['dosage']?.toString() ?? '',
      frequency: map['frequency']?.toString() ?? 'Günde 1 Kez',
      scheduleTimes: map['scheduleTimes']?.toString() ?? '09:00',
      usageInstruction: map['usageInstruction']?.toString() ?? 'Tok Karnına',
      startDate:
          DateTime.tryParse(map['startDate']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(map['endDate']?.toString() ?? '') ??
          DateTime.now().add(const Duration(days: 30)),
      remainingPills: int.tryParse(map['remainingPills']?.toString() ?? '20') ?? 20,
      takenToday: takenVal == 1 || takenVal == true,
      notes: map['notes']?.toString() ?? '',
    );
  }
}
