import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class EzqButton extends StatelessWidget {
  const EzqButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.destructive = false,
    this.large = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool destructive;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final height = large ? 60.0 : 54.0;
    if (destructive) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFBA1A1A),
            side: const BorderSide(color: Color(0x44BA1A1A), width: 2),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
          child: Text(label),
        ),
      );
    }

    final enabled = onPressed != null;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: enabled ? 1 : 0.48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: enabled
                  ? AppColors.primaryGradient
                  : const LinearGradient(
                      colors: [Color(0xFFB8C8D2), Color(0xFF8DA3AE)],
                    ),
              borderRadius: const BorderRadius.all(Radius.circular(999)),
              boxShadow: enabled
                  ? const [
                      BoxShadow(
                        color: Color(0x2E12A9DC),
                        blurRadius: 18,
                        offset: Offset(0, 9),
                      ),
                    ]
                  : const [],
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: large ? 19 : 16,
                      fontWeight: large ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 10),
                    Icon(icon, color: Colors.white, size: large ? 20 : 18),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
