// VaxTrace AI — OCR Service (SnapCard Engine)
// Uses Google ML Kit text recognition to extract child name + dose date
// from handwritten paper vaccination cards.

import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  final String? childName;
  final String? guardianName;
  final String? vaccineName;
  final DateTime? lastDoseDate;
  final DateTime? dateOfBirth;
  final String rawText;
  final bool success;

  const OcrResult({
    this.childName,
    this.guardianName,
    this.vaccineName,
    this.lastDoseDate,
    this.dateOfBirth,
    required this.rawText,
    required this.success,
  });
}

class OcrService {
  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<OcrResult> scanVaccinationCard(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    RecognizedText recognizedText;

    try {
      recognizedText = await _recognizer.processImage(inputImage);
    } catch (e) {
      return OcrResult(rawText: '', success: false);
    }

    final rawText = recognizedText.text;
    final childName = _extractChildName(rawText);
    final guardianName = _extractGuardianName(rawText);
    final vaccineName = _extractVaccineName(rawText);
    final lastDoseDate = _extractLastDoseDate(rawText, context: 'last_dose');
    final dateOfBirth = _extractLastDoseDate(rawText, context: 'dob');

    return OcrResult(
      childName: childName,
      guardianName: guardianName,
      vaccineName: vaccineName,
      lastDoseDate: lastDoseDate,
      dateOfBirth: dateOfBirth,
      rawText: rawText,
      success: childName != null || lastDoseDate != null,
    );
  }

  // ─────────────────────────────────────────────
  // Extraction logic
  // ─────────────────────────────────────────────

  String? _extractChildName(String text) {
    // Pattern: "Name: John Doe" or "Child Name: John Doe" or "Name of Child: John"
    final patterns = [
      RegExp(r"(?:Child\s+)?Name\s*[:\-]\s*([A-Za-z\s]+)", caseSensitive: false),
      RegExp(r"Patient\s*[:\-]\s*([A-Za-z\s]+)", caseSensitive: false),
      RegExp(r"குழந்தையின் பெயர்\s*[:\-]\s*([A-Za-z\u0B80-\u0BFF\s]+)", caseSensitive: false),
      RegExp(r"बच्चे का नाम\s*[:\-]\s*([A-Za-z\u0900-\u097F\s]+)", caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.group(1) != null) {
        final name = match.group(1)!.trim();
        if (name.length >= 2 && name.length <= 60) {
          return name;
        }
      }
    }

    // Fallback: first meaningful line that looks like a name
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (RegExp(r'^[A-Za-z]{2,}\s+[A-Za-z]{2,}').hasMatch(trimmed)) {
        return trimmed.split(RegExp(r'\s+')).take(3).join(' ');
      }
    }

    return null;
  }

  String? _extractGuardianName(String text) {
    final patterns = [
      RegExp(r"(?:Mother|Father|Guardian|Parent|Caregiver)\s*[:\-]\s*([A-Za-z\s]{2,40})", caseSensitive: false),
      RegExp(r"(?:ماں|باپ|والدین)\s*[:\-]\s*([A-Za-z؀-ۿ\s]{2,40})", caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m?.group(1) != null) return m!.group(1)!.trim();
    }
    return null;
  }

  String? _extractVaccineName(String text) {
    const vaccines = ['BCG', 'OPV', 'DTP', 'Pentavalent', 'Measles', 'MMR',
        'Pneumococcal', 'PCV', 'Rotavirus', 'Hepatitis', 'IPV', 'MCV'];
    for (final v in vaccines) {
      if (text.contains(RegExp(v, caseSensitive: false))) return v;
    }
    return null;
  }

  DateTime? _extractLastDoseDate(String text, {String context = 'last_dose'}) {
    // Common date patterns on vaccination cards
    final datePatterns = [
      // DD/MM/YYYY or DD-MM-YYYY
      RegExp(r'(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})'),
      // Month DD, YYYY
      RegExp(r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s+(\d{1,2}),?\s+(\d{4})',
          caseSensitive: false),
    ];

    // Look for context lines matching the requested context
    final contextRegex = context == 'dob'
        ? RegExp(r'date\s*of\s*birth|dob|born|تاریخ پیدائش', caseSensitive: false)
        : RegExp(r'last\s*dose|date\s*given|administered|DTP|OPV|BCG|Measles|Polio', caseSensitive: false);

    final contextLines = text.split('\n').where((l) => contextRegex.hasMatch(l)).toList();
    final searchText = contextLines.isNotEmpty ? contextLines.join('\n') : text;

    for (final pattern in datePatterns) {
      final match = pattern.firstMatch(searchText);
      if (match != null) {
        try {
          return _parseDate(match);
        } catch (_) {
          continue;
        }
      }
    }

    return null;
  }

  DateTime? _parseDate(RegExpMatch match) {
    final g1 = match.group(1)!;
    final g2 = match.group(2)!;
    final g3 = match.group(3)!;

    // DD/MM/YYYY format
    if (int.tryParse(g1) != null && int.tryParse(g2) != null) {
      final day = int.parse(g1);
      final month = int.parse(g2);
      var year = int.parse(g3);
      if (year < 100) year += 2000;
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    }

    // Mon DD, YYYY format
    final monthMap = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4,
      'may': 5, 'jun': 6, 'jul': 7, 'aug': 8,
      'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    final monthNum = monthMap[g1.substring(0, 3).toLowerCase()];
    if (monthNum != null) {
      return DateTime(int.parse(g3), monthNum, int.parse(g2));
    }

    return null;
  }

  void dispose() {
    _recognizer.close();
  }
}
