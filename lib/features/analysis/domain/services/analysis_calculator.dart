import 'package:intl/intl.dart';

import 'package:expense_app/core/constants/category_constants.dart';
import 'package:expense_app/features/transactions/domain/entities/transaction_entity.dart';
import 'package:expense_app/shared/enums/transaction_enums.dart';
import '../entities/analysis_data.dart';
import '../entities/analysis_period.dart';

/// Pure deterministic calculator for financial analytics from SQLite transactions.
class AnalysisCalculator {
  AnalysisCalculator._();

  static AnalysisData calculate({
    required List<Transaction> allTransactions,
    required AnalysisPeriod period,
    DateTime? referenceDate,
  }) {
    // 1. Filter transactions for the current period
    final currentTx = allTransactions.where((tx) {
      return !tx.date.isBefore(period.startDate) && !tx.date.isAfter(period.endDate);
    }).toList();

    // 2. Filter transactions for previous equivalent period
    final previousPeriod = period.getPreviousEquivalentPeriod();
    final prevTx = allTransactions.where((tx) {
      return !tx.date.isBefore(previousPeriod.startDate) &&
          !tx.date.isAfter(previousPeriod.endDate);
    }).toList();

    // 3. Compute Metrics
    int totalIncome = 0;
    int totalExpense = 0;
    int incomeCount = 0;
    int expenseCount = 0;
    int largestExpense = 0;
    int largestIncome = 0;
    Transaction? largestExpenseTx;

    for (final tx in currentTx) {
      if (tx.type == TransactionType.income) {
        totalIncome += tx.amount;
        incomeCount++;
        if (tx.amount > largestIncome) {
          largestIncome = tx.amount;
        }
      } else {
        totalExpense += tx.amount;
        expenseCount++;
        if (tx.amount > largestExpense) {
          largestExpense = tx.amount;
          largestExpenseTx = tx;
        }
      }
    }

    final netMinor = totalIncome - totalExpense;
    final avgExpenseMinor = expenseCount > 0 ? (totalExpense / expenseCount).round() : 0;

    final metrics = AnalysisMetrics(
      totalIncomeMinor: totalIncome,
      totalExpenseMinor: totalExpense,
      netMinor: netMinor,
      expenseCount: expenseCount,
      incomeCount: incomeCount,
      avgExpenseMinor: avgExpenseMinor,
      largestExpenseMinor: largestExpense,
      largestIncomeMinor: largestIncome,
      largestExpenseTransaction: largestExpenseTx,
    );

    // 4. Compute Comparison
    int prevIncome = 0;
    int prevExpense = 0;
    for (final tx in prevTx) {
      if (tx.type == TransactionType.income) {
        prevIncome += tx.amount;
      } else {
        prevExpense += tx.amount;
      }
    }

    final comparison = _calculateComparison(
      currentExpense: totalExpense,
      prevExpense: prevExpense,
      currentIncome: totalIncome,
      prevIncome: prevIncome,
      hasPrevTransactions: prevTx.isNotEmpty,
      periodType: period.type,
    );

    // 5. Compute Trend Buckets
    final trendBuckets = _calculateTrendBuckets(
      currentTx: currentTx,
      period: period,
    );

    // 6. Compute Category Breakdown
    final categoryBreakdown = _calculateCategoryBreakdown(
      currentTx: currentTx,
      totalExpense: totalExpense,
    );

    // 7. Top Expenses
    final expensesOnly = currentTx
        .where((tx) => tx.type == TransactionType.expense)
        .toList();
    expensesOnly.sort((a, b) => b.amount.compareTo(a.amount));
    final topExpenses = expensesOnly.take(5).toList();

    // 8. Rule-Based Insights
    final insights = _generateDeterministicInsights(
      metrics: metrics,
      comparison: comparison,
      categoryBreakdown: categoryBreakdown,
      topExpenses: topExpenses,
      currentTx: currentTx,
      period: period,
    );

    return AnalysisData(
      period: period,
      metrics: metrics,
      comparison: comparison,
      trendBuckets: trendBuckets,
      categoryBreakdown: categoryBreakdown,
      topExpenses: topExpenses,
      insights: insights,
      periodTransactions: currentTx,
    );
  }

  static PeriodComparison _calculateComparison({
    required int currentExpense,
    required int prevExpense,
    required int currentIncome,
    required int prevIncome,
    required bool hasPrevTransactions,
    required AnalysisPeriodType periodType,
  }) {
    final periodWord = _getPeriodWord(periodType);

    if (!hasPrevTransactions && prevExpense == 0 && prevIncome == 0 && currentExpense == 0 && currentIncome == 0) {
      return const PeriodComparison(
        prevTotalIncomeMinor: 0,
        prevTotalExpenseMinor: 0,
        expensePercentageChange: null,
        expenseComparisonText: 'No previous period data',
        isExpenseHigher: false,
        isRoughlyUnchanged: true,
        hasPreviousData: false,
      );
    }

    if (prevExpense == 0) {
      if (currentExpense == 0) {
        return PeriodComparison(
          prevTotalIncomeMinor: prevIncome,
          prevTotalExpenseMinor: 0,
          expensePercentageChange: 0,
          expenseComparisonText: 'Unchanged vs $periodWord',
          isExpenseHigher: false,
          isRoughlyUnchanged: true,
          hasPreviousData: true,
        );
      } else {
        final diffMajor = (currentExpense / 100).toStringAsFixed(0);
        return PeriodComparison(
          prevTotalIncomeMinor: prevIncome,
          prevTotalExpenseMinor: 0,
          expensePercentageChange: null,
          expenseComparisonText: '₹$diffMajor more than $periodWord',
          isExpenseHigher: true,
          isRoughlyUnchanged: false,
          hasPreviousData: true,
        );
      }
    }

    final diff = currentExpense - prevExpense;
    final pct = (diff / prevExpense) * 100;

    if (pct.abs() < 1.0) {
      return PeriodComparison(
        prevTotalIncomeMinor: prevIncome,
        prevTotalExpenseMinor: prevExpense,
        expensePercentageChange: pct,
        expenseComparisonText: 'Roughly unchanged vs $periodWord',
        isExpenseHigher: false,
        isRoughlyUnchanged: true,
        hasPreviousData: true,
      );
    } else if (pct > 0) {
      return PeriodComparison(
        prevTotalIncomeMinor: prevIncome,
        prevTotalExpenseMinor: prevExpense,
        expensePercentageChange: pct,
        expenseComparisonText: '${pct.toStringAsFixed(1)}% higher than $periodWord',
        isExpenseHigher: true,
        isRoughlyUnchanged: false,
        hasPreviousData: true,
      );
    } else {
      return PeriodComparison(
        prevTotalIncomeMinor: prevIncome,
        prevTotalExpenseMinor: prevExpense,
        expensePercentageChange: pct,
        expenseComparisonText: '${pct.abs().toStringAsFixed(1)}% lower than $periodWord',
        isExpenseHigher: false,
        isRoughlyUnchanged: false,
        hasPreviousData: true,
      );
    }
  }

  static String _getPeriodWord(AnalysisPeriodType type) {
    switch (type) {
      case AnalysisPeriodType.today:
        return 'yesterday';
      case AnalysisPeriodType.thisWeek:
        return 'last week';
      case AnalysisPeriodType.thisMonth:
        return 'last month';
      case AnalysisPeriodType.lastMonth:
        return 'previous month';
      case AnalysisPeriodType.last3Months:
        return 'previous 3 months';
      case AnalysisPeriodType.thisYear:
        return 'last year';
      case AnalysisPeriodType.custom:
        return 'previous period';
    }
  }

  static List<TrendBucket> _calculateTrendBuckets({
    required List<Transaction> currentTx,
    required AnalysisPeriod period,
  }) {
    final List<TrendBucket> buckets = [];

    switch (period.type) {
      case AnalysisPeriodType.today:
        // 6 4-hour buckets: 00:00, 04:00, 08:00, 12:00, 16:00, 20:00
        for (int i = 0; i < 6; i++) {
          final startH = i * 4;
          final bStart = DateTime(
            period.startDate.year,
            period.startDate.month,
            period.startDate.day,
            startH,
          );
          final bEnd = DateTime(
            period.startDate.year,
            period.startDate.month,
            period.startDate.day,
            startH + 3,
            59,
            59,
            999,
          );

          int exp = 0;
          int inc = 0;
          for (final tx in currentTx) {
            if (!tx.date.isBefore(bStart) && !tx.date.isAfter(bEnd)) {
              if (tx.type == TransactionType.expense) exp += tx.amount;
              if (tx.type == TransactionType.income) inc += tx.amount;
            }
          }

          buckets.add(
            TrendBucket(
              label: '${startH.toString().padLeft(2, '0')}:00',
              date: bStart,
              expenseMinor: exp,
              incomeMinor: inc,
            ),
          );
        }
        break;

      case AnalysisPeriodType.thisWeek:
        // 7 daily buckets (Mon..Sun)
        final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        for (int i = 0; i < 7; i++) {
          final bDate = period.startDate.add(Duration(days: i));
          final bStart = DateTime(bDate.year, bDate.month, bDate.day);
          final bEnd = DateTime(bDate.year, bDate.month, bDate.day, 23, 59, 59, 999);

          int exp = 0;
          int inc = 0;
          for (final tx in currentTx) {
            if (!tx.date.isBefore(bStart) && !tx.date.isAfter(bEnd)) {
              if (tx.type == TransactionType.expense) exp += tx.amount;
              if (tx.type == TransactionType.income) inc += tx.amount;
            }
          }

          buckets.add(
            TrendBucket(
              label: weekdays[i],
              date: bStart,
              expenseMinor: exp,
              incomeMinor: inc,
            ),
          );
        }
        break;

      case AnalysisPeriodType.thisMonth:
      case AnalysisPeriodType.lastMonth:
        // 4 weekly buckets: Days 1-7, 8-14, 15-21, 22-end
        final totalDays = period.endDate.day;
        final intervals = [
          [1, 7],
          [8, 14],
          [15, 21],
          [22, totalDays],
        ];

        for (int i = 0; i < intervals.length; i++) {
          final sDay = intervals[i][0];
          final eDay = intervals[i][1];
          final bStart = DateTime(period.startDate.year, period.startDate.month, sDay);
          final bEnd = DateTime(period.startDate.year, period.startDate.month, eDay, 23, 59, 59, 999);

          int exp = 0;
          int inc = 0;
          for (final tx in currentTx) {
            if (!tx.date.isBefore(bStart) && !tx.date.isAfter(bEnd)) {
              if (tx.type == TransactionType.expense) exp += tx.amount;
              if (tx.type == TransactionType.income) inc += tx.amount;
            }
          }

          buckets.add(
            TrendBucket(
              label: 'W${i + 1} ($sDay-$eDay)',
              date: bStart,
              expenseMinor: exp,
              incomeMinor: inc,
            ),
          );
        }
        break;

      case AnalysisPeriodType.last3Months:
        // 3 monthly buckets
        for (int i = 0; i < 3; i++) {
          final mDate = DateTime(period.startDate.year, period.startDate.month + i, 1);
          final lastDay = DateTime(mDate.year, mDate.month + 1, 0).day;
          final bStart = DateTime(mDate.year, mDate.month, 1);
          final bEnd = DateTime(mDate.year, mDate.month, lastDay, 23, 59, 59, 999);

          int exp = 0;
          int inc = 0;
          for (final tx in currentTx) {
            if (!tx.date.isBefore(bStart) && !tx.date.isAfter(bEnd)) {
              if (tx.type == TransactionType.expense) exp += tx.amount;
              if (tx.type == TransactionType.income) inc += tx.amount;
            }
          }

          buckets.add(
            TrendBucket(
              label: DateFormat('MMM').format(bStart),
              date: bStart,
              expenseMinor: exp,
              incomeMinor: inc,
            ),
          );
        }
        break;

      case AnalysisPeriodType.thisYear:
        // 12 monthly buckets
        for (int m = 1; m <= 12; m++) {
          final bStart = DateTime(period.startDate.year, m, 1);
          final lastDay = DateTime(period.startDate.year, m + 1, 0).day;
          final bEnd = DateTime(period.startDate.year, m, lastDay, 23, 59, 59, 999);

          int exp = 0;
          int inc = 0;
          for (final tx in currentTx) {
            if (!tx.date.isBefore(bStart) && !tx.date.isAfter(bEnd)) {
              if (tx.type == TransactionType.expense) exp += tx.amount;
              if (tx.type == TransactionType.income) inc += tx.amount;
            }
          }

          buckets.add(
            TrendBucket(
              label: DateFormat('MMM').format(bStart),
              date: bStart,
              expenseMinor: exp,
              incomeMinor: inc,
            ),
          );
        }
        break;

      case AnalysisPeriodType.custom:
        final days = period.endDate.difference(period.startDate).inDays + 1;
        if (days <= 10) {
          // Daily buckets
          for (int i = 0; i < days; i++) {
            final bDate = period.startDate.add(Duration(days: i));
            final bStart = DateTime(bDate.year, bDate.month, bDate.day);
            final bEnd = DateTime(bDate.year, bDate.month, bDate.day, 23, 59, 59, 999);

            int exp = 0;
            int inc = 0;
            for (final tx in currentTx) {
              if (!tx.date.isBefore(bStart) && !tx.date.isAfter(bEnd)) {
                if (tx.type == TransactionType.expense) exp += tx.amount;
                if (tx.type == TransactionType.income) inc += tx.amount;
              }
            }

            buckets.add(
              TrendBucket(
                label: DateFormat('d MMM').format(bStart),
                date: bStart,
                expenseMinor: exp,
                incomeMinor: inc,
              ),
            );
          }
        } else {
          // 4 equal chunks
          final chunkDays = (days / 4).ceil();
          for (int i = 0; i < 4; i++) {
            final bStart = period.startDate.add(Duration(days: i * chunkDays));
            var bEnd = period.startDate.add(Duration(days: (i + 1) * chunkDays - 1, hours: 23, minutes: 59, seconds: 59));
            if (bEnd.isAfter(period.endDate)) bEnd = period.endDate;

            int exp = 0;
            int inc = 0;
            for (final tx in currentTx) {
              if (!tx.date.isBefore(bStart) && !tx.date.isAfter(bEnd)) {
                if (tx.type == TransactionType.expense) exp += tx.amount;
                if (tx.type == TransactionType.income) inc += tx.amount;
              }
            }

            buckets.add(
              TrendBucket(
                label: DateFormat('d MMM').format(bStart),
                date: bStart,
                expenseMinor: exp,
                incomeMinor: inc,
              ),
            );
          }
        }
        break;
    }

    return buckets;
  }

  static List<CategoryBreakdownItem> _calculateCategoryBreakdown({
    required List<Transaction> currentTx,
    required int totalExpense,
  }) {
    final Map<String, int> totals = {};
    final Map<String, int> counts = {};

    for (final tx in currentTx) {
      if (tx.type == TransactionType.expense) {
        final catId = (tx.categoryId ?? 'other').toLowerCase();
        totals[catId] = (totals[catId] ?? 0) + tx.amount;
        counts[catId] = (counts[catId] ?? 0) + 1;
      }
    }

    final items = <CategoryBreakdownItem>[];
    for (final entry in totals.entries) {
      final catId = entry.key;
      final catTotal = entry.value;
      final percentage = totalExpense > 0 ? (catTotal / totalExpense) * 100 : 0.0;
      final categoryObj = CategoryConstants.getCategoryById(catId, TransactionType.expense);

      items.add(
        CategoryBreakdownItem(
          categoryId: catId,
          categoryName: categoryObj.name,
          totalMinor: catTotal,
          percentage: percentage,
          count: counts[catId] ?? 0,
        ),
      );
    }

    // Largest categories first
    items.sort((a, b) => b.totalMinor.compareTo(a.totalMinor));
    return items;
  }

  static List<DeterministicInsight> _generateDeterministicInsights({
    required AnalysisMetrics metrics,
    required PeriodComparison comparison,
    required List<CategoryBreakdownItem> categoryBreakdown,
    required List<Transaction> topExpenses,
    required List<Transaction> currentTx,
    required AnalysisPeriod period,
  }) {
    final insights = <DeterministicInsight>[];

    // 1. Comparison Insight
    if (comparison.hasPreviousData) {
      if (comparison.expensePercentageChange != null && !comparison.isRoughlyUnchanged) {
        final isHigher = comparison.isExpenseHigher;
        insights.add(
          DeterministicInsight(
            id: 'comparison_trend',
            title: isHigher ? 'Spending Increased' : 'Spending Decreased',
            message: 'Your spending is ${comparison.expenseComparisonText}.',
            type: isHigher ? InsightType.warning : InsightType.positive,
          ),
        );
      } else if (comparison.isRoughlyUnchanged) {
        insights.add(
          DeterministicInsight(
            id: 'comparison_steady',
            title: 'Steady Spending',
            message: 'Your spending is ${comparison.expenseComparisonText}.',
            type: InsightType.neutral,
          ),
        );
      }
    }

    // 2. Largest Category Insight
    if (categoryBreakdown.isNotEmpty) {
      final topCat = categoryBreakdown.first;
      if (topCat.percentage > 0) {
        insights.add(
          DeterministicInsight(
            id: 'top_category',
            title: 'Top Category',
            message: '${topCat.categoryName} is your largest expense category (${topCat.percentage.toStringAsFixed(0)}% of total spending).',
            type: InsightType.neutral,
          ),
        );
      }
    }

    // 3. Cash Flow / Savings Insight
    if (metrics.totalIncomeMinor > 0 && metrics.totalExpenseMinor > 0) {
      if (metrics.netMinor > 0) {
        final savingsPct = ((metrics.netMinor / metrics.totalIncomeMinor) * 100).toStringAsFixed(0);
        final savedMajor = (metrics.netMinor / 100).toStringAsFixed(0);
        insights.add(
          DeterministicInsight(
            id: 'positive_savings',
            title: 'Positive Cash Flow',
            message: 'You retained ₹$savedMajor ($savingsPct% of income) this period.',
            type: InsightType.positive,
          ),
        );
      } else if (metrics.netMinor < 0) {
        final deficitMajor = (metrics.netMinor.abs() / 100).toStringAsFixed(0);
        insights.add(
          DeterministicInsight(
            id: 'negative_cash_flow',
            title: 'Expenses Exceeded Income',
            message: 'Your expenses exceeded your income by ₹$deficitMajor.',
            type: InsightType.warning,
          ),
        );
      }
    }

    // 4. Largest Single Expense Insight
    if (metrics.largestExpenseMinor > 0 && metrics.largestExpenseTransaction != null) {
      final tx = metrics.largestExpenseTransaction!;
      final amountMajor = (tx.amount / 100).toStringAsFixed(0);
      final merchantOrTitle = tx.merchant?.isNotEmpty == true ? tx.merchant! : tx.title;
      insights.add(
        DeterministicInsight(
          id: 'largest_single_expense',
          title: 'Largest Expense',
          message: 'Your largest single expense was ₹$amountMajor on "$merchantOrTitle".',
          type: InsightType.neutral,
        ),
      );
    }

    // 5. Weekend vs Weekday analysis (if enough data and spanning >= 7 days)
    if (currentTx.length >= 4 && period.endDate.difference(period.startDate).inDays >= 6) {
      int weekendExpense = 0;
      int weekendCount = 0;
      int weekdayExpense = 0;
      int weekdayCount = 0;

      for (final tx in currentTx) {
        if (tx.type == TransactionType.expense) {
          if (tx.date.weekday == DateTime.saturday || tx.date.weekday == DateTime.sunday) {
            weekendExpense += tx.amount;
            weekendCount++;
          } else {
            weekdayExpense += tx.amount;
            weekdayCount++;
          }
        }
      }

      if (weekendCount > 0 && weekdayCount > 0) {
        final avgWeekend = weekendExpense / weekendCount;
        final avgWeekday = weekdayExpense / weekdayCount;

        if (avgWeekend > avgWeekday * 1.25) {
          final diffPct = (((avgWeekend - avgWeekday) / avgWeekday) * 100).toStringAsFixed(0);
          insights.add(
            DeterministicInsight(
              id: 'weekend_spending',
              title: 'Weekend Spending Pattern',
              message: 'You spend roughly $diffPct% more per transaction on weekends than on weekdays.',
              type: InsightType.neutral,
            ),
          );
        }
      }
    }

    // 6. Volume Insight
    if (metrics.expenseCount > 0) {
      final avgMajor = (metrics.avgExpenseMinor / 100).toStringAsFixed(0);
      insights.add(
        DeterministicInsight(
          id: 'transaction_volume',
          title: 'Activity Summary',
          message: 'You recorded ${metrics.expenseCount} expenses with an average spend of ₹$avgMajor.',
          type: InsightType.neutral,
        ),
      );
    }

    return insights;
  }
}

