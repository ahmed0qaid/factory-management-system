class AdvanceModel {
  final String id;
  final String companyId;
  final String employeeId;
  final DateTime requestDate;
  final DateTime? approvedDate;
  final num principalAmount;
  final num installmentAmount;
  final num remainingAmount;
  final num? approvedAmount;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? approvalNote;
  final String? rejectionReason;
  final int? installmentCount;
  final String? firstInstallmentMonth;
  final String? repaymentStatus;
  final String? reason;
  final String status;

  AdvanceModel({
    required this.id,
    required this.companyId,
    required this.employeeId,
    required this.requestDate,
    required this.principalAmount,
    required this.installmentAmount,
    required this.remainingAmount,
    this.approvedAmount,
    this.approvedBy,
    this.approvedAt,
    this.approvalNote,
    this.rejectionReason,
    this.installmentCount,
    this.firstInstallmentMonth,
    this.repaymentStatus,
    required this.status,
    this.approvedDate,
    this.reason,
  });

  factory AdvanceModel.fromMap(Map<String, dynamic> map) {
    return AdvanceModel(
      id: map['id'] as String,
      companyId: map['company_id'] as String? ?? '',
      employeeId: map['employee_id'] as String? ?? '',
      requestDate: map['request_date'] != null ? DateTime.parse(map['request_date'] as String) : DateTime.now(),
      approvedDate: map['approved_date'] == null
          ? null
          : DateTime.parse(map['approved_date'] as String),
      principalAmount: map['principal_amount'] as num? ?? 0,
      installmentAmount: map['installment_amount'] as num? ?? 0,
      remainingAmount: map['remaining_amount'] as num? ?? 0,
      approvedAmount: map['approved_amount'] as num?,
      approvedBy: map['approved_by'],
      approvedAt: map['approved_at'] != null ? DateTime.parse(map['approved_at']) : null,
      approvalNote: map['approval_note'],
      rejectionReason: map['rejection_reason'],
      installmentCount: map['installment_count'] as int?,
      firstInstallmentMonth: map['first_installment_month'],
      repaymentStatus: map['repayment_status'],
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
