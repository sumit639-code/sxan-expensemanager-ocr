import 'package:intl/intl.dart';

/// Predefined time periods supported by the Analysis dashboard.
enum AnalysisPeriodType {
  today('Today'),
  thisWeek('This Week'),
  thisMonth('This Month'),
  lastMonth('Last Month'),
  last3Months('Last 3 Months'),
  thisYear('This Year'),
  custom('Custom Range');

  final String label;
  const AnalysisPeriodType(this.label);
}

/// Represents the selected period and holds date ranges for current and previous equivalent period.
class AnalysisPeriod {
  final AnalysisPeriodType type;
  final DateTime startDate;
  final DateTime endDate;

  const AnalysisPeriod({
    required this.type,
    required this.startDate,
    required this.endDate,
  });

  /// Formatted display label for the period selector button.
  String get displayLabel {
    switch (type) {
      case AnalysisPeriodType.today:
        return 'Today';
      case AnalysisPeriodType.thisWeek:
        return 'This Week';
      case AnalysisPeriodType.thisMonth:
        return 'This Month';
      case AnalysisPeriodType.lastMonth:
        return 'Last Month';
      case AnalysisPeriodType.last3Months:
        return 'Last 3 Months';
      case AnalysisPeriodType.thisYear:
        return 'This Year';
      case AnalysisPeriodType.custom:
        final df = DateFormat('MMM d, yyyy');
        return '${df.format(startDate)} – ${df.format(endDate)}';
    }
  }

  /// Creates an [AnalysisPeriod] for a given [AnalysisPeriodType] relative to [referenceDate].
  factory AnalysisPeriod.fromType(
    AnalysisPeriodType type, {
    DateTime? referenceDate,
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final now = referenceDate ?? DateTime.now();
    switch (type) {
      case AnalysisPeriodType.today:
        final start = DateTime(now.year, now.month, now.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return AnalysisPeriod(type: type, startDate: start, endDate: end);

      case AnalysisPeriodType.thisWeek:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        final end = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + 6, 23, 59, 59, 999);
        return AnalysisPeriod(type: type, startDate: start, endDate: end);

      case AnalysisPeriodType.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final lastDay = DateTime(now.year, now.month + 1, 0).day;
        final end = DateTime(now.year, now.month, lastDay, 23, 59, 59, 999);
        return AnalysisPeriod(type: type, startDate: start, endDate: end);

      case AnalysisPeriodType.lastMonth:
        final prevMonth = DateTime(now.year, now.month - 1, 1);
        final start = DateTime(prevMonth.year, prevMonth.month, 1);
        final lastDay = DateTime(prevMonth.year, prevMonth.month + 1, 0).day;
        final end = DateTime(prevMonth.year, prevMonth.month, lastDay, 23, 59, 59, 999);
        return AnalysisPeriod(type: type, startDate: start, endDate: end);

      case AnalysisPeriodType.last3Months:
        final startMonth = DateTime(now.year, now.month - 2, 1);
        final start = DateTime(startMonth.year, startMonth.month, 1);
        final lastDay = DateTime(now.year, now.month + 1, 0).day;
        final end = DateTime(now.year, now.month, lastDay, 23, 59, 59, 999);
        return AnalysisPeriod(type: type, startDate: start, endDate: end);

      case AnalysisPeriodType.thisYear:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year, 12, 31, 23, 59, 59, 999);
        return AnalysisPeriod(type: type, startDate: start, endDate: end);

      case AnalysisPeriodType.custom:
        final start = customStart ?? DateTime(now.year, now.month, 1);
        final end = customEnd ?? DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return AnalysisPeriod(type: type, startDate: start, endDate: end);
    }
  }

  /// Calculates the corresponding previous equivalent period for deterministic comparison.
  AnalysisPeriod getPreviousEquivalentPeriod() {
    switch (type) {
      case AnalysisPeriodType.today:
        final prevDay = startDate.subtract(const Duration(days: 1));
        return AnalysisPeriod(
          type: type,
          startDate: DateTime(prevDay.year, prevDay.month, prevDay.day),
          endDate: DateTime(prevDay.year, prevDay.month, prevDay.day, 23, 59, 59, 999),
        );

      case AnalysisPeriodType.thisWeek:
        final prevWeekStart = startDate.subtract(const Duration(days: 7));
        final prevWeekEnd = endDate.subtract(const Duration(days: 7));
        return AnalysisPeriod(
          type: type,
          startDate: prevWeekStart,
          endDate: prevWeekEnd,
        );

      case AnalysisPeriodType.thisMonth:
        final prevMonthDate = DateTime(startDate.year, startDate.month - 1, 1);
        final lastDay = DateTime(prevMonthDate.year, prevMonthDate.month + 1, 0).day;
        return AnalysisPeriod(
          type: type,
          startDate: DateTime(prevMonthDate.year, prevMonthDate.month, 1),
          endDate: DateTime(prevMonthDate.year, prevMonthDate.month, lastDay, 23, 59, 59, 999),
        );

      case AnalysisPeriodType.lastMonth:
        final prevMonthDate = DateTime(startDate.year, startDate.month - 1, 1);
        final lastDay = DateTime(prevMonthDate.year, prevMonthDate.month + 1, 0).day;
        return AnalysisPeriod(
          type: type,
          startDate: DateTime(prevMonthDate.year, prevMonthDate.month, 1),
          endDate: DateTime(prevMonthDate.year, prevMonthDate.month, lastDay, 23, 59, 59, 999),
        );

      case AnalysisPeriodType.last3Months:
        final prevPeriodStart = DateTime(startDate.year, startDate.month - 3, 1);
        final prevPeriodEnd = DateTime(startDate.year, startDate.month, 0, 23, 59, 59, 999);
        return AnalysisPeriod(
          type: type,
          startDate: prevPeriodStart,
          endDate: prevPeriodEnd,
        );

      case AnalysisPeriodType.thisYear:
        return AnalysisPeriod(
          type: type,
          startDate: DateTime(startDate.year - 1, 1, 1),
          endDate: DateTime(startDate.year - 1, 12, 31, 23, 59, 59, 999),
        );

      case AnalysisPeriodType.custom:
        final duration = endDate.difference(startDate);
        final prevEnd = startDate.subtract(const Duration(milliseconds: 1));
        final prevStart = prevEnd.subtract(duration);
        return AnalysisPeriod(
          type: type,
          startDate: prevStart,
          endDate: prevEnd,
        );
    }
  }
}
