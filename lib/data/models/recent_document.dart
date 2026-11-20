enum DocumentSource { local, drive }

class RecentDocument {
  const RecentDocument({
    required this.id,
    required this.name,
    required this.source,
    required this.lastOpenedAt,
  });

  final String id;
  final String name;
  final DocumentSource source;
  final DateTime lastOpenedAt;

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'source': source.name,
    'lastOpenedAt': lastOpenedAt.toIso8601String(),
  };

  factory RecentDocument.fromJson(Map<String, Object?> json) {
    return RecentDocument(
      id: json['id']! as String,
      name: json['name']! as String,
      source: DocumentSource.values.byName(json['source']! as String),
      lastOpenedAt: DateTime.parse(json['lastOpenedAt']! as String),
    );
  }
}
