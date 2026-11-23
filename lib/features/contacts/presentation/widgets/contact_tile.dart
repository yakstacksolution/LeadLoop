import 'package:flutter/material.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/contact_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/venue_contact.dart';

/// Initials and a stable colour for a contact, so a list of people is
/// scannable without reading every name.
class ContactAvatar extends StatelessWidget {
  const ContactAvatar({super.key, required this.name, this.radius = 21});

  final String name;
  final double radius;

  /// Palette indexed by the name's hash: the same person always gets the same
  /// colour, and adjacent contacts rarely collide.
  static const _palette = [
    AppColors.secondary,
    AppColors.info,
    Color(0xFF5E35B1),
    Color(0xFF00897B),
    Color(0xFF795548),
    AppColors.primary,
  ];

  static String initialsOf(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  static Color colorOf(String name) =>
      _palette[name.trim().isEmpty ? 0 : name.trim().hashCode.abs() % _palette.length];

  @override
  Widget build(BuildContext context) {
    final color = colorOf(name);

    return Container(
      height: radius * 2,
      width: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.13),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      alignment: Alignment.center,
      child: Text(
        initialsOf(name),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.72,
        ),
      ),
    );
  }
}

/// One person at a venue, with the ways to reach them one tap away.
///
/// The phone number is an action, not a label: staff open this screen while
/// already holding the phone to their ear, so calling, messaging and mailing
/// are buttons across the bottom rather than text to copy out by hand.
class ContactTile extends StatelessWidget {
  const ContactTile({
    super.key,
    required this.contact,
    this.onEdit,
    this.onMakePrimary,
    this.onDelete,
  });

  final VenueContact contact;
  final VoidCallback? onEdit;
  final VoidCallback? onMakePrimary;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    // Email is no longer collected; older contacts may still carry one, so
    // it is shown when present but never asked for.
    final hasEmail = contact.email.trim().isNotEmpty;
    final method = contact.preferredContactMethod;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          // The primary contact gets a tinted edge so it is findable in a
          // long list without re-reading the chips.
          color: contact.isPrimary
              ? AppColors.primary.withValues(alpha: 0.45)
              : AppColors.outline,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ContactAvatar(name: contact.fullName, radius: 21),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              contact.fullName.trim().isEmpty
                                  ? 'Unnamed contact'
                                  : contact.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (contact.isPrimary) ...[
                            const SizedBox(width: 6),
                            const _PrimaryBadge(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        contact.displayRole,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _CopyableLine(
                        icon: Icons.phone_outlined,
                        text: contact.phone,
                        onLongPress: () => _copy(context, contact.phone, 'Number'),
                      ),
                      if (hasEmail) ...[
                        const SizedBox(height: 3),
                        _CopyableLine(
                          icon: Icons.mail_outline,
                          text: contact.email.trim(),
                          onLongPress: () =>
                              _copy(context, contact.email.trim(), 'Email'),
                        ),
                      ],
                    ],
                  ),
                ),
                _OverflowMenu(
                  contact: contact,
                  onEdit: onEdit,
                  onMakePrimary: onMakePrimary,
                  onDelete: onDelete,
                ),
              ],
            ),
            if (contact.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  contact.notes.trim(),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Row(
                children: [
                  Expanded(
                    child: ContactActionButton(
                      icon: Icons.call,
                      label: 'Call',
                      color: AppColors.success,
                      filled: method == ContactMethod.phone,
                      onTap: () => _launch(
                        context,
                        ContactLauncher.call(contact.phone),
                        'No dialler available on this device.',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ContactActionButton(
                      icon: Icons.chat_outlined,
                      label: method == ContactMethod.viber ? 'Viber' : 'WhatsApp',
                      color: AppColors.secondary,
                      filled: method == ContactMethod.whatsapp ||
                          method == ContactMethod.viber,
                      onTap: () => _launch(
                        context,
                        method == ContactMethod.viber
                            ? ContactLauncher.viber(contact.phone)
                            : ContactLauncher.whatsapp(contact.phone),
                        method == ContactMethod.viber
                            ? 'Could not open Viber for this number.'
                            : 'Could not open WhatsApp — check the number has '
                                'a country code.',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ContactActionButton(
                      icon: Icons.sms_outlined,
                      label: 'SMS',
                      color: AppColors.info,
                      onTap: () => _launch(
                        context,
                        ContactLauncher.sms(contact.phone),
                        'No messaging app available on this device.',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (method == ContactMethod.inPerson) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.handshake_outlined,
                      size: 14, color: AppColors.textMuted),
                  SizedBox(width: 6),
                  Text(
                    'Prefers to be met in person',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Future<void> _launch(
    BuildContext context,
    Future<bool> action,
    String failureMessage,
  ) async {
    final ok = await action;
    if (!ok && context.mounted) context.showError(failureMessage);
  }

  static Future<void> _copy(
    BuildContext context,
    String value,
    String what,
  ) async {
    await ContactLauncher.copy(value);
    if (context.mounted) context.showSuccess('$what copied.');
  }
}

/// One of the three reach-out buttons under a contact.
///
/// [filled] marks the contact's stated preference, so the right channel is
/// the obvious one to tap.
class ContactActionButton extends StatelessWidget {
  const ContactActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: filled ? 0.16 : 0.07),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: filled ? FontWeight.w700 : FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryBadge extends StatelessWidget {
  const _PrimaryBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(7),
      ),
      child: const Row(
        children: [
          Icon(Icons.star_rounded, size: 12, color: AppColors.primary),
          SizedBox(width: 3),
          Text(
            'Primary',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyableLine extends StatelessWidget {
  const _CopyableLine({
    required this.icon,
    required this.text,
    required this.onLongPress,
  });

  final IconData icon;
  final String text;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({
    required this.contact,
    this.onEdit,
    this.onMakePrimary,
    this.onDelete,
  });

  final VenueContact contact;
  final VoidCallback? onEdit;
  final VoidCallback? onMakePrimary;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textMuted),
      tooltip: 'Contact options',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) => switch (value) {
        'edit' => onEdit?.call(),
        'primary' => onMakePrimary?.call(),
        'delete' => onDelete?.call(),
        _ => null,
      },
      itemBuilder: (context) => [
        if (onEdit != null)
          const PopupMenuItem(
            value: 'edit',
            child: _MenuRow(icon: Icons.edit_outlined, label: 'Edit'),
          ),
        if (onMakePrimary != null && !contact.isPrimary)
          const PopupMenuItem(
            value: 'primary',
            child: _MenuRow(icon: Icons.star_outline, label: 'Make primary'),
          ),
        if (onDelete != null)
          const PopupMenuItem(
            value: 'delete',
            child: _MenuRow(
              icon: Icons.delete_outline,
              label: 'Delete',
              color: AppColors.danger,
            ),
          ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.textPrimary;
    return Row(
      children: [
        Icon(icon, size: 18, color: tint),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 14, color: tint)),
      ],
    );
  }
}
