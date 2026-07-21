import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

typedef ResponsiveFloorItemBuilder =
    Widget Function(BuildContext context, int index, double width);
typedef ResponsiveFloorWidthBuilder = double Function(int index);

class ResponsiveCapacitySection extends StatelessWidget {
  const ResponsiveCapacitySection({
    super.key,
    required this.header,
    required this.floorCount,
    required this.floorBuilder,
    required this.minFloorWidth,
    required this.headerToGridGap,
    required this.floorGap,
    this.floorWidthBuilder,
  });

  final Widget header;
  final int floorCount;
  final ResponsiveFloorItemBuilder floorBuilder;
  final double minFloorWidth;
  final double headerToGridGap;
  final double floorGap;
  final ResponsiveFloorWidthBuilder? floorWidthBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        SizedBox(height: headerToGridGap),
        ResponsiveFloorGrid(
          itemCount: floorCount,
          itemBuilder: floorBuilder,
          minItemWidth: minFloorWidth,
          itemGap: floorGap,
          itemWidthBuilder: floorWidthBuilder,
        ),
      ],
    );
  }
}

class ResponsiveFloorGrid extends StatefulWidget {
  const ResponsiveFloorGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.minItemWidth,
    required this.itemGap,
    this.itemWidthBuilder,
  });

  final int itemCount;
  final ResponsiveFloorItemBuilder itemBuilder;
  final double minItemWidth;
  final double itemGap;
  final ResponsiveFloorWidthBuilder? itemWidthBuilder;

  @override
  State<ResponsiveFloorGrid> createState() => _ResponsiveFloorGridState();
}

class _ResponsiveFloorGridState extends State<ResponsiveFloorGrid> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final itemWidths = [
          for (var index = 0; index < widget.itemCount; index++)
            _itemWidthFor(index),
        ];
        final totalGaps = widget.itemGap * (widget.itemCount - 1);
        final contentWidth =
            itemWidths.fold<double>(0, (sum, width) => sum + width) + totalGaps;
        final rows = _FloorGridRows(
          itemCount: widget.itemCount,
          itemBuilder: widget.itemBuilder,
          itemWidths: itemWidths,
          itemGap: widget.itemGap,
          columns: widget.itemCount,
        );
        if (!availableWidth.isFinite) {
          return rows;
        }

        if (contentWidth <= availableWidth) {
          return rows;
        }

        return ScrollConfiguration(
          behavior: const _FloorRailScrollBehavior(),
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            trackVisibility: true,
            interactive: true,
            thickness: 5,
            radius: const Radius.circular(999),
            scrollbarOrientation: ScrollbarOrientation.bottom,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SingleChildScrollView(
                key: const ValueKey('floor-horizontal-scroll'),
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: SizedBox(width: contentWidth, child: rows),
              ),
            ),
          ),
        );
      },
    );
  }

  double _itemWidthFor(int index) {
    final preferredWidth = widget.itemWidthBuilder?.call(index);
    if (preferredWidth == null || preferredWidth < widget.minItemWidth) {
      return widget.minItemWidth;
    }
    return preferredWidth;
  }
}

class _FloorRailScrollBehavior extends MaterialScrollBehavior {
  const _FloorRailScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}

class _FloorGridRows extends StatelessWidget {
  const _FloorGridRows({
    required this.itemCount,
    required this.itemBuilder,
    required this.itemWidths,
    required this.itemGap,
    required this.columns,
  });

  final int itemCount;
  final ResponsiveFloorItemBuilder itemBuilder;
  final List<double> itemWidths;
  final double itemGap;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var start = 0; start < itemCount; start += columns) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (
                  var index = start;
                  index < itemCount && index < start + columns;
                  index++
                ) ...[
                  SizedBox(
                    width: itemWidths[index],
                    child: itemBuilder(context, index, itemWidths[index]),
                  ),
                  if (index < itemCount - 1 && index < start + columns - 1)
                    SizedBox(width: itemGap),
                ],
              ],
            ),
          ),
          if (start + columns < itemCount) SizedBox(height: itemGap),
        ],
      ],
    );
  }
}
