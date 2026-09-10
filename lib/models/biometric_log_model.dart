class BiometricLogModel {
  final String id;
  final String companyId;
  final String importBatchId;
  final String biometricEmployeeId;
  final String? employeeId;
  final String? employeeNameFromDevice;
  final DateTime punchTime;
  final String? punchType;
  final String? rawLine;
  final bool isMatched;
  final bool isProcessed;
  final String? errorMessage;
  final DateTime createdAt;

  BiometricLogModel({
    required this.id,
    required this.companyId,
    required this.importBatchId,
    required this.biometricEmployeeId,
    this.employeeId,
    this.employeeNameFromDevice,
    required this.punchTime,
    this.punchType,
    this.rawLine,
    required this.isMatched,
    required this.isProcessed,
    this.errorMessage,
    required this.createdAt,
  });

  factory BiometricLogModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return BiometricLogModel(
      id: id ?? map['\$id'] ?? map['id'] ?? '',
      companyId: map['company_id'] ?? '',
      importBatchId: map['import_batch_id'] ?? '',
      biometricEmployeeId: map['biometric_employee_id'] ?? '',
      employeeId: map['employee_id'],
      employeeNameFromDevice: map['employee_name_from_device'],
      punchTime: DateTime.parse(map['punch_time']),
      punchType: map['punch_type'],
      rawLine: map['raw_line'],
      isMatched: map['is_matched'] ?? false,
      isProcessed: map['is_processed'] ?? false,
      errorMessage: map['error_message'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
