import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_id_card/features/data_entry/application/entry_providers.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Confirmation shown straight after a card is submitted.
///
/// Its job is to close the loop on an action that otherwise ends with the form
/// simply vanishing: it names what was submitted, gives the teacher a short id
/// they can quote to the office, and offers the one thing they almost always
/// want next - another card for the same class.
class SubmissionSuccessScreen extends ConsumerWidget {
  const SubmissionSuccessScreen({super.key, required this.entryId});

  final String entryId;

  static final DateFormat _stamp = DateFormat('dd MMM yyyy, h:mm a');

  /// The short id the teacher reads out. See `_RequestIdRow` in the detail
  /// screen - the two must agree, so both derive it the same way.
  static String shortId(String id) {
    final String cleaned = id.replaceAll('-', '').toUpperCase();
    return cleaned.length <= 6 ? cleaned : cleaned.substring(0, 6);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StudentEntry? entry = ref.watch(entryByIdProvider(entryId));
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      // No back arrow: going "back" from here would land on a form that has
      // already been submitted. Every route onward is an explicit button.
      appBar: AppBar(
        title: const Text('Submitted'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.gutter),
          child: Column(
            children: <Widget>[
              const Spacer(),
              const _SuccessMark(),
              const SizedBox(height: 24),
              FadeSlideIn(
                index: 1,
                child: Text(
                  'Sent to the office',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              FadeSlideIn(
                index: 2,
                child: Text(
                  entry == null
                      ? 'The card is saved on this device and will upload '
                          'automatically.'
                      : '${entry.name} is saved and will upload automatically '
                          'when you are online.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (entry != null)
                FadeSlideIn(index: 3, child: _ReceiptCard(entry: entry)),
              const Spacer(),
              FadeSlideIn(index: 4, child: _Actions(entryId: entryId)),
            ],
          ),
        ),
      ),
    );
  }
}

/// An animated tick that draws itself in. Deliberately brief - it is a
/// confirmation, not a celebration, and an operator submits dozens a day.
class _SuccessMark extends StatefulWidget {
  const _SuccessMark();

  @override
  State<_SuccessMark> createState() => _SuccessMarkState();
}

class _SuccessMarkState extends State<_SuccessMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> ring = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.6, curve: AppMotion.emphasized),
    );
    final Animation<double> tick = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.35, 1, curve: AppMotion.decelerate),
    );

    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, _) => Transform.scale(
        scale: ring.value,
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: StatusColors.synced.withValues(alpha: 0.12),
            border: Border.all(
              color: StatusColors.synced.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: Center(
            child: Opacity(
              opacity: tick.value,
              child: Transform.scale(
                scale: 0.7 + (tick.value * 0.3),
                child: const Icon(
                  Icons.check_rounded,
                  size: 52,
                  color: StatusColors.synced,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.entry});

  final StudentEntry entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String id = SubmissionSuccessScreen.shortId(entry.id);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gutter),
        child: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'Request ID',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: 10),
                SelectableText(
                  id,
                  style: const TextStyle(
                    fontSize: 20,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                IconButton(
                  tooltip: 'Copy',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: id));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(content: Text('Request ID copied')),
                      );
                  },
                ),
              ],
            ),
            const Divider(height: 20),
            Text(
              SubmissionSuccessScreen._stamp.format(entry.createdAt),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              'Quote this ID if you ring the office about this card.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.entryId});

  final String entryId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FilledButton.icon(
          // `go` rather than `push`: the new form must not stack on top of a
          // success screen, or Back walks through a pile of them.
          onPressed: () => context.go('/entry/new'),
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('Create another card'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => context.go('/submissions/$entryId'),
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('View this submission'),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => context.go('/home'),
          child: const Text('Back to home'),
        ),
      ],
    );
  }
}
