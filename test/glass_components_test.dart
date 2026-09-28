import 'package:flutter/material.dart';
import 'package:flutter_id_card/shared/theme/app_colors.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_bottom_nav.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_controls.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_scaffold.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_surface.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_text_field.dart';
import 'package:flutter_test/flutter_test.dart';

/// The design system the whole redesign is built on.
///
/// It had no tests, which is how a 57-pixel overflow in a popup menu reached
/// a commit and was caught by an unrelated admin-screen test rather than by
/// me. Every widget here is used on a dozen screens, so a layout bug in one
/// of them is a layout bug everywhere at once - and the machines this runs on
/// are cheap Android tablets and phones at the narrow end of the range.
///
/// Note on what these assert: Flutter throws on a RenderFlex overflow in
/// debug, and `pumpWidget` surfaces that as a test failure. So "pumps at 320
/// logical pixels without throwing" is a real assertion about layout, not a
/// smoke test that only proves the constructor runs.
void main() {
  /// The narrowest phone anyone is realistically using, and narrower than any
  /// of the reference designs were drawn at.
  const Size narrow = Size(320, 640);

  Future<void> pumpAt(
    WidgetTester tester,
    Widget child, {
    Size size = narrow,

    /// False for anything holding a CircularProgressIndicator: that animates
    /// forever, so pumpAndSettle would time out rather than telling us
    /// anything about layout.
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: child));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  group('GlassTextField', () {
    testWidgets('lays out with a long label and a long validation message', (
      WidgetTester tester,
    ) async {
      final TextEditingController c = TextEditingController();
      addTearDown(c.dispose);
      final GlobalKey<FormState> form = GlobalKey<FormState>();

      await pumpAt(
        tester,
        Scaffold(
          body: Form(
            key: form,
            child: GlassTextField(
              label: 'Permanent residential address as it prints',
              icon: Icons.home_outlined,
              controller: c,
              validator: (String? v) =>
                  'This field is required, and the message explaining why is '
                  'deliberately long enough to wrap onto several lines.',
            ),
          ),
        ),
      );

      form.currentState!.validate();
      await tester.pumpAndSettle();

      // Twice on purpose: the TextFormField keeps its own error so the Form
      // still knows validation failed, suppressed to zero height, and the
      // visible copy is rendered below the whole row - which is what keeps
      // the icon tile aligned with the rows above and below it.
      expect(find.textContaining('deliberately long enough'), findsNWidgets(2));
    });

    testWidgets('the validation message is only announced once', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final TextEditingController c = TextEditingController();
      addTearDown(c.dispose);
      final GlobalKey<FormState> form = GlobalKey<FormState>();

      await pumpAt(
        tester,
        Scaffold(
          body: Form(
            key: form,
            child: GlassTextField(
              label: 'Mobile',
              icon: Icons.phone_outlined,
              controller: c,
              validator: (String? _) => 'Enter a ten digit number',
            ),
          ),
        ),
      );

      form.currentState!.validate();
      await tester.pumpAndSettle();

      // The visible copy is excluded from semantics: the field already
      // announces its own error, and without that exclusion a screen reader
      // reads the message twice.
      // Exactly one. Without the ExcludeSemantics around the footer copy this
      // finds two, which is a screen reader saying the same thing twice - so
      // this assertion genuinely pins the fix rather than passing either way.
      expect(
        find.bySemanticsLabel('Enter a ten digit number'),
        findsOneWidget,
        reason: 'the footer copy must not be its own semantics node',
      );
      expect(find.text('Enter a ten digit number'), findsNWidgets(2));

      // Disposed in the body, not a tearDown: the framework checks for live
      // handles before tearDowns run.
      handle.dispose();
    });

    testWidgets('the counter tracks the controller and caps at the limit', (
      WidgetTester tester,
    ) async {
      final TextEditingController c = TextEditingController();
      addTearDown(c.dispose);

      await pumpAt(
        tester,
        Scaffold(
          body: GlassTextField(
            label: 'Address',
            icon: Icons.home_outlined,
            controller: c,
            maxLength: 10,
            showCounter: true,
            helperText: 'Prints on up to 2 lines',
          ),
        ),
      );

      expect(find.text('0/10'), findsOneWidget);
      expect(find.text('Prints on up to 2 lines'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'ABCDE');
      await tester.pump();
      expect(find.text('5/10'), findsOneWidget);

      // The limit is enforced by a formatter, so typing past it is refused
      // rather than accepted and rejected later.
      await tester.enterText(find.byType(TextField), 'ABCDEFGHIJKLMNOP');
      await tester.pump();
      expect(c.text.length, 10);
      expect(find.text('10/10'), findsOneWidget);
    });

    testWidgets('a locked field explains itself and takes no input', (
      WidgetTester tester,
    ) async {
      final TextEditingController c = TextEditingController(text: '10');
      addTearDown(c.dispose);

      await pumpAt(
        tester,
        Scaffold(
          body: GlassTextField(
            label: 'Class',
            icon: Icons.class_outlined,
            controller: c,
            readOnlyReason: 'Set by your class assignment',
          ),
        ),
      );

      expect(find.text('Set by your class assignment'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).enabled,
        isFalse,
        reason: 'a teacher must not be able to file a student out of section',
      );
    });
  });

  group('GlassButton', () {
    testWidgets('a long label ellipsises rather than overflowing', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: GlassButton(
              label: 'Save this student and preview the printed card now',
              icon: Icons.visibility_outlined,
              trailingIcon: Icons.arrow_forward,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byType(GlassButton), findsOneWidget);
    });

    testWidgets('busy hides the label affordance and blocks the tap', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await pumpAt(
        tester,
        Scaffold(
          body: GlassButton(
            label: 'Saving...',
            busy: true,
            onPressed: () => taps++,
          ),
        ),
        settle: false,
      );

      await tester.tap(find.byType(GlassButton));
      await tester.pump();

      expect(taps, 0, reason: 'a double-tap must not submit twice');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('a null callback disables it', (WidgetTester tester) async {
      await pumpAt(
        tester,
        const Scaffold(
          body: GlassButton(label: 'Unavailable', onPressed: null),
        ),
      );

      // Tapping a disabled button must not throw.
      await tester.tap(find.byType(GlassButton));
      await tester.pump();
      expect(find.text('Unavailable'), findsOneWidget);
    });
  });

  group('GlassBottomNav', () {
    testWidgets('three destinations and a three-digit badge fit at 320px', (
      WidgetTester tester,
    ) async {
      int? selected;

      await pumpAt(
        tester,
        Scaffold(
          bottomNavigationBar: GlassBottomNav(
            currentIndex: 0,
            onSelect: (int i) => selected = i,
            items: const <GlassNavItem>[
              GlassNavItem(
                icon: Icons.badge_outlined,
                activeIcon: Icons.badge,
                label: 'ID Cards',
              ),
              GlassNavItem(
                icon: Icons.forum_outlined,
                activeIcon: Icons.forum,
                label: 'Chats',
                badge: 1234,
              ),
              GlassNavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                badge: 7,
              ),
            ],
          ),
        ),
      );

      // Capped rather than allowed to widen the pill without limit.
      expect(find.text('99+'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);

      await tester.tap(find.text('Profile'));
      await tester.pump();
      expect(selected, 2);
    });
  });

  group('GlassIconButton', () {
    testWidgets('a null callback is inert and does not throw', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        const Scaffold(
          body: GlassIconButton(icon: Icons.content_copy_outlined, onTap: null),
        ),
      );

      await tester.tap(find.byType(GlassIconButton));
      await tester.pump();
      expect(find.byType(GlassIconButton), findsOneWidget);
    });
  });

  group('GlassSurface', () {
    testWidgets('flat depth builds no BackdropFilter', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        const Scaffold(body: GlassSurface(child: Text('flat'))),
      );

      // The whole performance argument for GlassDepth rests on this: a
      // surface that repeats must not cost a compositor pass per instance.
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('frosted depth builds exactly one BackdropFilter', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        const Scaffold(
          body: GlassSurface(depth: GlassDepth.frosted, child: Text('frosted')),
        ),
      );

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('the clip sits outside the blur', (WidgetTester tester) async {
      await pumpAt(
        tester,
        const Scaffold(
          body: GlassSurface(depth: GlassDepth.deep, child: Text('deep')),
        ),
      );

      // Inverted, a BackdropFilter with no clip above it blurs the entire
      // layer behind it rather than the area under this widget - which shows
      // up as the whole screen going soft the moment one card appears.
      final Finder clip = find.ancestor(
        of: find.byType(BackdropFilter),
        matching: find.byType(ClipRRect),
      );
      expect(clip, findsWidgets);
    });

    testWidgets('onTap fires', (WidgetTester tester) async {
      int taps = 0;
      await pumpAt(
        tester,
        Scaffold(
          body: GlassSurface(onTap: () => taps++, child: const Text('tap me')),
        ),
      );

      await tester.tap(find.text('tap me'));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('GlassScaffold', () {
    testWidgets('paints a backdrop and keeps the header out of the scroll', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        GlassScaffold(
          header: const GlassHeader(
            title: 'A rather long screen title that has to be truncated',
            subtitle: 'And a supporting line underneath it',
          ),
          child: ListView(
            children: <Widget>[for (int i = 0; i < 30; i++) Text('row $i')],
          ),
        ),
      );

      expect(find.textContaining('A rather long screen title'), findsOneWidget);
      expect(find.text('row 0'), findsOneWidget);
    });

    testWidgets('every backdrop builds', (WidgetTester tester) async {
      for (final GlassBackdrop b in GlassBackdrop.values) {
        await pumpAt(tester, GlassScaffold(backdrop: b, child: Text(b.name)));
        expect(find.text(b.name), findsOneWidget, reason: b.name);
      }
    });
  });

  group('GlassStat and GlassStatusBadge', () {
    testWidgets('three stats and four badges fit at 320px', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        const Scaffold(
          body: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: GlassStat(
                      icon: Icons.schedule,
                      value: '1234',
                      label: 'Pending review',
                      tint: AppColors.pending,
                    ),
                  ),
                  Expanded(
                    child: GlassStat(
                      icon: Icons.verified_outlined,
                      value: '99',
                      label: 'Approved',
                      tint: AppColors.approved,
                    ),
                  ),
                  Expanded(
                    child: GlassStat(
                      icon: Icons.print_outlined,
                      value: '0',
                      label: 'Printed',
                      tint: AppColors.printed,
                    ),
                  ),
                ],
              ),
              Wrap(
                children: <Widget>[
                  GlassStatusBadge(
                    label: 'PENDING',
                    color: AppColors.pending,
                    tint: AppColors.pendingTint,
                    icon: Icons.schedule,
                  ),
                  GlassStatusBadge(
                    label: 'APPROVED',
                    color: AppColors.approved,
                    tint: AppColors.approvedTint,
                  ),
                  GlassStatusBadge(
                    label: 'RETURNED',
                    color: AppColors.rejected,
                    tint: AppColors.rejectedTint,
                    compact: true,
                  ),
                  GlassStatusBadge(
                    label: 'PRINTED',
                    color: AppColors.printed,
                    tint: AppColors.printedTint,
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      expect(find.text('1234'), findsOneWidget);
      expect(find.text('RETURNED'), findsOneWidget);
    });
  });

  group('GlassListRow', () {
    testWidgets('a long title and subtitle ellipsise at 320px', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        Scaffold(
          body: Material(
            child: GlassListRow(
              icon: Icons.sync_outlined,
              title: 'A title long enough that it cannot possibly fit',
              subtitle:
                  'And a subtitle that is also far too long for a narrow '
                  'phone, wrapping to two lines before it gives up.',
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byType(GlassListRow), findsOneWidget);
    });
  });
}
