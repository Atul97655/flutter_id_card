import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/shared/services/firebase/firebase_bootstrap.dart';
import 'package:flutter_id_card/shared/theme/app_colors.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/app_shadows.dart';
import 'package:flutter_id_card/shared/theme/app_spacing.dart';
import 'package:flutter_id_card/shared/theme/app_typography.dart';
import 'package:flutter_id_card/shared/widgets/app_logo.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_controls.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_scaffold.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_surface.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Sign-in for both audiences.
///
/// Operators sign in with a school code (remembered on this device after the
/// first success, so it becomes a dropdown); admins sign in with an email. The
/// two are separate tabs because the credential *shape* differs - trying to
/// infer the role from a single field produces confusing error messages.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  static const String routePath = '/login';
  static const String routeName = 'login';

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _identifier = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _isAdminTab = false;
  bool _obscure = true;
  List<String> _knownSchools = const <String>[];

  @override
  void initState() {
    super.initState();
    _loadKnownSchools();
  }

  Future<void> _loadKnownSchools() async {
    final List<String> codes = await ref
        .read(authRepositoryProvider)
        .knownSchoolCodes();
    if (!mounted) return;
    setState(() {
      _knownSchools = codes;
      if (_identifier.text.isEmpty && codes.isNotEmpty) {
        _identifier.text = codes.first;
      }
    });
  }

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final AuthController controller = ref.read(authControllerProvider.notifier);
    final bool ok = _isAdminTab
        ? await controller.signInAsAdmin(
            email: _identifier.text,
            password: _password.text,
          )
        : await controller.signInAsSchool(
            schoolCode: _identifier.text,
            password: _password.text,
          );

    if (!mounted || !ok) return;
    context.go(_isAdminTab ? '/admin' : '/home');
  }

  void _switchTab(bool admin) {
    if (_isAdminTab == admin) return;
    setState(() {
      _isAdminTab = admin;
      _identifier.text = admin
          ? ''
          : (_knownSchools.isEmpty ? '' : _knownSchools.first);
      _password.clear();
    });
    ref.read(authControllerProvider.notifier).clearError();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SessionUser?> auth = ref.watch(authControllerProvider);
    final bool busy = auth.isLoading;
    final String? errorText = auth.hasError ? _messageFor(auth.error) : null;

    return GlassScaffold(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const FadeSlideIn(offset: 18, child: Center(child: _Mark())),
                const SizedBox(height: AppSpacing.lg),
                FadeSlideIn(
                  index: 1,
                  child: Text(
                    'ID entity',
                    textAlign: TextAlign.center,
                    style: AppTypography.display.copyWith(fontSize: 30),
                  ),
                ),
                const SizedBox(height: 4),
                const FadeSlideIn(
                  index: 2,
                  child: Text(
                    'School ID cards, start to finish',
                    textAlign: TextAlign.center,
                    style: AppTypography.displaySub,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Everything you type sits in one panel, so the form reads as
                // a single object rather than a stack of floating boxes.
                FadeSlideIn(
                  index: 3,
                  child: GlassSurface(
                    radius: AppRadius.panelR,
                    fill: AppColors.glassFillStrong,
                    shadows: AppShadows.lifted,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _RoleTabs(
                            isAdmin: _isAdminTab,
                            enabled: !busy,
                            onChanged: _switchTab,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          // The field swaps shape between the two tabs - an
                          // email box for an admin, a school picker for an
                          // operator. Without a transition the whole form jumps
                          // by the height difference the instant a tab is
                          // tapped.
                          SmoothSwitcher(
                            child: KeyedSubtree(
                              key: ValueKey<bool>(_isAdminTab),
                              child: _identifierField(busy),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          GlassTextField(
                            label: 'Password',
                            icon: Icons.lock_outline,
                            controller: _password,
                            obscureText: _obscure,
                            enabled: !busy,
                            placeholder: 'Your password',
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => busy ? null : _submit(),
                            trailing: _EyeToggle(
                              obscured: _obscure,
                              onTap: () => setState(() => _obscure = !_obscure),
                            ),
                            validator: (String? v) => (v == null || v.isEmpty)
                                ? 'Enter your password'
                                : null,
                          ),
                          // A sign-in error appearing with no transition reads
                          // as a layout glitch; sliding it in reads as an
                          // answer.
                          SmoothSwitcher(
                            child: errorText == null
                                ? const SizedBox(width: double.infinity)
                                : Padding(
                                    key: ValueKey<String>(errorText),
                                    padding: const EdgeInsets.only(
                                      top: AppSpacing.md,
                                    ),
                                    child: _ErrorBanner(message: errorText),
                                  ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          GlassButton(
                            label: busy
                                ? 'Signing in...'
                                : (_isAdminTab
                                      ? 'Sign in as Admin'
                                      : 'Sign in'),
                            icon: Icons.login_rounded,
                            trailingIcon: busy ? null : Icons.arrow_forward,
                            busy: busy,
                            onPressed: busy ? null : _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (!FirebaseBootstrap.instance.isReady) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  _BackendUnavailableNotice(
                    detail: FirebaseBootstrap.instance.statusMessage,
                  ),
                ],
                if (kDebugMode) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  TextButton.icon(
                    onPressed: busy ? null : _startOfflineSession,
                    icon: const Icon(Icons.science_outlined, size: 18),
                    label: const Text('Debug: continue without Firebase'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _identifierField(bool busy) {
    if (_isAdminTab) {
      return GlassTextField(
        label: 'Admin Email',
        icon: Icons.alternate_email,
        controller: _identifier,
        enabled: !busy,
        placeholder: 'admin@example.com',
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        validator: (String? v) {
          if (v == null || v.trim().isEmpty) return 'Enter your admin email';
          if (!v.contains('@')) return 'Enter a valid email address';
          return null;
        },
      );
    }

    // School tab. Free text so a first-time device can sign in, with a menu of
    // codes that have worked on this device before.
    return GlassTextField(
      label: 'School Name / Code',
      icon: Icons.school_outlined,
      controller: _identifier,
      enabled: !busy,
      placeholder: 'e.g. stjohns',
      textInputAction: TextInputAction.next,
      trailing: _knownSchools.isEmpty
          ? null
          : PopupMenuButton<String>(
              icon: const Icon(
                Icons.expand_more,
                size: 20,
                color: AppColors.inkMuted,
              ),
              tooltip: 'Recent schools',
              onSelected: (String code) =>
                  setState(() => _identifier.text = code),
              itemBuilder: (BuildContext context) => _knownSchools
                  .map(
                    (String code) =>
                        PopupMenuItem<String>(value: code, child: Text(code)),
                  )
                  .toList(),
            ),
      validator: (String? v) => (v == null || v.trim().isEmpty)
          ? 'Enter your school name or code'
          : null,
    );
  }

  Future<void> _startOfflineSession() async {
    await ref
        .read(authControllerProvider.notifier)
        .startOfflineTestSession(schoolId: 'demo-school', asAdmin: _isAdminTab);
    if (!mounted) return;
    context.go(_isAdminTab ? '/admin' : '/home');
  }

  String _messageFor(Object? error) {
    if (error is AuthFailure) return error.message;
    return 'Sign-in failed. $error';
  }
}

/// The logo on a soft gradient disc, so it has something to sit on.
class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      height: 108,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.glassFillStrong,
        border: Border.all(color: AppColors.glassBorder, width: 1.4),
        boxShadow: AppShadows.lifted,
      ),
      child: const Center(child: AppLogo(size: 68)),
    );
  }
}

/// The School / Admin switch.
///
/// A glass pill with a sliding indicator rather than a SegmentedButton: the
/// Material segmented control draws its own outline and fill, which on a
/// translucent panel reads as a second, competing surface.
class _RoleTabs extends StatelessWidget {
  const _RoleTabs({
    required this.isAdmin,
    required this.enabled,
    required this.onChanged,
  });

  final bool isAdmin;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      // 56, not 48. At 48 the two tabs were 40pt tall next to 72pt input
      // rows below them, which read as a strip of text rather than as the
      // control that decides what the rest of the form means.
      height: 56,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.royal.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _Tab(
              label: 'School',
              icon: Icons.school_outlined,
              selected: !isAdmin,
              onTap: enabled ? () => onChanged(false) : null,
            ),
          ),
          Expanded(
            child: _Tab(
              label: 'Admin',
              icon: Icons.admin_panel_settings_outlined,
              selected: isAdmin,
              onTap: enabled ? () => onChanged(true) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.decelerate,
        decoration: BoxDecoration(
          color: selected ? AppColors.card : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: selected ? AppShadows.subtle : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              size: 19,
              color: selected ? AppColors.royal : AppColors.inkMuted,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: AppTypography.badge.copyWith(
                fontSize: 14.5,
                color: selected ? AppColors.royal : AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EyeToggle extends StatelessWidget {
  const _EyeToggle({required this.obscured, required this.onTap});

  final bool obscured;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: obscured ? 'Show password' : 'Hide password',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(
            obscured ? Icons.visibility_off : Icons.visibility,
            size: 19,
            color: AppColors.inkMuted,
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: AppRadius.fieldR,
      fill: AppColors.rejectedTint.withValues(alpha: 0.92),
      borderColor: AppColors.rejected.withValues(alpha: 0.26),
      shadows: const <BoxShadow>[],
      sheen: false,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline, color: AppColors.rejected, size: 19),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.body.copyWith(
                color: AppColors.rejected,
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackendUnavailableNotice extends StatelessWidget {
  const _BackendUnavailableNotice({required this.detail});

  final String detail;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: AppRadius.fieldR,
      fill: AppColors.pendingTint.withValues(alpha: 0.92),
      borderColor: AppColors.pending.withValues(alpha: 0.3),
      shadows: const <BoxShadow>[],
      sheen: false,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.cloud_off, size: 18, color: AppColors.pending),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Server not configured',
                style: AppTypography.section.copyWith(
                  color: AppColors.pending,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Add android/app/google-services.json from your Firebase project, '
            'then restart the app.\n\n$detail',
            style: AppTypography.support.copyWith(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.inkBody,
            ),
          ),
        ],
      ),
    );
  }
}
