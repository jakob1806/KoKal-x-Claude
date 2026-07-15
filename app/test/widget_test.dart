import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klassik_muenchen/main.dart';

void main() {
  testWidgets('Home-Tab zeigt Titelzeile "München"', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: KlassikMuenchenApp()));
    await tester.pumpAndSettle();

    expect(find.text('München'), findsOneWidget);
  });
}
