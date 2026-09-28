import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/student_field.dart';
import 'package:flutter_id_card/shared/theme/app_colors.dart';
import 'package:flutter_id_card/shared/theme/app_typography.dart';
import 'package:flutter_id_card/shared/utils/input_formatters.dart';
import 'package:flutter_id_card/shared/utils/validators.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_text_field.dart';

/// Renders the correct input for a [StudentField].
///
/// The form screen walks the school's enabled-field list and drops one of these
/// in per field, so adding a field to the system means adding an enum value and
/// a case here - never editing a hand-built form layout.
///
/// Every branch wears the same glass chrome, either directly via
/// [GlassTextField] or by putting a bare input inside a [GlassFieldShell].
/// That is deliberate: a form where the date picker is a slightly different
/// shape from the text boxes is the single most visible way a redesign leaks.
class DynamicFormField extends StatelessWidget {
  const DynamicFormField({
    super.key,
    required this.field,
    required this.controller,
    required this.selectedDate,
    required this.onDateChanged,
    this.options,
    this.autofocus = false,
    this.readOnlyReason,
  });

  final StudentField field;

  /// Backs text-like inputs. For [FieldKind.date] and [FieldKind.bloodGroup]
  /// it still holds the canonical string value so the whole form can be read
  /// back uniformly.
  final TextEditingController controller;

  final DateTime? selectedDate;
  final ValueChanged<DateTime?> onDateChanged;
  final List<String>? options;
  final bool autofocus;

  /// When set, the field is shown filled in and not editable, and this text
  /// explains why underneath it.
  ///
  /// Used for the class and section of a scoped teacher: a teacher never
  /// picks which section a student is filed under, it is stamped from their
  /// assignment. Leaving the field editable would be a way to file a student
  /// outside your own section - which the rules refuse, so the only thing an
  /// editable box could produce is a save that fails for reasons the teacher
  /// cannot see.
  final String? readOnlyReason;

  @override
  Widget build(BuildContext context) {
    final String? reason = readOnlyReason;
    if (reason != null) return _stamped(reason);

    if (options != null &&
        options!.isNotEmpty &&
        field.kind == FieldKind.text) {
      return _dropdown(options!, _iconFor(field));
    }
    return switch (field.kind) {
      FieldKind.text => _text(),
      FieldKind.multiline => _multiline(),
      FieldKind.mobile => _mobile(),
      FieldKind.bloodGroup => _bloodGroup(),
      FieldKind.date => _date(context),
      // The photo is captured on its own screen, not inline in the form.
      FieldKind.photo => const SizedBox.shrink(),
    };
  }

  /// A value the teacher is shown rather than asked for.
  Widget _stamped(String reason) {
    return GlassTextField(
      label: field.formLabel,
      icon: _iconFor(field),
      controller: controller,
      readOnlyReason: reason,
    );
  }

  List<TextInputFormatter> get _textFormatters => <TextInputFormatter>[
    if (field.forceUppercase) const UpperCaseTextInputFormatter(),
    const CollapseWhitespaceFormatter(),
  ];

  Widget _text() {
    return GlassTextField(
      label: field.formLabel,
      icon: _iconFor(field),
      controller: controller,
      placeholder: _placeholderFor(field),
      autofocus: autofocus,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: _textFormatters,
      // No counter: it is noise on short fields. Only the address needs one,
      // and that has its own branch.
      maxLength: Validators.nameMaxLength,
      validator: (String? v) => Validators.forField(field, v, isRequired: true),
    );
  }

  Widget _multiline() {
    return GlassTextField(
      label: field.formLabel,
      icon: Icons.home_outlined,
      controller: controller,
      placeholder: 'House, street, area',
      minLines: 2,
      maxLines: 3,
      textInputAction: TextInputAction.newline,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: _textFormatters,
      maxLength: Validators.addressMaxLength,
      showCounter: true,
      helperText: 'Prints on up to 2 lines',
      validator: Validators.address,
    );
  }

  Widget _mobile() {
    return GlassTextField(
      label: field.formLabel,
      icon: Icons.phone_outlined,
      controller: controller,
      placeholder: '10-digit number',
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      inputFormatters: const <TextInputFormatter>[
        DigitsOnlyFormatter(maxLength: Validators.mobileLength),
      ],
      validator: Validators.mobile,
    );
  }

  Widget _bloodGroup() {
    final String current = controller.text.trim();
    return _dropdownShell(
      icon: Icons.bloodtype_outlined,
      child: DropdownButtonFormField<String>(
        initialValue: kBloodGroups.contains(current) ? current : null,
        isExpanded: true,
        decoration: glassInputDecoration(
          hintText: 'Select',
          suppressError: false,
        ),
        style: AppTypography.input,
        icon: const Icon(
          Icons.expand_more,
          size: 20,
          color: AppColors.inkMuted,
        ),
        items: kBloodGroups
            .map(
              (String g) => DropdownMenuItem<String>(value: g, child: Text(g)),
            )
            .toList(),
        onChanged: (String? v) => controller.text = v ?? '',
        validator: Validators.bloodGroup,
      ),
    );
  }

  Widget _dropdown(List<String> items, IconData icon) {
    final String current = controller.text.trim();
    final List<String> allItems = <String>[
      ...items,
      // A school can edit its class list. An entry captured under the old
      // list must not silently lose its value when the form reopens.
      if (current.isNotEmpty && !items.contains(current)) current,
    ];

    return _dropdownShell(
      icon: icon,
      child: DropdownButtonFormField<String>(
        initialValue: current.isNotEmpty ? current : null,
        isExpanded: true,
        decoration: glassInputDecoration(
          hintText: 'Select',
          suppressError: false,
        ),
        style: AppTypography.input,
        icon: const Icon(
          Icons.expand_more,
          size: 20,
          color: AppColors.inkMuted,
        ),
        items: allItems
            .map(
              (String val) =>
                  DropdownMenuItem<String>(value: val, child: Text(val)),
            )
            .toList(),
        onChanged: (String? val) {
          controller.text = val ?? '';
        },
        validator: (String? v) =>
            Validators.forField(field, v, isRequired: true),
      ),
    );
  }

  /// A dropdown keeps its own error text inside the shell rather than below
  /// it: `DropdownButtonFormField` owns its validation state, and there is no
  /// clean way to observe it from outside without rebuilding the field.
  Widget _dropdownShell({required IconData icon, required Widget child}) {
    return GlassFieldShell(label: field.formLabel, icon: icon, child: child);
  }

  Widget _date(BuildContext context) {
    final String? fallback = Validators.dateOfBirth(selectedDate);

    return FormField<DateTime>(
      initialValue: selectedDate,
      validator: (DateTime? v) => Validators.dateOfBirth(v ?? selectedDate),
      builder: (FormFieldState<DateTime> state) {
        final bool hasError = state.hasError;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _pickDate(context, state),
          child: GlassFieldShell(
            label: field.formLabel,
            icon: Icons.cake_outlined,
            hasError: hasError,
            trailing: const Icon(
              Icons.calendar_month_outlined,
              size: 20,
              color: AppColors.royal,
            ),
            // Shows the live validator result, not just the post-submit one,
            // so a mistyped year is caught before the operator moves on.
            footer: hasError
                ? Text(
                    state.errorText ?? fallback ?? '',
                    style: AppTypography.support.copyWith(
                      color: AppColors.rejected,
                    ),
                  )
                : null,
            child: Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 1),
              child: Text(
                selectedDate == null
                    ? 'DD-MM-YYYY'
                    : StudentEntry.dobFormat.format(selectedDate!),
                style: selectedDate == null
                    ? AppTypography.placeholder
                    : AppTypography.input,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    FormFieldState<DateTime> state,
  ) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime(now.year - 10, now.month, now.day),
      firstDate: DateTime(now.year - Validators.maxAgeYears),
      lastDate: now,
      helpText: 'Select date of birth',
      // Operators know the DOB from a register and type it faster than they can
      // scroll a calendar back ten years.
      initialEntryMode: DatePickerEntryMode.calendar,
    );
    if (picked == null) return;
    onDateChanged(picked);
    state.didChange(picked);
  }

  static String? _placeholderFor(StudentField field) => switch (field) {
    StudentField.name => 'Full name as it prints',
    StudentField.fatherName => "Father's full name",
    StudentField.studentClass => 'e.g. 5',
    StudentField.division => 'e.g. A',
    StudentField.rollNumber => 'e.g. 12',
    _ => null,
  };

  static IconData _iconFor(StudentField field) => switch (field) {
    StudentField.name => Icons.person_outline,
    StudentField.fatherName => Icons.family_restroom_outlined,
    StudentField.studentClass => Icons.class_outlined,
    StudentField.division => Icons.grid_view_outlined,
    StudentField.rollNumber => Icons.format_list_numbered,
    StudentField.bloodGroup => Icons.bloodtype_outlined,
    StudentField.mobile => Icons.phone_outlined,
    StudentField.address => Icons.home_outlined,
    _ => Icons.edit_outlined,
  };
}
