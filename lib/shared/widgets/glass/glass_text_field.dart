import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_id_card/shared/theme/app_colors.dart';
import 'package:flutter_id_card/shared/theme/app_spacing.dart';
import 'package:flutter_id_card/shared/theme/app_typography.dart';

/// The chrome of a form row in the reference design: icon tile on the left,
/// label above the input, both inside one translucent rounded surface.
///
/// Extracted from [GlassTextField] because a dropdown and a date picker need
/// exactly the same frame around a completely different input. Copying the
/// frame into each of them is how a form ends up with three fields that are
/// each two pixels different from the others.
class GlassFieldShell extends StatelessWidget {
  const GlassFieldShell({
    super.key,
    required this.label,
    required this.icon,
    required this.child,
    this.locked = false,
    this.focused = false,
    this.hasError = false,
    this.trailing,
    this.footer,
  });

  final String label;
  final IconData icon;

  /// The bare input. Expected to carry no border and no fill of its own.
  final Widget child;

  final bool locked;
  final bool focused;
  final bool hasError;

  final Widget? trailing;

  /// Rendered under the whole surface - helper text, a counter, an error.
  ///
  /// Below rather than inside, so a two-line validation message cannot shove
  /// the icon tile out of alignment with the row above it.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    // The border is the only thing that moves on focus. A field that also
    // grows, glows and changes colour reads as an alert rather than as a
    // cursor landing in a box.
    final Color border = hasError
        ? AppColors.rejected.withValues(alpha: 0.55)
        : focused
        ? AppColors.royal.withValues(alpha: 0.55)
        : AppColors.glassBorder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: locked ? const Color(0x38FFFFFF) : AppColors.glassFillStrong,
            borderRadius: AppRadius.fieldR,
            border: Border.all(color: border, width: focused ? 1.6 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.royal.withValues(
                    alpha: locked ? 0.07 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: locked ? AppColors.inkMuted : AppColors.royal,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(label, style: AppTypography.label),
                    const SizedBox(height: 1),
                    child,
                  ],
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
              if (locked) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  Icons.lock_outline,
                  size: 17,
                  color: AppColors.inkMuted,
                ),
              ],
            ],
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              5,
              AppSpacing.lg,
              0,
            ),
            child: footer,
          ),
      ],
    );
  }
}

/// The stripped-bare input decoration every glass field uses.
///
/// Public so the dropdown and the date field can share it: the point of the
/// shell is that the surface draws the border, so every input inside one has
/// to be talked out of drawing its own.
InputDecoration glassInputDecoration({
  String? hintText,
  bool suppressError = true,
}) {
  return InputDecoration(
    isDense: true,
    filled: false,
    contentPadding: EdgeInsets.zero,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    hintText: hintText,
    hintStyle: AppTypography.placeholder,
    counterText: '',
    errorStyle: suppressError
        ? const TextStyle(height: 0, fontSize: 0)
        : AppTypography.support.copyWith(color: AppColors.rejected),
  );
}

/// A text field wearing the glass form-row chrome.
///
/// Note what this is NOT: a `TextField` with a themed decoration. The
/// reference puts the label above the input inside the same surface, with the
/// icon tile beside both - a layout `InputDecoration` cannot produce without
/// fighting it. So the row is laid out by [GlassFieldShell] and the
/// `TextField` is stripped bare and dropped into place.
///
/// Everything that made the old field work is kept and simply passed
/// through: the validator, the formatters, the keyboard type, the controller.
/// The point of this widget is the arrangement, not the behaviour.
class GlassTextField extends StatefulWidget {
  const GlassTextField({
    super.key,
    required this.label,
    required this.icon,
    required this.controller,
    this.placeholder,
    this.validator,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.showCounter = false,
    this.helperText,
    this.obscureText = false,
    this.autofocus = false,
    this.enabled = true,
    this.readOnlyReason,
    this.onTap,
    this.trailing,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String? placeholder;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final int? minLines;

  /// Enforced with a formatter rather than `TextField.maxLength`, so the
  /// built-in counter never appears where the design does not want one.
  final int? maxLength;

  /// Draws `used/limit` under the field. Requires [maxLength].
  final bool showCounter;

  final String? helperText;
  final bool obscureText;
  final bool autofocus;
  final bool enabled;

  /// When set the field is filled in, locked, and this explains why.
  final String? readOnlyReason;

  final VoidCallback? onTap;
  final Widget? trailing;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<GlassTextField> createState() => _GlassTextFieldState();
}

class _GlassTextFieldState extends State<GlassTextField> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!mounted) return;
      setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  List<TextInputFormatter>? get _formatters {
    final int? limit = widget.maxLength;
    if (limit == null) return widget.inputFormatters;
    return <TextInputFormatter>[
      ...?widget.inputFormatters,
      LengthLimitingTextInputFormatter(limit),
    ];
  }

  Widget? _footer() {
    final bool locked = widget.readOnlyReason != null;
    if (_error != null) {
      return Text(
        _error!,
        style: AppTypography.support.copyWith(color: AppColors.rejected),
      );
    }
    if (locked) {
      return Text(
        widget.readOnlyReason!,
        style: AppTypography.support.copyWith(color: AppColors.inkMuted),
      );
    }

    final bool counter = widget.showCounter && widget.maxLength != null;
    if (widget.helperText == null && !counter) return null;

    return Row(
      children: <Widget>[
        if (widget.helperText != null)
          Expanded(
            child: Text(
              widget.helperText!,
              style: AppTypography.support.copyWith(color: AppColors.inkMuted),
            ),
          )
        else
          const Spacer(),
        if (counter)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            builder: (BuildContext context, TextEditingValue value, _) => Text(
              '${value.text.length}/${widget.maxLength}',
              style: AppTypography.support.copyWith(
                color: value.text.length >= widget.maxLength!
                    ? AppColors.pending
                    : AppColors.inkMuted,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool locked = widget.readOnlyReason != null;

    return GlassFieldShell(
      label: widget.label,
      icon: widget.icon,
      locked: locked,
      focused: _focused,
      hasError: _error != null,
      trailing: widget.trailing,
      footer: _footer(),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focus,
        enabled: widget.enabled && !locked,
        readOnly: locked,
        autofocus: widget.autofocus,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textCapitalization: widget.textCapitalization,
        inputFormatters: _formatters,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: widget.onSubmitted,
        onTap: widget.onTap,
        style: AppTypography.input,
        cursorColor: AppColors.royal,
        // The error is caught and rendered underneath the whole row instead,
        // so a long message does not shove the icon tile out of alignment
        // with the row above it.
        validator: (String? v) {
          final String? result = widget.validator?.call(v);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && result != _error) {
              setState(() => _error = result);
            }
          });
          return result;
        },
        decoration: glassInputDecoration(hintText: widget.placeholder),
      ),
    );
  }
}
