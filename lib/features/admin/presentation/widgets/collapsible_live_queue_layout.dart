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
  double? _requestedPanelWidth;
  bool _isResizing = false;

  static const double _splitMaxPanelWidth = 620;
  static const double _minimumTablesWidth = 320;
  static const double _minimumContentWidth = 240;

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
        final defaultPanelWidth = split
            ? (width * 0.36).clamp(340.0, 480.0).toDouble()
            : width < 600
            ? math.max(0, width - (pagePadding * 2))
            : math.min(560.0, width * 0.88);
        final maximumPanelWidth = split
            ? math.max(
                0,
                math.min(
                  _splitMaxPanelWidth,
                  width - (pagePadding * 2) - gap - _minimumTablesWidth,
                ),
              )
            : math.max(0, width - (pagePadding * 2));
        final panelWidth = (_requestedPanelWidth ?? defaultPanelWidth)
            .clamp(0.0, maximumPanelWidth)
            .toDouble();
        final animationDuration =
            _isResizing || MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240);
        final open = widget.isLiveQueueOpen;
        final panelVisible = open && panelWidth > 0;
        final contentVisible =
            panelVisible && panelWidth >= _minimumContentWidth;
        final tableRightPadding = split && panelVisible
            ? pagePadding + panelWidth + gap
            : pagePadding;
        const handleWidth = 30.0;
        const handleHeight = 82.0;
        final handleRight = panelVisible
            ? math.min(
                pagePadding + panelWidth - (handleWidth / 2),
                width - handleWidth,
              )
            : pagePadding;
        final handleTop = height.isFinite
            ? math.max(pagePadding, (height - handleHeight) / 2)
            : pagePadding + 96;

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
                    ignoring: split || !panelVisible,
                    child: AnimatedOpacity(
                      duration: animationDuration,
                      opacity: !split && panelVisible ? 1 : 0,
                      child: ModalBarrier(
                        dismissible: true,
                        onDismiss: () => widget.onLiveQueueOpenChanged(false),
                        color: Colors.black.withValues(alpha: 0.24),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  key: const ValueKey('live-queue-panel'),
                  top: pagePadding,
                  bottom: pagePadding,
                  right: pagePadding,
                  width: panelVisible ? panelWidth : 0,
                  child: IgnorePointer(
                    ignoring: !contentVisible,
                    child: ClipRect(
                      child: Material(
                        color: Colors.transparent,
                        elevation: contentVisible && !split ? 18 : 0,
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: Offstage(
                          offstage: !contentVisible,
                          child: SingleChildScrollView(
                            controller: _queueScrollController,
                            child: widget.liveQueue,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  key: const ValueKey('live-queue-handle-position'),
                  top: handleTop,
                  right: handleRight,
                  child: _LiveQueueHandle(
                    isOpen: panelVisible,
                    onDragStart: () {
                      if (!mounted) return;
                      setState(() {
                        _isResizing = true;
                        _requestedPanelWidth = panelVisible ? panelWidth : 0;
                      });
                      if (!open) widget.onLiveQueueOpenChanged(true);
                    },
                    onDragUpdate: (delta) {
                      if (!mounted || !_isResizing || !delta.isFinite) return;
                      setState(() {
                        _requestedPanelWidth = (panelWidth - delta)
                            .clamp(0.0, maximumPanelWidth)
                            .toDouble();
                      });
                    },
                    onDragEnd: () {
                      if (!mounted) return;
                      final hidden = (_requestedPanelWidth ?? panelWidth) <= 0;
                      setState(() {
                        _isResizing = false;
                        if (hidden) _requestedPanelWidth = 0;
                      });
                      if (hidden && open) {
                        widget.onLiveQueueOpenChanged(false);
                      }
                    },
                    onIncrease: () {
                      if (!mounted) return;
                      setState(() {
                        _requestedPanelWidth = (panelWidth + 40)
                            .clamp(0.0, maximumPanelWidth)
                            .toDouble();
                      });
                      if (!open) widget.onLiveQueueOpenChanged(true);
                    },
                    onDecrease: () {
                      if (!mounted) return;
                      final nextWidth = (panelWidth - 40)
                          .clamp(0.0, maximumPanelWidth)
                          .toDouble();
                      setState(() => _requestedPanelWidth = nextWidth);
                      if (nextWidth <= 0 && open) {
                        widget.onLiveQueueOpenChanged(false);
                      }
                    },
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

class _LiveQueueHandle extends StatefulWidget {
  const _LiveQueueHandle({
    required this.isOpen,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onIncrease,
    required this.onDecrease,
  });

  final bool isOpen;
  final VoidCallback onDragStart;
  final ValueChanged<double> onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  @override
  State<_LiveQueueHandle> createState() => _LiveQueueHandleState();
}

class _LiveQueueHandleState extends State<_LiveQueueHandle> {
  int? _activePointer;
  double? _lastGlobalX;

  void _start(PointerDownEvent event) {
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    _lastGlobalX = event.position.dx;
    widget.onDragStart();
  }

  void _move(PointerMoveEvent event) {
    if (_activePointer != event.pointer) return;
    final previousX = _lastGlobalX;
    final currentX = event.position.dx;
    if (previousX == null || !previousX.isFinite || !currentX.isFinite) return;
    _lastGlobalX = currentX;
    final delta = currentX - previousX;
    if (delta.isFinite && delta != 0) widget.onDragUpdate(delta);
  }

  void _finish(int pointer) {
    if (_activePointer != pointer) return;
    _activePointer = null;
    _lastGlobalX = null;
    widget.onDragEnd();
  }

  @override
  Widget build(BuildContext context) {
    const label = 'Resize Live Queue';
    return Semantics(
      slider: true,
      label: label,
      hint: 'Drag horizontally to change the panel width',
      onIncrease: widget.onIncrease,
      onDecrease: widget.onDecrease,
      child: Listener(
        key: const ValueKey('live-queue-resize-handle'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: _start,
        onPointerMove: _move,
        onPointerUp: (event) => _finish(event.pointer),
        onPointerCancel: (event) => _finish(event.pointer),
        child: Container(
          width: 30,
          height: 82,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF4FCFB), Color(0xFFDDF4F1)],
            ),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFFB9E3DD)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F0F766E),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.isOpen
                    ? Icons.drag_indicator_rounded
                    : Icons.keyboard_double_arrow_left_rounded,
                color: AppColors.deepTeal,
                size: 19,
              ),
              const SizedBox(height: 7),
              Container(
                width: 3,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(alpha: 0.56),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
