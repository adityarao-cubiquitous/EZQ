import 'package:flutter/material.dart';

import '../../../../core/widgets/dialog_close_button.dart';

class SetupSummaryDialog extends StatelessWidget {
  const SetupSummaryDialog({super.key, required this.summaryText});

  final String summaryText;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      title: Row(
        children: [
          const Expanded(child: Text('Setup Summary')),
          DialogCloseButton(
            key: const ValueKey('setup-summary-close'),
            tooltip: 'Close Setup Summary',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(child: SelectableText(summaryText)),
      ),
    );
  }
}
