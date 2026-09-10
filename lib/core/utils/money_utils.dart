import 'package:intl/intl.dart';

/// Utilities for handling money and currency conversion in minor units (e.g. paise/cents).
///
/// Prevents floating-point precision loss by storing money as integers in minor units.
class MoneyUtils {
  MoneyUtils._();

  /// Converts a decimal major unit amount (e.g., 320.50) to minor units (e.g., 32050 paise).
  static int doubleToMinorUnits(double amount) {
    return (amount * 100).round();
  }

  /// Converts minor units (e.g., 32050 paise) back to a decimal major unit double (e.g., 320.50).
  static double minorUnitsToDouble(int minorUnits) {
    return minorUnits / 100.0;
  }

  /// Formats minor units into a localized currency string.
  ///
  /// Example: 32050 -> "₹320.50" (if currency is 'INR' and symbol is '₹')
  static String formatMinorUnits(
    int minorUnits, {
    String currency = 'INR',
    String symbol = '₹',
    String locale = 'en_IN',
  }) {
    final double amount = minorUnitsToDouble(minorUnits);
    final NumberFormat formatter = NumberFormat.currency(
      locale: locale,
      symbol: symbol,
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }
}
