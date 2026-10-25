import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/health_models.dart';
import 'database_service.dart';

/// Girilen sağlık verilerini derleyerek hekime sunulmak üzere profesyonel PDF
/// formatında "Kişisel Genel Sağlık Raporu" oluşturan servis.
class PdfReportService {
  static final PdfReportService instance = PdfReportService._internal();
  PdfReportService._internal();

  /// Türkçe karakterleri PDF standart yazı tipinde sorunsuz görüntülemek için normalize eder.
  String _trSafe(String input) {
    return input
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'G')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'U')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 'S')
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'I')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'O')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'C');
  }

  /// Tarih bilgisini GG.AA.YYYY biçiminde döndürür.
  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  /// Tüm sağlık geçmişini içeren PDF belgesinin byte dizisini üretir.
  Future<Uint8List> buildHealthSummaryPdf(DatabaseService db) async {
    final pdf = pw.Document();

    final List<DiseaseRecord> diseases = db.diseases;
    final List<DoctorVisitRecord> upcoming = db.upcomingVisits;
    final List<DoctorVisitRecord> past = db.pastVisits;
    final List<MedicationRecord> meds = db.medications;

    final int takenCount = meds.where((m) => m.takenToday).length;
    final int adherencePercent =
        meds.isEmpty ? 100 : ((takenCount / meds.length) * 100).round();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return [
            // Başlık Kutusu
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColors.teal700,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        _trSafe('KISISEL SAGLIK VE HASTALIK TAKIP RAPORU'),
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        _trSafe(
                            'Hasta: ${db.patientName} | Kan Grubu: ${db.bloodType} | Alerjiler: ${db.allergies}'),
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    _formatDate(DateTime.now()),
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Genel İstatistik Özeti
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _statBox('Toplam Hastalik', '${diseases.length} Kayit'),
                _statBox('Aktif Ilaclar', '${meds.length} Ilac'),
                _statBox('Gunluk Doz Uyumu', '%$adherencePercent'),
                _statBox('Gelecek Randevu', '${upcoming.length} Randevu'),
              ],
            ),
            pw.SizedBox(height: 18),

            // 1. Bölüm: Kayıtlı Hastalıklar
            pw.Text(
              _trSafe('1. HASTALIK GECMISI VE MEVCUT TANILAR'),
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.teal900,
              ),
            ),
            pw.Divider(color: PdfColors.teal700),
            ...diseases.map(
              (d) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          _trSafe('${d.name} (${d.category})'),
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        pw.Text(
                          _trSafe(
                              'Durum: ${d.status} | Siddet: ${d.severity}/10'),
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      _trSafe(
                          'Tani Tarihi: ${_formatDate(d.diagnosisDate)} | Hekim/Klinik: ${d.doctorOrClinic}'),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      _trSafe('Belirtiler: ${d.symptoms.join(", ")}'),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      _trSafe('Not: ${d.notes}'),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 12),

            // 2. Bölüm: İlaç Bilgileri
            pw.Text(
              _trSafe('2. KULLANILAN ILACLAR VE DOZ PLANI'),
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.teal900,
              ),
            ),
            pw.Divider(color: PdfColors.teal700),
            pw.TableHelper.fromTextArray(
              headers: [
                'Ilac Adi',
                'Hastalik',
                'Dozaj & Siklik',
                'Saat / Kullanim',
                'Stok',
              ],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.teal600,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              data: meds
                  .map((m) => [
                        _trSafe(m.name),
                        _trSafe(m.diseaseName),
                        _trSafe('${m.dosage} (${m.frequency})'),
                        _trSafe('${m.scheduleTimes} - ${m.usageInstruction}'),
                        '${m.remainingPills} Adet',
                      ])
                  .toList(),
            ),
            pw.SizedBox(height: 16),

            // 3. Bölüm: Doktor Ziyaretleri ve Gelecek Randevular
            pw.Text(
              _trSafe('3. DOKTOR ZIYARET NOTLARI VE GELECEK RANDEVULAR'),
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.teal900,
              ),
            ),
            pw.Divider(color: PdfColors.teal700),
            ...upcoming.map(
              (v) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Text(
                  _trSafe(
                      '[GELECEK RANDEVU - ${_formatDate(v.visitDateTime)}] ${v.hospitalName} (${v.department}) - ${v.doctorName} | Hazirlik: ${v.doctorNotes}'),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),
            ...past.map(
              (v) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Text(
                  _trSafe(
                      '[GECMIS MUAYENE - ${_formatDate(v.visitDateTime)}] ${v.hospitalName} (${v.department}) - ${v.doctorName} | Not: ${v.doctorNotes}'),
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _statBox(String label, String value) {
    return pw.Container(
      width: 120,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.teal50,
        border: pw.Border.all(color: PdfColors.teal200),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            _trSafe(label),
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            _trSafe(value),
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.teal900,
            ),
          ),
        ],
      ),
    );
  }

  /// PDF önizleme, yazdırma ve paylaşma penceresini açar.
  Future<void> previewAndPrintReport(DatabaseService db) async {
    await Printing.layoutPdf(
      name: 'Kisisel_Saglik_Raporu_YAZ305.pdf',
      onLayout: (PdfPageFormat format) => buildHealthSummaryPdf(db),
    );
  }
}
