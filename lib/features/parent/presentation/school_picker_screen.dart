import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/data_entry/presentation/data_entry_screen.dart';
import 'package:flutter_id_card/features/parent/application/parent_providers.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/providers/core_providers.dart';
import 'package:flutter_id_card/shared/services/local/school_repository.dart';
import 'package:flutter_id_card/shared/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Starts the parent's ID card flow: pick a school, fill that school's form,
/// take the photo, send.
///
/// Pushed imperatively and awaited, so the same call works from the home
/// screen and from the attachment tray inside a conversation - the caller
/// stays exactly where it was, and gets back the saved entry's id (or null if
/// the parent backed out). Going through the router instead would replace the
/// stack, closing the chat the tray was opened from.
Future<bool> startParentIdCard(BuildContext context) async {
  final String? entryId = await Navigator.of(context).push<String>(
    MaterialPageRoute<String>(
      builder: (BuildContext c) => const SchoolPickerScreen(),
    ),
  );
  if (entryId == null || !context.mounted) return false;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text(
          'Saved. It goes to the school office as soon as you are online.',
        ),
      ),
    );
  return true;
}

/// Lists every school and hands the parent to that school's form.
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
    final AsyncValue<List<SchoolConfig>> schools = ref.watch(
      schoolDirectoryProvider,
    );

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Choose your school')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search schools',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: schools.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, StackTrace _) => const _Message(
                'Could not load schools. Check your connection and try again.',
              ),
              data: (List<SchoolConfig> all) {
                final String q = _search.text.trim().toLowerCase();
                final List<SchoolConfig> shown = q.isEmpty
                    ? all
                    : all
                          .where(
                            (SchoolConfig s) =>
                                s.name.toLowerCase().contains(q) ||
                                s.addressLine.toLowerCase().contains(q),
                          )
                          .toList();
                if (shown.isEmpty) {
                  return _Message(
                    all.isEmpty
                        ? 'No schools are available yet.'
                        : 'No school matches "${_search.text.trim()}".',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: shown.length,
                  separatorBuilder: (BuildContext c, int i) =>
                      const Divider(height: 1),
                  itemBuilder: (BuildContext c, int i) {
                    final SchoolConfig s = shown[i];
                    return ListTile(
                      enabled: !_busy,
                      leading: const CircleAvatar(
                        child: Icon(Icons.school_outlined),
                      ),
                      title: Text(s.name),
                      subtitle: s.addressLine.isEmpty
                          ? null
                          : Text(s.addressLine),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _choose(s),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}
