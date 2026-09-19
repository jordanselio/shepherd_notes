import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The app's one shared "pill" toggle style: a neutral track holding a
/// raised, plain-typographic selected segment -- no color fill, no
/// checkmark. Used by Schedule's Day/Week switch and Prayer's
/// Active/Answered switch, so both look identical by construction rather
/// than by two copies of the same styling staying in sync by hand.
class SegmentedToggle<T> extends StatelessWidget {
  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;

  const SegmentedToggle({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = surfaceTokens(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: tokens.toggleTrack,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < values.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            _Segment(
              label: labels[i],
              selected: values[i] == selected,
              onTap: () => onChanged(values[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = surfaceTokens(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? tokens.selectedPill : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected && isLight
              ? [
                  BoxShadow(
                    color: scheme.onSurface.withValues(alpha: 0.12),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
