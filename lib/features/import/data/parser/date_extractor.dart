/// Detailed result from parsing a date from OCR text.
class DateExtractionResult {
  final DateTime date;
  final bool hasExplicitYear;
  final bool isRelative;
  final String rawMatchedText;

  const DateExtractionResult({
    required this.date,
    required this.hasExplicitYear,
    required this.isRelative,
    required this.rawMatchedText,
  });

  @override
  String toString() =>
      'DateExtractionResult(date: $date, explicitYear: $hasExplicitYear, relative: $isRelative)';
}

/// Comprehensive parser for various transaction date formats:
/// - Layout A dates: "7 September", "6 September", "5 September", "2 September 2026 at 2:35 pm"
/// - Layout B dates: "8 hours ago", "1 day ago", "04 Sept", "02 Sept"
/// - Standard formats: "07 Sep 2026", "07/09/2026", "07-09-2026"
class DateExtractor {
  const DateExtractor._();

  /// Month mapping supporting 3-letter, 4-letter ('sept'), and full month names.
  static const Map<String, int> _monthMap = {
    'jan': 1,
    'january': 1,
    'feb': 2,
    'february': 2,
    'mar': 3,
    'march': 3,
    'apr': 4,
    'april': 4,
    'may': 5,
    'jun': 6,
    'june': 6,
    'jul': 7,
    'july': 7,
    'aug': 8,
    'august': 8,
    'sep': 9,
    'sept': 9,
    'september': 9,
    'oct': 10,
    'october': 10,
    'nov': 11,
    'november': 11,
    'dec': 12,
    'december': 12,
  };

  /// Parses a date from a single line of OCR text, returning [DateExtractionResult] or null.
  static DateExtractionResult? parseDate(String text, {DateTime? now}) {
    var clean = text.trim();
    if (clean.isEmpty) return null;

    // Normalize compacted day+month without spaces: "1August" -> "1 August", "04Sept" -> "04 Sept"
    clean = clean.replaceAllMapped(
      RegExp(r'(\d{1,2})([A-Za-z]{3,9})'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );
    // Also compacted month+day: "August1" -> "August 1", "Sep07" -> "Sep 07"
    clean = clean.replaceAllMapped(
      RegExp(r'([A-Za-z]{3,9})(\d{1,2})'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );

    final lower = clean.toLowerCase();
    final baseTime = now ?? DateTime.now();

    // 1. Relative dates: "8 hours ago", "1 day ago", "2 days ago", "yesterday", "today"
    final hoursAgoMatch = RegExp(
      r'(\d+)\s+hours?\s+ago',
      caseSensitive: false,
    ).firstMatch(lower);
    if (hoursAgoMatch != null) {
      final hours = int.tryParse(hoursAgoMatch.group(1)!);
      if (hours != null) {
        final d = baseTime.subtract(Duration(hours: hours));
        return DateExtractionResult(
          date: d,
          hasExplicitYear: true,
          isRelative: true,
          rawMatchedText: hoursAgoMatch.group(0)!,
        );
      }
    }

    final daysAgoMatch = RegExp(
      r'(\d+)\s+days?\s+ago',
      caseSensitive: false,
    ).firstMatch(lower);
    if (daysAgoMatch != null) {
      final days = int.tryParse(daysAgoMatch.group(1)!);
      if (days != null) {
        final d = baseTime.subtract(Duration(days: days));
        return DateExtractionResult(
          date: DateTime(d.year, d.month, d.day),
          hasExplicitYear: true,
          isRelative: true,
          rawMatchedText: daysAgoMatch.group(0)!,
        );
      }
    }

    if (RegExp(r'\byesterday\b', caseSensitive: false).hasMatch(lower)) {
      final y = baseTime.subtract(const Duration(days: 1));
      return DateExtractionResult(
        date: DateTime(y.year, y.month, y.day),
        hasExplicitYear: true,
        isRelative: true,
        rawMatchedText: 'yesterday',
      );
    }

    if (RegExp(r'\btoday\b', caseSensitive: false).hasMatch(lower)) {
      return DateExtractionResult(
        date: DateTime(baseTime.year, baseTime.month, baseTime.day),
        hasExplicitYear: true,
        isRelative: true,
        rawMatchedText: 'today',
      );
    }

    // 2. Full Date with Time: "2 September 2026 at 2:35 pm" or "2 September 2026 2:35pm"
    final fullDateTimeMatch = RegExp(
      r'(\d{1,2})\s*([A-Za-z]{3,9})\s+(\d{4})(?:\s+at)?\s+(\d{1,2}):(\d{2})\s*(am|pm)?',
      caseSensitive: false,
    ).firstMatch(clean);

    if (fullDateTimeMatch != null) {
      final day = int.tryParse(fullDateTimeMatch.group(1)!);
      final monthStr = fullDateTimeMatch.group(2)!.toLowerCase();
      final year = int.tryParse(fullDateTimeMatch.group(3)!);
      var hour = int.tryParse(fullDateTimeMatch.group(4)!);
      final minute = int.tryParse(fullDateTimeMatch.group(5)!);
      final ampm = fullDateTimeMatch.group(6)?.toLowerCase();

      final month = _monthMap[monthStr];
      if (day != null &&
          month != null &&
          year != null &&
          hour != null &&
          minute != null) {
        if (ampm == 'pm' && hour < 12) hour += 12;
        if (ampm == 'am' && hour == 12) hour = 0;
        return DateExtractionResult(
          date: DateTime(year, month, day, hour, minute),
          hasExplicitYear: true,
          isRelative: false,
          rawMatchedText: fullDateTimeMatch.group(0)!,
        );
      }
    }

    // 3. Format: "07 Sep 2026" or "7 September 2026" (with year)
    final dMmmYMatch = RegExp(
      r'(\d{1,2})\s*([A-Za-z]{3,9})[,.]?\s+(\d{4})',
    ).firstMatch(clean);
    if (dMmmYMatch != null) {
      final day = int.tryParse(dMmmYMatch.group(1)!);
      final month = _monthMap[dMmmYMatch.group(2)!.toLowerCase()];
      final year = int.tryParse(dMmmYMatch.group(3)!);
      if (day != null &&
          month != null &&
          year != null &&
          _isValidDate(year, month, day)) {
        return DateExtractionResult(
          date: DateTime(year, month, day),
          hasExplicitYear: true,
          isRelative: false,
          rawMatchedText: dMmmYMatch.group(0)!,
        );
      }
    }

    // 4. Format: "07/09/2026" or "07-09-2026" (DD/MM/YYYY)
    final slashMatch = RegExp(
      r'(\d{1,2})[/-](\d{1,2})[/-](\d{4})',
    ).firstMatch(clean);
    if (slashMatch != null) {
      final day = int.tryParse(slashMatch.group(1)!);
      final month = int.tryParse(slashMatch.group(2)!);
      final year = int.tryParse(slashMatch.group(3)!);
      if (day != null &&
          month != null &&
          year != null &&
          _isValidDate(year, month, day)) {
        return DateExtractionResult(
          date: DateTime(year, month, day),
          hasExplicitYear: true,
          isRelative: false,
          rawMatchedText: slashMatch.group(0)!,
        );
      }
    }

    // 5. Layout A date without year: "7 September", "6 September", "04 Sept", "02 Sept", "7 Sep", "1August"
    final dMmmMatch = RegExp(
      r'(\d{1,2})\s*([A-Za-z]{3,9})\b',
    ).firstMatch(clean);
    if (dMmmMatch != null) {
      final day = int.tryParse(dMmmMatch.group(1)!);
      final monthStr = dMmmMatch.group(2)!.toLowerCase();
      final month = _monthMap[monthStr];
      if (day != null && month != null) {
        var year = baseTime.year;
        final testDate = DateTime(year, month, day);
        if (testDate.isAfter(baseTime.add(const Duration(days: 1)))) {
          year--;
        }
        if (_isValidDate(year, month, day)) {
          return DateExtractionResult(
            date: DateTime(year, month, day),
            hasExplicitYear: false,
            isRelative: false,
            rawMatchedText: dMmmMatch.group(0)!,
          );
        }
      }
    }

    // 6. Format: "Sep 07" or "September 7" or "Sep07"
    final mmmDMatch = RegExp(
      r'([A-Za-z]{3,9})\s*(\d{1,2})\b',
    ).firstMatch(clean);
    if (mmmDMatch != null) {
      final monthStr = mmmDMatch.group(1)!.toLowerCase();
      final month = _monthMap[monthStr];
      final day = int.tryParse(mmmDMatch.group(2)!);
      if (day != null && month != null) {
        var year = baseTime.year;
        final testDate = DateTime(year, month, day);
        if (testDate.isAfter(baseTime.add(const Duration(days: 1)))) {
          year--;
        }
        if (_isValidDate(year, month, day)) {
          return DateExtractionResult(
            date: DateTime(year, month, day),
            hasExplicitYear: false,
            isRelative: false,
            rawMatchedText: mmmDMatch.group(0)!,
          );
        }
      }
    }

    return null;
  }

  static bool _isValidDate(int y, int m, int d) {
    if (y < 2000 || y > 2099) return false;
    if (m < 1 || m > 12) return false;
    if (d < 1 || d > 31) return false;
    return true;
  }
}
