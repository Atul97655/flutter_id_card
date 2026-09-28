import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/data_entry/application/entry_providers.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/join_theme.dart';
import 'package:flutter_id_card/shared/widgets/approval_status_chip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Picking which card to send into a conversation.
///
/// Only cards the office has already approved are offered. Sending a pending
/// card would be asking the admin to review it twice - once in the queue
/// where the decision is recorded, and again in a chat where it is not - and
/// the second review would have nowhere to go.
class SendIdCardScreen extends ConsumerStatefulWidget {
  const SendIdCardScreen({super.key, required this.recipientLabel});

  /// Shown at the top so the teacher can see who this is going to before they
  /// pick. The mistake this prevents is sending a child's details into the
  /// wrong conversation, which is not a mistake that can be taken back.
  final String recipientLabel;

  @override
  ConsumerState<SendIdCardScreen> createState() => _SendIdCardScreenState();
}

class _SendIdCardScreenState extends ConsumerState<SendIdCardScreen> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final List<StudentEntry> all =
        ref.watch(entriesProvider).value ?? const <StudentEntry>[];

    final List<StudentEntry> sendable = all
        .where((StudentEntry e) => e.approvalStatus.isPrintable)
        .toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: JoinTheme.header,
        foregroundColor: Colors.white,
        title: const Text('Send ID Card'),
      ),
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: JoinTheme.accentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'To',
                  style: TextStyle(fontSize: 11.5, color: Colors.black54),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.recipientLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: JoinTheme.header,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: sendable.isEmpty
                ? const _NothingToSend()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: sendable.length,
                    itemBuilder: (BuildContext c, int i) {
                      final StudentEntry e = sendable[i];
                      final bool selected = e.id == _selectedId;
                      return FadeSlideIn(
                        index: i,
                        child: Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: selected
                                  ? JoinTheme.header
                                  : Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: ListTile(
                            onTap: () => setState(() => _selectedId = e.id),
                            title: Text(
                              e.name.isEmpty ? 'Unnamed' : e.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(_describe(e)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                ApprovalStatusChip(status: e.approvalStatus),
                                const SizedBox(width: 8),
                                Icon(
                                  selected
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  color: selected
                                      ? JoinTheme.header
                                      : Colors.black26,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          if (sendable.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF3DC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'The card goes into the chat as a message. The office can '
                  'open and print it.',
                  style: TextStyle(fontSize: 12.5, height: 1.4),
                ),
              ),
            ),

          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: FilledButton(
                style: JoinTheme.filledButton(),
                onPressed: _selectedId == null
                    ? null
                    : () => Navigator.of(context).pop(_selectedId),
                child: const Text('Send ID Card'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Roll 24 · Class 10-A", skipping whatever the school does not collect.
String _describe(StudentEntry e) {
  final String section = e.division.isEmpty ? '' : '-${e.division}';
  return <String>[
    if (e.rollNumber.isNotEmpty) 'Roll ${e.rollNumber}',
    if (e.studentClass.isNotEmpty) 'Class ${e.studentClass}$section',
  ].join(' · ');
}

class _NothingToSend extends StatelessWidget {
  const _NothingToSend();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.badge_outlined, size: 44, color: Colors.black26),
            const SizedBox(height: 14),
            Text(
              'No approved cards yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Only cards the office has approved can be sent. Submit a card '
              'and it will appear here once it has been signed off.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
