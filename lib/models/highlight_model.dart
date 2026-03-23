class Highlight {
  final int pageNumber;
  final String text;
  final DateTime createdAt;

  Highlight({
    required this.pageNumber,
    required this.text,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'pageNumber': pageNumber,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Highlight.fromJson(Map<String, dynamic> json) => Highlight(
        pageNumber: json['pageNumber'] as int,
        text: json['text'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
