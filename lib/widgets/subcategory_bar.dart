import 'package:flutter/material.dart';

class SubCategoryBar extends StatelessWidget {
  final Function(String) onSelect;
  final String? selectedSub;

  const SubCategoryBar({super.key, required this.onSelect, this.selectedSub});

  @override
  Widget build(BuildContext context) {
    const subCategories = [
      'Mais populares',
      'Mais comprados',
      'Mais baratos',
      'Novos',
      'Promoções',
      'Recomendados',
    ];

    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (context, index) {
          final sub = subCategories[index];
          final isSelected = sub == selectedSub;

          return GestureDetector(
            onTap: () => onSelect(sub),
            child: Chip(
              label: Text(sub),
              backgroundColor: isSelected
                  ? Colors.deepPurple
                  : Colors.deepPurple.shade50,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.deepPurple,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: subCategories.length,
      ),
    );
  }
}
