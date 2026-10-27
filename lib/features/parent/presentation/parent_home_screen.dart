import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/parent/application/parent_providers.dart';
import 'package:flutter_id_card/features/parent/presentation/school_picker_screen.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A parent's home: one button to make a card, and the status of every card
/// they have sent.
///
/// The status line is the whole point of the list. A parent has no one to ask
/// "did it arrive?" except the office, so each row says plainly where the card
/// is: still on the phone, with the office, approved, printed, or sent back
/// with the reason.
class ParentHomeScreen extends ConsumerWidget {
  const ParentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<StudentEntry> entries =
        ref.watch(parentEntriesProvider).value ?? const <StudentEntry>[];
    final Map<String, String> schoolNames =
        ref.watch(schoolNamesProvider).value ?? const <String, String>{};
    final String name = ref.watch(currentSessionProvider)?.displayName ?? '';

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('ID Cards')),
      body: ListView(
        // Clears the floating bottom navigation.
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: <Widget>[
          if (name.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Hello, $name',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          FilledButton.icon(
            onPressed: () => startParentIdCard(context),
            icon: const Icon(Icons.badge_outlined),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Make an ID card'),
            ),
          ),
          const SizedBox(height: 24),
          Text('Your cards', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'No cards yet. Tap "Make an ID card", choose the school, add '
                "your child's photo and details, and send.",
                textAlign: TextAlign.center,
              ),
            )
          else
            for (final StudentEntry e in entries)
              _CardRow(entry: e, schoolName: schoolNames[e.schoolId] ?? ''),
        ],
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({required this.entry, required this.schoolName});

  final StudentEntry entry;
  final String schoolName;

  /// Where the card is, in the parent's terms rather than the system's.
  ///
  /// The sync state only matters until the office has the record; after that
  /// the office's decision is the answer. A rejected card carries its reason,
  /// since that is what the parent has to act on.
  String get _status {
    if (entry.syncStatus != SyncStatus.synced) {
      return entry.syncStatus == SyncStatus.failed
          ? 'Could not send yet - will retry'
          : 'Waiting to send';
    }
    return switch (entry.approvalStatus) {
      ApprovalStatus.pending => 'With the school office',
      ApprovalStatus.approved => 'Approved',
      ApprovalStatus.printed => 'Printed',
      ApprovalStatus.rejected =>
        (entry.rejectionReason ?? '').isEmpty
            ? 'Sent back by the office'
            : 'Sent back: ${entry.rejectionReason}',
    };
  }

  Color get _color => switch (entry.approvalStatus) {
    ApprovalStatus.rejected => AppColors.rejected,
    ApprovalStatus.approved || ApprovalStatus.printed => AppColors.chatDeep,
    ApprovalStatus.pending => AppColors.inkMuted,
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
        title: Text(entry.name),
        subtitle: Text(
          schoolName.isEmpty ? _status : '$schoolName\n$_status',
          style: TextStyle(color: _color),
        ),
        isThreeLine: schoolName.isNotEmpty,
      ),
    );
  }
}
