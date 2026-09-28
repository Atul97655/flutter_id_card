import 'package:flutter/material.dart';
import 'package:flutter_id_card/shared/theme/app_colors.dart';
import 'package:flutter_id_card/shared/theme/app_gradients.dart';
import 'package:flutter_id_card/shared/theme/app_shadows.dart';
import 'package:flutter_id_card/shared/theme/app_spacing.dart';
import 'package:flutter_id_card/shared/theme/app_typography.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_controls.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_scaffold.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_surface.dart';
import 'package:go_router/go_router.dart';

/// Placeholder for a route whose feature lands in a later phase.
///
/// Exists so every navigation path in the app is reachable and testable from
/// day one - a dead button teaches an operator to distrust the app, whereas a
/// screen that says what is coming does not.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    super.key,
    required this.title,
    required this.phase,
    required this.description,
  });

  final String title;
  final String phase;
  final String description;

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      backdrop: GlassBackdrop.calm,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: GlassSurface(
              radius: AppRadius.panelR,
              fill: AppColors.glassFillStrong,
              shadows: AppShadows.card,
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppGradients.statusTint(AppColors.royal),
                    ),
                    child: const Icon(
                      Icons.construction_outlined,
                      size: 36,
                      color: AppColors.royal,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  GlassStatusBadge(
                    label: phase,
                    color: AppColors.violet,
                    tint: AppColors.printedTint,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppTypography.display.copyWith(fontSize: 23),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  GlassButton(
                    label: 'Go back',
                    icon: Icons.arrow_back,
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
