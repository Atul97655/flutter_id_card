import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/admin/application/admin_providers.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/managed_user.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/messaging/application/chat_providers.dart';
import 'package:flutter_id_card/features/messaging/domain/chat_models.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/providers/core_providers.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How the admin picked who receives a broadcast.
enum RecipientMode { everyone, bySchool, selected }

/// Outcome of one broadcast, shown as the delivery report the plan asks for.
class BroadcastResult {
  const BroadcastResult({
    required this.recipients,
    required this.schools,
    required this.failures,
    required this.sentAt,
  });

  final int recipients;
  final int schools;

  /// Recipients the send could not reach, by display name. Non-empty means a
  /// partial delivery, which must be reported rather than rounded up to
  /// "sent".
  final List<String> failures;

  final DateTime sentAt;

  int get delivered => recipients - failures.length;
  bool get isComplete => failures.isEmpty;
}

/// Compose one message and send it to many operators at once.
///
/// The messaging model already supported `ChatKind.broadcast`, but nothing ever
/// created one - there was no way for an admin to reach more than one school
/// without opening each conversation by hand. This is that missing screen.
///
/// A broadcast is delivered as one announcement conversation whose members are
/// every chosen operator. It is not a fan-out of N private chats: the plan
/// describes an announcement, and N chats would give every recipient a thread
/// they could reply into, which the hub-and-spoke rules do not want.
class BroadcastScreen extends ConsumerStatefulWidget {
  const BroadcastScreen({super.key});

  static const String routePath = '/admin/broadcast';

  @override
  ConsumerState<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends ConsumerState<BroadcastScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  RecipientMode _mode = RecipientMode.everyone;
  final Set<String> _schoolIds = <String>{};
  final Set<String> _userUids = <String>{};

  bool _sending = false;
  BroadcastResult? _result;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  /// Operators eligible to receive a broadcast.
  ///
  /// Admins are excluded: a broadcast is addressed to the schools, and
  /// including yourself would put your own announcement in your inbox.
  /// Deactivated accounts are excluded because they cannot sign in to read it.
  List<ManagedUser> _eligible(List<ManagedUser> all) => all
      .where((ManagedUser u) => u.role != UserRole.admin && u.active)
      .toList();

  /// The operators the current selection resolves to.
  List<ManagedUser> _recipientsFrom(List<ManagedUser> users) =>
      switch (_mode) {
        RecipientMode.everyone => users,
        RecipientMode.bySchool => users
            .where((ManagedUser u) =>
                u.schoolId != null && _schoolIds.contains(u.schoolId))
            .toList(),
        RecipientMode.selected =>
          users.where((ManagedUser u) => _userUids.contains(u.uid)).toList(),
      };

  @override
  Widget build(BuildContext context) {
    final List<SchoolConfig> schools =
        ref.watch(allSchoolsProvider).value ?? const <SchoolConfig>[];
    final AsyncValue<List<ManagedUser>> usersAsync =
        ref.watch(allUsersProvider);
    final List<ManagedUser> users = _eligible(
      usersAsync.value ?? const <ManagedUser>[],
    );
    final List<ManagedUser> recipients = _recipientsFrom(users);

    return Scaffold(
      appBar: AppBar(title: const Text('Bulk Message')),
      body: usersAsync.isLoading && usersAsync.value == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(AppTheme.gutter),
                children: <Widget>[
                  FadeSlideIn(
                    child: _ModeCard(
                      mode: _mode,
                      onChanged: (RecipientMode m) => setState(() {
                        _mode = m;
                        _result = null;
                      }),
                    ),
                  ),
                  const SizedBox(height: AppTheme.gutter),

                  SmoothSwitcher(
                    child: switch (_mode) {
                      RecipientMode.bySchool => _SchoolPicker(
                          key: const ValueKey<String>('schools'),
                          schools: schools,
                          users: users,
                          selected: _schoolIds,
                          onToggle: (String id) => setState(() {
                            if (!_schoolIds.remove(id)) _schoolIds.add(id);
                            _result = null;
                          }),
                        ),
                      RecipientMode.selected => _UserPicker(
                          key: const ValueKey<String>('users'),
                          users: users,
                          selected: _userUids,
                          onToggle: (String uid) => setState(() {
                            if (!_userUids.remove(uid)) _userUids.add(uid);
                            _result = null;
                          }),
                        ),
                      RecipientMode.everyone => const SizedBox.shrink(
                          key: ValueKey<String>('everyone'),
                        ),
                    },
                  ),

                  const SizedBox(height: AppTheme.gutter),
                  FadeSlideIn(
                    index: 1,
                    child: _RecipientSummary(count: recipients.length),
                  ),

                  const SizedBox(height: AppTheme.gutter),
                  FadeSlideIn(index: 2, child: _composer()),

                  SmoothSwitcher(
                    child: _error == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: AppTheme.gutter),
                            child: _ErrorCard(message: _error!),
                          ),
                  ),

                  SmoothSwitcher(
                    child: _result == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: AppTheme.gutter),
                            child: _DeliveryReport(result: _result!),
                          ),
                  ),

                  const SizedBox(height: AppTheme.gutter),
                  FilledButton.icon(
                    onPressed:
                        _sending || recipients.isEmpty ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.campaign_outlined),
                    label: Text(
                      _sending
                          ? 'Sending...'
                          : recipients.isEmpty
                              ? 'Choose at least one recipient'
                              : 'Send to ${recipients.length} recipient(s)',
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _composer() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Message',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Subject',
                hintText: 'e.g. Photo quality reminder',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (String? v) =>
                  (v ?? '').trim().isEmpty ? 'Give it a subject' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _body,
              minLines: 4,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Message',
                alignLabelWithHint: true,
              ),
              validator: (String? v) =>
                  (v ?? '').trim().isEmpty ? 'Write something to send' : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    if (!(_form.currentState?.validate() ?? false)) return;

    final SessionUser? admin = ref.read(currentSessionProvider);
    if (admin == null) return;

    final List<ManagedUser> recipients = _recipientsFrom(
      _eligible(ref.read(allUsersProvider).value ?? const <ManagedUser>[]),
    );
    if (recipients.isEmpty) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Send to ${recipients.length} recipient(s)?'),
        content: Text(
          'This posts "${_title.text.trim()}" as an announcement. '
          'Recipients can read it but cannot reply to the announcement itself.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _sending = true;
      _error = null;
      _result = null;
    });

    try {
      final Set<String> schoolIds = <String>{
        for (final ManagedUser u in recipients)
          if (u.schoolId != null) u.schoolId!,
      };

      final Chat chat = await ref.read(chatRepositoryProvider).createChat(
            title: _title.text.trim(),
            // The admin is a member too, so the announcement appears in their
            // own list as a record of what went out.
            members: <String>{
              admin.uid,
              ...recipients.map((ManagedUser u) => u.uid),
            }.toList(),
            kind: ChatKind.broadcast,
          );

      await ref.read(chatRepositoryProvider).sendMessage(
            chat: chat,
            senderId: admin.uid,
            senderName: admin.displayName.isEmpty
                ? 'Admin'
                : admin.displayName,
            body: _body.text.trim(),
          );

      await ref.read(auditRepositoryProvider).log(
            action: 'broadcast',
            entityType: 'chat',
            entityId: chat.id,
            actorUid: admin.uid,
            details: <String, Object?>{
              'title': _title.text.trim(),
              'recipients': recipients.length,
              'schools': schoolIds.length,
              'mode': _mode.name,
            },
          );

      if (!mounted) return;
      setState(() {
        _result = BroadcastResult(
          recipients: recipients.length,
          schools: schoolIds.length,
          failures: const <String>[],
          sentAt: DateTime.now(),
        );
        _title.clear();
        _body.clear();
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not send: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Recipient mode
// ---------------------------------------------------------------------------

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.mode, required this.onChanged});

  final RecipientMode mode;
  final ValueChanged<RecipientMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Send to',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SegmentedButton<RecipientMode>(
              segments: const <ButtonSegment<RecipientMode>>[
                ButtonSegment<RecipientMode>(
                  value: RecipientMode.everyone,
                  icon: Icon(Icons.groups_outlined),
                  label: Text('Everyone'),
                ),
                ButtonSegment<RecipientMode>(
                  value: RecipientMode.bySchool,
                  icon: Icon(Icons.school_outlined),
                  label: Text('By school'),
                ),
                ButtonSegment<RecipientMode>(
                  value: RecipientMode.selected,
                  icon: Icon(Icons.person_outline),
                  label: Text('Pick'),
                ),
              ],
              selected: <RecipientMode>{mode},
              onSelectionChanged: (Set<RecipientMode> s) =>
                  onChanged(s.first),
            ),
          ],
        ),
      ),
    );
  }
}

class _SchoolPicker extends StatelessWidget {
  const _SchoolPicker({
    super.key,
    required this.schools,
    required this.users,
    required this.selected,
    required this.onToggle,
  });

  final List<SchoolConfig> schools;
  final List<ManagedUser> users;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: <Widget>[
          for (final SchoolConfig s in schools)
            CheckboxListTile(
              dense: true,
              value: selected.contains(s.id),
              onChanged: (_) => onToggle(s.id),
              title: Text(s.name, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${users.where((ManagedUser u) => u.schoolId == s.id).length} '
                'operator(s)',
                style: const TextStyle(fontSize: 11.5),
              ),
            ),
          if (schools.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppTheme.gutter),
              child: Text('No schools yet.'),
            ),
        ],
      ),
    );
  }
}

class _UserPicker extends StatelessWidget {
  const _UserPicker({
    super.key,
    required this.users,
    required this.selected,
    required this.onToggle,
  });

  final List<ManagedUser> users;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: <Widget>[
          for (final ManagedUser u in users)
            CheckboxListTile(
              dense: true,
              value: selected.contains(u.uid),
              onChanged: (_) => onToggle(u.uid),
              title: Text(
                u.displayName.isEmpty ? u.email : u.displayName,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                u.email,
                style: const TextStyle(fontSize: 11.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (users.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppTheme.gutter),
              child: Text('No active operator accounts yet.'),
            ),
        ],
      ),
    );
  }
}

class _RecipientSummary extends StatelessWidget {
  const _RecipientSummary({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool none = count == 0;

    return Card(
      color: none
          ? StatusColors.pending.withValues(alpha: 0.08)
          : theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Icon(
              none ? Icons.person_off_outlined : Icons.groups,
              color: none ? StatusColors.pending : theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            AnimatedCount(
              value: count,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color:
                    none ? StatusColors.pending : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                none
                    ? 'No recipients selected yet'
                    : 'operator(s) will receive this',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Delivery report
// ---------------------------------------------------------------------------

class _DeliveryReport extends StatelessWidget {
  const _DeliveryReport({required this.result});

  final BroadcastResult result;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color tint =
        result.isComplete ? StatusColors.synced : StatusColors.pending;

    return Card(
      color: tint.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cornerRadius),
        side: BorderSide(color: tint.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  result.isComplete
                      ? Icons.mark_email_read_outlined
                      : Icons.warning_amber_rounded,
                  color: tint,
                ),
                const SizedBox(width: 10),
                Text(
                  result.isComplete ? 'Delivered' : 'Partly delivered',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                _Stat(label: 'Recipients', value: result.delivered),
                _Stat(label: 'Schools', value: result.schools),
                if (!result.isComplete)
                  _Stat(label: 'Failed', value: result.failures.length),
              ],
            ),
            if (!result.isComplete) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                'Could not reach: ${result.failures.join(', ')}',
                style: const TextStyle(fontSize: 12, height: 1.4),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              'Recipients see this the next time they open the app. Push '
              'notifications are not enabled, so it will not reach a closed '
              'app yet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AnimatedCount(
            value: value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: StatusColors.failed.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.error_outline, color: StatusColors.failed),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
