class Tutorial {
  final String id;
  final String title;
  final String description;
  final String fileName;
  final String category;
  final String iconName;
  final DateTime lastUpdated;
  final int estimatedReadTime; // en minutos
  final List<String> tags;
  final bool isRequired;
  final int priority; // 1 = alta, 2 = media, 3 = baja

  const Tutorial({
    required this.id,
    required this.title,
    required this.description,
    required this.fileName,
    required this.category,
    required this.iconName,
    required this.lastUpdated,
    required this.estimatedReadTime,
    required this.tags,
    this.isRequired = false,
    this.priority = 2,
  });

  Tutorial copyWith({
    String? id,
    String? title,
    String? description,
    String? fileName,
    String? category,
    String? iconName,
    DateTime? lastUpdated,
    int? estimatedReadTime,
    List<String>? tags,
    bool? isRequired,
    int? priority,
  }) {
    return Tutorial(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      fileName: fileName ?? this.fileName,
      category: category ?? this.category,
      iconName: iconName ?? this.iconName,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      estimatedReadTime: estimatedReadTime ?? this.estimatedReadTime,
      tags: tags ?? this.tags,
      isRequired: isRequired ?? this.isRequired,
      priority: priority ?? this.priority,
    );
  }
}