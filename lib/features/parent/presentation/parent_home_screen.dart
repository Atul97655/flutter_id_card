import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/parent/application/parent_providers.dart';
import 'package:flutter_id_card/features/parent/application/parent_strings.dart';
import 'package:flutter_id_card/features/parent/presentation/school_picker_screen.dart';
import 'package:flutter_id_card/features/parent/presentation/widgets/parent_widgets.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A parent's home: one obvious button to make a card, and where every card
/// they have sent has got to.
///
/// Built for someone who has never used the app and may be reading it over a
/// child's shoulder: one action, big type, icons doing as much of the talking
/// as words, and a progress line on each card so "did it arrive?" never needs
/// a phone call to the office.
class ParentHomeScreen extends ConsumerWidget {
  const ParentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ParentStrings s = ref.watch(parentStringsProvider);
    final List<StudentEntry> entries =
        ref.watch(parentEntriesProvider).value ?? const <StudentEntry>[];
    final Map<String, String> schoolNames =
        ref.watch(schoolNamesProvider).value ?? const <String, String>{};
    final String name = ref.watch(currentSessionProvider)?.displayName ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ParentBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(
            // The bottom padding clears the floating navigation bar.
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            children: <Widget>[
              Row(
                children: <Widget>[
                  const BrandMark(size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.hello(name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: ParentColors.ink,
                      ),
                    ),
                  ),
                  const LanguageToggle(),
                ],
              ),
              const SizedBox(height: 22),
              _Hero(strings: s),
              const SizedBox(height: 28),
              Text(
                s.yourCards,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: ParentColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              if (entries.isEmpty)
                _Empty(strings: s)
              else
                for (final StudentEntry e in entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CardTile(
                      entry: e,
                      schoolName: schoolNames[e.schoolId] ?? '',
                      strings: s,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.strings});

  final ParentStrings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: ParentColors.hero,
        borderRadius: BorderRadius.circular(28),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: ParentColors.brand.withValues(alpha: 0.32),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            strings.heroTitle,
            style: const TextStyle(
              fontSize: 25,
              height: 1.2,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            strings.heroSubtitle,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              _HeroStep(
                icon: Icons.school_rounded,
                label: strings.stepSchool,
              ),
              const _HeroArrow(),
              _HeroStep(
                icon: Icons.photo_camera_rounded,
                label: strings.stepPhoto,
              ),
              const _HeroArrow(),
              _HeroStep(icon: Icons.send_rounded, label: strings.stepSend),
            ],
          ),
          const SizedBox(height: 22),
          BigButton(
            label: strings.makeCard,
            icon: Icons.add_rounded,
            onHero: true,
            onPressed: () => startParentIdCard(context),
          ),
        ],
      ),
    );
  }
}

class _HeroStep extends StatelessWidget {
  const _HeroStep({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 23),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroArrow extends StatelessWidget {
  const _HeroArrow();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 26),
    child: Icon(
      Icons.chevron_right_rounded,
      color: Colors.white.withValues(alpha: 0.6),
      size: 20,
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.strings});

  final ParentStrings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: ParentColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ParentColors.line),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: ParentColors.brand.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.badge_outlined,
              color: ParentColors.brand,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            strings.emptyTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: ParentColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            strings.emptyHint,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.45,
              color: ParentColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

/// Where a card has got to, as four ticks along a line.
class _CardTile extends StatelessWidget {
  const _CardTile({
    required this.entry,
    required this.schoolName,
    required this.strings,
  });

  final StudentEntry entry;
  final String schoolName;
  final ParentStrings strings;

  bool get _sent => entry.syncStatus == SyncStatus.synced;
  bool get _rejected => _sent && entry.approvalStatus == ApprovalStatus.rejected;
  bool get _approved =>
      _sent &&
      (entry.approvalStatus == ApprovalStatus.approved ||
          entry.approvalStatus == ApprovalStatus.printed);
  bool get _printed => _sent && entry.approvalStatus == ApprovalStatus.printed;

  /// The one line that answers "what is happening with this card?".
  String get _status {
    if (!_sent) {
      return entry.syncStatus == SyncStatus.failed
          ? strings.statusRetry
          : strings.statusWaiting;
    }
    return switch (entry.approvalStatus) {
      ApprovalStatus.pending => strings.statusOffice,
      ApprovalStatus.approved => strings.statusApproved,
      ApprovalStatus.printed => strings.statusPrinted,
      ApprovalStatus.rejected => strings.statusSentBack,
    };
  }

  Color get _statusColor {
    if (_rejected) return ParentColors.danger;
    if (_approved) return ParentColors.success;
    if (!_sent && entry.syncStatus == SyncStatus.failed) {
      return ParentColors.danger;
    }
    return ParentColors.warn;
  }

  String get _initials {
    final List<String> parts = entry.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ParentColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ParentColors.line),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: ParentColors.ink.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  gradient: ParentColors.hero,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: ParentColors.ink,
                      ),
                    ),
                    if (schoolName.isNotEmpty)
                      Text(
                        schoolName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: ParentColors.inkSoft,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Icon(Icons.circle, size: 9, color: _statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _status,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: _statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (_rejected) ...<Widget>[
            const SizedBox(height: 10),
            if ((entry.rejectionReason ?? '').isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ParentColors.danger.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  entry.rejectionReason!,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: ParentColors.ink,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => startParentIdCard(context),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(strings.makeAgain),
              ),
            ),
          ] else ...<Widget>[
            const SizedBox(height: 16),
            _Progress(
              labels: <String>[
                strings.progressSaved,
                strings.progressSent,
                strings.progressApproved,
                strings.progressPrinted,
              ],
              done: <bool>[true, _sent, _approved, _printed],
            ),
          ],
        ],
      ),
    );
  }
}

/// Four labelled dots joined by a line; filled up to the last one reached.
class _Progress extends StatelessWidget {
  const _Progress({required this.labels, required this.done});

  final List<String> labels;
  final List<bool> done;

  @override
  Widget build(BuildContext context) {
    final List<Widget> row = <Widget>[];
    for (int i = 0; i < labels.length; i++) {
      if (i > 0) {
        row.add(
          Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.only(bottom: 22),
              decoration: BoxDecoration(
                color: done[i] ? ParentColors.success : ParentColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      }
      row.add(_Node(label: labels[i], done: done[i]));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: row);
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: done ? ParentColors.success : ParentColors.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: done ? ParentColors.success : ParentColors.line,
                width: 2,
              ),
            ),
            child: done
                ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: done ? ParentColors.ink : ParentColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
