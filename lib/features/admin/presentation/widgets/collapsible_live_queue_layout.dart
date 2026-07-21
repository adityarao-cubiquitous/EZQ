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
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            key: const ValueKey('live-queue-toggle'),
            width: 42,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.deepTeal, AppColors.inkBlue],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33153647),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: InkWell(
              onTap: onPressed,
              focusColor: AppColors.tracuraCyan.withValues(alpha: 0.34),
              hoverColor: AppColors.primaryTeal.withValues(alpha: 0.2),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        isOpen
                            ? Icons.close_fullscreen_rounded
                            : Icons.view_sidebar_rounded,
                        key: ValueKey(isOpen),
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Text(
                          isOpen ? 'HIDE QUEUE' : 'LIVE QUEUE',
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 18,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
