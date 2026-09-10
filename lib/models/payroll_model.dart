class PayrollRecordModel {
  final String id;
  final num baseSalary;
  final num monthlyBonus;
  final num monthlyEntitlement;
  final num attendanceEarnings;
  final num overtimeAmount;
  final num allowances;
  final num bonuses;
  final num absenceDeductions;
  final num lateDeductions;
  final num penaltiesAmount;
  final num advanceInstallments;
  final num otherDeductions;
  final num netSalary;
  final String status;
  final DateTime createdAt;

  PayrollRecordModel({
    required this.id,
    required this.baseSalary,
    required this.monthlyBonus,
    required this.monthlyEntitlement,
    required this.attendanceEarnings,
    required this.overtimeAmount,
    required this.allowances,
    required this.bonuses,
    required this.absenceDeductions,
    required this.lateDeductions,
    required this.penaltiesAmount,
    required this.advanceInstallments,
    required this.otherDeductions,
    required this.netSalary,
    required this.status,
    required this.createdAt,
  });

  factory PayrollRecordModel.fromMap(Map<String, dynamic> map) {
    return PayrollRecordModel(
      id: map['id'] as String,
      baseSalary: map['base_salary'] as num? ?? 0,
      monthlyBonus: map['monthly_bonus'] as num? ?? 0,
      monthlyEntitlement:
          map['monthly_entitlement'] as num? ??
          ((map['base_salary'] as num? ?? 0) +
              (map['monthly_bonus'] as num? ?? 0)),
      attendanceEarnings: map['attendance_earnings'] as num? ?? 0,
      overtimeAmount: map['overtime_amount'] as num? ?? 0,
      allowances: map['allowances'] as num? ?? 0,
      bonuses: map['bonuses'] as num? ?? 0,
      absenceDeductions: map['absence_deductions'] as num? ?? 0,
      lateDeductions: map['late_deductions'] as num? ?? 0,
      penaltiesAmount: map['penalties_amount'] as num? ?? 0,
      advanceInstallments: map['advance_installments'] as num? ?? 0,
      otherDeductions: map['other_deductions'] as num? ?? 0,
      netSalary: map['net_salary'] as num? ?? 0,
      status: map['status'] as String? ?? 'draft',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
