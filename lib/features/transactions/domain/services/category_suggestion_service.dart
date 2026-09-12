import '../../../../core/constants/category_constants.dart';
import '../../../../shared/enums/transaction_enums.dart';

/// Result of a deterministic category suggestion.
class CategorySuggestion {
  final String categoryId;
  final String categoryName;
  final String reason;

  const CategorySuggestion({
    required this.categoryId,
    required this.categoryName,
    required this.reason,
  });
}

/// Local, 100% deterministic keyword-based rule engine for transaction categorization.
///
/// Operates completely offline without any cloud or AI dependency.
class CategorySuggestionService {
  CategorySuggestionService._();

  static const Map<String, List<String>> _expenseKeywordMap = {
    'food': [
      'swiggy',
      'zomato',
      'restaurant',
      'hotel',
      'cafe',
      'coffee',
      'tea',
      'chai',
      'bakery',
      'mcdonald',
      'starbucks',
      'kfc',
      'burger',
      'pizza',
      'domino',
      'subway',
      'food',
      'dining',
      'eatery',
      'dhaba',
      'kitchen',
      'biryani',
      'sweets',
      'bar',
      'pub',
      'bistro',
      'snacks',
      'canteen',
    ],
    'transport': [
      'uber',
      'ola',
      'rapido',
      'metro',
      'fuel',
      'petrol',
      'diesel',
      'hpcl',
      'bpcl',
      'ioc',
      'indian oil',
      'auto',
      'cab',
      'taxi',
      'toll',
      'fastag',
      'parking',
      'railway',
      'irctc',
      'bus',
      'redbus',
      'transport',
    ],
    'shopping': [
      'amazon',
      'flipkart',
      'myntra',
      'meesho',
      'ajio',
      'blinkit',
      'zepto',
      'instamart',
      'bigbasket',
      'supermarket',
      'mart',
      'mall',
      'store',
      'retail',
      'grocery',
      'apparel',
      'clothing',
      'fashion',
      'shopping',
      'decathlon',
      'zara',
      'h&m',
    ],
    'bills': [
      'electricity',
      'bescom',
      'tneb',
      'water',
      'wifi',
      'broadband',
      'recharge',
      'airtel',
      'jio',
      'vi',
      'vodafone',
      'gas',
      'cylinder',
      'bill',
      'utility',
      'rent',
      'maintenance',
      'dth',
      'tata play',
      'insurance',
      'lic',
    ],
    'entertainment': [
      'netflix',
      'spotify',
      'prime',
      'hotstar',
      'disney',
      'youtube',
      'movie',
      'cinema',
      'pvr',
      'inox',
      'bookmyshow',
      'games',
      'playstation',
      'steam',
      'theatre',
      'concert',
    ],
    'health': [
      'pharmacy',
      'hospital',
      'clinic',
      'medicine',
      'medical',
      'doctor',
      'apollo',
      '1mg',
      'pharmeasy',
      'medplus',
      'lab',
      'dental',
      'health',
      'diagnostic',
      'therapy',
      'opticals',
    ],
    'education': [
      'school',
      'college',
      'tuition',
      'course',
      'books',
      'fees',
      'university',
      'udemy',
      'coursera',
      'training',
      'exam',
      'academy',
      'class',
    ],
    'travel': [
      'flight',
      'airline',
      'indigo',
      'air india',
      'hotel',
      'makemytrip',
      'mmt',
      'booking.com',
      'agoda',
      'resort',
      'trip',
      'vacation',
      'tour',
      'airbnb',
    ],
    'personal': [
      'salon',
      'spa',
      'haircut',
      'parlour',
      'beauty',
      'cosmetics',
      'nykaa',
      'grooming',
      'personal',
      'massage',
    ],
  };

  static const Map<String, List<String>> _incomeKeywordMap = {
    'salary': [
      'salary',
      'payroll',
      'wage',
      'stipend',
      'bonus',
      'earnings',
      'employer',
      'payout',
    ],
    'freelance': [
      'freelance',
      'client',
      'consulting',
      'contract',
      'upwork',
      'fiverr',
      'gig',
    ],
    'business': [
      'revenue',
      'sales',
      'customer',
      'invoice',
      'vendor',
      'merchant payment',
      'business',
      'settlement',
    ],
    'investment': [
      'dividend',
      'interest',
      'stock',
      'zerodha',
      'groww',
      'mutual fund',
      'crypto',
      'returns',
      'deposit',
      'fd',
      'rd',
    ],
    'gift': [
      'gift',
      'cashback',
      'reward',
      'prize',
      'lottery',
      'donation',
      'received from',
    ],
  };

  /// Suggests a category based on the transaction [title], optional [merchant],
  /// and [type] (Expense vs Income).
  ///
  /// Returns `null` if no deterministic keywords match.
  static CategorySuggestion? suggestCategory({
    required String title,
    String? merchant,
    required TransactionType type,
  }) {
    final combinedText = '${title.toLowerCase()} ${merchant?.toLowerCase() ?? ''}';
    final keywordMap = type == TransactionType.income
        ? _incomeKeywordMap
        : _expenseKeywordMap;

    for (final entry in keywordMap.entries) {
      final categoryId = entry.key;
      final keywords = entry.value;

      for (final keyword in keywords) {
        if (_containsWordOrPhrase(combinedText, keyword)) {
          final category = CategoryConstants.getCategoryById(categoryId, type);
          return CategorySuggestion(
            categoryId: category.id,
            categoryName: category.name,
            reason: 'Matched "$keyword"',
          );
        }
      }
    }

    return null;
  }

  /// Suggests a category or returns the default category ('other' or 'other_income') if no match.
  static CategorySuggestion suggestCategoryOrFallback({
    required String title,
    String? merchant,
    required TransactionType type,
  }) {
    final match = suggestCategory(title: title, merchant: merchant, type: type);
    if (match != null) return match;
    final fallback = type == TransactionType.income
        ? CategoryConstants.incomeCategories.last
        : CategoryConstants.expenseCategories.last;
    return CategorySuggestion(
      categoryId: fallback.id,
      categoryName: fallback.name,
      reason: 'Default fallback',
    );
  }

  /// Convenience alias for [suggestCategoryOrFallback].
  static CategorySuggestion suggest({
    required String title,
    String? merchant,
    required TransactionType type,
  }) => suggestCategoryOrFallback(title: title, merchant: merchant, type: type);

  /// Checks if [text] contains the [keyword] with word-boundary awareness.
  static bool _containsWordOrPhrase(String text, String keyword) {
    if (keyword.contains(' ') || keyword.contains('&') || keyword.contains('.')) {
      return text.contains(keyword);
    }
    final regex = RegExp(r'\b' + RegExp.escape(keyword) + r'\b', caseSensitive: false);
    return regex.hasMatch(text);
  }
}
