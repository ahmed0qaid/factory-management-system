class InstallmentModel {
  final String id;
  final String companyId;
  final String advanceId;
  final String employeeId;
  final int installmentNumber;
  final String dueMonth; // YYYY-MM
  final num amount;
  final String status; // pending, deducted, skipped, cancelled
  final String? payrollRecordId;
  final DateTime? deductedAt;
  final DateTime createdAt;

  InstallmentModel({
    required this.id,
    required this.companyId,
    required this.advanceId,
    required this.employeeId,
    required this.installmentNumber,
    required this.dueMonth,
    required this.amount,
    required this.status,
    this.payrollRecordId,
    this.deductedAt,
    required this.createdAt,
  });

  factory InstallmentModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return InstallmentModel(
      id: id ?? map['\$id'] ?? map['id'] ?? '',
      companyId: map['company_id'] ?? '',
      advanceId: map['advance_id'] ?? '',
      employeeId: map['employee_id'] ?? '',
      installmentNumber: map['installment_number'] as int? ?? 1,
      dueMonth: map['due_month'] ?? '',
      amount: map['amount'] as num? ?? 0,
      status: map['status'] ?? 'pending',
      payrollRecordId: map['payroll_record_id'],
      deductedAt: map['deducted_at'] != null ? DateTime.parse(map['deducted_at']) : null,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
