import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marekt_lens/app/theme.dart';
import 'package:marekt_lens/features/cart/quantity_dialog.dart';

void main() {
  testWidgets(
    'quantité zéro et dépassement refusés sur petit écran avec clavier',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () async {
                  result = await quantityDialog(
                    context,
                    title: 'Vendre AAPL',
                    maximum: 3,
                  );
                },
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '0');
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      expect(find.text('Entier requis, entre 1 et 3.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '4');
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      await tester.enterText(find.byType(TextFormField), '3');
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      expect(result, 3);
      expect(tester.takeException(), isNull);
    },
  );
}
