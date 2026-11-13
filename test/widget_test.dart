import 'package:flutter_test/flutter_test.dart';
import 'package:tp5_widget/main.dart';

void main() {
  testWidgets('La page du TP5 s\'affiche et passe en alerte', (tester) async {
    await tester.pumpWidget(const AppTp5());
    expect(find.text('Ruche connectée'), findsOneWidget);
    expect(find.text('34.0 °C'), findsWidgets); // aperçu + carte de réglage
    expect(find.text('ALERTE'), findsNothing);  // 34 < 38 : pas d'alerte
  });
}
