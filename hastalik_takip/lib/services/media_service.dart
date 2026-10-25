import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Uygulama içi sesli bildirimleri ve işitsel geri bildirimleri yöneten servis.
/// Düşük boyutlu WAV ses dosyalarını (assets/audio/) oynatır.
class MediaService {
  static final MediaService instance = MediaService._internal();
  MediaService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _soundEnabled = true;

  bool get soundEnabled => _soundEnabled;

  /// Sesli bildirimleri açıp kapatır.
  void toggleSound(bool enabled) {
    _soundEnabled = enabled;
  }

  /// İlaç dozu alındığında veya ilaç hatırlatmasında çalınan ses.
  Future<void> playMedicationSound() async {
    await _playAsset('audio/ilac_bildirim.wav');
  }

  /// Doktor randevusu hatırlatması ve bildiriminde çalınan ses.
  Future<void> playAppointmentSound() async {
    await _playAsset('audio/randevu_uyari.wav');
  }

  /// Kayıt eklendiğinde veya rapor oluşturulduğunda çalınan onay sesi.
  Future<void> playSuccessSound() async {
    await _playAsset('audio/saglik_onay.wav');
  }

  /// Belirtilen ses kaynağını güvenli şekilde oynatır.
  Future<void> _playAsset(String assetRelativePath) async {
    if (!_soundEnabled) return;
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(assetRelativePath));
    } catch (_) {
      // Ses donanımı meşgulse sistem geri bildirim sesini çal
      await SystemSound.play(SystemSoundType.click);
    }
  }
}
