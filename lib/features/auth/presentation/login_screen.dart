import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/shared/services/firebase/firebase_bootstrap.dart';
import 'package:flutter_id_card/shared/widgets/app_logo.dart';
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
    final List<String> codes =
        await ref.read(authRepositoryProvider).knownSchoolCodes();
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
      _identifier.text = admin ? '' : (_knownSchools.isEmpty ? '' : _knownSchools.first);
      _password.clear();
    });
    ref.read(authControllerProvider.notifier).clearError();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<SessionUser?> auth = ref.watch(authControllerProvider);
    final bool busy = auth.isLoading;
    final String? errorText = auth.hasError ? _messageFor(auth.error) : null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: 12),
                    const Center(child: AppLogo(size: 84)),
                    const SizedBox(height: 18),
                    Text(
                      'ID entity',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sign in to continue',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    _RoleTabs(
                      isAdmin: _isAdminTab,
                      enabled: !busy,
                      onChanged: _switchTab,
                    ),
                    const SizedBox(height: 20),
                    _identifierField(busy),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      enabled: !busy,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => busy ? null : _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                          tooltip: _obscure ? 'Show password' : 'Hide password',
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (String? v) =>
                          (v == null || v.isEmpty) ? 'Enter your password' : null,
                    ),
                    if (errorText != null) ...<Widget>[
                      const SizedBox(height: 14),
                      _ErrorBanner(message: errorText),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: busy ? null : _submit,
                      child: busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(_isAdminTab ? 'Sign in as Admin' : 'Sign in'),
                    ),
                    if (!FirebaseBootstrap.instance.isReady) ...<Widget>[
                      const SizedBox(height: 18),
                      _BackendUnavailableNotice(
                        detail: FirebaseBootstrap.instance.statusMessage,
                      ),
                    ],
                    if (kDebugMode) ...<Widget>[
                      const SizedBox(height: 12),
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
        ),
      ),
    );
  }

  Widget _identifierField(bool busy) {
    if (_isAdminTab) {
      return TextFormField(
        controller: _identifier,
        enabled: !busy,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(
          labelText: 'Admin Email',
          hintText: 'admin@example.com',
          prefixIcon: Icon(Icons.alternate_email),
        ),
        validator: (String? v) {
          if (v == null || v.trim().isEmpty) return 'Enter your admin email';
          if (!v.contains('@')) return 'Enter a valid email address';
          return null;
        },
      );
    }

    // School tab. Free text so a first-time device can sign in, with an
    // autocomplete of codes that have worked on this device before.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextFormField(
          controller: _identifier,
          enabled: !busy,
          autocorrect: false,
          textCapitalization: TextCapitalization.none,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'School Name / Code',
            hintText: 'e.g. stjohns',
            prefixIcon: const Icon(Icons.school_outlined),
            suffixIcon: _knownSchools.isEmpty
                ? null
                : PopupMenuButton<String>(
                    icon: const Icon(Icons.arrow_drop_down),
                    tooltip: 'Recent schools',
                    onSelected: (String code) => setState(() => _identifier.text = code),
                    itemBuilder: (BuildContext context) => _knownSchools
                        .map(
                          (String code) => PopupMenuItem<String>(
                            value: code,
                            child: Text(code),
                          ),
                        )
                        .toList(),
                  ),
          ),
          validator: (String? v) => (v == null || v.trim().isEmpty)
              ? 'Enter your school name or code'
              : null,
        ),
      ],
    );
  }

  Future<void> _startOfflineSession() async {
    await ref
        .read(authControllerProvider.notifier)
        .startOfflineTestSession(
          schoolId: 'demo-school',
          asAdmin: _isAdminTab,
        );
    if (!mounted) return;
    context.go(_isAdminTab ? '/admin' : '/home');
  }

  String _messageFor(Object? error) {
    if (error is AuthFailure) return error.message;
    return 'Sign-in failed. $error';
  }
}

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
    return SegmentedButton<bool>(
      segments: const <ButtonSegment<bool>>[
        ButtonSegment<bool>(
          value: false,
          label: Text('School'),
          icon: Icon(Icons.school_outlined),
        ),
        ButtonSegment<bool>(
          value: true,
          label: Text('Admin'),
          icon: Icon(Icons.admin_panel_settings_outlined),
        ),
      ],
      selected: <bool>{isAdmin},
      onSelectionChanged:
          enabled ? (Set<bool> s) => onChanged(s.first) : null,
      showSelectedIcon: false,
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer, height: 1.35),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.cloud_off, size: 18, color: Color(0xFFE65100)),
              SizedBox(width: 8),
              Text(
                'Server not configured',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE65100),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Add android/app/google-services.json from your Firebase project, '
            'then restart the app.\n\n$detail',
            style: const TextStyle(fontSize: 12.5, height: 1.4, color: Color(0xFF8D4B00)),
          ),
        ],
      ),
    );
  }
}
