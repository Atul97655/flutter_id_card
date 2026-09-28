import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/onboarding/application/join_providers.dart';
import 'package:flutter_id_card/features/onboarding/domain/join_models.dart';
import 'package:flutter_id_card/features/onboarding/presentation/awaiting_assignment_screen.dart';
import 'package:flutter_id_card/shared/theme/app_colors.dart';
import 'package:flutter_id_card/shared/theme/app_shadows.dart';
import 'package:flutter_id_card/shared/theme/app_spacing.dart';
import 'package:flutter_id_card/shared/theme/app_typography.dart';
import 'package:flutter_id_card/shared/theme/join_theme.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_controls.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_surface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Screen 16 — pointing the camera at the staffroom wall, and screen 17, the
/// sheet that asks the teacher to confirm what it found.
///
/// The two are one screen because they are one moment: the scan resolves and
/// the answer slides up over the still-running camera. Pushing a separate
/// route would mean a teacher who scanned the wrong poster has to go back and
/// restart the camera to try again.
class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  static const String routePath = '/join/scan';
  static const String routeName = 'join-scan';

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
  );

  /// Set while a scan is being resolved, so the stream of detections from a
  /// steady camera does not fire a dozen lookups for the same code.
  bool _busy = false;

  /// The resolved school, once there is one. Non-null means the confirm sheet
  /// is up.
  SchoolInvitation? _invitation;

  String? _error;
  bool _joining = false;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || _invitation != null) return;

    final String? raw = capture.barcodes
        .map((Barcode b) => b.rawValue)
        .firstWhere(
          (String? v) => v != null && v.isNotEmpty,
          orElse: () => null,
        );
    if (raw == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final Object result = await ref.read(joinRepositoryProvider).resolve(raw);
    if (!mounted) return;

    if (result is SchoolInvitation) {
      // Stop the camera while the sheet is up. Leaving it running would keep
      // firing detections behind the sheet and drains the battery of a phone
      // somebody is holding up at a wall.
      await _controller.stop();
      if (!mounted) return;
      setState(() {
        _invitation = result;
        _busy = false;
      });
      return;
    }

    setState(() {
      _error = (result as ScanFailure).message;
      _busy = false;
    });
  }

  Future<void> _confirmJoin() async {
    final SchoolInvitation? invite = _invitation;
    final SessionUser? session = ref.read(currentSessionProvider);
    if (invite == null || session == null) return;

    setState(() => _joining = true);

    final bool ok = await ref
        .read(joinRepositoryProvider)
        .requestJoin(
          invitation: invite,
          uid: session.uid,
          displayName: session.displayName,
          email: session.email,
        );

    if (!mounted) return;

    if (!ok) {
      setState(() {
        _joining = false;
        _error =
            'Could not reach the office. Check your connection and try again.';
      });
      return;
    }

    context.pushReplacement(AwaitingAssignmentScreen.routePath);
  }

  Future<void> _dismissSheet() async {
    setState(() {
      _invitation = null;
      _error = null;
    });
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    final SchoolInvitation? invite = _invitation;

    return Scaffold(
      backgroundColor: JoinTheme.scannerBackdrop,
      appBar: AppBar(
        backgroundColor: JoinTheme.scannerBackdrop,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Scan school QR code'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Torch',
            onPressed: () => unawaited(_controller.toggleTorch()),
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: (BarcodeCapture c) => unawaited(_onDetect(c)),
              errorBuilder: (BuildContext c, MobileScannerException e) =>
                  _CameraUnavailable(error: e),
            ),
          ),

          const Positioned.fill(child: IgnorePointer(child: _ScanFrame())),

          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _error != null
                  ? _ScanError(
                      key: const ValueKey<String>('error'),
                      message: _error!,
                      onRetry: () => setState(() => _error = null),
                    )
                  : const Text(
                      key: ValueKey<String>('hint'),
                      'Hold the phone steady over the code your school gave '
                      'you.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 13.5),
                    ),
            ),
          ),

          if (invite != null)
            _ConfirmSheet(
              invitation: invite,
              busy: _joining,
              onJoin: () => unawaited(_confirmJoin()),
              onCancel: () => unawaited(_dismissSheet()),
            ),
        ],
      ),
    );
  }
}

/// The cut-out the teacher aims through.
class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 232,
        height: 232,
        decoration: BoxDecoration(
          border: Border.all(color: JoinTheme.accent, width: 3),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class _ScanError extends StatelessWidget {
  const _ScanError({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // Frosted rather than opaque white: this floats over the live camera
    // preview, and a solid card there reads as the camera having stopped.
    return GlassSurface(
      depth: GlassDepth.frosted,
      radius: AppRadius.fieldR,
      fill: const Color(0xD9FFFFFF),
      shadows: AppShadows.lifted,
      sheen: false,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(fontSize: 13.5, height: 1.45),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Try again',
              style: AppTypography.badge.copyWith(
                fontSize: 13.5,
                color: AppColors.chatDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A camera that will not start is not the teacher's fault, and a blank black
/// rectangle tells them nothing. Naming the likely cause turns it into
/// something they can fix.
class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final bool denied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white54,
              size: 44,
            ),
            const SizedBox(height: 14),
            Text(
              denied
                  ? 'The app needs camera access to read the code. Allow it in '
                        'Settings, then come back to this screen.'
                  : 'The camera could not be started on this device. You can '
                        'still sign in with the details your office gave you.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Screen 17 — "Join this school?"
///
/// The school name is the only thing the app is allowed to know at this point,
/// and showing it is what makes the question answerable. The sheet also says
/// what joining does NOT do, because a teacher who believes scanning granted
/// access will sit on the next screen wondering why nothing works.
class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.invitation,
    required this.busy,
    required this.onJoin,
    required this.onCancel,
  });

  final SchoolInvitation invitation;
  final bool busy;
  final VoidCallback onJoin;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 1, end: 0),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (BuildContext c, double t, Widget? child) =>
            Transform.translate(offset: Offset(0, t * 240), child: child),
        child: GlassSurface(
          // Deep blur: the camera is still running behind this, and the point
          // of the sheet is that the preview recedes while a question is
          // being answered.
          depth: GlassDepth.deep,
          radius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
          fill: const Color(0xF2FFFFFF),
          shadows: AppShadows.floating,
          sheen: false,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.inkMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: <Color>[AppColors.chatAccent, AppColors.chatDeep],
                    ),
                    boxShadow: AppShadows.glow(AppColors.chatDeep),
                  ),
                  child: const Icon(
                    Icons.home_outlined,
                    color: AppColors.onDark,
                    size: 28,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Join this school?',
                  style: AppTypography.display.copyWith(fontSize: 21),
                ),
                const SizedBox(height: 6),
                Text(
                  invitation.schoolName.isEmpty
                      ? invitation.schoolId
                      : invitation.schoolName,
                  textAlign: TextAlign.center,
                  style: AppTypography.section.copyWith(
                    color: AppColors.chatDeep,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Your name goes to this school office. They will assign '
                  'your class and section before you can send anything.',
                  textAlign: TextAlign.center,
                  style: AppTypography.support.copyWith(
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                GlassButton(
                  label: 'Yes, join',
                  icon: Icons.check_rounded,
                  busy: busy,
                  gradient: const LinearGradient(
                    colors: <Color>[AppColors.chatAccent, AppColors.chatDeep],
                  ),
                  onPressed: busy ? null : onJoin,
                ),
                TextButton(
                  onPressed: busy ? null : onCancel,
                  child: Text(
                    'Scan a different code',
                    style: AppTypography.badge.copyWith(
                      fontSize: 13.5,
                      color: AppColors.chatDeep,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
