import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/data_entry/application/entry_providers.dart';
import 'package:flutter_id_card/features/notifications/application/notification_providers.dart';
import 'package:flutter_id_card/shared/app_version.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/theme/app_colors.dart';
import 'package:flutter_id_card/shared/theme/app_gradients.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/app_shadows.dart';
import 'package:flutter_id_card/shared/theme/app_spacing.dart';
import 'package:flutter_id_card/shared/theme/app_typography.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_controls.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_scaffold.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_surface.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Who is signed in, which school they work for, what they have submitted, and
/// the account actions they ever need.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionUser? session = ref.watch(currentSessionProvider);
    final AsyncValue<SchoolConfig> config = ref.watch(schoolConfigProvider);
    final AsyncValue<Map<ApprovalStatus, int>> counts = ref.watch(
      submissionCountsProvider,
    );
    final int unreadNotifications = ref.watch(unreadNotificationCountProvider);

    int count(ApprovalStatus s) => counts.value?[s] ?? 0;
    final int total = ApprovalStatus.values.fold(
      0,
      (int sum, ApprovalStatus s) => sum + count(s),
    );
    final int rejected = count(ApprovalStatus.rejected);

    return GlassScaffold(
      backdrop: GlassBackdrop.calm,
      header: GlassHeader(
        title: 'Profile',
        subtitle: config.value?.name ?? 'Your account',
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.navClearance,
        ),
        children: <Widget>[
          FadeSlideIn(
            child: _IdentityCard(session: session, config: config.value),
          ),
          const SizedBox(height: AppSpacing.gutter),

          // The three states an operator asks the office about by name. The
          // fourth - returned - is not a statistic, it is a to-do list, so it
          // gets a row of its own in the panel below rather than a tile here.
          FadeSlideIn(
            index: 1,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _StatusCard(
                    icon: Icons.schedule,
                    value: count(ApprovalStatus.pending),
                    label: 'Pending',
                    color: AppColors.pending,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _StatusCard(
                    icon: Icons.verified_outlined,
                    value: count(ApprovalStatus.approved),
                    label: 'Approved',
                    color: AppColors.approved,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _StatusCard(
                    icon: Icons.print_outlined,
                    value: count(ApprovalStatus.printed),
                    label: 'Printed',
                    color: AppColors.printed,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.gutter),

          FadeSlideIn(
            index: 2,
            child: _SubmissionsPanel(
              total: total,
              rejected: rejected,
              onOpenAll: () => context.push('/entries'),
            ),
          ),
          const SizedBox(height: AppSpacing.gutter),

          const Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: AppSpacing.sm,
            ),
            child: Text('Account', style: AppTypography.title),
          ),
          FadeSlideIn(
            index: 3,
            child: _UtilityGrid(
              unreadNotifications: unreadNotifications,
              onNotifications: () => context.push('/notifications'),
              onSync: () => context.push('/sync'),
              onPassword: () => _changePassword(context, ref),
              onLogout: () => _confirmLogout(context, ref),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Column(
              children: <Widget>[
                Text(
                  session?.email ?? 'Signed out',
                  style: AppTypography.support,
                ),
                const SizedBox(height: 2),
                // So "have I actually got the new build?" is answerable by
                // looking, instead of by guessing.
                Text(
                  kVersionLabel,
                  style: AppTypography.support.copyWith(fontSize: 11.5),
                ),
              ],
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
      backgroundColor: AppColors.canvas,
      builder: (BuildContext ctx) => Padding(
        // Lifts the sheet above the keyboard rather than letting it cover the
        // fields the operator is typing into.
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const _ChangePasswordSheet(),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final AsyncValue<Map<SyncStatus, int>> counts = ref.read(
      syncCountsProvider,
    );
    final int unsynced =
        (counts.value?[SyncStatus.pending] ?? 0) +
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
    final String display = (session?.displayName ?? '').trim().isNotEmpty
        ? session!.displayName
        : (session?.email.split('@').first ?? 'Signed out');

    return GlassSurface(
      radius: AppRadius.panelR,
      fill: AppColors.glassFillStrong,
      shadows: AppShadows.card,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: <Widget>[
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.avatar,
              boxShadow: AppShadows.glow(AppColors.violet),
            ),
            child: Center(
              child: Text(
                display.isEmpty ? '?' : display[0].toUpperCase(),
                style: AppTypography.displayOnDark.copyWith(fontSize: 34),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            display.toUpperCase(),
            style: AppTypography.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            config?.name ?? 'No school assigned',
            style: AppTypography.support,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (session != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _RoleChip(role: session!.role),
          ],
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final bool admin = role == UserRole.admin;
    return GlassStatusBadge(
      label: role.wireValue.toUpperCase(),
      icon: admin ? Icons.shield_outlined : Icons.badge_outlined,
      color: admin ? AppColors.printed : AppColors.info,
      tint: admin ? AppColors.printedTint : AppColors.infoTint,
    );
  }
}

// ---------------------------------------------------------------------------
// Counts
// ---------------------------------------------------------------------------

/// One status figure, on its own card.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: AppRadius.cardR,
      shadows: AppShadows.subtle,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GlassIconTile(icon: icon, tint: color, size: 40),
          const SizedBox(height: AppSpacing.sm),
          // Counts in, rather than snapping: these change when a sync pass
          // lands, which is a moment the operator is usually watching for.
          AnimatedCount(value: value, style: AppTypography.stat),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.statLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// The total, and the one number that is a to-do rather than a statistic.
class _SubmissionsPanel extends StatelessWidget {
  const _SubmissionsPanel({
    required this.total,
    required this.rejected,
    required this.onOpenAll,
  });

  final int total;
  final int rejected;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: AppRadius.panelR,
      fill: AppColors.glassFillStrong,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('My Submissions', style: AppTypography.section),
              const Spacer(),
              AnimatedCount(
                value: total,
                style: AppTypography.stat.copyWith(
                  fontSize: 22,
                  color: AppColors.royal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            total == 0
                ? 'Nothing submitted from this account yet'
                : 'Cards you have sent to the office',
            style: AppTypography.support,
          ),
          const SizedBox(height: AppSpacing.md),
          // Returned cards are the only thing on this screen that needs doing,
          // so they are stated as an instruction rather than counted quietly
          // alongside the others.
          if (rejected > 0)
            GlassSurface(
              radius: AppRadius.fieldR,
              fill: AppColors.rejectedTint.withValues(alpha: 0.9),
              borderColor: AppColors.rejected.withValues(alpha: 0.24),
              shadows: const <BoxShadow>[],
              sheen: false,
              padding: const EdgeInsets.all(AppSpacing.md),
              onTap: onOpenAll,
              child: Row(
                children: <Widget>[
                  const GlassIconTile(
                    icon: Icons.assignment_return_outlined,
                    tint: AppColors.rejected,
                    size: 40,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          rejected == 1
                              ? '1 card came back'
                              : '$rejected cards came back',
                          style: AppTypography.section.copyWith(
                            color: AppColors.rejected,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Fix and resubmit them',
                          style: AppTypography.support,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.rejected,
                  ),
                ],
              ),
            )
          else
            GlassButton(
              label: 'View all submissions',
              icon: Icons.list_alt_outlined,
              trailingIcon: Icons.arrow_forward,
              onPressed: onOpenAll,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Utilities
// ---------------------------------------------------------------------------

/// The four account actions, as a 2x2 grid.
///
/// A grid rather than a list because there are exactly four of them and they
/// are unrelated to each other - a list implies an order to work through,
/// which these do not have.
class _UtilityGrid extends StatelessWidget {
  const _UtilityGrid({
    required this.unreadNotifications,
    required this.onNotifications,
    required this.onSync,
    required this.onPassword,
    required this.onLogout,
  });

  final int unreadNotifications;
  final VoidCallback onNotifications;
  final VoidCallback onSync;
  final VoidCallback onPassword;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: _UtilityTile(
                  icon: Icons.notifications_none,
                  title: 'Notifications',
                  subtitle: unreadNotifications == 0
                      ? 'Approvals and messages'
                      : '$unreadNotifications need you',
                  tint: AppColors.info,
                  badge: unreadNotifications,
                  onTap: onNotifications,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _UtilityTile(
                  icon: Icons.sync_outlined,
                  title: 'Sync status',
                  subtitle: 'Uploads waiting',
                  tint: AppColors.royal,
                  onTap: onSync,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: _UtilityTile(
                  icon: Icons.lock_outline,
                  title: 'Change password',
                  subtitle: 'For this account',
                  tint: AppColors.violet,
                  onTap: onPassword,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _UtilityTile(
                  icon: Icons.logout,
                  title: 'Log out',
                  subtitle: 'Entries stay saved',
                  tint: AppColors.rejected,
                  onTap: onLogout,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UtilityTile extends StatelessWidget {
  const _UtilityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: AppRadius.cardR,
      shadows: AppShadows.subtle,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              GlassIconTile(icon: icon, tint: tint, size: 42),
              if (badge > 0)
                Positioned(
                  top: -4,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(
                      color: AppColors.rejected,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: Colors.white, width: 1.4),
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      textAlign: TextAlign.center,
                      style: AppTypography.buttonSmall.copyWith(fontSize: 10.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: AppTypography.section.copyWith(fontSize: 14.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTypography.support.copyWith(fontSize: 11.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
      await ref
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Password changed')));
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
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppGradients.pageCalm),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.gutter,
        ),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text('Change password', style: AppTypography.display),
              const SizedBox(height: AppSpacing.lg),
              GlassTextField(
                label: 'Current password',
                icon: Icons.lock_outline,
                controller: _current,
                obscureText: _obscure,
                placeholder: 'Enter it to confirm it is you',
                trailing: _EyeToggle(
                  obscured: _obscure,
                  onTap: () => setState(() => _obscure = !_obscure),
                ),
                validator: (String? v) =>
                    (v ?? '').isEmpty ? 'Enter your current password' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              GlassTextField(
                label: 'New password',
                icon: Icons.lock_reset_outlined,
                controller: _next,
                obscureText: _obscure,
                helperText: 'At least 6 characters',
                validator: (String? v) =>
                    (v ?? '').length < 6 ? 'Use at least 6 characters' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              GlassTextField(
                label: 'Confirm new password',
                icon: Icons.check_circle_outline,
                controller: _confirm,
                obscureText: _obscure,
                validator: (String? v) =>
                    v != _next.text ? 'The two passwords do not match' : null,
              ),
              SmoothSwitcher(
                child: _error == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: GlassSurface(
                          radius: AppRadius.fieldR,
                          fill: AppColors.rejectedTint.withValues(alpha: 0.9),
                          borderColor: AppColors.rejected.withValues(
                            alpha: 0.24,
                          ),
                          shadows: const <BoxShadow>[],
                          sheen: false,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Icon(
                                Icons.error_outline,
                                size: 18,
                                color: AppColors.rejected,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: AppTypography.support.copyWith(
                                    color: AppColors.rejected,
                                    fontSize: 13,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),
              GlassButton(
                label: 'Change password',
                icon: Icons.lock_reset_outlined,
                busy: _busy,
                onPressed: _busy ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EyeToggle extends StatelessWidget {
  const _EyeToggle({required this.obscured, required this.onTap});

  final bool obscured;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Icon(
          obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 19,
          color: AppColors.inkMuted,
        ),
      ),
    );
  }
}
