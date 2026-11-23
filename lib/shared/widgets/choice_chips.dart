import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// A selectable chip, used anywhere a short list of options would otherwise
/// hide inside a dropdown.
///
/// The app prefers these to `AppDropdownField` when there are five or fewer
/// options and the choice changes what the rest of the screen offers — seeing
/// the alternatives is worth the vertical space.
class AppChoiceChip extends StatelessWidget {
  const AppChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.leading,
    this.color = AppColors.primary,
    this.pill = false,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  /// Replaces [icon] with an arbitrary widget, e.g. a contact avatar.
  final Widget? leading;

  final Color color;

  /// Fully rounded. Used for free-text suggestions; option chips stay at the
  /// app's usual 10px radius.
  final bool pill;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(pill ? 20 : 10);
    final tint = !enabled
        ? AppColors.textMuted
        : selected
            ? color
            : AppColors.textSecondary;

    return Material(
      color: selected && enabled
          ? color.withValues(alpha: 0.12)
          : AppColors.surfaceMuted,
      borderRadius: radius,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: radius,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: pill ? 13 : 11,
            vertical: pill ? 7 : 9,
          ),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected && enabled
                  ? color.withValues(alpha: 0.45)
                  : AppColors.outline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 7),
              ] else if (icon != null) ...[
                Icon(icon, size: 15, color: tint),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: tint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A wrapped row of [AppChoiceChip]s over a list of values.
class AppChoiceChips<T> extends StatelessWidget {
  const AppChoiceChips({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.iconOf,
    this.leadingOf,
    this.colorOf,
    this.color = AppColors.primary,
    this.pill = false,
    this.enabled = true,
  });

  final List<T> values;
  final T? selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;
  final IconData? Function(T value)? iconOf;
  final Widget? Function(T value)? leadingOf;

  /// A colour per value, for chips that carry a meaning of their own — a lead
  /// status keeps its pipeline colour here as it does on a venue card.
  final Color Function(T value)? colorOf;

  final Color color;
  final bool pill;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          AppChoiceChip(
            label: labelOf(value),
            icon: iconOf?.call(value),
            leading: leadingOf?.call(value),
            selected: value == selected,
            color: colorOf?.call(value) ?? color,
            pill: pill,
            enabled: enabled,
            onTap: () => onSelected(value),
          ),
      ],
    );
  }
}

/// The small-caps band label used to group a form or a dashboard.
class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
                color: AppColors.textMuted,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
