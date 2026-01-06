import '../services/product_filter_service.dart';

/// Modelo de Subcategoria
/// Gerenciado apenas por administradores no Supabase
class SubcategoryModel {
  final String id;
  final String name;
  final String? description;
  final ProductFilterType filterType;
  final int displayOrder;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  SubcategoryModel({
    required this.id,
    required this.name,
    this.description,
    required this.filterType,
    required this.displayOrder,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SubcategoryModel.fromJson(Map<String, dynamic> json) {
    return SubcategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      filterType: _parseFilterType(json['filter_type'] as String),
      displayOrder: json['display_order'] as int? ?? 0,
      active: json['active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'filter_type': _filterTypeToString(filterType),
      'display_order': displayOrder,
      'active': active,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Converte string do banco para enum
  static ProductFilterType _parseFilterType(String filterTypeString) {
    switch (filterTypeString) {
      case 'maisPopulares':
        return ProductFilterType.maisPopulares;
      case 'maisComprados':
        return ProductFilterType.maisComprados;
      case 'maisBaratos':
        return ProductFilterType.maisBaratos;
      case 'novos':
        return ProductFilterType.novos;
      case 'promocoes':
        return ProductFilterType.promocoes;
      case 'recomendados':
        return ProductFilterType.recomendados;
      default:
        return ProductFilterType.recomendados;
    }
  }

  /// Converte enum para string do banco
  static String _filterTypeToString(ProductFilterType filterType) {
    switch (filterType) {
      case ProductFilterType.maisPopulares:
        return 'maisPopulares';
      case ProductFilterType.maisComprados:
        return 'maisComprados';
      case ProductFilterType.maisBaratos:
        return 'maisBaratos';
      case ProductFilterType.novos:
        return 'novos';
      case ProductFilterType.promocoes:
        return 'promocoes';
      case ProductFilterType.recomendados:
        return 'recomendados';
    }
  }
}
