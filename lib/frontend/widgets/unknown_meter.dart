import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'design_widgets.dart';

/// A neutral track until a received value exists; never an indeterminate timer.
class UnknownMeter extends StatelessWidget {
  const UnknownMeter({super.key, required this.label, this.fraction});
  final String label;
  final double? fraction;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: AppTheme.outline,
              borderRadius: BorderRadius.circular(10),
            ),
            child: fraction == null
                ? null
                : FractionallySizedBox(
                    widthFactor: fraction!.clamp(0, 1),
                    alignment: Alignment.centerLeft,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppTheme.crimson,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Text(label, style: mutedStyle),
        ],
      ),
    ),
  );
}
