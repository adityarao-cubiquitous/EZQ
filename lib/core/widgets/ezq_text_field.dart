import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class EzqTextField extends StatelessWidget {
  const EzqTextField({
    super.key,
    required this.label,
    this.hintText,
    this.controller,
    this.keyboardType,
    this.maxLines = 1,
    this.prefixText,
    this.validator,
  });

  final String label;
  final String? hintText;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? prefixText;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF3E484F),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.28,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(color: AppColors.navyText, fontSize: 16),
          decoration: InputDecoration(
            hintText: hintText,
            prefixText: prefixText,
            hintStyle: const TextStyle(color: Color(0xFF6B7280)),
          ),
        ),
      ],
    );
  }
}
