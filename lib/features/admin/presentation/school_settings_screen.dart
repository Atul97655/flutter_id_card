import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/admin/application/admin_providers.dart';
import 'package:flutter_id_card/features/card_render/application/card_render_providers.dart';
import 'package:flutter_id_card/features/card_render/data/template_repository.dart';
import 'package:flutter_id_card/features/card_render/domain/card_template.dart';
import 'package:flutter_id_card/shared/models/card_size.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_field.dart';
import 'package:flutter_id_card/shared/providers/core_providers.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Per-school configuration: identity, card size, template, field toggles and
/// colours.
///
/// Edits are held locally and written on Save rather than applied per
/// keystroke - a half-typed school name propagating to every operator's next
/// card would be worse than making the admin press a button.
///
/// [schoolId] is null when creating a new school.
class SchoolSettingsScreen extends ConsumerWidget {
  const SchoolSettingsScreen({super.key, this.schoolId});

  final String? schoolId;

  bool get isNew => schoolId == null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isNew) {
      return const _SchoolSettingsForm(existing: null);
    }

    final AsyncValue<SchoolConfig?> schoolAsync = ref.watch(
      schoolByIdProvider(schoolId!),
    );

    return schoolAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('School Settings')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (Object e, StackTrace s) => Scaffold(
        appBar: AppBar(title: const Text('School Settings')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (SchoolConfig? school) {
        if (school == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('School Settings')),
            body: const Center(child: Text('School not found')),
          );
        }
        return _SchoolSettingsForm(existing: school);
      },
    );
  }
}

class _SchoolSettingsForm extends ConsumerStatefulWidget {
  const _SchoolSettingsForm({required this.existing});

  final SchoolConfig? existing;

  bool get isNew => existing == null;

  @override
  ConsumerState<_SchoolSettingsForm> createState() =>
      _SchoolSettingsFormState();
}

class _SchoolSettingsFormState extends ConsumerState<_SchoolSettingsForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _id = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _contact = TextEditingController();

  String _cardSizeId = CardSize.defaultSize.id;
  String _templateId = TemplateRepository.defaultVerticalId;
  Set<String> _enabled = SchoolConfig.allFieldKeys;
  int _primary = SchoolConfig.kDefaultPrimaryHex;
  int _secondary = SchoolConfig.kDefaultSecondaryHex;
  int _header = SchoolConfig.kDefaultHeaderHex;
  Map<String, int> _divisionColors = <String, int>{};

  String? _localLogoPath;
  String? _logoUrl;
  String? _localSignaturePath;
  String? _signatureUrl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final SchoolConfig? config = widget.existing;
    if (config != null) {
      _id.text = config.id;
      _name.text = config.name;
      _address.text = config.addressLine;
      _contact.text = config.contactLine;
      _cardSizeId = config.cardSizeId;
      _templateId = config.templateId;
      _enabled = Set<String>.of(config.enabledFieldKeys);
      _primary = config.primaryColorHex;
      _secondary = config.secondaryColorHex;
      _header = config.headerColorHex;
      _divisionColors = Map<String, int>.of(config.divisionColors);
      _localLogoPath = config.localLogoPath;
      _logoUrl = config.logoUrl;
      _localSignaturePath = config.localPrincipalSignaturePath;
      _signatureUrl = config.principalSignatureUrl;
    }
  }

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    _address.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _pickAsset({required bool isLogo}) async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 95,
    );
    if (file == null) return;

    final Directory dir = await getApplicationDocumentsDirectory();
    final String schoolId =
        widget.existing?.id ??
        (_id.text.trim().isEmpty ? 'new_school' : _id.text.trim());
    final String folder = '${dir.path}/school_assets';
    await Directory(folder).create(recursive: true);

    final String ext = p.extension(file.path).isEmpty
        ? '.png'
        : p.extension(file.path);
    final String dest =
        '$folder/${schoolId}_${isLogo ? "logo" : "signature"}$ext';

    await File(file.path).copy(dest);

    if (!mounted) return;
    setState(() {
      if (isLogo) {
        _localLogoPath = dest;
      } else {
        _localSignaturePath = dest;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<CardTemplate>> templates = ref.watch(
      bundledTemplatesProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'Add School' : 'School Settings'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.gutter),
          children: <Widget>[
            _section('Identity'),
            TextFormField(
              controller: _id,
              // The id is the Firestore document key and is baked into every
              // entry's path, so it cannot change once records exist.
              enabled: widget.isNew,
              decoration: InputDecoration(
                labelText: 'School code (login ID)',
                hintText: 'e.g. stjohns',
                helperText: widget.isNew
                    ? 'Operators type this to sign in. Lowercase, no spaces.'
                    : 'Cannot be changed once the school exists.',
                prefixIcon: const Icon(Icons.tag),
              ),
              validator: (String? v) {
                if (!widget.isNew) return null;
                final String t = (v ?? '').trim();
                if (t.isEmpty) return 'A school code is required';
                if (!RegExp(r'^[a-z0-9._-]+$').hasMatch(t)) {
                  return 'Lowercase letters, digits, dot, dash, underscore only';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'School name (printed on the card)',
                prefixIcon: Icon(Icons.school_outlined),
              ),
              validator: (String? v) =>
                  (v ?? '').trim().isEmpty ? 'A name is required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _address,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Address line',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _contact,
              decoration: const InputDecoration(
                labelText: 'Contact line (footer)',
                hintText: 'Office: 0836-2345678',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),

            const SizedBox(height: AppTheme.gutter * 1.5),
            _section('Assets & Signature'),
            _assetCard(
              title: 'School Logo',
              subtitle: 'Printed in the header band of vertical and horizontal cards.',
              filePath: _localLogoPath,
              isSignature: false,
              onUpload: () => _pickAsset(isLogo: true),
              onRemove: () => setState(() {
                _localLogoPath = null;
                _logoUrl = null;
              }),
            ),
            const SizedBox(height: 10),
            _assetCard(
              title: 'Principal Signature',
              subtitle: 'Rendered directly above the "Principal Sign" line on framed cards.',
              filePath: _localSignaturePath,
              isSignature: true,
              onUpload: () => _pickAsset(isLogo: false),
              onRemove: () => setState(() {
                _localSignaturePath = null;
                _signatureUrl = null;
              }),
            ),

            const SizedBox(height: AppTheme.gutter * 1.5),
            _section('Card'),
            DropdownButtonFormField<String>(
              key: ValueKey<String>(_cardSizeId),
              initialValue: _cardSizeId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Card size',
                prefixIcon: Icon(Icons.crop_free),
              ),
              items: CardSize.all
                  .map(
                    (CardSize s) => DropdownMenuItem<String>(
                      value: s.id,
                      child: Text(s.label),
                    ),
                  )
                  .toList(),
              onChanged: (String? v) =>
                  setState(() => _cardSizeId = v ?? _cardSizeId),
            ),
            const SizedBox(height: 14),
            templates.when(
              loading: () => const LinearProgressIndicator(),
              error: (Object e, StackTrace s) =>
                  Text('Templates unavailable: $e'),
              data: (List<CardTemplate> list) => DropdownButtonFormField<String>(
                key: ValueKey<String>(_templateId),
                initialValue: list.any((CardTemplate t) => t.id == _templateId)
                    ? _templateId
                    : list.firstOrNull?.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Layout template',
                  prefixIcon: Icon(Icons.dashboard_outlined),
                ),
                items: list
                    .map(
                      (CardTemplate t) => DropdownMenuItem<String>(
                        value: t.id,
                        // Ellipsised rather than clipped: the size suffix makes
                        // some names longer than the field, and a hard clip
                        // drops the closing bracket mid-word.
                        child: Text(
                          '${t.name} - ${t.authoredSize.label}',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (String? v) =>
                    setState(() => _templateId = v ?? _templateId),
              ),
            ),

            const SizedBox(height: AppTheme.gutter * 1.5),
            _section('Fields on the card'),
            Text(
              'Switch off anything this school does not want printed. Name and '
              'Photo are always on.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Card(
              child: Column(
                children: <Widget>[
                  for (final StudentField field in StudentField.values)
                    SwitchListTile(
                      dense: true,
                      title: Text(field.formLabel),
                      subtitle: field.alwaysEnabled
                          ? const Text(
                              'Always on',
                              style: TextStyle(fontSize: 11.5),
                            )
                          : null,
                      value:
                          field.alwaysEnabled || _enabled.contains(field.key),
                      onChanged: field.alwaysEnabled
                          ? null
                          : (bool v) => setState(() {
                              if (v) {
                                _enabled.add(field.key);
                              } else {
                                _enabled.remove(field.key);
                              }
                            }),
                    ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.gutter * 1.5),
            _section('Colours'),
            _colorRow(
              'Header band',
              _header,
              (int v) => setState(() => _header = v),
            ),
            _colorRow(
              'Primary (Name, Class, Mobile, Address)',
              _primary,
              (int v) => setState(() => _primary = v),
            ),
            _colorRow(
              "Secondary (Father's Name, DOB)",
              _secondary,
              (int v) => setState(() => _secondary = v),
            ),

            const SizedBox(height: AppTheme.gutter),
            _DivisionColourEditor(
              colors: _divisionColors,
              onChanged: (Map<String, int> next) =>
                  setState(() => _divisionColors = next),
            ),

            const SizedBox(height: AppTheme.gutter * 2),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppTheme.gutter,
          0,
          AppTheme.gutter,
          12,
        ),
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Saving...' : 'Save settings'),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    ),
  );

  Widget _assetCard({
    required String title,
    required String subtitle,
    required String? filePath,
    required bool isSignature,
    required VoidCallback onUpload,
    required VoidCallback onRemove,
  }) {
    final bool hasFile = filePath != null && File(filePath).existsSync();
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasFile
                  ? Image.file(File(filePath), fit: BoxFit.contain)
                  : Icon(
                      isSignature ? Icons.draw_outlined : Icons.school_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 28,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: onUpload,
                        icon: Icon(
                          hasFile ? Icons.swap_horiz : Icons.upload,
                          size: 16,
                        ),
                        label: Text(
                          hasFile ? 'Change' : 'Upload',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      if (hasFile) ...<Widget>[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: onRemove,
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: Colors.red,
                          ),
                          label: const Text(
                            'Remove',
                            style: TextStyle(fontSize: 12, color: Colors.red),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorRow(String label, int value, ValueChanged<int> onChanged) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        title: Text(label, style: const TextStyle(fontSize: 13.5)),
        subtitle: Text(
          _hex(value),
          style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace'),
        ),
        trailing: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Color(value),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        onTap: () => _pickColor(label, value, onChanged),
      ),
    );
  }

  static String _hex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  Future<void> _pickColor(
    String label,
    int current,
    ValueChanged<int> onChanged,
  ) async {
    final TextEditingController field = TextEditingController(
      text: _hex(current),
    );

    final int? picked = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  <int>[
                        0xFFD32F2F,
                        0xFF1565C0,
                        0xFF2E7D32,
                        0xFFF57C00,
                        0xFF7B1FA2,
                        0xFF00838F,
                        0xFFAD1457,
                        0xFF1A3D7C,
                        0xFF111111,
                        0xFF9C1AB1,
                        0xFFE01B1B,
                        0xFF14A05A,
                      ]
                      .map(
                        (int c) => InkWell(
                          onTap: () => Navigator.of(ctx).pop(c),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Color(c),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: field,
              decoration: const InputDecoration(
                labelText: 'Or enter a hex value',
                hintText: '#RRGGBB',
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx)
                    .pop(SchoolConfig.parseHex(field.text, current)),
            child: const Text('Use'),
          ),
        ],
      ),
    );

    field.dispose();
    if (picked != null) onChanged(picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      final SchoolConfig config = SchoolConfig(
        id: widget.isNew ? _id.text.trim() : widget.existing!.id,
        name: _name.text.trim(),
        addressLine: _address.text.trim(),
        contactLine: _contact.text.trim(),
        cardSizeId: _cardSizeId,
        templateId: _templateId,
        enabledFieldKeys: _enabled,
        primaryColorHex: _primary,
        secondaryColorHex: _secondary,
        headerColorHex: _header,
        divisionColors: _divisionColors,
        logoUrl: _logoUrl,
        localLogoPath: _localLogoPath,
        principalSignatureUrl: _signatureUrl,
        localPrincipalSignaturePath: _localSignaturePath,
        updatedAt: DateTime.now(),
      );

      await ref.read(schoolRepositoryProvider).save(config);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Settings saved')));
      context.pop();
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save: $e'),
          backgroundColor: StatusColors.failed,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// Editor for the per-division accent colours.
class _DivisionColourEditor extends StatelessWidget {
  const _DivisionColourEditor({required this.colors, required this.onChanged});

  final Map<String, int> colors;
  final ValueChanged<Map<String, int>> onChanged;

  static const List<int> _palette = <int>[
    0xFFE01B1B,
    0xFF1A1AE0,
    0xFFE0189C,
    0xFF14A05A,
    0xFFF07A16,
    0xFF7B1FA2,
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> divisions = colors.keys.toList()..sort();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Per-division colours',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Optional. When set, a student\'s Div picks the accent colour '
              'instead of the school colour - one template produces a whole '
              'colour-coded set.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (divisions.isEmpty)
              Text(
                'None set - every card uses the school colours.',
                style: theme.textTheme.bodySmall,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: divisions
                    .map(
                      (String d) => Chip(
                        avatar: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Color(colors[d]!),
                            shape: BoxShape.circle,
                          ),
                        ),
                        label: Text('Div $d'),
                        onDeleted: () {
                          final Map<String, int> next = Map<String, int>.of(
                            colors,
                          )..remove(d);
                          onChanged(next);
                        },
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () => _addDivision(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add division'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (colors.isEmpty)
                  TextButton(
                    onPressed: () => onChanged(<String, int>{
                      for (int i = 0; i < 6; i++)
                        String.fromCharCode(65 + i): _palette[i],
                    }),
                    child: const Text('Use A-F preset'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addDivision(BuildContext context) async {
    final TextEditingController name = TextEditingController();

    final String? division = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Add division colour'),
        content: TextField(
          controller: name,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Division',
            hintText: 'A',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final String t = name.text.trim().toUpperCase();
              if (t.isEmpty) return;
              Navigator.of(ctx).pop(t);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    name.dispose();
    if (division == null) return;

    final Map<String, int> next = Map<String, int>.of(colors);
    next[division] = _palette[next.length % _palette.length];
    onChanged(next);
  }
}
