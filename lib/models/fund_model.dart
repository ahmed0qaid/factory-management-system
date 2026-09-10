class FundModel {
  final String id;
  final String name;
  final String type; // local, bank, wallet
  final double balance;
  final bool active;

  FundModel({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.active,
  });

  factory FundModel.fromMap(Map<String, dynamic> map) {
    return FundModel(
      id: map['id'] ?? map['\$id'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? 'local',
      balance: (map['balance'] ?? 0.0).toDouble(),
      active: map['active'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'balance': balance,
      'active': active,
    };
  }
}
