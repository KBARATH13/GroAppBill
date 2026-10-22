import 'package:flutter/material.dart';

class CategorySortButton extends StatelessWidget {
  final bool alphabetical;
  final VoidCallback onPressed;

  const CategorySortButton({
    super.key,
    required this.alphabetical,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: alphabetical
          ? 'Sort categories by product count'
          : 'Sort categories alphabetically',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 48),
      color: alphabetical
          ? Theme.of(context).colorScheme.primary
          : Colors.white70,
      icon: const Icon(Icons.swap_vert),
      onPressed: onPressed,
    );
  }
}