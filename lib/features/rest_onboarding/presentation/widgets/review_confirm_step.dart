import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import 'table_configuration_matrix.dart';

class ReviewConfirmStep extends StatelessWidget {
  const ReviewConfirmStep({
    super.key,
    required this.restaurantName,
    required this.branchName,
    required this.area,
    required this.floorCount,
    required this.selectedTableCapacities,
    required this.tableCountsByFloor,
    required this.totalTables,
    required this.totalSeats,
    required this.onBack,
    required this.onSaveDraft,
    required this.onConfirm,
  });

  final String restaurantName;
  final String branchName;
  final String area;
  final int floorCount;
  final List<int> selectedTableCapacities;
  final List<List<int>> tableCountsByFloor;
  final int totalTables;
  final int totalSeats;
  final VoidCallback onBack;
  final VoidCallback onSaveDraft;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= 768;

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _StepHeader(
                  title: 'Review & Confirm',
                  subtitle:
                      'Review restaurant details and table configuration before completing setup.',
                ),
                const SizedBox(height: 24),
                _SectionPanel(
                  child: _DetailGroup(
                    title: 'Restaurant Information',
                    rows: [
                      _DetailRow('Restaurant Name', restaurantName),
                      _DetailRow('Branch Name', branchName),
                      _DetailRow(
                        'Area / Locality',
                        area.isEmpty ? 'Not specified' : area,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _SectionPanel(
                  child: _RestaurantLayoutSection(
                    floorCount: floorCount,
                    selectedTableCapacities: selectedTableCapacities,
                    tableCountsByFloor: tableCountsByFloor,
                  ),
                ),
                const SizedBox(height: 20),
                _SectionPanel(
                  surface: AppColors.softSurface,
                  child: TableConfigurationMatrix(
                    title: 'Restaurant Layout Matrix',
                    selectedCapacities: selectedTableCapacities,
                    tableCountsByFloor: tableCountsByFloor,
                  ),
                ),
                const SizedBox(height: 20),
                _SectionPanel(
                  child: _TotalsSection(
                    floorCount: floorCount,
                    capacityTypeCount: selectedTableCapacities.length,
                    totalTables: totalTables,
                    totalSeats: totalSeats,
                  ),
                ),
                const SizedBox(height: 32),
                _FooterActions(
                  isMobile: isMobile,
                  onBack: onBack,
                  onSaveDraft: onSaveDraft,
                  onConfirm: onConfirm,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.navyText,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.mutedText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({required this.child, this.surface});

  final Widget child;
  final Color? surface;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface ?? AppColors.background,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _DetailGroup extends StatelessWidget {
  const _DetailGroup({required this.title, required this.rows});

  final String title;
  final List<_DetailRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.navyText,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        for (var index = 0; index < rows.length; index++) ...[
          _ReviewLine(label: rows[index].label, value: rows[index].value),
          if (index != rows.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _DetailRow {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;
}

class _RestaurantLayoutSection extends StatelessWidget {
  const _RestaurantLayoutSection({
    required this.floorCount,
    required this.selectedTableCapacities,
    required this.tableCountsByFloor,
  });

  final int floorCount;
  final List<int> selectedTableCapacities;
  final List<List<int>> tableCountsByFloor;

  @override
  Widget build(BuildContext context) {
    final hasTableCounts = selectedTableCapacities.asMap().entries.any(
      (entry) => _capacityTotal(entry.key) > 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Restaurant Layout',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.navyText,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        _ReviewLine(label: 'Number of Floors', value: '$floorCount'),
        const SizedBox(height: 16),
        Text(
          'Capacity Types',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.navyText,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        if (selectedTableCapacities.isEmpty)
          Text(
            'No capacities configured',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w700,
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final capacity in selectedTableCapacities)
                _CapacityChip(label: '$capacity Top'),
            ],
          ),
        const SizedBox(height: 18),
        Text(
          'Tables per Capacity',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.navyText,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        if (selectedTableCapacities.isEmpty || !hasTableCounts)
          Text(
            selectedTableCapacities.isEmpty
                ? 'No table capacity types selected.'
                : 'No configured table counts yet.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w700,
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (
                var index = 0;
                index < selectedTableCapacities.length;
                index++
              )
                if (_capacityTotal(index) > 0)
                  SizedBox(
                    width: 180,
                    height: 68,
                    child: _SummaryPill(
                      label: '${selectedTableCapacities[index]} Top',
                      value: '${_capacityTotal(index)} tables',
                    ),
                  ),
            ],
          ),
      ],
    );
  }

  int _capacityTotal(int capacityIndex) {
    return tableCountsByFloor.fold<int>(
      0,
      (total, floorCounts) =>
          total +
          (capacityIndex < floorCounts.length ? floorCounts[capacityIndex] : 0),
    );
  }
}

class _TotalsSection extends StatelessWidget {
  const _TotalsSection({
    required this.floorCount,
    required this.capacityTypeCount,
    required this.totalTables,
    required this.totalSeats,
  });

  final int floorCount;
  final int capacityTypeCount;
  final int totalTables;
  final int totalSeats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Totals',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.navyText,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth = constraints.maxWidth >= 960
                ? (constraints.maxWidth - 48) / 4
                : constraints.maxWidth >= 560
                ? (constraints.maxWidth - 16) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: tileWidth,
                  height: 104,
                  child: _MetricTile(label: 'Floors', value: '$floorCount'),
                ),
                SizedBox(
                  width: tileWidth,
                  height: 104,
                  child: _MetricTile(
                    label: 'Capacity Types',
                    value: '$capacityTypeCount',
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  height: 104,
                  child: _MetricTile(
                    label: 'Total Tables',
                    value: '$totalTables',
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  height: 104,
                  child: _MetricTile(
                    label: 'Total Seats',
                    value: '$totalSeats',
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.navyText,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 152),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.mutedText,
            fontWeight: FontWeight.w700,
          ),
          children: [
            TextSpan(
              text: '$label\n',
              style: const TextStyle(
                color: AppColors.navyText,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
            TextSpan(text: value, style: const TextStyle(height: 1.3)),
          ],
        ),
      ),
    );
  }
}

class _CapacityChip extends StatelessWidget {
  const _CapacityChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Capacity type $label',
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.softSurface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.navyText,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ReviewLine extends StatelessWidget {
  const _ReviewLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelWidth = constraints.maxWidth >= 520 ? 180.0 : 132.0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: labelWidth,
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.navyText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FooterActions extends StatelessWidget {
  const _FooterActions({
    required this.isMobile,
    required this.onBack,
    required this.onSaveDraft,
    required this.onConfirm,
  });

  final bool isMobile;
  final VoidCallback onBack;
  final VoidCallback onSaveDraft;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SecondaryButton(label: 'Back', onPressed: onBack),
          const SizedBox(height: 12),
          _SaveDraftButton(onPressed: onSaveDraft),
          const SizedBox(height: 12),
          _GradientButton(label: 'Confirm Setup', onPressed: onConfirm),
        ],
      );
    }

    return Row(
      children: [
        _SecondaryButton(label: 'Back', onPressed: onBack),
        const SizedBox(width: 16),
        Flexible(child: _SaveDraftButton(onPressed: onSaveDraft)),
        const Spacer(),
        Flexible(
          flex: 2,
          child: Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 240, maxWidth: 420),
              child: _GradientButton(
                label: 'Confirm Setup',
                onPressed: onConfirm,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SaveDraftButton extends StatelessWidget {
  const _SaveDraftButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.save_outlined, size: 18),
      label: const Text('Save Draft'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.deepTeal,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryTeal,
        side: const BorderSide(color: AppColors.primaryTeal),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.primaryTeal,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.progressGradient,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.background,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
