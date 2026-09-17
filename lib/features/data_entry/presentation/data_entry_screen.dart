import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/data_entry/application/entry_providers.dart';
import 'package:flutter_id_card/features/data_entry/data/draft_store.dart';
import 'package:flutter_id_card/features/data_entry/presentation/widgets/dynamic_form_field.dart';
import 'package:flutter_id_card/features/photo_capture/presentation/photo_capture_screen.dart'
    show photoFileExists;
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/student_field.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/providers/core_providers.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

/// The student data-entry form.
///
/// The layout is built from [SchoolConfig.enabledFields], so two schools using
/// the same build can present completely different forms. Nothing about which
/// fields exist is hard-coded in this widget.
class DataEntryScreen extends ConsumerStatefulWidget {
  const DataEntryScreen({super.key, this.entryId});

  /// Null for a new entry; an existing id when editing from the preview or the
  /// saved-entries list.
  final String? entryId;

  static const String routeName = 'dataEntry';

  @override
  ConsumerState<DataEntryScreen> createState() => _DataEntryScreenState();
}

class _DataEntryScreenState extends ConsumerState<DataEntryScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final Map<StudentField, TextEditingController> _controllers =
      <StudentField, TextEditingController>{};

  DateTime? _dob;
  String? _photoPath;
  bool _loadedExisting = false;
  bool _saving = false;
  bool _dirty = false;

  /// Preserved across an edit so re-saving does not reset the sync history.
  StudentEntry? _existing;

  static const DraftStore _drafts = DraftStore();

  /// Coalesces autosave writes. Every keystroke firing a SharedPreferences
  /// write would be pointless IO; a short debounce still guarantees the draft
  /// is on disk well before the OS can kill a backgrounded app.
  Timer? _autosaveTimer;
  bool _draftChecked = false;

  @override
  void initState() {
    super.initState();
    for (final StudentField field in StudentField.values) {
      _controllers[field] = TextEditingController()
        ..addListener(() {
          if (!_dirty) _dirty = true;
          _scheduleAutosave();
        });
    }
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    for (final TextEditingController c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Draft autosave
  // ------------------------------------------------------------------

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 800), _writeDraft);
  }

  Future<void> _writeDraft() async {
    final String? schoolId = ref.read(activeSchoolIdProvider);
    if (schoolId == null || schoolId.isEmpty) return;

    await _drafts.save(
      EntryDraft(
        schoolId: schoolId,
        entryId: widget.entryId,
        name: _ctrl(StudentField.name).text,
        fatherName: _ctrl(StudentField.fatherName).text,
        studentClass: _ctrl(StudentField.studentClass).text,
        division: _ctrl(StudentField.division).text,
        rollNumber: _ctrl(StudentField.rollNumber).text,
        bloodGroup: _ctrl(StudentField.bloodGroup).text,
        dobIso: _dob?.toIso8601String(),
        mobile: _ctrl(StudentField.mobile).text,
        address: _ctrl(StudentField.address).text,
        photoPath: _photoPath,
        savedAt: DateTime.now(),
      ),
    );
  }

  /// Offers a recovered draft once, on a fresh (non-edit) form.
  Future<void> _offerDraftRestore() async {
    if (_draftChecked || widget.entryId != null) return;
    _draftChecked = true;

    final String? schoolId = ref.read(activeSchoolIdProvider);
    if (schoolId == null || schoolId.isEmpty) return;

    final EntryDraft? draft = await _drafts.load(schoolId);
    if (draft == null || !mounted) return;

    final bool? restore = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Unfinished entry found'),
        content: Text(
          draft.name.trim().isEmpty
              ? 'You had an entry in progress. Restore it?'
              : 'You had an entry for "${draft.name}" in progress. Restore it?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (restore != true) {
      await _drafts.clear();
      return;
    }

    setState(() {
      _ctrl(StudentField.name).text = draft.name;
      _ctrl(StudentField.fatherName).text = draft.fatherName;
      _ctrl(StudentField.studentClass).text = draft.studentClass;
      _ctrl(StudentField.division).text = draft.division;
      _ctrl(StudentField.rollNumber).text = draft.rollNumber;
      _ctrl(StudentField.bloodGroup).text = draft.bloodGroup;
      _ctrl(StudentField.mobile).text = draft.mobile;
      _ctrl(StudentField.address).text = draft.address;
      _dob = draft.dobIso == null ? null : DateTime.tryParse(draft.dobIso!);
      // Only restore the photo if the file is still on disk - the OS may have
      // cleared it, and a dangling path renders as a broken tile.
      _photoPath = photoFileExists(draft.photoPath) ? draft.photoPath : null;
      _dirty = true;
    });
  }

  TextEditingController _ctrl(StudentField f) => _controllers[f]!;

  void _hydrateFrom(StudentEntry entry) {
    _existing = entry;
    _ctrl(StudentField.name).text = entry.name;
    _ctrl(StudentField.fatherName).text = entry.fatherName;
    _ctrl(StudentField.studentClass).text = entry.studentClass;
    _ctrl(StudentField.division).text = entry.division;
    _ctrl(StudentField.rollNumber).text = entry.rollNumber;
    _ctrl(StudentField.bloodGroup).text = entry.bloodGroup;
    _ctrl(StudentField.mobile).text = entry.mobile;
    _ctrl(StudentField.address).text = entry.address;
    _dob = entry.dob;
    _photoPath = entry.localPhotoPath;
    _dirty = false;
  }

  /// Copies Class and Div from the most recent entry. An operator processing a
  /// whole classroom retypes the same two values dozens of times otherwise.
  void _repeatLast() {
    final List<StudentEntry> entries =
        ref.read(entriesProvider).value ?? const <StudentEntry>[];
    if (entries.isEmpty) return;
    final StudentEntry last = entries.first;
    setState(() {
      _ctrl(StudentField.studentClass).text = last.studentClass;
      _ctrl(StudentField.division).text = last.division;
      _dirty = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Filled Class "${last.studentClass}" and Div "${last.division}" '
          'from the last entry',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _capturePhoto() async {
    final String? path = await context.push<String>(
      '/photo',
      extra: _photoPath,
    );
    if (!mounted || path == null) return;
    setState(() {
      _photoPath = path;
      _dirty = true;
    });
    // A captured photo is the most expensive thing to lose - it means finding
    // the student again - so persist it immediately rather than on a debounce.
    unawaited(_writeDraft());
  }

  Future<void> _save(SchoolConfig config) async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      _showError('Fix the highlighted fields before continuing');
      return;
    }
    if (_photoPath == null || _photoPath!.isEmpty) {
      _showError('Capture the student photo before saving');
      return;
    }

    final String? schoolId = ref.read(activeSchoolIdProvider);
    if (schoolId == null || schoolId.isEmpty) {
      _showError('No school is selected for this session');
      return;
    }

    final SessionUser? session = ref.read(currentSessionProvider);
    if (session != null &&
        session.role != UserRole.admin &&
        session.schoolId != null) {
      if (session.schoolId != schoolId) {
        _showError(
          'Unauthorized: operator not permitted to submit for this school',
        );
        return;
      }
    }
    if (_existing != null && _existing!.schoolId != schoolId) {
      _showError('Unauthorized: cross-school modification forbidden');
      return;
    }

    final String candidateName = _ctrl(StudentField.name).text.trim();
    final String candidateClass = _ctrl(StudentField.studentClass).text.trim();
    final List<StudentEntry> duplicates = await ref
        .read(studentRepositoryProvider)
        .findPotentialDuplicates(
          schoolId: schoolId,
          name: candidateName,
          studentClass: candidateClass,
          dob: _dob,
          excludeId: _existing?.id,
        );

    if (duplicates.isNotEmpty && mounted) {
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 36,
          ),
          title: const Text('Potential Duplicate Student'),
          content: Text(
            'A student named "$candidateName" is already registered in Class "$candidateClass".\n\n'
            'Do you want to proceed and save this record anyway?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Review Entry'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save Anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _saving = true);

    final DateTime now = DateTime.now();
    final StudentEntry entry = StudentEntry(
      id: _existing?.id ?? const Uuid().v4(),
      schoolId: schoolId,
      name: _ctrl(StudentField.name).text.trim(),
      fatherName: _ctrl(StudentField.fatherName).text.trim(),
      studentClass: _ctrl(StudentField.studentClass).text.trim(),
      division: _ctrl(StudentField.division).text.trim(),
      rollNumber: _ctrl(StudentField.rollNumber).text.trim(),
      bloodGroup: _ctrl(StudentField.bloodGroup).text.trim(),
      dob: _dob,
      mobile: _ctrl(StudentField.mobile).text.trim(),
      address: _ctrl(StudentField.address).text.trim(),
      localPhotoPath: _photoPath,
      remotePhotoUrl: _existing?.remotePhotoUrl,
      // Editing a synced record puts it back in the queue so the correction
      // actually reaches the server.
      syncStatus: SyncStatus.pending,
      syncAttempts: 0,
      createdAt: _existing?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      await ref.read(studentRepositoryProvider).save(entry);

      // The draft has served its purpose - the entry is committed. Leaving it
      // would prompt the operator to "restore" work they already saved.
      _autosaveTimer?.cancel();
      await _drafts.clear();

      if (!mounted) return;
      _dirty = false;
      context.pushReplacement('/preview/${entry.id}');
    } on Object catch (e) {
      if (!mounted) return;
      _showError('Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: StatusColors.failed),
      );
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Discard this entry?'),
        content: const Text('The details you typed have not been saved.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SchoolConfig> configAsync = ref.watch(
      schoolConfigProvider,
    );

    // Offer a recovered draft on the first frame of a fresh form.
    if (!_draftChecked && widget.entryId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_offerDraftRestore());
      });
    }

    // Load the record being edited exactly once, after the entries stream has
    // produced data.
    if (widget.entryId != null && !_loadedExisting) {
      final List<StudentEntry>? entries = ref.watch(entriesProvider).value;
      if (entries != null) {
        final StudentEntry? match = entries
            .where((StudentEntry e) => e.id == widget.entryId)
            .firstOrNull;
        if (match != null) {
          _loadedExisting = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _hydrateFrom(match));
          });
        }
      }
    }

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final bool leave = await _confirmDiscard();
        if (!leave || !context.mounted) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.entryId == null ? 'New ID Card' : 'Edit Entry'),
          actions: <Widget>[
            IconButton(
              tooltip: 'Copy Class & Div from last entry',
              icon: const Icon(Icons.content_copy_outlined),
              onPressed: _saving ? null : _repeatLast,
            ),
          ],
        ),
        body: SmoothSwitcher(
          alignment: Alignment.center,
          child: configAsync.when(
            loading: () => const Center(
              key: ValueKey<String>('loading'),
              child: CircularProgressIndicator(),
            ),
            error: (Object e, StackTrace s) => Center(
              key: const ValueKey<String>('error'),
              child: Text('Settings error: $e'),
            ),
            data: _form,
          ),
        ),
        bottomNavigationBar: configAsync.hasValue
            ? _saveBar(configAsync.requireValue)
            : null,
      ),
    );
  }

  Widget _form(SchoolConfig config) {
    final List<StudentField> fields = config.enabledFields
        .where((StudentField f) => f.kind != FieldKind.photo)
        .toList();

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.gutter,
          AppTheme.gutter,
          AppTheme.gutter,
          AppTheme.gutter * 2,
        ),
        children: <Widget>[
          FadeSlideIn(
            child: _PhotoTile(path: _photoPath, onTap: _capturePhoto),
          ),
          const SizedBox(height: 20),
          // Staggered so the form assembles itself rather than appearing all
          // at once - which on a school's enabled-field set can be a dozen
          // identical boxes landing in one frame.
          for (int i = 0; i < fields.length; i++) ...<Widget>[
            FadeSlideIn(
              index: i + 1,
              child: DynamicFormField(
                field: fields[i],
                controller: _ctrl(fields[i]),
                selectedDate: _dob,
                options: fields[i] == StudentField.studentClass
                    ? config.classes
                    : (fields[i] == StudentField.division
                          ? config.divisions
                          : null),
                onDateChanged: (DateTime? d) {
                  setState(() {
                    _dob = d;
                    _dirty = true;
                  });
                  // DOB does not go through a text controller, so autosave has
                  // to be triggered explicitly here.
                  _scheduleAutosave();
                },
                autofocus: i == 0 && widget.entryId == null,
              ),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _saveBar(SchoolConfig config) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        0,
        AppTheme.gutter,
        12,
      ),
      child: FilledButton.icon(
        onPressed: _saving ? null : () => _save(config),
        icon: AnimatedSwitcher(
          duration: AppMotion.fast,
          child: _saving
              ? const SizedBox(
                  key: ValueKey<bool>(true),
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(
                  Icons.visibility_outlined,
                  key: ValueKey<bool>(false),
                ),
        ),
        label: AnimatedSwitcher(
          duration: AppMotion.fast,
          child: Text(
            _saving ? 'Saving...' : 'Save & Preview Card',
            key: ValueKey<bool>(_saving),
          ),
        ),
      ),
    );
  }
}

/// Photo slot rendered at the true 1.2:1.5 aspect ratio so the operator sees
/// the real crop, not a square thumbnail that hides a bad framing.
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.path, required this.onTap});

  final String? path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasPhoto =
        path != null && path!.isNotEmpty && File(path!).existsSync();

    return Center(
      child: Column(
        children: <Widget>[
          PressableSurface(
            onTap: onTap,
            scale: 0.96,
            child: AnimatedContainer(
              duration: AppMotion.normal,
              curve: AppMotion.decelerate,
              width: 132,
              height: 165, // 1.2 : 1.5
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasPhoto
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                  width: hasPhoto ? 2 : 1.2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: AnimatedSwitcher(
                duration: AppMotion.normal,
                child: hasPhoto
                    ? Image.file(
                        key: ValueKey<String>(path!),
                        File(path!),
                        fit: BoxFit.cover,
                        cacheWidth: 360,
                        cacheHeight: 450,
                      )
                    : Column(
                        key: const ValueKey<String>('empty'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 34,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add Photo',
                            style: TextStyle(color: theme.colorScheme.outline),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '1.2 x 1.5 in',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          SmoothSwitcher(
            child: hasPhoto
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retake / Edit'),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
