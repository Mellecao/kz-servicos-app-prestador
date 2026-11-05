class MockPeriodEarning {
  final double total;
  final int trips;

  const MockPeriodEarning({required this.total, required this.trips});
}

class MockMonthlyEarning {
  final int month;
  final int year;
  final double total;
  final int trips;

  const MockMonthlyEarning({
    required this.month,
    required this.year,
    required this.total,
    required this.trips,
  });
}

class MockEarnings {
  final double currentMonthTotal;
  final double previousMonthTotal;
  final int currentMonthTrips;
  final int previousMonthTrips;
  final double availableBalance;
  final String bankName;
  final String bankAgency;
  final String bankAccount;
  final List<MockEarningEntry> recentEntries;
  final List<MockMonthlyEarning> monthlyHistory;
  final MockPeriodEarning dailyEarning;
  final MockPeriodEarning weeklyEarning;
  final MockPeriodEarning monthlyEarning;
  final MockPeriodEarning yearlyEarning;

  const MockEarnings({
    required this.currentMonthTotal,
    required this.previousMonthTotal,
    required this.currentMonthTrips,
    required this.previousMonthTrips,
    required this.availableBalance,
    required this.bankName,
    required this.bankAgency,
    required this.bankAccount,
    required this.recentEntries,
    required this.monthlyHistory,
    required this.dailyEarning,
    required this.weeklyEarning,
    required this.monthlyEarning,
    required this.yearlyEarning,
  });

  /// Returns the most recent entry (last trip or last withdrawal).
  MockEarningEntry get lastTransaction => recentEntries.first;

  double get monthOverMonthChange {
    if (previousMonthTotal == 0) return 100;
    return ((currentMonthTotal - previousMonthTotal) / previousMonthTotal) *
        100;
  }

  static final MockEarnings sample = MockEarnings(
    currentMonthTotal: 2850.00,
    previousMonthTotal: 2450.00,
    currentMonthTrips: 45,
    previousMonthTrips: 38,
    availableBalance: 4280.50,
    bankName: 'Nubank',
    bankAgency: '0001',
    bankAccount: '****5678',
    dailyEarning: MockPeriodEarning(total: 185.50, trips: 5),
    weeklyEarning: MockPeriodEarning(total: 1280.00, trips: 22),
    monthlyEarning: MockPeriodEarning(total: 2850.00, trips: 45),
    yearlyEarning: MockPeriodEarning(total: 28450.00, trips: 448),
    monthlyHistory: [
      MockMonthlyEarning(month: 5, year: 2025, total: 1850.00, trips: 28),
      MockMonthlyEarning(month: 6, year: 2025, total: 2100.00, trips: 32),
      MockMonthlyEarning(month: 7, year: 2025, total: 1950.00, trips: 30),
      MockMonthlyEarning(month: 8, year: 2025, total: 2300.00, trips: 35),
      MockMonthlyEarning(month: 9, year: 2025, total: 2600.00, trips: 40),
      MockMonthlyEarning(month: 10, year: 2025, total: 2200.00, trips: 34),
      MockMonthlyEarning(month: 11, year: 2025, total: 2750.00, trips: 42),
      MockMonthlyEarning(month: 12, year: 2025, total: 3100.00, trips: 48),
      MockMonthlyEarning(month: 1, year: 2026, total: 2400.00, trips: 37),
      MockMonthlyEarning(month: 2, year: 2026, total: 2550.00, trips: 39),
      MockMonthlyEarning(month: 3, year: 2026, total: 2450.00, trips: 38),
      MockMonthlyEarning(month: 4, year: 2026, total: 2850.00, trips: 45),
    ],
    recentEntries: [
      MockEarningEntry(
        id: 'earn_1',
        description: 'Viagem #312 - Ana Carolina',
        amount: 32.50,
        date: DateTime(2026, 4, 14, 18, 45),
        type: EarningType.trip,
      ),
      MockEarningEntry(
        id: 'earn_2',
        description: 'Viagem #311 - Pedro Alves',
        amount: 28.00,
        date: DateTime(2026, 4, 14, 14, 20),
        type: EarningType.trip,
      ),
      MockEarningEntry(
        id: 'earn_3',
        description: 'Viagem #310 - Lucia Santos',
        amount: 55.00,
        date: DateTime(2026, 4, 13, 6, 30),
        type: EarningType.trip,
      ),
      MockEarningEntry(
        id: 'earn_4',
        description: 'Saque para conta bancária',
        amount: -1500.00,
        date: DateTime(2026, 4, 10, 12, 0),
        type: EarningType.withdrawal,
      ),
      MockEarningEntry(
        id: 'earn_5',
        description: 'Bônus por avaliação 5 estrelas',
        amount: 15.00,
        date: DateTime(2026, 4, 9, 20, 0),
        type: EarningType.bonus,
      ),
    ],
  );
}

class MockEarningEntry {
  final String id;
  final String description;
  final double amount;
  final DateTime date;
  final EarningType type;

  const MockEarningEntry({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    required this.type,
  });
}

enum EarningType { trip, withdrawal, bonus }
