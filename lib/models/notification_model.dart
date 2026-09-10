class NotificationModel {
  final String id;
  final String companyId;
  final String employeeId;
  final String title;
  final String body;
  final String type;
  final String? referenceTable;
  final String? referenceId;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.companyId,
    required this.employeeId,
    required this.title,
    required this.body,
    required this.type,
    this.referenceTable,
    this.referenceId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['\$id'] ?? map['id'] ?? '',
      companyId: map['company_id'] ?? '',
      employeeId: map['employee_id'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? '',
      referenceTable: map['reference_table'],
      referenceId: map['reference_id'],
      isRead: map['is_read'] ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }
}
