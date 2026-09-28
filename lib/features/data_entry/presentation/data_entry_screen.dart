import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/data_entry/application/entry_providers.dart';
import 'package:flutter_id_card/features/data_entry/data/draft_store.dart';
import 'package:flutter_id_card/features/data_entry/presentation/widgets/dynamic_form_field.dart';
import 'package:flutter_id_card/features/onboarding/application/join_providers.dart';
import 'package:flutter_id_card/features/onboarding/domain/join_models.dart';
import 'package:flutter_id_card/features/photo_capture/presentation/photo_capture_screen.dart'
    show photoFileExists;
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/student_field.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/providers/core_providers.dart';
import 'package:flutter_id_card/shared/theme/app_colors.dart';
import 'package:flutter_id_card/shared/theme/app_gradients.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/app_shadows.dart';
import 'package:flutter_id_card/shared/theme/app_spacing.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_id_card/shared/theme/app_typography.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_controls.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_scaffold.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_surface.dart';
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
      // Attribution is stamped once, at creation, and never rewritten. An
      // admin correcting a typo is not the person who submitted the card, and
      // a record that quietly changes hands on edit is worse than one with no
      // name on it at all. Pre-v10 rows keep their null.
      submittedByUid: _existing?.submittedByUid ?? session?.uid,
      submittedByName: _existing?.submittedByName ?? session?.displayName,
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
      child: GlassScaffold(
        header: GlassHeader(
          title: widget.entryId == null ? 'New ID Card' : 'Edit Entry',
          subtitle: widget.entryId == null
              ? 'Capture the student, then preview the card'
              : 'Changes go back into the sync queue',
          // Routed through maybePop so the PopScope above still gets its say
          // and the unsaved-work prompt is not bypassed by the back button.
          onBack: () => Navigator.of(context).maybePop(),
          actions: <Widget>[
            GlassIconButton(
              icon: Icons.content_copy_outlined,
              tooltip: 'Copy Class & Div from last entry',
              onTap: _saving ? null : _repeatLast,
            ),
          ],
        ),
        bottomBar: configAsync.hasValue
            ? _saveBar(configAsync.requireValue)
            : null,
        child: SmoothSwitcher(
          alignment: Alignment.center,
          child: configAsync.when(
            loading: () => const Center(
              key: ValueKey<String>('loading'),
              child: CircularProgressIndicator(),
            ),
            error: (Object e, StackTrace s) => Center(
              key: const ValueKey<String>('error'),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                child: Text(
                  'Settings error: $e',
                  textAlign: TextAlign.center,
                  style: AppTypography.body,
                ),
              ),
            ),
            data: _form,
          ),
        ),
      ),
    );
  }

  /// Fills in the class and section a scoped teacher is not asked for.
  ///
  /// Done here rather than in `initState` because the assignment arrives on a
  /// stream and may land after the form is first built. Writing the same
  /// value twice is a no-op, so this is safe to call on every build; writing
  /// a DIFFERENT value is not, which is why an existing entry is left alone -
  /// an old card keeps the section it was filed under, and re-stamping it
  /// would silently move a student between sections on open.
  void _applyAssignment(JoinState? join) {
    if (join == null || !join.isReady) return;
    if (widget.entryId != null) return;

    final TextEditingController cls = _ctrl(StudentField.studentClass);
    final TextEditingController div = _ctrl(StudentField.division);
    if (cls.text != join.classLevel) cls.text = join.classLevel;
    if (div.text != join.division) div.text = join.division;
  }

  /// Why a field is shown filled in rather than asked for, or null when it
  /// is an ordinary editable field.
  ///
  /// A teacher never picks which section a student is filed under - it is
  /// stamped from their assignment. Leaving these editable would be a way to
  /// file a student outside your own section, which the rules refuse, so an
  /// editable box could only ever produce a save that fails for a reason the
  /// teacher cannot see on screen.
  ///
  /// Null for an unscoped teacher, who still types both. That is every
  /// account that existed before sections.
  static String? _stampReason(StudentField field, JoinState? join) {
    if (join == null || !join.isReady) return null;
    return switch (field) {
      StudentField.studentClass => 'Set by your class assignment',
      StudentField.division => 'Set by your class assignment',
      _ => null,
    };
  }

  Widget _form(SchoolConfig config) {
    final List<StudentField> fields = config.enabledFields
        .where((StudentField f) => f.kind != FieldKind.photo)
        .toList();

    final JoinState? join = ref.watch(joinStateProvider).value;
    _applyAssignment(join);

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          // Clears the floating save bar, which the page scrolls underneath.
          AppSpacing.navClearance,
        ),
        children: <Widget>[
          FadeSlideIn(
            child: _PhotoCard(path: _photoPath, onTap: _capturePhoto),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: AppSpacing.sm,
            ),
            child: Text('Student Details', style: AppTypography.title),
          ),
          // One panel holding every field, rather than a field per card: the
          // reference groups them, and a dozen separate floating cards on a
          // school with every field enabled reads as a pile rather than a
          // form.
          GlassSurface(
            radius: AppRadius.panelR,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Staggered so the form assembles itself rather than
                // appearing all at once - which on a school's enabled-field
                // set can be a dozen identical boxes landing in one frame.
                for (int i = 0; i < fields.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: AppSpacing.md),
                  FadeSlideIn(
                    index: i + 1,
                    child: DynamicFormField(
                      field: fields[i],
                      controller: _ctrl(fields[i]),
                      readOnlyReason: _stampReason(fields[i], join),
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
                        // DOB does not go through a text controller, so
                        // autosave has to be triggered explicitly here.
                        _scheduleAutosave();
                      },
                      autofocus: i == 0 && widget.entryId == null,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _saveBar(SchoolConfig config) {
    return GlassSurface(
      // One of the few real blurs in the app: the form scrolls underneath
      // this bar, so a flat gradient would show the seam the moment a field
      // passed behind it.
      depth: GlassDepth.frosted,
      radius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheet),
      ),
      fill: AppColors.glassFillStrong,
      shadows: AppShadows.floating,
      sheen: false,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.md,
          AppSpacing.gutter,
          AppSpacing.md,
        ),
        child: GlassButton(
          label: _saving ? 'Saving...' : 'Save & Preview Card',
          icon: Icons.visibility_outlined,
          trailingIcon: _saving ? null : Icons.arrow_forward,
          busy: _saving,
          onPressed: _saving ? null : () => _save(config),
        ),
      ),
    );
  }
}

/// The photo slot.
///
/// Rendered at the true 1.2:1.5 aspect ratio so the operator sees the real
/// crop, not a square thumbnail that hides a bad framing. This is the one
/// thing on the screen that cannot be re-typed later - if the framing is
/// wrong, somebody has to find the student again - so it gets the top of the
/// page and a card of its own.
class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.path, required this.onTap});

  final String? path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool hasPhoto =
        path != null && path!.isNotEmpty && File(path!).existsSync();

    return GlassSurface(
      radius: AppRadius.panelR,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
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
                color: AppColors.card,
                gradient: hasPhoto ? null : AppGradients.avatar,
                borderRadius: AppRadius.cardR,
                border: Border.all(
                  color: hasPhoto
                      ? AppColors.royal
                      : AppColors.royal.withValues(alpha: 0.28),
                  width: hasPhoto ? 2 : 1.4,
                ),
                boxShadow: hasPhoto
                    ? AppShadows.lifted
                    : AppShadows.subtle,
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
                    : const Column(
                        key: ValueKey<String>('empty'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 32,
                            color: AppColors.onDark,
                          ),
                          SizedBox(height: AppSpacing.sm),
                          Text('Add Photo', style: AppTypography.buttonSmall),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            hasPhoto ? 'Student Photo' : 'Photo required',
            style: AppTypography.section,
          ),
          const SizedBox(height: 2),
          Text(
            hasPhoto ? 'Tap to retake or re-crop' : 'Passport size, 1.2 x 1.5 in',
            style: AppTypography.support,
            textAlign: TextAlign.center,
          ),
          SmoothSwitcher(
            child: hasPhoto
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: GlassSurface(
                      radius: BorderRadius.circular(AppRadius.pill),
                      fill: AppColors.glassFillStrong,
                      shadows: AppShadows.subtle,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      onTap: onTap,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.refresh,
                            size: 17,
                            color: AppColors.royal,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Retake / Edit',
                            style: AppTypography.badge.copyWith(
                              color: AppColors.royal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
