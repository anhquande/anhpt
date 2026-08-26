import 'package:anhpt/app/app_controller.dart';
import 'package:anhpt/main.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app shows onboarding on first launch', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(LocalStore());
    await controller.initialize();

    await tester.pumpWidget(AnhPtApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('AnhPT'), findsWidgets);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
