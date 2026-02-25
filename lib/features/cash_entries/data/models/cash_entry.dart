import 'package:hive/hive.dart';

part 'cash_entry.g.dart';

@HiveType(typeId: 0)
class CashEntry {
  CashEntry({
    required this.date,
    required this.cash,
    required this.cashNotes,
    required this.coins,
    required this.till,
    required this.expenses,
    this.userId = '',
    this.branchId = '',
  }) {
    _validateNonNegative(cash, 'cash');
    _validateNonNegative(cashNotes, 'cashNotes');
    _validateNonNegative(coins, 'coins');
    _validateNonNegative(till, 'till');
    _validateNonNegative(expenses, 'expenses');
  }

  @HiveField(0)
  DateTime date;

  @HiveField(1)
  double cash;

  @HiveField(2)
  double cashNotes;

  @HiveField(3)
  double coins;

  @HiveField(4)
  double till;

  @HiveField(5)
  double expenses;

  @HiveField(6)
  String userId;

  @HiveField(7)
  String branchId;

  CashEntry copyWith({
    DateTime? date,
    double? cash,
    double? cashNotes,
    double? coins,
    double? till,
    double? expenses,
    String? userId,
    String? branchId,
  }) {
    final nextCash = cash ?? this.cash;
    final nextCashNotes = cashNotes ?? this.cashNotes;
    final nextCoins = coins ?? this.coins;
    final nextTill = till ?? this.till;
    final nextExpenses = expenses ?? this.expenses;

    _validateNonNegative(nextCash, 'cash');
    _validateNonNegative(nextCashNotes, 'cashNotes');
    _validateNonNegative(nextCoins, 'coins');
    _validateNonNegative(nextTill, 'till');
    _validateNonNegative(nextExpenses, 'expenses');

    return CashEntry(
      date: date ?? this.date,
      cash: nextCash,
      cashNotes: nextCashNotes,
      coins: nextCoins,
      till: nextTill,
      expenses: nextExpenses,
      userId: userId ?? this.userId,
      branchId: branchId ?? this.branchId,
    );
  }

  static void _validateNonNegative(double value, String fieldName) {
    if (value < 0) {
      throw ArgumentError.value(value, fieldName, 'must be non-negative');
    }
  }
}
