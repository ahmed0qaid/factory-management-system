class BiometricImportBatchModel {
  final String id;
  final String companyId;
  final String fileName;
  final String importedBy;
  final DateTime importedAt;
  final String status;
  final int totalRows;
  final int validRows;
  final int invalidRows;
  final int processedRows;
  final String? notes;

  BiometricImportBatchModel({
    required this.id,
    required this.companyId,
    required this.fileName,
    required this.importedBy,
    required this.importedAt,
    required this.status,
    required this.totalRows,
    required this.validRows,
    required this.invalidRows,
    required this.processedRows,
    this.notes,
  });

  factory BiometricImportBatchModel.fromMap(
    Map<String, dynamic> map, {
    String? id,
  }) {
    return BiometricImportBatchModel(
      id: id ?? map['\$id'] ?? map['id'] ?? '',
      companyId: map['company_id'] ?? '',
      fileName: map['file_name'] ?? '',
      importedBy: map['imported_by'] ?? '',
      importedAt: DateTime.parse(map['imported_at']),
      status: map['status'] ?? '',
      totalRows: map['total_rows'] ?? 0,
      validRows: map['valid_rows'] ?? 0,
      invalidRows: map['invalid_rows'] ?? 0,
      processedRows: map['processed_rows'] ?? 0,
      notes: map['notes'],
    );
  }
}
