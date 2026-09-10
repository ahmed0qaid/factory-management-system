class FundClosureModel {
  final String id;
  final String fundId;
  final DateTime date;
  final double openingBalance;
  final double totalIn;
  final double totalOut;
  final double closingBalance;
  final String closedBy;

  FundClosureModel({
    required this.id,
    required this.fundId,
    required this.date,
    required this.openingBalance,
    required this.totalIn,
    required this.totalOut,
    required this.closingBalance,
    required this.closedBy,
  });

  factory FundClosureModel.fromMap(Map<String, dynamic> map) {
    return FundClosureModel(
      id: map['id'] ?? map['\$id'] ?? '',
      fundId: map['fund_id'] ?? '',
      date: DateTime.parse(map['date']),
      openingBalance: (map['opening_balance'] ?? 0.0).toDouble(),
      totalIn: (map['total_in'] ?? 0.0).toDouble(),
      totalOut: (map['total_out'] ?? 0.0).toDouble(),
      closingBalance: (map['closing_balance'] ?? 0.0).toDouble(),
      closedBy: map['closed_by'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fund_id': fundId,
      'date': date.toIso8601String(),
      'opening_balance': openingBalance,
      'total_in': totalIn,
      'total_out': totalOut,
      'closing_balance': closingBalance,
      'closed_by': closedBy,
    };
  }
}
