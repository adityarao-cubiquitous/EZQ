import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class CollapsibleDashboardControls extends StatefulWidget {
  const CollapsibleDashboardControls({
    super.key,
    required this.enabled,
    required this.expanded,
    required this.onExpandedChanged,
    required this.child,
  });

  final bool enabled;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final Widget child;

  @override
  State<CollapsibleDashboardControls> createState() =>
      _CollapsibleDashboardControlsState();
}

class _CollapsibleDashboardControlsState
    extends State<CollapsibleDashboardControls> {
  late bool _expanded = widget.expanded;

  @override
  void didUpdateWidget(CollapsibleDashboardControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded != widget.expanded && _expanded != widget.expanded) {
      _expanded = widget.expanded;
    }
  }

  void _toggleExpanded() {
    final expanded = !_expanded;
    setState(() => _expanded = expanded);
    widget.onExpandedChanged(expanded);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey('dashboard-controls-toggle'),
            borderRadius: BorderRadius.circular(12),
            onTap: _toggleExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    turns: _expanded ? 0.5 : 0,
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: AppColors.deepTeal,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Dashboard Controls',
                    style: TextStyle(
                      color: AppColors.deepTeal,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _expanded
              ? KeyedSubtree(
                  key: const ValueKey('dashboard-controls-expanded'),
                  child: widget.child,
                )
              : const SizedBox(
                  key: ValueKey('dashboard-controls-collapsed'),
                  width: double.infinity,
                ),
        ),
      ],
    );
  }
}
