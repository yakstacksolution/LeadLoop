import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/services/contact_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../shared/widgets/action_tiles.dart';
import '../../../../shared/widgets/app_fab.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../../../shared/widgets/map_tiles.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../activities/domain/repositories/activity_repository.dart';
import '../../../activities/presentation/widgets/activity_card.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../contacts/domain/entities/venue_contact.dart';
import '../../../contacts/domain/repositories/contact_repository.dart';
import '../../../contacts/presentation/widgets/contact_form_sheet.dart';
import '../../../contacts/presentation/widgets/contact_tile.dart';
import '../../../visits/domain/entities/visit.dart';
import '../../../visits/presentation/widgets/visit_tile.dart';
import '../../domain/entities/venue.dart';
import '../../domain/repositories/venue_repository.dart';
import '../../../visits/domain/repositories/visit_repository.dart';
import '../bloc/venue_detail_cubit.dart';
import '../widgets/status_change_sheet.dart';
import '../widgets/venue_header.dart';
import '../widgets/venue_timeline.dart';

class VenueDetailPage extends StatelessWidget {
  const VenueDetailPage({super.key, required this.venueId});

  final String venueId;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthCubit>().state;

    return BlocProvider(
      create: (_) => VenueDetailCubit(
        venueRepository: sl<VenueRepository>(),
        activityRepository: sl<ActivityRepository>(),
        visitRepository: sl<VisitRepository>(),
        contactRepository: sl<ContactRepository>(),
        venueId: venueId,
        currentUserId: auth.uid ?? '',
        currentUserName: auth.user?.fullName ?? '',
      )..watch(),
      child: const _VenueDetailView(),
    );
  }
}

class _VenueDetailView extends StatefulWidget {
  const _VenueDetailView();

  @override
  State<_VenueDetailView> createState() => _VenueDetailViewState();
}

class _VenueDetailViewState extends State<_VenueDetailView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static String _label(String name, int count) =>
      count == 0 ? name : '$name ($count)';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _changeStatus(BuildContext context, Venue venue) async {
    final cubit = context.read<VenueDetailCubit>();
    final choice = await showStatusChangeSheet(context, current: venue.status);
    if (choice == null || !context.mounted) return;

    final ok = await cubit.changeStatus(choice.status, reason: choice.reason);
    if (!context.mounted) return;

    if (ok) {
      context.showSuccess('Status updated to ${choice.status.label}.');
    } else {
      context.showError(cubit.state.failure ?? 'Could not update the status.');
    }
  }

  Future<void> _addNote(BuildContext context) async {
    final cubit = context.read<VenueDetailCubit>();
    final text = await promptForText(
      context,
      title: 'Add a note',
      label: 'What happened?',
      confirmLabel: 'Add note',
    );
    if (text == null || !context.mounted) return;

    final ok = await cubit.addNote(text);
    if (!context.mounted) return;

    if (ok) {
      context.showSuccess('Note added.');
    } else {
      context.showError(cubit.state.failure ?? 'Could not add the note.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VenueDetailCubit, VenueDetailState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Scaffold(body: LoadingView());
        }

        final venue = state.venue;
        if (venue == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Venue')),
            body: ErrorView(
              failure: state.failure ?? const NotFoundFailure(),
              onRetry: () => context.read<VenueDetailCubit>().watch(),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(venue.name, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit venue',
                onPressed: () => context.push(AppRoutes.editVenueFor(venue.id)),
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  final cubit = context.read<VenueDetailCubit>();
                  if (value == 'archive') {
                    final ok = await confirm(
                      context,
                      title: venue.isArchived
                          ? 'Restore venue?'
                          : 'Archive venue?',
                      message: venue.isArchived
                          ? 'It will show in the normal venue list again.'
                          : 'It stays in the database with its full history, '
                                'but is hidden from the default list.',
                      confirmLabel: venue.isArchived ? 'Restore' : 'Archive',
                    );
                    if (!ok || !context.mounted) return;
                    await cubit.setArchived(!venue.isArchived);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'archive',
                    child: Text(
                      venue.isArchived ? 'Restore venue' : 'Archive venue',
                    ),
                  ),
                ],
              ),
            ],
            // Not DefaultTabController: its scope notifies TabBarView when
            // tickers are muted (e.g. a route covers this page), and TabBarView
            // then jumps pages mid-build, dirtying these tabs.
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                const Tab(text: 'Overview'),
                Tab(text: _label('Timeline', state.timeline.length)),
                Tab(text: _label('Contacts', state.contacts.length)),
                Tab(text: _label('Activities', state.activities.length)),
                Tab(text: _label('Visits', state.visits.length)),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _OverviewTab(
                venue: venue,
                primaryContact: state.primaryContact,
                openVisit: state.openVisit,
                onChangeStatus: () => _changeStatus(context, venue),
                onAddNote: () => _addNote(context),
              ),
              state.timeline.isEmpty
                  ? const EmptyView(
                      icon: Icons.history,
                      title: 'Nothing recorded yet',
                      message:
                          'Notes, status changes, calls and visits will '
                          'appear here in order.',
                    )
                  : VenueTimeline(entries: state.timeline),
              _ContactsTab(venue: venue, contacts: state.contacts),
              _ActivitiesTab(state: state),
              _VisitsTab(state: state),
            ],
          ),
        );
      },
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.venue,
    required this.primaryContact,
    required this.openVisit,
    required this.onChangeStatus,
    required this.onAddNote,
  });

  final Venue venue;
  final VenueContact? primaryContact;
  final Visit? openVisit;
  final VoidCallback onChangeStatus;
  final VoidCallback onAddNote;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const PageStorageKey('venue-overview'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
      children: [
        VenueHeader(venue: venue, onStatusTap: onChangeStatus),
        const SizedBox(height: 16),

        // The four things done on this screen, in the same tile style as the
        // dashboards so the primary actions look the same everywhere.
        ActionTileGrid(
          actions: [
            AppAction(
              label: 'Change status',
              icon: Icons.swap_horiz_rounded,
              color: AppColors.forLeadStatus(venue.status),
              badge: venue.status.label,
              onTap: onChangeStatus,
            ),
            AppAction(
              label: 'Add note',
              icon: Icons.note_add_outlined,
              color: AppColors.info,
              onTap: onAddNote,
            ),
            AppAction(
              label: 'Schedule',
              icon: Icons.event_outlined,
              color: AppColors.primary,
              badge: venue.nextFollowUpAt == null
                  ? 'Nothing planned'
                  : AppDateUtils.relativeLabel(venue.nextFollowUpAt),
              onTap: () =>
                  context.push(AppRoutes.scheduleActivityFor(venue.id)),
            ),
            AppAction(
              // The label follows the real state: an employee with a visit
              // already running needs to finish it, not start another.
              label: openVisit == null ? 'Record visit' : 'Finish visit',
              icon: openVisit == null
                  ? Icons.where_to_vote_outlined
                  : Icons.stop_circle_outlined,
              color: AppColors.secondary,
              badge: openVisit != null
                  ? 'In progress'
                  : (venue.hasBeenVisited
                        ? 'Last ${AppDateUtils.formatShortDate(venue.lastVisitedAt)}'
                        : 'Never visited'),
              onTap: () => context.push(AppRoutes.recordVisitFor(venue.id)),
            ),
          ],
        ),

        if (primaryContact != null) ...[
          const SizedBox(height: 16),
          _PrimaryContactCard(contact: primaryContact!),
        ],

        const SizedBox(height: 16),
        SectionCard(
          title: 'Venue',
          action: venue.hasLocation
              ? TextButton.icon(
                  onPressed: () => ContactLauncher.directions(
                    venue.latitude!,
                    venue.longitude!,
                    label: venue.name,
                  ),
                  icon: const Icon(Icons.directions_outlined, size: 16),
                  label: const Text('Directions'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (venue.hasLocation) ...[
                // The pin says more about where this venue is than a
                // coordinate pair ever did, and it is the same preview the
                // edit form shows.
                MapPreview(
                  latitude: venue.latitude!,
                  longitude: venue.longitude!,
                  height: 132,
                  onTap: () => ContactLauncher.directions(
                    venue.latitude!,
                    venue.longitude!,
                    label: venue.name,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              DetailRow(
                label: 'Address',
                value: venue.address,
                icon: Icons.place_outlined,
              ),
              DetailRow(label: 'City', value: venue.city),
              DetailRow(label: 'Area', value: venue.area),
              DetailRow(label: 'Type', value: venue.venueType.label),
              DetailRow(
                label: 'Courts',
                value: venue.courtCount?.toString() ?? '—',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Lead',
          child: Column(
            children: [
              DetailRow(label: 'Source', value: venue.leadSource.label),
              DetailRow(label: 'Priority', value: venue.priority.label),
              DetailRow(
                label: 'Created',
                value: AppDateUtils.formatDate(venue.createdAt),
              ),
              DetailRow(
                label: 'Last activity',
                value: AppDateUtils.formatDateTime(venue.lastActivityAt),
              ),
              DetailRow(
                label: 'Next follow-up',
                value: venue.nextFollowUpAt == null
                    ? 'Not scheduled'
                    : '${AppDateUtils.formatDateTime(venue.nextFollowUpAt)}'
                          ' (${AppDateUtils.relativeLabel(venue.nextFollowUpAt)})',
                icon: Icons.event_repeat_outlined,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The person to call first, surfaced on Overview so it is one tap away
/// instead of buried behind the Contacts tab.
class _PrimaryContactCard extends StatelessWidget {
  const _PrimaryContactCard({required this.contact});

  final VenueContact contact;

  Future<void> _launch(
    BuildContext context,
    Future<bool> action,
    String failureMessage,
  ) async {
    final ok = await action;
    if (!ok && context.mounted) context.showError(failureMessage);
  }

  @override
  Widget build(BuildContext context) {
    final method = contact.preferredContactMethod;

    return SectionCard(
      title: 'Primary contact',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ContactAvatar(name: contact.fullName, radius: 22),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${contact.displayRole} · ${contact.phone}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Prefers ${method.label}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
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
                  filled:
                      method == ContactMethod.whatsapp ||
                      method == ContactMethod.viber,
                  onTap: () => _launch(
                    context,
                    method == ContactMethod.viber
                        ? ContactLauncher.viber(contact.phone)
                        : ContactLauncher.whatsapp(contact.phone),
                    'Could not open a chat for this number.',
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
        ],
      ),
    );
  }
}

class _ContactsTab extends StatelessWidget {
  const _ContactsTab({required this.venue, required this.contacts});

  final Venue venue;

  /// Supplied by [VenueDetailCubit], which already watches this exact query —
  /// a second StreamBuilder here would mean two listeners for one list.
  final List<VenueContact> contacts;

  Future<void> _add(BuildContext context) async {
    final contact = await showContactFormSheet(
      context,
      venueId: venue.id,
      projectId: venue.projectId,
      assignedEmployeeId: venue.assignedEmployeeId,
    );
    if (contact == null || !context.mounted) return;

    final auth = context.read<AuthCubit>().state;
    final result = await sl<ContactRepository>().createContact(
      contact,
      createdBy: auth.uid ?? '',
    );

    if (!context.mounted) return;
    result.fold(
      context.showError,
      (_) => context.showSuccess('Contact added.'),
    );
  }

  Future<void> _edit(BuildContext context, VenueContact contact) async {
    final updated = await showContactFormSheet(
      context,
      venueId: venue.id,
      projectId: venue.projectId,
      assignedEmployeeId: venue.assignedEmployeeId,
      existing: contact,
    );
    if (updated == null || !context.mounted) return;

    final repository = sl<ContactRepository>();
    final result = await repository.updateContact(updated);
    if (!context.mounted) return;

    // Promoting on edit still has to demote whoever held the flag before.
    if (result.isSuccess && updated.isPrimary && !contact.isPrimary) {
      await repository.setPrimary(
        venueId: venue.id,
        contactId: contact.id,
        assignedEmployeeId: venue.assignedEmployeeId,
      );
    }
    if (!context.mounted) return;

    result.fold(
      context.showError,
      (_) => context.showSuccess('Contact updated.'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: AppFab(
        // One per tab, and the tab views are built together.
        heroTag: 'fab-venue-contacts',
        icon: Icons.person_add_alt,
        label: 'Add contact',
        onPressed: () => _add(context),
      ),
      body: contacts.isEmpty
          ? EmptyView(
              icon: Icons.contacts_outlined,
              title: 'No contacts yet',
              message: 'Add the owner, manager or whoever you deal with here.',
              actionLabel: 'Add contact',
              onAction: () => _add(context),
            )
          : ListView.builder(
              key: const PageStorageKey('venue-contacts'),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return ContactTile(
                  contact: contact,
                  onEdit: () => _edit(context, contact),
                  onMakePrimary: () async {
                    final result = await sl<ContactRepository>().setPrimary(
                      venueId: venue.id,
                      contactId: contact.id,
                      assignedEmployeeId: venue.assignedEmployeeId,
                    );
                    if (!context.mounted) return;
                    result.fold(
                      context.showError,
                      (_) => context.showSuccess('Primary contact updated.'),
                    );
                  },
                  onDelete: () async {
                    final ok = await confirm(
                      context,
                      title: 'Delete contact?',
                      message:
                          'This removes ${contact.fullName} from the venue.',
                      confirmLabel: 'Delete',
                      isDestructive: true,
                    );
                    if (!ok || !context.mounted) return;

                    final result = await sl<ContactRepository>().deleteContact(
                      contact.id,
                    );
                    if (!context.mounted) return;
                    result.fold(
                      context.showError,
                      (_) => context.showSuccess('Contact deleted.'),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _ActivitiesTab extends StatelessWidget {
  const _ActivitiesTab({required this.state});

  final VenueDetailState state;

  @override
  Widget build(BuildContext context) {
    final venue = state.venue!;

    return Scaffold(
      floatingActionButton: AppFab(
        heroTag: 'fab-venue-activities',
        icon: Icons.event_outlined,
        label: 'Schedule',
        onPressed: () => context.push(AppRoutes.scheduleActivityFor(venue.id)),
      ),
      body: state.activities.isEmpty
          ? EmptyView(
              icon: Icons.event_busy_outlined,
              title: 'Nothing scheduled',
              message:
                  'Schedule a call, meeting or visit to keep this lead moving.',
              actionLabel: 'Schedule activity',
              onAction: () =>
                  context.push(AppRoutes.scheduleActivityFor(venue.id)),
            )
          : ListView.builder(
              key: const PageStorageKey('venue-activities'),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
              itemCount: state.activities.length,
              itemBuilder: (context, index) {
                final activity = state.activities[index];
                return ActivityCard(
                  activity: activity,
                  showVenue: false,
                  onTap: () =>
                      context.push(AppRoutes.activityDetailFor(activity.id)),
                );
              },
            ),
    );
  }
}

class _VisitsTab extends StatelessWidget {
  const _VisitsTab({required this.state});

  final VenueDetailState state;

  @override
  Widget build(BuildContext context) {
    final venue = state.venue!;

    return Scaffold(
      floatingActionButton: AppFab(
        heroTag: 'fab-venue-visits',
        icon: Icons.where_to_vote_outlined,
        label: state.openVisit == null ? 'Record visit' : 'Finish visit',
        onPressed: () => context.push(AppRoutes.recordVisitFor(venue.id)),
      ),
      body: state.visits.isEmpty
          ? EmptyView(
              icon: Icons.not_listed_location_outlined,
              title: 'Not visited yet',
              message: 'Record a visit when you go to this venue.',
              actionLabel: 'Record visit',
              onAction: () => context.push(AppRoutes.recordVisitFor(venue.id)),
            )
          : ListView.builder(
              key: const PageStorageKey('venue-visits'),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
              itemCount: state.visits.length,
              itemBuilder: (context, index) =>
                  VisitTile(visit: state.visits[index]),
            ),
    );
  }
}
