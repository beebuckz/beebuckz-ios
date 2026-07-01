// Basic smoke test for the Bee Buckz WebView app.

import 'package:flutter_test/flutter_test.dart';

import 'package:beebuckz/main.dart';

void main() {
  testWidgets('App builds and shows the loading indicator', (tester) async {
    await tester.pumpWidget(const BeeBuckzApp());

    // The bee splash shows while the WebView loads.
    expect(find.text('🐝'), findsOneWidget);
  });
}
