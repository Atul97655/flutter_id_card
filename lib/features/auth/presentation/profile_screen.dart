import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/data_entry/application/entry_providers.dart';
import 'package:flutter_id_card/features/notifications/application/notification_providers.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_id_card/shared/widgets/approval_status_chip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Who is signed in, which school they work for, what they have submitted, and
/// the two account actions they ever need: change password and log out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionUser? session = ref.watch(currentSessionProvider);
    final AsyncValue<SchoolConfig> config = ref.watch(schoolConfigProvider);
    final AsyncValue<Map<ApprovalStatus, int>> counts =
        ref.watch(submissionCountsProvider);
    final int unreadNotifications =
        ref.watch(unreadNotificationCountProvider);

    int count(ApprovalStatus s) => counts.value?[s] ?? 0;
    final int total = ApprovalStatus.values.fold(
      0,
      (int sum, ApprovalStatus s) => sum + count(s),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.gutter),
        children: <Widget>[
          FadeSlideIn(
            child: _IdentityCard(session: session, config: config.value),
          ),
          const SizedBox(height: AppTheme.gutter),

          FadeSlideIn(
            index: 1,
            child: _CountsCard(
              total: total,
              pending: count(ApprovalStatus.pending),
              approved: count(ApprovalStatus.approved),
              printed: count(ApprovalStatus.printed),
              rejected: count(ApprovalStatus.rejected),
            ),
          ),
          const SizedBox(height: AppTheme.gutter),

          FadeSlideIn(
            index: 2,
            child: Card(
              child: Column(
                children: <Widget>[
                  _Row(
                    icon: Icons.notifications_none,
                    title: 'Notifications',
                    subtitle: unreadNotifications == 0
                        ? 'Approvals, returned cards and messages'
                        : '$unreadNotifications need your attention',
                    badge: unreadNotifications,
                    onTap: () => context.push('/notifications'),
                  ),
                  const Divider(height: 1, indent: 60),
                  _Row(
                    icon: Icons.sync_outlined,
                    title: 'Sync status',
                    subtitle: 'Uploads waiting or failed',
                    onTap: () => context.push('/sync'),
                  ),
                  const Divider(height: 1, indent: 60),
                  _Row(
                    icon: Icons.lock_outline,
                    title: 'Change password',
                    subtitle: 'Update the password for this account',
                    onTap: () => _changePassword(context, ref),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.gutter),

          FadeSlideIn(
            index: 3,
            child: Card(
              child: _Row(
                icon: Icons.logout,
                title: 'Log out',
                subtitle: session?.email ?? '',
                tint: StatusColors.failed,
                onTap: () => _confirmLogout(context, ref),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) => Padding(
        // Lifts the sheet above the keyboard rather than letting it cover the
        // fields the operator is typing into.
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: const _ChangePasswordSheet(),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final AsyncValue<Map<SyncStatus, int>> counts =
        ref.read(syncCountsProvider);
    final int unsynced = (counts.value?[SyncStatus.pending] ?? 0) +
        (counts.value?[SyncStatus.failed] ?? 0);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: Text(
          unsynced > 0
              // Entries live in the local database, not the session, so they
              // genuinely do survive - say so plainly to stop operators
              // hoarding logins out of fear of losing a day's work.
              ? '$unsynced entries have not uploaded yet.\n\nThey stay saved on '
                  'this device and will upload the next time you sign in.'
              : 'You will need your school code and password to sign back in.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await ref.read(authControllerProvider.notifier).signOut();
    if (context.mounted) context.go('/login');
  }
}

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.session, required this.config});

  final SessionUser? session;
  final SchoolConfig? config;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String display = (session?.displayName ?? '').trim().isNotEmpty
        ? session!.displayName
        : (session?.email.split('@').first ?? 'Signed out');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gutter),
        child: Row(
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  display.isEmpty ? '?' : display[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    display.toUpperCase(),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    config?.name ?? 'No school assigned',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (session != null) _RoleChip(role: session!.role),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final Color color =
        role == UserRole.admin ? StatusColors.printed : StatusColors.syncing;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        role.wireValue.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Counts
// ---------------------------------------------------------------------------

class _CountsCard extends StatelessWidget {
  const _CountsCard({
    required this.total,
    required this.pending,
    required this.approved,
    required this.printed,
    required this.rejected,
  });

  final int total;
  final int pending;
  final int approved;
  final int printed;
  final int rejected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'My submissions',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                AnimatedCount(
                  value: total,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _Pill(status: ApprovalStatus.pending, value: pending),
                _Pill(status: ApprovalStatus.approved, value: approved),
                _Pill(status: ApprovalStatus.printed, value: printed),
                _Pill(status: ApprovalStatus.rejected, value: rejected),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.status, required this.value});

  final ApprovalStatus status;
  final int value;

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon) = ApprovalStatusChip.visualsFor(status);
    final bool empty = value == 0;
    final Color tint =
        empty ? Theme.of(context).colorScheme.outline : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tint.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: tint),
          const SizedBox(width: 6),
          Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: tint,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(fontSize: 11.5, color: tint),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rows
// ---------------------------------------------------------------------------

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge = 0,
    this.tint,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int badge;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = tint ?? theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: <Widget>[
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tint,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (badge > 0)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: StatusColors.failed,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Icon(Icons.chevron_right, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Change password
// ---------------------------------------------------------------------------

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(authRepositoryProvider).changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Password changed')),
        );
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Object catch (e) {
      if (mounted) setState(() => _error = 'Could not change the password: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        0,
        AppTheme.gutter,
        AppTheme.gutter,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Change password',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _current,
              obscureText: _obscure,
              autofillHints: const <String>[AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Current password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (String? v) =>
                  (v ?? '').isEmpty ? 'Enter your current password' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _next,
              obscureText: _obscure,
              autofillHints: const <String>[AutofillHints.newPassword],
              decoration: const InputDecoration(
                labelText: 'New password',
                prefixIcon: Icon(Icons.lock_reset_outlined),
                helperText: 'At least 6 characters',
              ),
              validator: (String? v) => (v ?? '').length < 6
                  ? 'Use at least 6 characters'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: _obscure,
              decoration: const InputDecoration(
                labelText: 'Confirm new password',
                prefixIcon: Icon(Icons.check_circle_outline),
              ),
              validator: (String? v) =>
                  v != _next.text ? 'The two passwords do not match' : null,
            ),
            SmoothSwitcher(
              child: _error == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(
                            Icons.error_outline,
                            size: 18,
                            color: StatusColors.failed,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: StatusColors.failed,
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Change password'),
            ),
          ],
        ),
      ),
    );
  }
}
