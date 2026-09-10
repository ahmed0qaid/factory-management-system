class AnnouncementModel {
  final String id;
  final String title;
  final String body;
  final DateTime publishAt;

  AnnouncementModel({
    required this.id,
    required this.title,
    required this.body,
    required this.publishAt,
  });

  factory AnnouncementModel.fromMap(Map<String, dynamic> map) {
    return AnnouncementModel(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      publishAt: DateTime.parse(map['publish_at'] as String),
    );
  }
}
