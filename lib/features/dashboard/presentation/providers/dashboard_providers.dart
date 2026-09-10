import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock_dashboard_data.dart';
import '../../domain/models/dashboard_summary.dart';

/// Riverpod provider exposing [DashboardSummary] state for the Dashboard UI.
final dashboardSummaryProvider = Provider<DashboardSummary>((ref) {
  return MockDashboardData.mockSummary;
});
