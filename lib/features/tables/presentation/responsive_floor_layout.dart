import 'package:flutter/widgets.dart';

typedef ResponsiveFloorItemBuilder =
    Widget Function(BuildContext context, int index, double width);

class ResponsiveCapacitySection extends StatelessWidget {
  const ResponsiveCapacitySection({
    super.key,
    required this.header,
    required this.floorCount,
    required this.floorBuilder,
    required this.minFloorWidth,
    required this.headerToGridGap,
    required this.floorGap,
  });

  final Widget header;
  final int floorCount;
  final ResponsiveFloorItemBuilder floorBuilder;
  final double minFloorWidth;
  final double headerToGridGap;
  final double floorGap;

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
        ),
      ],
    );
  }
}

class ResponsiveFloorGrid extends StatelessWidget {
  const ResponsiveFloorGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.minItemWidth,
    required this.itemGap,
  });

  final int itemCount;
  final ResponsiveFloorItemBuilder itemBuilder;
  final double minItemWidth;
  final double itemGap;

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        if (!availableWidth.isFinite) {
          return _FloorGridRows(
            itemCount: itemCount,
            itemBuilder: itemBuilder,
            itemWidth: minItemWidth,
            itemGap: itemGap,
            columns: itemCount,
          );
        }

        final columns = _columnCountFor(availableWidth);
        final itemWidth =
            (availableWidth - (itemGap * (columns - 1))) / columns;
        if (itemWidth >= minItemWidth) {
          return _FloorGridRows(
            itemCount: itemCount,
            itemBuilder: itemBuilder,
            itemWidth: itemWidth,
            itemGap: itemGap,
            columns: columns,
          );
        }

        final scrollWidth =
            (minItemWidth * itemCount) + (itemGap * (itemCount - 1));
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: scrollWidth,
            child: _FloorGridRows(
              itemCount: itemCount,
              itemBuilder: itemBuilder,
              itemWidth: minItemWidth,
              itemGap: itemGap,
              columns: itemCount,
            ),
          ),
        );
      },
    );
  }

  int _columnCountFor(double availableWidth) {
    final rawColumns = ((availableWidth + itemGap) / (minItemWidth + itemGap))
        .floor();
    return rawColumns.clamp(1, itemCount);
  }
}

class _FloorGridRows extends StatelessWidget {
  const _FloorGridRows({
    required this.itemCount,
    required this.itemBuilder,
    required this.itemWidth,
    required this.itemGap,
    required this.columns,
  });

  final int itemCount;
  final ResponsiveFloorItemBuilder itemBuilder;
  final double itemWidth;
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
                    width: itemWidth,
                    child: itemBuilder(context, index, itemWidth),
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
