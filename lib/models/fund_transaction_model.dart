class FundTransactionModel {
  final String id;
  final String fundId;
  final String type; // 'in' or 'out'
  final double amount;
  final String description;
  final DateTime date;
  final String? referenceId;
  final String createdBy;

  FundTransactionModel({
    required this.id,
    required this.fundId,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    this.referenceId,
    required this.createdBy,
  });

  factory FundTransactionModel.fromMap(Map<String, dynamic> map) {
    return FundTransactionModel(
      id: map['id'] ?? map['\$id'] ?? '',
      fundId: map['fund_id'] ?? '',
      type: map['type'] ?? 'out',
      amount: (map['amount'] ?? 0.0).toDouble(),
      description: map['description'] ?? '',
      date: DateTime.parse(map['date']),
      referenceId: map['reference_id'],
      createdBy: map['created_by'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fund_id': fundId,
      'type': type,
      'amount': amount,
      'description': description,
      'date': date.toIso8601String(),
      if (referenceId != null) 'reference_id': referenceId,
      'created_by': createdBy,
    };
  }
}
