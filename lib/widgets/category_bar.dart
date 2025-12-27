import 'package:flutter/material.dart';
import '../services/category_service.dart';
import '../models/category_model.dart';
import 'skeleton_loader.dart';

class CategoryBar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onSelect;
  final bool isLoading;

  const CategoryBar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    this.isLoading = false,
  });

  @override
  State<CategoryBar> createState() => _CategoryBarState();
}

class _CategoryBarState extends State<CategoryBar> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant CategoryBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _autoCenterCategory();
    }
  }

  void _autoCenterCategory() {
    final double itemWidth = 100; // largura aproximada
    final double screenWidth = MediaQuery.of(context).size.width;
    final double targetOffset =
        (widget.selectedIndex * itemWidth) - (screenWidth / 2 - itemWidth / 2);

    _scrollController.animateTo(
      targetOffset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Usar categorias dinâmicas do serviço
    final categories = CategoryService.categories;
    
    // Se estiver carregando ou não houver categorias, mostrar skeleton
    if (widget.isLoading || categories.isEmpty) {
      return const CategoryBarSkeleton(itemCount: 5);
    }
    
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final isSelected = index == widget.selectedIndex;
            final category = categories[index];
            return GestureDetector(
              onTap: () => widget.onSelect(index),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.deepPurple.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  category.name,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.deepPurple
                        : Colors.grey.shade700,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
