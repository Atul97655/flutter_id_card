import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/admin/application/admin_providers.dart';
import 'package:flutter_id_card/features/admin/presentation/school_settings_screen.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders SchoolSettingsScreen properly for existing school', (WidgetTester tester) async {
    const SchoolConfig config = SchoolConfig(
      id: 'demo-school',
      name: 'SACRED HEART CONVENT',
      addressLine: 'St. Marks Road, Bengaluru',
      contactLine: 'Office: 080-22213456',
      cardSizeId: 'v54x86',
      templateId: 'framed_vertical',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          schoolByIdProvider('demo-school').overrideWith(
            (ref) => Stream.value(config),
          ),
        ],
        child: const MaterialApp(
          home: SchoolSettingsScreen(schoolId: 'demo-school'),
        ),
      ),
    );

    // Initial pump
    await tester.pump();
    // Allow stream and futures to resolve
    await tester.pumpAndSettle();

    expect(find.text('School Settings'), findsOneWidget);
    expect(find.text('Identity'), findsOneWidget);
    expect(find.text('SACRED HEART CONVENT'), findsOneWidget);
    expect(find.text('School Logo'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Principal Signature'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Principal Signature'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Card size'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Card size'), findsOneWidget);
  });
}
