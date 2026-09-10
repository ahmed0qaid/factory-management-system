class TemporaryEmployeeModel {
  final String id;
  final String companyId;
  final String biometricEmployeeId;
  final String? employeeNameFromDevice;
  final String status;
  final DateTime? firstSeenAt;
  final DateTime? lastSeenAt;
  final int punchesCount;
  final String? sourceBatchId;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  final DateTime? rejectedAt;
  final String? rejectedBy;
  final DateTime? linkedAt;
  final String? linkedBy;
  final String? linkedProfileId;

  TemporaryEmployeeModel({
    required this.id,
    required this.companyId,
    required this.biometricEmployeeId,
    this.employeeNameFromDevice,
    required this.status,
    this.firstSeenAt,
    this.lastSeenAt,
    this.punchesCount = 0,
    this.sourceBatchId,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.approvedAt,
    this.approvedBy,
    this.rejectedAt,
    this.rejectedBy,
    this.linkedAt,
    this.linkedBy,
    this.linkedProfileId,
  });

  factory TemporaryEmployeeModel.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    return TemporaryEmployeeModel(
      id: id,
      companyId: map['company_id'] ?? '',
      biometricEmployeeId: map['biometric_employee_id'] ?? '',
      employeeNameFromDevice: map['employee_name_from_device'],
      status: map['status'] ?? 'pending',
      firstSeenAt: map['first_seen_at'] != null
          ? DateTime.tryParse(map['first_seen_at'])
          : null,
      lastSeenAt: map['last_seen_at'] != null
          ? DateTime.tryParse(map['last_seen_at'])
          : null,
      punchesCount: map['punches_count'] ?? 0,
      sourceBatchId: map['source_batch_id'],
      notes: map['notes'],
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'])
          : null,
      approvedAt: map['approved_at'] != null
          ? DateTime.tryParse(map['approved_at'])
          : null,
      approvedBy: map['approved_by'],
      rejectedAt: map['rejected_at'] != null
          ? DateTime.tryParse(map['rejected_at'])
          : null,
      rejectedBy: map['rejected_by'],
      linkedAt: map['linked_at'] != null
          ? DateTime.tryParse(map['linked_at'])
          : null,
      linkedBy: map['linked_by'],
      linkedProfileId: map['linked_profile_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'company_id': companyId,
      'biometric_employee_id': biometricEmployeeId,
      if (employeeNameFromDevice != null &&
          employeeNameFromDevice!.trim().isNotEmpty)
        'employee_name_from_device': employeeNameFromDevice!.trim(),
      'status': status,
      'first_seen_at': firstSeenAt?.toIso8601String(),
      'last_seen_at': lastSeenAt?.toIso8601String(),
      'punches_count': punchesCount,
      'source_batch_id': sourceBatchId,
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
      'approved_by': approvedBy,
      'rejected_at': rejectedAt?.toIso8601String(),
      'rejected_by': rejectedBy,
      'linked_at': linkedAt?.toIso8601String(),
      'linked_by': linkedBy,
      'linked_profile_id': linkedProfileId,
    };
  }
}
