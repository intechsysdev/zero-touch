import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zerotouch/src/app.dart';

void main() {
  testWidgets('Login screen is shown when there is no session', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ZeroTouchApp()));
    await tester.pumpAndSettle();

    expect(find.text('ZeroTouch Intechsys'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });
}
