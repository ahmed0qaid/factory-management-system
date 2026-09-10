class PenaltyModel {
  final String id;
  final DateTime penaltyDate;
  final String category;
  final String reason;
  final num amount;
  final int minutesDeducted;
  final String status;

  PenaltyModel({
    required this.id,
    required this.penaltyDate,
    required this.category,
    required this.reason,
    required this.amount,
    required this.minutesDeducted,
    required this.status,
  });

  factory PenaltyModel.fromMap(Map<String, dynamic> map) {
    return PenaltyModel(
      id: map['id'] as String,
      penaltyDate: DateTime.parse(map['penalty_date'] as String),
      category: map['category'] as String? ?? '-',
      reason: map['reason'] as String? ?? '-',
      amount: map['amount'] as num? ?? 0,
      minutesDeducted: map['minutes_deducted'] as int? ?? 0,
      status: map['status'] as String? ?? 'pending',
    );
  }
}
