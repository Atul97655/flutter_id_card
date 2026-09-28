import 'package:flutter/material.dart';
import 'package:flutter_id_card/shared/theme/app_spacing.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_scaffold.dart';

/// The chrome every admin screen wears.
///
/// The admin section is by far the largest part of the app - ten screens, most
/// of them long - and the thing that made them look like ten different tools
/// was that each one built its own `Scaffold` and `AppBar`. This exists so
/// that the page background, the title block and the back button are decided
/// in one file.
///
/// It is deliberately thin. It does not touch the body: the admin screens are
/// built out of Material `Card`s and `ListTile`s, which the theme has already
/// been taught to draw as glass, so the pages pick up the redesign without
/// thousands of lines being rewritten by hand.
class AdminPage extends StatelessWidget {
  const AdminPage({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const <Widget>[],
    this.onBack,
    this.bottomBar,
    this.floatingActionButton,
    this.backdrop = GlassBackdrop.blue,
    this.tabBar,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;

  /// Null means "no back button" - a root of a navigation branch.
  final VoidCallback? onBack;

  final Widget? bottomBar;
  final Widget? floatingActionButton;
  final GlassBackdrop backdrop;

  /// A `TabBar`, drawn under the title rather than inside a bar.
  final Widget? tabBar;

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      backdrop: backdrop,
      bottomBar: bottomBar,
      floatingActionButton: floatingActionButton,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          GlassHeader(
            title: title,
            subtitle: subtitle,
            onBack: onBack,
            actions: actions,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.sm,
              AppSpacing.gutter,
              tabBar == null ? AppSpacing.md : AppSpacing.xs,
            ),
          ),
          if (tabBar != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: tabBar,
            ),
        ],
      ),
      child: child,
    );
  }
}
