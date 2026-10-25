import 'package:flutter_test/flutter_test.dart';
import 'package:hastalik_takip/main.dart';
import 'package:hastalik_takip/models/health_models.dart';
import 'package:hastalik_takip/services/database_service.dart';
import 'package:hastalik_takip/services/ocr_service.dart';

/// Uygulama veri modellerini, OCR ayrıştırma algoritmasını ve tüm ekranların
/// hatasız derlenip çalıştığını doğrulayan kapsamlı testler.
void main() {
  test('Hastalık, Doktor Ziyareti ve İlaç modelleri Map dönüşüm testi', () {
    final disease = DiseaseRecord(
      id: 'test_1',
      name: 'Demir Eksikliği Anemisi',
      category: 'Kronik',
      diagnosisDate: DateTime(2026, 10, 25),
      status: 'Aktif / Devam Ediyor',
      severity: 6,
      symptoms: const ['Halsizlik', 'Baş dönmesi'],
      doctorOrClinic: 'Uzm. Dr. Ahmet Yılmaz',
      notes: 'Test açıklama notu',
    );

    final map = disease.toMap();
    final restored = DiseaseRecord.fromMap(map);

    expect(restored.id, 'test_1');
    expect(restored.name, 'Demir Eksikliği Anemisi');
    expect(restored.symptoms.length, 2);
    expect(restored.severity, 6);
  });

  test('OCR tıbbi belge metin ayrıştırma testi', () async {
    final doc = await OcrService.instance.scanPresetTemplate('recete');
    expect(doc.detectedDisease.isNotEmpty, true);
    expect(doc.detectedMedicationName.contains('Ferrosanol'), true);
    expect(doc.detectedDoctor.contains('Ahmet Yılmaz'), true);
  });

  testWidgets('Ana uygulama ve tüm sekmeler hatasız oluşturuluyor', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HastalikTakipApp());
    await tester.pump();

    expect(find.text('Hastalıklar'), findsOneWidget);
    expect(find.text('Ziyaretler'), findsOneWidget);
    expect(find.text('İlaçlar'), findsOneWidget);
    expect(find.text('OCR & Medya'), findsOneWidget);
    expect(find.text('Raporlama'), findsOneWidget);
    expect(DatabaseService.instance.activeStorageSummary.isNotEmpty, true);
  });
}
