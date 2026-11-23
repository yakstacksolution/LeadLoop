import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/app_date_utils.dart';

/// Standard labelled text input used across every form in the app.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.maxLength,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.enabled = true,
    this.autofillHints,
    this.inputFormatters,
    this.onSubmitted,
    this.onChanged,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final int? maxLength;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: obscureText ? 1 : maxLines,
      maxLength: maxLength,
      obscureText: obscureText,
      enabled: enabled,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      onFieldSubmitted: onSubmitted,
      onChanged: onChanged,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
        suffixIcon: suffix,
        alignLabelWithHint: maxLines > 1,
        counterText: '',
      ),
    );
  }
}

/// A dropdown that matches [AppTextField]'s look.
class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
    this.itemLabel,
    this.validator,
    this.prefixIcon,
    this.enabled = true,
  });

  final T? value;
  final List<T> items;
  final String label;
  final ValueChanged<T?> onChanged;
  final String Function(T value)? itemLabel;
  final String? Function(T?)? validator;
  final IconData? prefixIcon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      validator: validator,
      onChanged: enabled ? onChanged : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
      ),
      items: [
        for (final item in items)
          DropdownMenuItem<T>(
            value: item,
            child: Text(
              itemLabel?.call(item) ?? item.toString(),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

/// Tappable field that opens a date picker, and optionally a time picker.
class AppDateField extends StatelessWidget {
  const AppDateField({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    this.includeTime = false,
    this.firstDate,
    this.lastDate,
    this.clearable = true,
    this.enabled = true,
    this.validatorMessage,
  });

  final DateTime? value;
  final String label;
  final ValueChanged<DateTime?> onChanged;
  final bool includeTime;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool clearable;
  final bool enabled;

  /// When set, the field renders an error and reports invalid to the form.
  final String? validatorMessage;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: firstDate ?? DateTime(now.year - 2),
      lastDate: lastDate ?? DateTime(now.year + 5),
    );
    if (date == null) return;

    if (!includeTime) {
      onChanged(AppDateUtils.combine(date));
      return;
    }

    if (!context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value ?? now),
    );
    // Cancelling the time step keeps the chosen day at a sensible default
    // rather than throwing the whole selection away.
    onChanged(
      AppDateUtils.combine(
        date,
        hour: time?.hour ?? 9,
        minute: time?.minute ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? 'Not set'
        : (includeTime
            ? AppDateUtils.formatDateTime(value)
            : AppDateUtils.formatDate(value));

    return InkWell(
      onTap: enabled ? () => _pick(context) : null,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: validatorMessage,
          prefixIcon: Icon(
            includeTime ? Icons.event_outlined : Icons.calendar_today_outlined,
            size: 20,
          ),
          suffixIcon: (clearable && value != null && enabled)
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => onChanged(null),
                  tooltip: 'Clear',
                )
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: value == null ? AppColors.textMuted : AppColors.textPrimary,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

/// A labelled group of content inside a card — the app's main layout unit.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.action,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final String? title;
  final Widget? action;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  ?action,
                ],
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// One `label: value` row, used throughout the detail screens.
class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, required this.value, this.icon});

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 10),
          ],
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '—' : value,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
