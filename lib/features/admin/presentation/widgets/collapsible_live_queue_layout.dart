import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';

const double liveQueueSplitLandscapeBreakpoint = 900;
const double liveQueueSplitWideBreakpoint = 1200;

bool useSplitLiveQueueLayout({required double width, required double height}) {
  return width >= liveQueueSplitWideBreakpoint ||
      (width > height && width >= liveQueueSplitLandscapeBreakpoint);
}

class CollapsibleLiveQueueLayout extends StatefulWidget {
  const CollapsibleLiveQueueLayout({
    super.key,
    required this.isLiveQueueOpen,
    required this.onLiveQueueOpenChanged,
    required this.tables,
    required this.liveQueue,
    this.compact = false,
  });

  final bool isLiveQueueOpen;
  final ValueChanged<bool> onLiveQueueOpenChanged;
  final Widget tables;
  final Widget liveQueue;
  final bool compact;

  @override
  State<CollapsibleLiveQueueLayout> createState() =>
      _CollapsibleLiveQueueLayoutState();
}

class _CollapsibleLiveQueueLayoutState
    extends State<CollapsibleLiveQueueLayout> {
  final ScrollController _tablesScrollController = ScrollController();
  final ScrollController _queueScrollController = ScrollController();

  @override
  void dispose() {
    _tablesScrollController.dispose();
    _queueScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = MediaQuery.sizeOf(context);
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final split = useSplitLiveQueueLayout(
          width: width,
          height: height.isFinite ? height : viewport.height,
        );
        final pagePadding = widget.compact ? 12.0 : 24.0;
        final gap = widget.compact ? 12.0 : 16.0;
        final panelWidth =
            (split
                    ? (width * 0.36).clamp(340.0, 480.0)
                    : width < 600
                    ? math.max(0, width - pagePadding)
                    : math.min(560.0, width * 0.88))
                .toDouble();
        final animationDuration = MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240);
        final open = widget.isLiveQueueOpen;
        final queueRight = open ? pagePadding : -(panelWidth + gap);
        final tableRightPadding = split && open
            ? pagePadding + panelWidth + gap
            : pagePadding;
        final handleRight = open
            ? math.min(pagePadding + panelWidth - 22, width - 44)
            : pagePadding;

        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (!split && open) widget.onLiveQueueOpenChanged(false);
            },
          },
          child: Focus(
            autofocus: !split && open,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(
                  child: AnimatedPadding(
                    key: const ValueKey('live-queue-tables-area'),
                    duration: animationDuration,
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.fromLTRB(
                      pagePadding,
                      pagePadding,
                      tableRightPadding,
                      pagePadding,
                    ),
                    child: SingleChildScrollView(
                      key: const ValueKey('live-queue-tables-scroll'),
                      controller: _tablesScrollController,
                      child: widget.tables,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: split || !open,
                    child: AnimatedOpacity(
                      duration: animationDuration,
                      opacity: !split && open ? 1 : 0,
                      child: ModalBarrier(
                        dismissible: true,
                        onDismiss: () => widget.onLiveQueueOpenChanged(false),
                        color: Colors.black.withValues(alpha: 0.24),
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  key: const ValueKey('live-queue-panel'),
                  duration: animationDuration,
                  curve: Curves.easeOutCubic,
                  top: pagePadding,
                  bottom: pagePadding,
                  right: queueRight,
                  width: panelWidth,
                  child: Material(
                    color: Colors.transparent,
                    elevation: split ? 0 : 18,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      controller: _queueScrollController,
                      child: widget.liveQueue,
                    ),
                  ),
                ),
                AnimatedPositioned(
                  key: const ValueKey('live-queue-handle-position'),
                  duration: animationDuration,
                  curve: Curves.easeOutCubic,
                  top: pagePadding + 16,
                  right: handleRight,
                  child: _LiveQueueHandle(
                    isOpen: open,
                    onPressed: () => widget.onLiveQueueOpenChanged(!open),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LiveQueueHandle extends StatelessWidget {
  const _LiveQueueHandle({required this.isOpen, required this.onPressed});

  final bool isOpen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = isOpen ? 'Hide Live Queue' : 'Show Live Queue';
    return Semantics(
      button: true,
      expanded: isOpen,
      label: label,
      child: Material(
        color: AppColors.deepTeal,
        elevation: 6,
        shape: const StadiumBorder(),
        child: IconButton(
          key: const ValueKey('live-queue-toggle'),
          tooltip: label,
          onPressed: onPressed,
          icon: Icon(
            isOpen ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
          ),
          color: Colors.white,
          iconSize: 26,
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          style: IconButton.styleFrom(
            focusColor: AppColors.tracuraCyan.withValues(alpha: 0.34),
            hoverColor: AppColors.primaryTeal.withValues(alpha: 0.2),
          ),
        ),
      ),
    );
  }
}
