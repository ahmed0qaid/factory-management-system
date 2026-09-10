class JobTitleModel {
  final String id;
  final String companyId;
  final String name;
  final bool active;
  final String? description;

  JobTitleModel({
    required this.id,
    required this.companyId,
    required this.name,
    this.active = true,
    this.description,
  });

  factory JobTitleModel.fromMap(Map<String, dynamic> map) {
    return JobTitleModel(
      id: map['\$id'] ?? map['id'] ?? '',
      companyId: map['company_id'] ?? '',
      name: map['name'] ?? '',
      active: map['active'] ?? true,
      description: map['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'company_id': companyId,
      'name': name,
      'active': active,
      if (description != null) 'description': description,
    };
  }
}
