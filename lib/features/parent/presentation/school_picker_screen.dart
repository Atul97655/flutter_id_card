import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/data_entry/presentation/data_entry_screen.dart';
import 'package:flutter_id_card/features/parent/application/parent_providers.dart';
import 'package:flutter_id_card/features/parent/application/parent_strings.dart';
import 'package:flutter_id_card/features/parent/presentation/widgets/parent_widgets.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/providers/core_providers.dart';
import 'package:flutter_id_card/shared/services/local/school_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Starts the parent's ID card flow: pick a school, fill that school's form,
/// take the photo, send.
///
/// Pushed imperatively and awaited, so the same call works from the home
/// screen and from the attachment tray inside a conversation - the caller
/// stays exactly where it was, and gets back whether a card was saved.
/// Going through the router instead would replace the stack, closing the chat
/// the tray was opened from.
Future<bool> startParentIdCard(BuildContext context) async {
  final String? entryId = await Navigator.of(context).push<String>(
    MaterialPageRoute<String>(
      builder: (BuildContext c) => const SchoolPickerScreen(),
    ),
  );
  if (entryId == null || !context.mounted) return false;

  final ParentStrings s = ProviderScope.containerOf(
    context,
  ).read(parentStringsProvider);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ParentColors.ink,
        content: Text(s.savedMessage),
      ),
    );
  return true;
}

/// Lists every school and hands the parent to that school's form.
///
/// Big rows, a search box, and the school's own colour on its avatar so a
/// child can find "the blue one" as easily as read the name. The list is
/// filtered on the device, which is fine into the low thousands of schools;
/// past that it would want a server-side prefix query.
class SchoolPickerScreen extends ConsumerStatefulWidget {
  const SchoolPickerScreen({super.key});

  @override
  ConsumerState<SchoolPickerScreen> createState() => _SchoolPickerScreenState();
}

class _SchoolPickerScreenState extends ConsumerState<SchoolPickerScreen> {
  final TextEditingController _search = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _choose(SchoolConfig school) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      // The form reads its settings from the local cache, never the network,
      // so the chosen school has to be there before the form opens. Keep a
      // logo already downloaded for it: the directory copy only has the URL.
      final SchoolRepository repo = ref.read(schoolRepositoryProvider);
      final SchoolConfig? existing = await repo.find(school.id);
      await repo.save(
        existing?.localLogoPath == null
            ? school
            : school.copyWith(localLogoPath: existing!.localLogoPath),
      );
      ref.read(activeSchoolIdProvider.notifier).select(school.id);

      if (!mounted) return;
      final String? entryId = await Navigator.of(context).push<String>(
        MaterialPageRoute<String>(
          builder: (BuildContext c) =>
              const DataEntryScreen(returnsEntryId: true),
        ),
      );
      if (!mounted) return;
      if (entryId != null) Navigator.of(context).pop(entryId);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ParentStrings s = ref.watch(parentStringsProvider);
    final AsyncValue<List<SchoolConfig>> schools = ref.watch(
      schoolDirectoryProvider,
    );

    return Scaffold(
      body: ParentBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: _busy ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: ParentColors.ink,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                    ),
                    const Spacer(),
                    const LanguageToggle(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _StepPills(label: s.stepOfThree),
                    const SizedBox(height: 14),
                    Text(
                      s.chooseSchool,
                      style: const TextStyle(
                        fontSize: 28,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        color: ParentColors.ink,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: s.searchSchools,
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: ParentColors.inkSoft,
                        ),
                        filled: true,
                        fillColor: ParentColors.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 18,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: ParentColors.line,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: ParentColors.line,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: ParentColors.brand,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: schools.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (Object e, StackTrace _) => _Message(
                    text: s.loadError,
                    actionLabel: s.retry,
                    onAction: () => ref.invalidate(schoolDirectoryProvider),
                  ),
                  data: (List<SchoolConfig> all) {
                    final String q = _search.text.trim().toLowerCase();
                    final List<SchoolConfig> shown = q.isEmpty
                        ? all
                        : all
                              .where(
                                (SchoolConfig c) =>
                                    c.name.toLowerCase().contains(q) ||
                                    c.addressLine.toLowerCase().contains(q),
                              )
                              .toList();
                    if (shown.isEmpty) {
                      return _Message(
                        text: all.isEmpty
                            ? s.noSchools
                            : s.noMatch(_search.text.trim()),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      itemCount: shown.length,
                      separatorBuilder: (BuildContext c, int i) =>
                          const SizedBox(height: 10),
                      itemBuilder: (BuildContext c, int i) =>
                          _SchoolRow(school: shown[i], onTap: _busy ? null : () => _choose(shown[i])),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Step 1 of 3" with three bars, the first filled.
class _StepPills extends StatelessWidget {
  const _StepPills({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    Widget bar(bool on) => Container(
      width: 28,
      height: 6,
      margin: const EdgeInsets.only(right: 5),
      decoration: BoxDecoration(
        color: on ? ParentColors.brand : ParentColors.line,
        borderRadius: BorderRadius.circular(3),
      ),
    );
    return Row(
      children: <Widget>[
        bar(true),
        bar(false),
        bar(false),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: ParentColors.inkSoft,
          ),
        ),
      ],
    );
  }
}

class _SchoolRow extends StatelessWidget {
  const _SchoolRow({required this.school, required this.onTap});

  final SchoolConfig school;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color tint = Color(school.headerColorHex);
    final String initial = school.name.trim().isEmpty
        ? '?'
        : school.name.trim().substring(0, 1).toUpperCase();

    return Material(
      color: ParentColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ParentColors.line),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      school.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16.5,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        color: ParentColors.ink,
                      ),
                    ),
                    if (school.addressLine.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          school.addressLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: ParentColors.inkSoft,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: ParentColors.inkSoft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15.5,
              height: 1.45,
              color: ParentColors.inkSoft,
            ),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 14),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}
