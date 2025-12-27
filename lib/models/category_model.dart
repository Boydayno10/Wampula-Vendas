class CategoryModel {
  final String id;
  final String name;
  final String? icon;
  final String? description;
  final int displayOrder;
  final bool active;
  final DateTime createdAt;

  CategoryModel({
    required this.id,
    required this.name,
    this.icon,
    this.description,
    required this.displayOrder,
    required this.active,
    required this.createdAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      description: json['description'] as String?,
      displayOrder: json['display_order'] as int? ?? 0,
      active: json['active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'description': description,
      'display_order': displayOrder,
      'active': active,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
