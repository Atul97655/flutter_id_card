import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/student_field.dart';
import 'package:flutter_id_card/shared/utils/input_formatters.dart';
import 'package:flutter_id_card/shared/utils/validators.dart';

/// Renders the correct input for a [StudentField].
///
/// The form screen walks the school's enabled-field list and drops one of these
/// in per field, so adding a field to the system means adding an enum value and
/// a case here - never editing a hand-built form layout.
class DynamicFormField extends StatelessWidget {
  const DynamicFormField({
    super.key,
    required this.field,
    required this.controller,
    required this.selectedDate,
    required this.onDateChanged,
    this.autofocus = false,
  });

  final StudentField field;

  /// Backs text-like inputs. For [FieldKind.date] and [FieldKind.bloodGroup]
  /// it still holds the canonical string value so the whole form can be read
  /// back uniformly.
  final TextEditingController controller;

  final DateTime? selectedDate;
  final ValueChanged<DateTime?> onDateChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return switch (field.kind) {
      FieldKind.text => _text(context),
      FieldKind.multiline => _multiline(context),
      FieldKind.mobile => _mobile(context),
      FieldKind.bloodGroup => _bloodGroup(context),
      FieldKind.date => _date(context),
      // The photo is captured on its own screen, not inline in the form.
      FieldKind.photo => const SizedBox.shrink(),
    };
  }

  List<TextInputFormatter> get _textFormatters => <TextInputFormatter>[
        if (field.forceUppercase) const UpperCaseTextInputFormatter(),
        const CollapseWhitespaceFormatter(),
      ];

  Widget _text(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: _textFormatters,
      maxLength: Validators.nameMaxLength,
      decoration: InputDecoration(
        labelText: field.formLabel,
        prefixIcon: Icon(_iconFor(field)),
        // The character counter is noise on short fields; only the address
        // needs it, and that has its own branch.
        counterText: '',
      ),
      validator: (String? v) =>
          Validators.forField(field, v, isRequired: true),
    );
  }

  Widget _multiline(BuildContext context) {
    return TextFormField(
      controller: controller,
      minLines: 2,
      maxLines: 3,
      textInputAction: TextInputAction.newline,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: _textFormatters,
      maxLength: Validators.addressMaxLength,
      decoration: InputDecoration(
        labelText: field.formLabel,
        prefixIcon: const Icon(Icons.home_outlined),
        helperText: 'Prints on up to 2 lines',
      ),
      validator: Validators.address,
    );
  }

  Widget _mobile(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      inputFormatters: const <TextInputFormatter>[
        DigitsOnlyFormatter(maxLength: Validators.mobileLength),
      ],
      decoration: InputDecoration(
        labelText: field.formLabel,
        prefixIcon: const Icon(Icons.phone_outlined),
        counterText: '',
      ),
      validator: Validators.mobile,
    );
  }

  Widget _bloodGroup(BuildContext context) {
    final String current = controller.text.trim();
    return DropdownButtonFormField<String>(
      initialValue: kBloodGroups.contains(current) ? current : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: field.formLabel,
        prefixIcon: const Icon(Icons.bloodtype_outlined),
      ),
      items: kBloodGroups
          .map(
            (String g) => DropdownMenuItem<String>(
              value: g,
              child: Text(g),
            ),
          )
          .toList(),
      onChanged: (String? v) => controller.text = v ?? '',
      validator: Validators.bloodGroup,
    );
  }

  Widget _date(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? error = Validators.dateOfBirth(selectedDate);

    return FormField<DateTime>(
      initialValue: selectedDate,
      validator: (DateTime? v) => Validators.dateOfBirth(v ?? selectedDate),
      builder: (FormFieldState<DateTime> state) {
        return InkWell(
          onTap: () => _pickDate(context, state),
          borderRadius: BorderRadius.circular(10),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: field.formLabel,
              prefixIcon: const Icon(Icons.cake_outlined),
              // Show the live validator result, not just the post-submit one,
              // so a mistyped year is caught before the operator moves on.
              errorText: state.hasError ? (state.errorText ?? error) : null,
              suffixIcon: const Icon(Icons.calendar_month_outlined),
            ),
            child: Text(
              selectedDate == null
                  ? 'DD-MM-YYYY'
                  : StudentEntry.dobFormat.format(selectedDate!),
              style: TextStyle(
                fontSize: 16,
                color: selectedDate == null
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickDate(BuildContext context, FormFieldState<DateTime> state) async {
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

  static IconData _iconFor(StudentField field) => switch (field) {
        StudentField.name => Icons.person_outline,
        StudentField.fatherName => Icons.family_restroom_outlined,
        StudentField.studentClass => Icons.class_outlined,
        StudentField.division => Icons.grid_view_outlined,
        _ => Icons.edit_outlined,
      };
}
