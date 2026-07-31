import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class DialogCloseButton extends StatelessWidget {
  const DialogCloseButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
  });

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: const Icon(Icons.close_rounded),
      style: IconButton.styleFrom(
        foregroundColor: AppColors.mutedText,
        backgroundColor: AppColors.softSurface,
      ),
    );
  }
}
