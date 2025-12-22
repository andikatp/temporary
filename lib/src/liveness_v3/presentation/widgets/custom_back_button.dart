import 'package:flutter/material.dart';

class CustomBackButton extends StatelessWidget {
  const CustomBackButton({required this.onTap, super.key});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const .all(10),
        decoration: BoxDecoration(
          borderRadius: .circular(16),
          color: Colors.black,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.6),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.chevron_left, size: 16, color: Colors.white),
      ),
    );
  }
}
