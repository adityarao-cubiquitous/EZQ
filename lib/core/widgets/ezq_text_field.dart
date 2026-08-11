import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    this.prefix,
    this.focusNode,
    this.inputFormatters,
    this.hintStyle,
    this.validator,
  });

  final String label;
  final String? hintText;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? prefixText;
  final Widget? prefix;
  final FocusNode? focusNode;
  final List<TextInputFormatter>? inputFormatters;
  final TextStyle? hintStyle;
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
          focusNode: focusNode,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(color: AppColors.navyText, fontSize: 16),
          decoration: InputDecoration(
            hintText: hintText,
            prefixText: prefixText,
            prefixIcon: prefix == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 16, right: 2),
                    child: Center(widthFactor: 1, child: prefix),
                  ),
            prefixIconConstraints: prefix == null
                ? null
                : const BoxConstraints(minWidth: 0, minHeight: 0),
            hintStyle: hintStyle ?? const TextStyle(color: Color(0xFF6B7280)),
          ),
        ),
      ],
    );
  }
}
