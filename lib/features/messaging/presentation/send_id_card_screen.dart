import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/data_entry/application/entry_providers.dart';
import 'package:flutter_id_card/features/data_entry/presentation/data_entry_screen.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/join_theme.dart';
import 'package:flutter_id_card/shared/widgets/approval_status_chip.dart';
import 'package:flutter_id_card/shared/widgets/glass/admin_page.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Picking which card to send into a conversation - or making a new one.
///
/// Only cards the office has already approved can be *sent*. Sending a pending
/// card would be asking the admin to review it twice - once in the queue
/// where the decision is recorded, and again in a chat where it is not - and
/// the second review would have nowhere to go.
///
/// That rule used to make this screen a dead end. A teacher who opened it for
/// a student whose card did not exist yet was told "No approved cards yet"
/// and had to back out of the conversation, find the home screen, make the
/// card, and come back. Creating one is now the first thing on the screen,
/// above the list, because it is the thing someone who finds this list empty
/// actually needs. The new card goes to the office on the same path as every
/// other submission; it is listed under "With the office" until it comes
/// back approved.
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

  /// The card made during this visit, if any.
  ///
  /// Held so it can be called out by name when it comes back approved, and so
  /// the screen can say something more useful than silence the moment the
  /// form closes.
  String? _justCreatedId;

  Future<void> _createCard() async {
    final String? newId = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        // Pushed imperatively, not through the router, and told to hand the
        // id back instead of walking on to the preview. The router's own
        // `/entry/new` ends at a receipt screen reached with `go`, which
        // replaces the whole stack - taking the conversation this was opened
        // from with it.
        builder: (BuildContext c) => const DataEntryScreen(returnsEntryId: true),
      ),
    );
    if (newId == null || !mounted) return;

    setState(() => _justCreatedId = newId);

    final StudentEntry? made = ref.read(entryByIdProvider(newId));
    // An approved card can be sent at once. In practice a new one is pending,
    // and saying so plainly is better than leaving the teacher to work out
    // why the card they just made is not selectable.
    if (made != null && made.approvalStatus.isPrintable) {
      setState(() => _selectedId = newId);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Sent to the office for approval. You can send it here once it '
          'comes back approved.',
        ),
        duration: Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<StudentEntry> all =
        ref.watch(entriesProvider).value ?? const <StudentEntry>[];

    final List<StudentEntry> sendable = all
        .where((StudentEntry e) => e.approvalStatus.isPrintable)
        .toList();

    // Only the cards still with the office, and only the ones this teacher
    // would recognise as "the one I just made" - the whole school's pending
    // queue would bury the point.
    final List<StudentEntry> waiting = all
        .where(
          (StudentEntry e) =>
              e.approvalStatus == ApprovalStatus.pending &&
              (e.id == _justCreatedId || _isRecent(e)),
        )
        .toList();

    return AdminPage(
      // The chat backdrop: this screen is reached from a conversation, and
      // arriving on the card pipeline's blue would read as having left it.
      backdrop: GlassBackdrop.chat,
      title: 'Send ID Card',
      subtitle: 'Only approved cards can be sent',
      onBack: () => Navigator.of(context).maybePop(),
      child: Column(
        children: <Widget>[
          // Slivers rather than a ListView with a children list. A school
          // that has been running a while has hundreds of approved cards, and
          // a children list builds every one of them before the first frame -
          // which on the handsets this runs on is a visible stall every time
          // the picker opens. The header block is one sliver; the rows stay
          // lazy.
          Expanded(
            child: CustomScrollView(
              slivers: <Widget>[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(<Widget>[
                      _RecipientCard(label: widget.recipientLabel),
                      const SizedBox(height: 14),

                      // Above the list, deliberately. Someone who gets here
                      // with nothing to send needs this, and someone who has
                      // cards to send loses nothing but one row of scroll.
                      _CreateCardTile(onTap: _createCard),

                      if (waiting.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 18),
                        _SectionLabel(
                          waiting.length == 1
                              ? 'With the office'
                              : 'With the office (${waiting.length})',
                        ),
                        const SizedBox(height: 8),
                        for (final StudentEntry e in waiting)
                          _WaitingRow(
                            entry: e,
                            isNew: e.id == _justCreatedId,
                          ),
                      ],

                      const SizedBox(height: 18),
                      _SectionLabel(
                        sendable.isEmpty
                            ? 'Approved cards'
                            : 'Approved cards (${sendable.length})',
                      ),
                      const SizedBox(height: 8),
                      if (sendable.isEmpty) const _NothingToSend(),
                    ]),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((
                      BuildContext c,
                      int i,
                    ) {
                      final StudentEntry e = sendable[i];
                      return FadeSlideIn(
                        index: i,
                        child: _SendableRow(
                          entry: e,
                          selected: e.id == _selectedId,
                          onTap: () => setState(() => _selectedId = e.id),
                        ),
                      );
                    }, childCount: sendable.length),
                  ),
                ),
              ],
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

/// Submitted in the last day.
///
/// The window exists so a teacher who made a card, backed out, and came back
/// still sees where it went. Older pending cards belong on the submissions
/// list, not in a send picker.
bool _isRecent(StudentEntry e) =>
    DateTime.now().difference(e.createdAt).inHours < 24;

class _RecipientCard extends StatelessWidget {
  const _RecipientCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: JoinTheme.header,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11.5,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
          color: Colors.black54,
        ),
      ),
    );
  }
}

/// "Create a new ID card", sitting above everything that already exists.
class _CreateCardTile extends StatelessWidget {
  const _CreateCardTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: JoinTheme.header.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: JoinTheme.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.add_card_outlined,
                  color: JoinTheme.header,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Create a new ID card',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: JoinTheme.header,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Goes to the office for approval',
                      style: TextStyle(fontSize: 12.5, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: JoinTheme.header,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A card that has gone to the office and not come back yet.
///
/// Drawn, not hidden. The alternative - a card that vanishes the moment it is
/// submitted - reads as work that was lost, and the teacher makes it again.
class _WaitingRow extends StatelessWidget {
  const _WaitingRow({required this.entry, required this.isNew});

  final StudentEntry entry;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListTile(
        // Not tappable. There is nothing to do with it here yet, and a row
        // that responds to a tap by doing nothing is worse than one that
        // plainly does not.
        title: Text(
          entry.name.isEmpty ? 'Unnamed' : entry.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          isNew
              ? 'Just sent to the office'
              : _describe(entry).isEmpty
              ? 'Waiting for approval'
              : _describe(entry),
        ),
        trailing: ApprovalStatusChip(status: entry.approvalStatus),
      ),
    );
  }
}

class _SendableRow extends StatelessWidget {
  const _SendableRow({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final StudentEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected
              ? JoinTheme.header
              : Theme.of(context).colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(
          entry.name.isEmpty ? 'Unnamed' : entry.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(_describe(entry)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ApprovalStatusChip(status: entry.approvalStatus),
            const SizedBox(width: 8),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? JoinTheme.header : Colors.black26,
            ),
          ],
        ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.badge_outlined, size: 40, color: Colors.black26),
          const SizedBox(height: 12),
          Text(
            'No approved cards yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Only cards the office has approved can be sent. Make one above '
            'and it will appear here once it has been signed off.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}
