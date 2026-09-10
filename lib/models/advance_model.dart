class AdvanceModel {
  final String id;
  final DateTime requestDate;
  final DateTime? approvedDate;
  final num principalAmount;
  final num installmentAmount;
  final num remainingAmount;
  final String? reason;
  final String status;

  AdvanceModel({
    required this.id,
    required this.requestDate,
    required this.principalAmount,
    required this.installmentAmount,
    required this.remainingAmount,
    required this.status,
    this.approvedDate,
    this.reason,
  });

  factory AdvanceModel.fromMap(Map<String, dynamic> map) {
    return AdvanceModel(
      id: map['id'] as String,
      requestDate: DateTime.parse(map['request_date'] as String),
      approvedDate: map['approved_date'] == null
          ? null
          : DateTime.parse(map['approved_date'] as String),
      principalAmount: map['principal_amount'] as num? ?? 0,
      installmentAmount: map['installment_amount'] as num? ?? 0,
      remainingAmount: map['remaining_amount'] as num? ?? 0,
      reason: map['reason'] as String?,
      status: map['status'] as String? ?? 'pending',
    );
  }
}

class AdvanceBalanceInfo {
  final DateTime periodStart;
  final DateTime periodEnd;
  final int workingDaysInPeriod;
  final int workingDaysUntilToday;
  final int attendanceDays;
  final num monthlyEntitlement;
  final num accruedSalary;
  final num previousAdvances;
  final int penaltiesCount;
  final num penaltiesAmount;
  final num availableBalance;
  final bool canRequestAdvance;

  AdvanceBalanceInfo({
    required this.periodStart,
    required this.periodEnd,
    required this.workingDaysInPeriod,
    required this.workingDaysUntilToday,
    required this.attendanceDays,
    required this.monthlyEntitlement,
    required this.accruedSalary,
    required this.previousAdvances,
    required this.penaltiesCount,
    required this.penaltiesAmount,
    required this.availableBalance,
    required this.canRequestAdvance,
  });
}
