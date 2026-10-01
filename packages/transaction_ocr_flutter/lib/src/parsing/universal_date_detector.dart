/// Result of universal date / time detection on an OCR token.
class DateDetectionResult {
  final bool isDate;
  final bool isTime;
  final bool isDateTime;
  final DateTime? date;
  final String normalizedText;
  final double confidence;
  final bool hasExplicitYear;

  const DateDetectionResult({
    required this.isDate,
    required this.isTime,
    required this.isDateTime,
    this.date,
    required this.normalizedText,
    required this.confidence,
    this.hasExplicitYear = false,
  });

  bool get isAny => isDate || isTime || isDateTime;
}

/// Universal date and time parser and detector.
///
/// Designed to classify dates and timestamps BEFORE amount parsing, ensuring
/// that tokens such as "16:48", "14:22:05", "2:30 PM", "4 September", "1Aug"
/// are never misinterpreted as financial amounts.
class UniversalDateDetector {
  static const Map<String, int> _monthMap = {
    'jan': 1, 'january': 1,
    'feb': 2, 'february': 2,
    'mar': 3, 'march': 3,
    'apr': 4, 'april': 4,
    'may': 5,
    'jun': 6, 'june': 6,
    'jul': 7, 'july': 7,
    'aug': 8, 'august': 8,
    'sep': 9, 'sept': 9, 'september': 9,
    'oct': 10, 'october': 10,
    'nov': 11, 'november': 11,
    'dec': 12, 'december': 12,
  };

  // Pure time patterns (e.g. "14:22", "14:22:05", "2:30 PM", "08:56?", "10:42 AM")
  static final RegExp _rePureTime = RegExp(
    r'^\s*(?:at\s+)?(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([ap]m)?\s*\??\s*$',
    caseSensitive: false,
  );

  // Compact alphanumeric date (e.g. "1Aug", "2September", "18Sep2026", "02Sept")
  static final RegExp _reCompactDate = RegExp(
    r'^\s*(\d{1,2})\s*([a-z]{3,9})\s*(\d{2,4})?\s*$',
    caseSensitive: false,
  );

  // Month first or month-year (e.g. "September 2026", "September 18, 2026")
  static final RegExp _reMonthFirst = RegExp(
    r'^\s*([a-z]{3,9})\s+(\d{1,2})(?:st|nd|rd|th)?(?:\s*,?\s*(\d{2,4}))?\s*$',
    caseSensitive: false,
  );

  // Numeric separated dates: 18/09/2026, 18-09-2026, 18.09.2026, 2026-09-18, 09/18/2026
  static final RegExp _reNumericDate = RegExp(
    r'^\s*(\d{1,4})[\/\-\.](\d{1,2})[\/\-\.](\d{1,4})\s*$',
  );

  // Relative dates: Today, Yesterday, "Today, 10:42 AM", "Yesterday, 7:20 PM", "2 hours ago"
  static final RegExp _reRelative = RegExp(
    r'^\s*(today|yesterday)(?:(?:\s+at|\s*,)?\s*(\d{1,2}:\d{2}(?::\d{2})?\s*[ap]m?))?\s*$',
    caseSensitive: false,
  );

  static final RegExp _reRelativeAgo = RegExp(
    r'^\s*\d+\s*(?:sec|secs|second|seconds|min|mins|minute|minutes|hr|hrs|hour|hours|day|days|week|weeks|month|months)\s+ago\s*$',
    caseSensitive: false,
  );

  // Full compound date-time: "18 Sep, 2:30 PM", "18 September 2026 at 2:30 PM", "paid on 18 Sep"
  static final RegExp _reCompoundDateTime = RegExp(
    r'^\s*(?:paid\s+on|debited\s+on|credited\s+on|received\s+on|transferred\s+on|on\s+)?'
    r'(\d{1,2})\s+([a-z]{3,9})(?:\s*,?\s*(\d{2,4}))?'
    r'(?:(?:\s+at|\s*,)\s*(\d{1,2}:\d{2}(?::\d{2})?\s*[ap]?m?))?\s*$',
    caseSensitive: false,
  );

  /// Tests if [text] represents a date, time, or datetime token.
  static DateDetectionResult detect(String? text, {DateTime? referenceTime}) {
    if (text == null || text.trim().isEmpty) {
      return const DateDetectionResult(
        isDate: false,
        isTime: false,
        isDateTime: false,
        normalizedText: '',
        confidence: 0.0,
      );
    }

    final trimmed = text.trim();
    final now = referenceTime ?? DateTime.now();

    // 1. Pure Time
    final timeMatch = _rePureTime.firstMatch(trimmed);
    if (timeMatch != null) {
      final hourStr = timeMatch.group(1)!;
      final minStr = timeMatch.group(2)!;
      final secStr = timeMatch.group(3);
      final ampm = timeMatch.group(4)?.toLowerCase();

      var hour = int.tryParse(hourStr) ?? 0;
      final minute = int.tryParse(minStr) ?? 0;
      final second = secStr != null ? (int.tryParse(secStr) ?? 0) : 0;

      if (ampm != null) {
        if (ampm.startsWith('p') && hour < 12) hour += 12;
        if (ampm.startsWith('a') && hour == 12) hour = 0;
      }

      if (hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
        final dt = DateTime(now.year, now.month, now.day, hour, minute, second);
        return DateDetectionResult(
          isDate: false,
          isTime: true,
          isDateTime: false,
          date: dt,
          normalizedText: trimmed,
          confidence: 0.95,
        );
      }
    }

    // 2. Relative time ("2 hours ago", "1 day ago")
    if (_reRelativeAgo.hasMatch(trimmed)) {
      return DateDetectionResult(
        isDate: true,
        isTime: false,
        isDateTime: true,
        date: now,
        normalizedText: trimmed,
        confidence: 0.90,
      );
    }

    // 3. Relative Date ("Today", "Yesterday", "Today, 10:42 AM")
    final relMatch = _reRelative.firstMatch(trimmed);
    if (relMatch != null) {
      final keyword = relMatch.group(1)!.toLowerCase();
      var baseDate = keyword == 'yesterday'
          ? now.subtract(const Duration(days: 1))
          : now;

      final timePart = relMatch.group(2);
      bool hasTime = false;
      if (timePart != null) {
        final tRes = _parseTimeString(timePart, baseDate);
        if (tRes != null) {
          baseDate = tRes;
          hasTime = true;
        }
      }

      return DateDetectionResult(
        isDate: true,
        isTime: hasTime,
        isDateTime: hasTime,
        date: baseDate,
        normalizedText: trimmed,
        confidence: 0.95,
      );
    }

    // 4. Compact alphanumeric (e.g. "1Aug", "2September", "18Sep2026", "02Sept")
    final compactMatch = _reCompactDate.firstMatch(trimmed);
    if (compactMatch != null) {
      final day = int.tryParse(compactMatch.group(1)!);
      final monthKey = compactMatch.group(2)!.toLowerCase();
      final yearStr = compactMatch.group(3);

      final month = _resolveMonth(monthKey);
      if (day != null && month != null && day >= 1 && day <= 31) {
        final year = _resolveYear(yearStr, now.year);
        final dt = DateTime(year, month, day);
        return DateDetectionResult(
          isDate: true,
          isTime: false,
          isDateTime: false,
          date: dt,
          normalizedText: trimmed,
          confidence: 0.95,
          hasExplicitYear: yearStr != null,
        );
      }
    }

    // 5. Month first (e.g. "September 18, 2026")
    final monthFirstMatch = _reMonthFirst.firstMatch(trimmed);
    if (monthFirstMatch != null) {
      final month = _resolveMonth(monthFirstMatch.group(1)!.toLowerCase());
      final day = int.tryParse(monthFirstMatch.group(2)!);
      final yearStr = monthFirstMatch.group(3);
      if (month != null && day != null && day >= 1 && day <= 31) {
        final year = _resolveYear(yearStr, now.year);
        return DateDetectionResult(
          isDate: true,
          isTime: false,
          isDateTime: false,
          date: DateTime(year, month, day),
          normalizedText: trimmed,
          confidence: 0.95,
          hasExplicitYear: yearStr != null,
        );
      }
    }

    // 6. Compound Date Time (e.g. "18 Sep, 2:30 PM", "18 September 2026")
    final compoundMatch = _reCompoundDateTime.firstMatch(trimmed);
    if (compoundMatch != null) {
      final day = int.tryParse(compoundMatch.group(1)!);
      final month = _resolveMonth(compoundMatch.group(2)!.toLowerCase());
      final yearStr = compoundMatch.group(3);
      final timeStr = compoundMatch.group(4);

      if (day != null && month != null && day >= 1 && day <= 31) {
        final year = _resolveYear(yearStr, now.year);
        var dt = DateTime(year, month, day);
        bool hasTime = false;
        if (timeStr != null) {
          final tRes = _parseTimeString(timeStr, dt);
          if (tRes != null) {
            dt = tRes;
            hasTime = true;
          }
        }

        return DateDetectionResult(
          isDate: true,
          isTime: hasTime,
          isDateTime: hasTime,
          date: dt,
          normalizedText: trimmed,
          confidence: 0.95,
          hasExplicitYear: yearStr != null,
        );
      }
    }

    // 7. Numeric date formats: DD/MM/YYYY, YYYY-MM-DD, MM/DD/YYYY, DD.MM.YYYY
    final numMatch = _reNumericDate.firstMatch(trimmed);
    if (numMatch != null) {
      final p1 = int.tryParse(numMatch.group(1)!);
      final p2 = int.tryParse(numMatch.group(2)!);
      final p3 = int.tryParse(numMatch.group(3)!);

      if (p1 != null && p2 != null && p3 != null) {
        // Check YYYY-MM-DD
        if (p1 > 1000 && p2 >= 1 && p2 <= 12 && p3 >= 1 && p3 <= 31) {
          return DateDetectionResult(
            isDate: true,
            isTime: false,
            isDateTime: false,
            date: DateTime(p1, p2, p3),
            normalizedText: trimmed,
            confidence: 0.95,
            hasExplicitYear: true,
          );
        }
        // Check DD/MM/YYYY or DD-MM-YYYY
        final year = p3 > 100 ? p3 : (p3 < 50 ? 2000 + p3 : 1900 + p3);
        if (p1 >= 1 && p1 <= 31 && p2 >= 1 && p2 <= 12) {
          return DateDetectionResult(
            isDate: true,
            isTime: false,
            isDateTime: false,
            date: DateTime(year, p2, p1),
            normalizedText: trimmed,
            confidence: 0.90,
            hasExplicitYear: true,
          );
        }
      }
    }

    return const DateDetectionResult(
      isDate: false,
      isTime: false,
      isDateTime: false,
      normalizedText: '',
      confidence: 0.0,
    );
  }

  static int? _resolveMonth(String key) {
    if (_monthMap.containsKey(key)) return _monthMap[key];
    for (final entry in _monthMap.entries) {
      if (key.startsWith(entry.key) || entry.key.startsWith(key)) {
        return entry.value;
      }
    }
    return null;
  }

  static int _resolveYear(String? yearStr, int currentYear) {
    if (yearStr == null) return currentYear;
    final y = int.tryParse(yearStr);
    if (y == null) return currentYear;
    if (y < 100) return 2000 + y;
    return y;
  }

  static DateTime? _parseTimeString(String timeStr, DateTime base) {
    final m = _rePureTime.firstMatch(timeStr.trim());
    if (m == null) return null;
    final hStr = m.group(1)!;
    final minStr = m.group(2)!;
    final sStr = m.group(3);
    final ampm = m.group(4)?.toLowerCase();

    var hour = int.tryParse(hStr) ?? 0;
    final min = int.tryParse(minStr) ?? 0;
    final sec = sStr != null ? (int.tryParse(sStr) ?? 0) : 0;

    if (ampm != null) {
      if (ampm.startsWith('p') && hour < 12) hour += 12;
      if (ampm.startsWith('a') && hour == 12) hour = 0;
    }

    return DateTime(base.year, base.month, base.day, hour, min, sec);
  }
}
