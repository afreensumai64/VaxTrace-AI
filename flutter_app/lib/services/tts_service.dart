// VaxTrace AI — GuardianVoice TTS Service
// Supports English, Tamil, Hindi voice reminders

import 'package:flutter_tts/flutter_tts.dart';
import '../models/child.dart';

enum AppLanguage { english, hindi, tamil }

class TtsService {
  final FlutterTts _tts = FlutterTts();
  AppLanguage _currentLanguage = AppLanguage.english;

  TtsService() {
    _init();
  }

  Future<void> _init() async {
    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    await _setLocale(_currentLanguage);
  }

  Future<void> _setLocale(AppLanguage lang) async {
    switch (lang) {
      case AppLanguage.english:
        await _tts.setLanguage('en-IN');
        break;
      case AppLanguage.hindi:
        await _tts.setLanguage('hi-IN');
        break;
      case AppLanguage.tamil:
        await _tts.setLanguage('ta-IN');
        break;
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    _currentLanguage = language;
    await _setLocale(language);
  }

  /// Speak a vaccine reminder for the given child
  Future<void> speakVaccineReminder(Child child) async {
    final message = _buildReminderMessage(child, _currentLanguage);
    await _tts.stop();
    await _tts.speak(message);
  }

  /// Speak a high-risk alert for a child
  Future<void> speakHighRiskAlert(Child child) async {
    final message = _buildHighRiskMessage(child, _currentLanguage);
    await _tts.stop();
    await _tts.speak(message);
  }

  Future<void> speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  // ─────────────────────────────────────────────
  // Message builders per locale
  // ─────────────────────────────────────────────

  String _buildReminderMessage(Child child, AppLanguage lang) {
    final days = child.daysUntilNextDose;
    final dueDate = child.nextDueDate != null
        ? '${child.nextDueDate!.day}/${child.nextDueDate!.month}/${child.nextDueDate!.year}'
        : 'soon';

    switch (lang) {
      case AppLanguage.english:
        if (child.isOverdue) {
          return 'Alert! ${child.guardianName}, ${child.name}\'s vaccine is overdue. '
              'Please visit the clinic immediately.';
        }
        return 'Hello ${child.guardianName}! ${child.name}\'s next vaccine is due '
            'in $days days on $dueDate. Please visit the nearest clinic on time.';

      case AppLanguage.hindi:
        if (child.isOverdue) {
          return 'सावधान! ${child.guardianName}, ${child.name} का टीका देरी से है। '
              'कृपया तुरंत क्लिनिक जाएं।';
        }
        return 'नमस्ते ${child.guardianName}! ${child.name} का अगला टीका '
            '$days दिनों में $dueDate को लगना है। कृपया समय पर नजदीकी क्लिनिक जाएं।';

      case AppLanguage.tamil:
        if (child.isOverdue) {
          return 'எச்சரிக்கை! ${child.guardianName}, ${child.name}க்கு தடுப்பூசி தாமதமாகிவிட்டது. '
              'தயவுசெய்து உடனடியாக மருத்துவமனைக்கு வாருங்கள்.';
        }
        return 'வணக்கம் ${child.guardianName}! ${child.name}க்கு அடுத்த தடுப்பூசி '
            '$days நாட்களில் $dueDate அன்று உள்ளது. '
            'தயவுசெய்து சரியான நேரத்தில் மருத்துவமனைக்கு வாருங்கள்.';
    }
  }

  String _buildHighRiskMessage(Child child, AppLanguage lang) {
    switch (lang) {
      case AppLanguage.english:
        return 'High risk alert for ${child.name}. '
            'Risk score: ${child.riskScore.toStringAsFixed(0)}. '
            'Distance: ${child.distanceFromClinicKm.toStringAsFixed(1)} km. '
            'Immediate follow-up required.';
      case AppLanguage.hindi:
        return '${child.name} के लिए उच्च जोखिम चेतावनी। '
            'जोखिम स्कोर: ${child.riskScore.toStringAsFixed(0)}। '
            'दूरी: ${child.distanceFromClinicKm.toStringAsFixed(1)} किलोमीटर। '
            'तत्काल अनुवर्ती कार्रवाई आवश्यक है।';
      case AppLanguage.tamil:
        return '${child.name}க்கு அதிக ஆபத்து எச்சரிக்கை. '
            'ஆபத்து மதிப்பெண்: ${child.riskScore.toStringAsFixed(0)}. '
            'தூரம்: ${child.distanceFromClinicKm.toStringAsFixed(1)} கி.மீ. '
            'உடனடி தொடர்பு தேவை.';
    }
  }

  void dispose() {
    _tts.stop();
  }
}
