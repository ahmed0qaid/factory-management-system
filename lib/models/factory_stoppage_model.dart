class FactoryStoppageModel {
  final String id;
  final String companyId;
  final String title;
  final String? reason;
  final DateTime startDate;
  final DateTime endDate;
  final bool isPaid;
  final String? createdBy;
  final DateTime createdAt;

  const FactoryStoppageModel({
    required this.id,
    required this.companyId,
    required this.title,
    this.reason,
    required this.startDate,
    required this.endDate,
    required this.isPaid,
    this.createdBy,
    required this.createdAt,
  });

  factory FactoryStoppageModel.fromMap(Map<String, dynamic> map) {
    return FactoryStoppageModel(
      id: (map['id'] ?? map[r'$id'] ?? '').toString(),
      companyId: map['company_id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      reason: map['reason']?.toString(),
      startDate: DateTime.parse(map['start_date'].toString()),
      endDate: DateTime.parse(map['end_date'].toString()),
      isPaid: map['is_paid'] as bool? ?? true,
      createdBy: map['created_by']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'].toString())
          : DateTime.now(),
    );
  }
}
