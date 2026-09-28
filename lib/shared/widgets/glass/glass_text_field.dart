import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_id_card/shared/theme/app_colors.dart';
import 'package:flutter_id_card/shared/theme/app_spacing.dart';
import 'package:flutter_id_card/shared/theme/app_typography.dart';

/// A form row in the reference design: icon tile, label, and the value or its
/// placeholder underneath.
///
/// Note what this is NOT: a `TextField` with a themed decoration. The
/// reference puts the label above the input inside the same surface, with the
/// icon tile beside both - a layout `InputDecoration` cannot produce without
/// fighting it. So the row is laid out directly and the `TextField` is
/// stripped bare and dropped into place.
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

  @override
  Widget build(BuildContext context) {
    final bool locked = widget.readOnlyReason != null;
    final bool hasError = _error != null;

    // The border is the only thing that moves on focus. A field that also
    // grows, glows and changes colour reads as an alert rather than as a
    // cursor landing in a box.
    final Color border = hasError
        ? AppColors.rejected.withValues(alpha: 0.55)
        : _focused
        ? AppColors.royal.withValues(alpha: 0.55)
        : AppColors.glassBorder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: locked ? const Color(0x38FFFFFF) : AppColors.glassFillStrong,
            borderRadius: AppRadius.fieldR,
            border: Border.all(color: border, width: _focused ? 1.6 : 1),
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
                  widget.icon,
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
                    Text(widget.label, style: AppTypography.label),
                    const SizedBox(height: 1),
                    TextFormField(
                      controller: widget.controller,
                      focusNode: _focus,
                      enabled: widget.enabled && !locked,
                      readOnly: locked,
                      autofocus: widget.autofocus,
                      obscureText: widget.obscureText,
                      keyboardType: widget.keyboardType,
                      textCapitalization: widget.textCapitalization,
                      inputFormatters: widget.inputFormatters,
                      maxLines: widget.maxLines,
                      minLines: widget.minLines,
                      textInputAction: widget.textInputAction,
                      onFieldSubmitted: widget.onSubmitted,
                      onTap: widget.onTap,
                      style: AppTypography.input,
                      cursorColor: AppColors.royal,
                      // The error is caught and rendered underneath the whole
                      // row instead, so a long message does not shove the
                      // icon tile out of alignment with the row above it.
                      validator: (String? v) {
                        final String? result = widget.validator?.call(v);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && result != _error) {
                            setState(() => _error = result);
                          }
                        });
                        return result;
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        hintText: widget.placeholder,
                        hintStyle: AppTypography.placeholder,
                        // Suppressed: rendered below the row instead.
                        errorStyle: const TextStyle(height: 0, fontSize: 0),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.trailing != null) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                widget.trailing!,
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
        if (hasError || locked)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              5,
              AppSpacing.lg,
              0,
            ),
            child: Text(
              hasError ? _error! : widget.readOnlyReason!,
              style: AppTypography.support.copyWith(
                color: hasError ? AppColors.rejected : AppColors.inkMuted,
              ),
            ),
          ),
      ],
    );
  }
}
