import 'package:flutter_test/flutter_test.dart';
import 'package:expense_app/shared/enums/transaction_enums.dart';
import 'package:expense_app/features/import/data/parser/bank_sms_parser.dart';

void main() {
  const parser = BankSmsParser();

  group('BankSmsParser Tests', () {
    test('Parses HDFC Bank debit SMS correctly', () {
      const sms =
          'HDFC Bank: Rs 450.00 debited from a/c **4321 on 22-09-26 to SWIGGY. UPI Ref 382910. Avl bal: Rs 12,345.00';
      final result = parser.parse(body: sms, sender: 'VK-HDFCBK');

      expect(result, isNotNull);
      expect(result!.amount, 45000); // 450.00 in paise
      expect(result.type, TransactionType.expense);
      expect(result.merchant, 'Swiggy');
      expect(result.source, TransactionSource.sms);
      expect(result.sourceReference, 'HDFC Bank');
      expect(result.note, contains('A/C **4321'));
      expect(result.date?.year, 2026);
      expect(result.date?.month, 9);
      expect(result.date?.day, 22);
    });

    test('Parses SBI credit SMS correctly', () {
      const sms =
          'Dear SBI User, your A/C ending 1234 credited by Rs. 5,000.00 on 22-Sep-26 by UPI/ref no 12345678. Bal: Rs 15,200.00';
      final result = parser.parse(body: sms, sender: 'AX-SBIINB');

      expect(result, isNotNull);
      expect(result!.amount, 500000); // 5000.00 in paise
      expect(result.type, TransactionType.income);
      expect(result.source, TransactionSource.sms);
      expect(result.sourceReference, 'State Bank of India');
      expect(result.note, contains('A/C **1234'));
      expect(result.date?.year, 2026);
      expect(result.date?.month, 9);
      expect(result.date?.day, 22);
    });

    test('Parses ICICI Bank debit with Info counterparty', () {
      const sms =
          'ICICI Bank Acct XX123 debited for INR 1,299.00 on 21-SEP-26. Info: Amazon Pay. Available Balance: INR 8,400.00';
      final result = parser.parse(body: sms, sender: 'AD-ICICIB');

      expect(result, isNotNull);
      expect(result!.amount, 129900);
      expect(result.type, TransactionType.expense);
      expect(result.merchant, 'Amazon Pay');
      expect(result.source, TransactionSource.sms);
      expect(result.date?.day, 21);
    });

    test('Parses Axis Bank Credit Card spend', () {
      const sms =
          'Axis Bank: Rs. 250.00 spent on your Credit Card ending 9876 at STARBUCKS on 22/09/2026. Avail Limit: Rs. 45,000';
      final result = parser.parse(body: sms, sender: 'DM-AXISBK');

      expect(result, isNotNull);
      expect(result!.amount, 25000);
      expect(result.type, TransactionType.expense);
      expect(result.merchant, 'Starbucks');
      expect(result.source, TransactionSource.sms);
    });

    test('Parses UPI VPA transfer', () {
      const sms =
          'Paid Rs. 120.00 to Chai Point using UPI ref 234141. Your A/C XX7890 debited. Avl bal Rs 3,450.';
      final result = parser.parse(body: sms);

      expect(result, isNotNull);
      expect(result!.amount, 12000);
      expect(result.type, TransactionType.expense);
      expect(result.merchant, 'Chai Point');
    });

    test('Filters out OTP authentication messages', () {
      const otpSms1 =
          '123456 is your OTP for transaction of Rs 500.00 at Swiggy. Do not share your OTP with anyone.';
      final result1 = parser.parse(body: otpSms1);
      expect(result1, isNull);

      const otpSms2 =
          'Your one time password to log in to SBI Net Banking is 987654. Valid for 5 minutes.';
      final result2 = parser.parse(body: otpSms2);
      expect(result2, isNull);
    });

    test('Filters out promotional loan offers', () {
      const promoSms =
          'Congratulations! You are eligible for a pre-approved personal loan of Rs 5,00,000. Apply now at http://xyz.bank';
      final result = parser.parse(body: promoSms);
      expect(result, isNull);
    });

    test('Converts parsed SMS into persistent Transaction entity preserving source', () {
      const sms =
          'HDFC Bank: Rs 750.00 debited from a/c **4321 on 22-09-26 to ZOMATO.';
      final extracted = parser.parse(body: sms, sender: 'VK-HDFCBK');
      expect(extracted, isNotNull);

      final entity = extracted!.toTransactionEntity();
      expect(entity.amount, 75000);
      expect(entity.source, TransactionSource.sms);
      expect(entity.title, 'Zomato');
    });

    test('Parses user multiline HDFC UPI SMS accurately', () {
      const multilineSms = '''
Sent Rs.170.00
From HDFC Bank A/C *2711
To RABI COSMETICS
On 20/09/26
Ref 129959218177
Not You?
Call 18002586161/SMS BLOCK UPI to 7308080808
''';
      final result = parser.parse(body: multilineSms, sender: 'AD-HDFCBK');
      expect(result, isNotNull);
      expect(result!.amount, 17000); // Rs 170.00 in paise
      expect(result.type, TransactionType.expense);
      expect(result.merchant, 'Rabi Cosmetics');
      expect(result.title, 'Rabi Cosmetics');
      expect(result.sourceReference, 'HDFC Bank');
      expect(result.note, contains('From: HDFC Bank A/C *2711'));
      expect(result.note, contains('To: RABI COSMETICS'));
      expect(result.note, contains('Ref: 129959218177'));
      expect(result.note, contains('Sent Rs.170.00'));
      expect(result.date?.year, 2026);
      expect(result.date?.month, 9);
      expect(result.date?.day, 20);
    });

    test('Never extracts "Block Your Card" as merchant from security disclaimers', () {
      const sms =
          'Your a/c no. XX1234 is debited for Rs.2,000.00 on 15-Sep-26. If not done by you, to Block your card SMS BLOCK to 56767';
      final result = parser.parse(body: sms, sender: 'AD-SBIUPI');
      expect(result, isNotNull);
      expect(result!.amount, 200000);
      expect(result.type, TransactionType.expense);
      expect(result.merchant, isNot(contains('Block')));
      expect(result.title, 'State Bank of India Expense');
      expect(result.sourceReference, 'State Bank of India');
    });

    test('Extracts actual merchant and ignores trailing "Block Your Card" disclaimer', () {
      const sms =
          'Rs. 2,000.00 spent on your Card ending 1234 at RELIANCE DIGITAL on 15-Sep-26. If not you, to block your card call 1800123456';
      final result = parser.parse(body: sms);
      expect(result, isNotNull);
      expect(result!.amount, 200000);
      expect(result.merchant, 'Reliance Digital');
    });

    test('Never extracts "Your Card Ending" as merchant for income transactions', () {
      const sms =
          'Rs 7,655.00 credited to your card ending 5404 on 11-Sep-26 from AMAZON REFUND. Avl bal Rs 25,000.';
      final result = parser.parse(body: sms);
      expect(result, isNotNull);
      expect(result!.amount, 765500);
      expect(result.type, TransactionType.income);
      expect(result.merchant, 'Amazon Refund');
      expect(result.title, 'Amazon Refund');
    });

    test('Extracts counterparty for bank credits/income accurately', () {
      const sms =
          'Dear SBI User, your A/C ending 1234 credited by Rs. 2,678.00 on 17-Sep-26 by transfer from RAMESH SHARMA / UPI-Ref 123456. Bal: Rs 15,200.00';
      final result = parser.parse(body: sms, sender: 'AD-SBIUPI');
      expect(result, isNotNull);
      expect(result!.amount, 267800);
      expect(result.type, TransactionType.income);
      expect(result.merchant, 'Ramesh Sharma');
      expect(result.sourceReference, 'State Bank of India');
    });

    test('Parses PhonePe payment SMS accurately', () {
      const sms =
          'Paid Rs. 350.00 to APOLLO PHARMACY using PhonePe on 21-Sep-26. Debited from A/C XX9988.';
      final result = parser.parse(body: sms, sender: 'JM-PHONPE');
      expect(result, isNotNull);
      expect(result!.amount, 35000);
      expect(result.type, TransactionType.expense);
      expect(result.merchant, 'Apollo Pharmacy');
      expect(result.title, 'Apollo Pharmacy');
      expect(result.sourceReference, 'PhonePe');
    });

    test('Parses Kotak Bank debit alert', () {
      const sms =
          'Kotak Bank: Rs 1,499.00 debited from A/C **5566 on 18-Sep-26 towards NETFLIX. Avl bal Rs 34,200.';
      final result = parser.parse(body: sms, sender: 'BZ-KOTAKB');
      expect(result, isNotNull);
      expect(result!.amount, 149900);
      expect(result.type, TransactionType.expense);
      expect(result.merchant, 'Netflix');
      expect(result.title, 'Netflix');
      expect(result.sourceReference, 'Kotak Mahindra Bank');
    });

    test('Parses Bank of Baroda credited SMS', () {
      const sms =
          'Your A/C ending 3322 credited with INR 10,000.00 on 19-Sep-26 by salary transfer. Total Bal INR 55,000.00';
      final result = parser.parse(body: sms, sender: 'AD-BOBSMS');
      expect(result, isNotNull);
      expect(result!.amount, 1000000);
      expect(result.type, TransactionType.income);
      expect(result.sourceReference, 'Bank of Baroda');
    });

    test('Adds SMS message to note/description when merchant from/to is not found', () {
      const sms =
          'Your A/C ending 1234 is debited by Rs. 500.00 on 20-Sep-26. Avl Bal Rs. 12,000. If not done by you, to Block your card SMS BLOCK to 56767';
      final result = parser.parse(body: sms, sender: 'AD-SBIUPI');
      expect(result, isNotNull);
      expect(result!.merchant, isNull);
      expect(result.title, 'State Bank of India Expense');
      // Verify message is present in note/description
      expect(result.note, contains('Your A/C ending 1234 is debited by Rs. 500.00'));
      expect(result.note, contains('State Bank of India'));
      expect(result.note, contains('A/C **1234'));
      // Verify the entire unmodified SMS message is preserved in note
      expect(result.note, contains('Block your card SMS BLOCK to 56767'));
    });

    test('Parses multiline SMS with colon format (To: and From:)', () {
      const sms = '''
Sent: Rs.250.00
From: HDFC Bank A/C *2711
To: DOMINOS PIZZA
On: 21/09/26
Ref: 998877665544
''';
      final result = parser.parse(body: sms, sender: 'AD-HDFCBK');
      expect(result, isNotNull);
      expect(result!.amount, 25000);
      expect(result.merchant, 'Dominos Pizza');
      expect(result.title, 'Dominos Pizza');
      expect(result.note, contains('From: HDFC Bank A/C *2711'));
      expect(result.note, contains('To: DOMINOS PIZZA'));
      expect(result.note, contains('Sent: Rs.250.00'));
    });

    test('Extracts strictly words after "to" and strips "and some message"', () {
      const sms =
          'Rs 550.00 debited from A/C XX4321 to Uber India and some message about transaction. Bal Rs 1,200';
      final result = parser.parse(body: sms, sender: 'VK-HDFCBK');
      expect(result, isNotNull);
      expect(result!.amount, 55000);
      expect(result.type, TransactionType.expense);
      // Must be strictly "Uber India", without "To:" and without "and some message"
      expect(result.title, 'Uber India');
      expect(result.merchant, 'Uber India');
    });

    test('Filters out promotional messages with bonus or recharge', () {
      const promo1 =
          'Congratulations! Rs 500 bonus credited to your wallet. Play now!';
      final result1 = parser.parse(body: promo1);
      expect(result1, isNull);

      const promo2 =
          'Your recharge of Rs 299 was successful. Daily data limit 1.5GB pack expiring soon.';
      final result2 = parser.parse(body: promo2);
      expect(result2, isNull);
    });

    test('Filters out messages matching custom user excluded keywords', () {
      const customSms =
          'Rs 1,000.00 debited from A/C XX1234 to Dream11 contest entry. Bal Rs 4,000';
      // Without excluded keyword, it would normally parse
      final normal = parser.parse(body: customSms);
      expect(normal, isNotNull);

      // With excluded keyword "dream11", it is filtered out
      final filtered = parser.parse(
        body: customSms,
        excludedKeywords: ['dream11', 'rummy'],
      );
      expect(filtered, isNull);
    });
  });
}
