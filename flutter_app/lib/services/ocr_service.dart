// VaxTrace AI — OCR Service (SnapCard Engine)
// Uses Google ML Kit text recognition to extract child name + dose date
// from handwritten paper vaccination cards.

import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  final String? childName;
  final DateTime? lastDoseDate;
  final String rawText;
  final bool success;

  const OcrResult({
    this.childName,
    this.lastDoseDate,
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
    final lastDoseDate = _extractLastDoseDate(rawText);

    return OcrResult(
      childName: childName,
      lastDoseDate: lastDoseDate,
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

  DateTime? _extractLastDoseDate(String text) {
    // Common date patterns on vaccination cards
    final datePatterns = [
      // DD/MM/YYYY or DD-MM-YYYY
      RegExp(r'(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})'),
      // Month DD, YYYY
      RegExp(r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s+(\d{1,2}),?\s+(\d{4})',
          caseSensitive: false),
    ];

    // Look for context lines: "Last Dose", "Date Given", "DTP", etc.
    final contextLines = text
        .split('\n')
        .where((line) => RegExp(
              r'last\s*dose|date\s*given|administered|DTP|OPV|BCG|Measles|Polio',
              caseSensitive: false,
            ).hasMatch(line))
        .toList();

    final searchText = contextLines.isNotEmpty
        ? contextLines.join('\n')
        : text;

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
