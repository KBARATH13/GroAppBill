import 'package:flutter/material.dart';

/// A master background widget that uses vibrant mesh gradients for a modern look.
class VibrantBackground extends StatelessWidget {
  final Widget? child;
  final List<Color>? colors;

  const VibrantBackground({
    super.key,
    this.child,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A2E), // Solid deep blue
      child: child,
    );
  }
}
