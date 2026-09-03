import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/data_entry/application/entry_providers.dart';
import 'package:flutter_id_card/features/data_entry/presentation/widgets/dynamic_form_field.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/student_field.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/providers/core_providers.dart';
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

  @override
  void initState() {
    super.initState();
    for (final StudentField field in StudentField.values) {
      _controllers[field] = TextEditingController()
        ..addListener(() {
          if (!_dirty) _dirty = true;
        });
    }
  }

  @override
  void dispose() {
    for (final TextEditingController c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrl(StudentField f) => _controllers[f]!;

  void _hydrateFrom(StudentEntry entry) {
    _existing = entry;
    _ctrl(StudentField.name).text = entry.name;
    _ctrl(StudentField.fatherName).text = entry.fatherName;
    _ctrl(StudentField.studentClass).text = entry.studentClass;
    _ctrl(StudentField.division).text = entry.division;
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
    final List<StudentEntry> entries = ref.read(entriesProvider).value ?? const <StudentEntry>[];
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
    final String? path = await context.push<String>('/photo', extra: _photoPath);
    if (!mounted || path == null) return;
    setState(() {
      _photoPath = path;
      _dirty = true;
    });
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

    setState(() => _saving = true);

    final DateTime now = DateTime.now();
    final StudentEntry entry = StudentEntry(
      id: _existing?.id ?? const Uuid().v4(),
      schoolId: schoolId,
      name: _ctrl(StudentField.name).text.trim(),
      fatherName: _ctrl(StudentField.fatherName).text.trim(),
      studentClass: _ctrl(StudentField.studentClass).text.trim(),
      division: _ctrl(StudentField.division).text.trim(),
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
        SnackBar(
          content: Text(message),
          backgroundColor: StatusColors.failed,
        ),
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
    final AsyncValue<SchoolConfig> configAsync = ref.watch(schoolConfigProvider);

    // Load the record being edited exactly once, after the entries stream has
    // produced data.
    if (widget.entryId != null && !_loadedExisting) {
      final List<StudentEntry>? entries = ref.watch(entriesProvider).value;
      if (entries != null) {
        final StudentEntry? match =
            entries.where((StudentEntry e) => e.id == widget.entryId).firstOrNull;
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
        body: configAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, StackTrace s) => Center(child: Text('Settings error: $e')),
          data: _form,
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
          _PhotoTile(
            path: _photoPath,
            onTap: _capturePhoto,
          ),
          const SizedBox(height: 20),
          for (int i = 0; i < fields.length; i++) ...<Widget>[
            DynamicFormField(
              field: fields[i],
              controller: _ctrl(fields[i]),
              selectedDate: _dob,
              onDateChanged: (DateTime? d) => setState(() {
                _dob = d;
                _dirty = true;
              }),
              autofocus: i == 0 && widget.entryId == null,
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _saveBar(SchoolConfig config) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(AppTheme.gutter, 0, AppTheme.gutter, 12),
      child: FilledButton.icon(
        onPressed: _saving ? null : () => _save(config),
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.visibility_outlined),
        label: Text(_saving ? 'Saving...' : 'Save & Preview Card'),
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
    final bool hasPhoto = path != null && path!.isNotEmpty && File(path!).existsSync();

    return Center(
      child: Column(
        children: <Widget>[
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 132,
              height: 165, // 1.2 : 1.5
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasPhoto ? theme.colorScheme.primary : theme.colorScheme.outline,
                  width: hasPhoto ? 2 : 1.2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasPhoto
                  ? Image.file(File(path!), fit: BoxFit.cover)
                  : Column(
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
          if (hasPhoto) ...<Widget>[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retake / Edit'),
            ),
          ],
        ],
      ),
    );
  }
}
