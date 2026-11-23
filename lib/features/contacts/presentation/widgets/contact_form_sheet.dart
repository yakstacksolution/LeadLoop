import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../shared/widgets/choice_chips.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../domain/entities/venue_contact.dart';
import 'contact_tile.dart';

/// Add or edit a venue contact. Returns the filled contact, or null if the
/// sheet was dismissed.
Future<VenueContact?> showContactFormSheet(
  BuildContext context, {
  required String venueId,
  required String projectId,
  required String assignedEmployeeId,
  VenueContact? existing,
}) {
  return showModalBottomSheet<VenueContact>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ContactFormSheet(
      venueId: venueId,
      projectId: projectId,
      assignedEmployeeId: assignedEmployeeId,
      existing: existing,
    ),
  );
}

class _ContactFormSheet extends StatefulWidget {
  const _ContactFormSheet({
    required this.venueId,
    required this.projectId,
    required this.assignedEmployeeId,
    this.existing,
  });

  final String venueId;
  final String projectId;
  final String assignedEmployeeId;
  final VenueContact? existing;

  @override
  State<_ContactFormSheet> createState() => _ContactFormSheetState();
}

class _ContactFormSheetState extends State<_ContactFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.fullName ?? '');
  late final _designation =
      TextEditingController(text: widget.existing?.designation ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');

  late ContactMethod _method =
      widget.existing?.preferredContactMethod ?? ContactMethod.phone;
  late bool _isPrimary = widget.existing?.isPrimary ?? false;

  /// Common designations, offered as chips so the usual case is a tap.
  static const _roleSuggestions = [
    'Owner',
    'Manager',
    'Receptionist',
    'Accountant',
    'Coach',
  ];

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    for (final controller in [_name, _designation, _phone, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    Navigator.of(context).pop(
      VenueContact(
        id: widget.existing?.id ?? '',
        venueId: widget.venueId,
        projectId: widget.projectId,
        assignedEmployeeId: widget.assignedEmployeeId,
        fullName: _name.text.trim(),
        designation: _designation.text.trim(),
        phone: _phone.text.trim(),
        // Email is not collected here — staff reach venues by phone. Anything
        // already stored on an existing contact is preserved rather than
        // wiped by an edit.
        email: widget.existing?.email ?? '',
        preferredContactMethod: _method,
        notes: _notes.text.trim(),
        isPrimary: _isPrimary,
        createdBy: widget.existing?.createdBy,
        createdAt: widget.existing?.createdAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // Bottom only: the sheet's top is already inset by the drag handle, and
      // the sides sit against the sheet's own rounded edges.
      top: false,
      left: false,
      right: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(name: _name.text, isEditing: _isEditing),
                const SizedBox(height: 20),

                const _FieldLabel('Name and role'),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _name,
                  label: 'Full name',
                  prefixIcon: Icons.person_outline,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) =>
                      Validators.minLength(value, 2, 'Full name'),
                  // Drives the avatar preview in the header.
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: _designation,
                  label: 'Designation',
                  hint: 'Owner, Manager, Receptionist…',
                  prefixIcon: Icons.badge_outlined,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                AppChoiceChips<String>(
                  values: _roleSuggestions,
                  selected: _roleSuggestions.firstWhere(
                    (role) =>
                        role.toLowerCase() ==
                        _designation.text.trim().toLowerCase(),
                    orElse: () => '',
                  ),
                  labelOf: (role) => role,
                  pill: true,
                  onSelected: (role) =>
                      setState(() => _designation.text = role),
                ),
                const SizedBox(height: 20),

                const _FieldLabel('How to reach them'),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _phone,
                  label: 'Phone',
                  hint: '98XXXXXXXX',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  // Keeps the stored number dialable: digits, a leading +,
                  // and the separators people paste out of their contacts.
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
                  ],
                  validator: Validators.phone,
                ),
                const SizedBox(height: 14),
                const _FieldHint('Preferred contact method'),
                const SizedBox(height: 8),
                // Chips rather than a dropdown: five short options, and the
                // choice decides which button is highlighted on the contact
                // card, so it deserves to be visible.
                AppChoiceChips<ContactMethod>(
                  values: ContactMethod.values,
                  selected: _method,
                  labelOf: (method) => method.label,
                  iconOf: AppIcons.forContactMethod,
                  onSelected: (method) => setState(() => _method = method),
                ),
                const SizedBox(height: 20),

                const _FieldLabel('Notes'),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _notes,
                  label: 'Notes (optional)',
                  hint: 'Best time to call, who they answer to…',
                  maxLines: 3,
                  maxLength: 300,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 14),

                _PrimaryToggle(
                  value: _isPrimary,
                  onChanged: (value) => setState(() => _isPrimary = value),
                ),
                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _submit,
                        icon: Icon(
                          _isEditing ? Icons.check : Icons.person_add_alt,
                          size: 18,
                        ),
                        label: Text(_isEditing ? 'Save changes' : 'Add contact'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar, title and subtitle. The avatar previews as the name is typed, so
/// the sheet visibly builds the card the contact will become.
class _Header extends StatelessWidget {
  const _Header({required this.name, required this.isEditing});

  final String name;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ContactAvatar(name: name, radius: 22),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? 'Edit contact' : 'Add contact',
                style: const TextStyle(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name.trim().isEmpty
                    ? 'Who you deal with at this venue.'
                    : name.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _FieldHint extends StatelessWidget {
  const _FieldHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _PrimaryToggle extends StatelessWidget {
  const _PrimaryToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: value
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.outline,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
      // ListTile paints its ink on the nearest Material; without this one the
      // container's background would hide it.
      child: Material(
        type: MaterialType.transparency,
        child: SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: value,
          activeThumbColor: AppColors.primary,
          title: const Row(
            children: [
              Icon(Icons.star_rounded, size: 16, color: AppColors.primary),
              SizedBox(width: 6),
              Text(
                'Primary contact',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          subtitle: const Text(
            'The person to call first. Setting this demotes the current '
            'primary contact.',
            style: TextStyle(fontSize: 11.5, height: 1.35),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
