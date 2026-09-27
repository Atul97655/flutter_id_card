/// The attachment tray, and the slot the ID Card takes.
///
/// The design gives ID Card the row a consumer app gives to payments - the
/// one people reach for without reading. What is asserted here is that the
/// row exists, that it is the one that stands out, and that the two rows
/// this product has no use for are visibly present and unusable rather than
/// quietly missing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/messaging/presentation/widgets/attachment_tray.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<AttachmentChoice?> open(WidgetTester tester) async {
    AttachmentChoice? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showAttachmentTray(context);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('offers every row the design shows', (WidgetTester tester) async {
    await open(tester);

    expect(find.text('Document'), findsOneWidget);
    expect(find.text('Photos & videos'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('Contact'), findsOneWidget);
    expect(find.text('ID Card'), findsOneWidget);
  });

  testWidgets('the ID Card row says what it does', (WidgetTester tester) async {
    await open(tester);

    expect(find.text('Send a student ID card'), findsOneWidget);
  });

  // Drawn and disabled rather than omitted: the design shows them, and
  // leaving them out would look like the tray was half-built.
  testWidgets('Audio and Contact are present but unusable', (
    WidgetTester tester,
  ) async {
    await open(tester);

    expect(find.text('Not used in this app'), findsNWidgets(2));

    final Iterable<ListTile> tiles = tester.widgetList<ListTile>(
      find.byType(ListTile),
    );
    final Iterable<ListTile> disabled = tiles.where(
      (ListTile t) => t.onTap == null,
    );

    expect(disabled.length, 2);
  });

  testWidgets('choosing ID Card returns that choice', (
    WidgetTester tester,
  ) async {
    AttachmentChoice? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  chosen = await showAttachmentTray(context);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // ID Card is the last row, so on a short viewport it sits below the
    // fold - which is what the tray's scroll view is there for. A real phone
    // shows all six without scrolling; the 800x600 test surface does not.
    await tester.ensureVisible(find.text('ID Card'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ID Card'));
    await tester.pumpAndSettle();
    // The sheet's route future resolves a microtask after the pop animation
    // finishes, so the assignment in `onPressed` lands on the next pump.
    await tester.pump();

    expect(chosen, AttachmentChoice.idCard);
  });

  testWidgets('tapping Audio does nothing at all', (WidgetTester tester) async {
    AttachmentChoice? chosen;
    bool closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  chosen = await showAttachmentTray(context);
                  closed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Audio'));
    await tester.pumpAndSettle();

    expect(chosen, isNull);
    expect(
      closed,
      isFalse,
      reason:
          'a disabled row must not dismiss the tray - a teacher who '
          'tapped it would be left wondering whether something was sent',
    );
  });
}
