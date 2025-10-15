// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

import 'package:messenger_flutter/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const MethodChannel channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          switch (call.method) {
            case 'read':
              return null;
            case 'write':
              return null;
            case 'delete':
              return null;
            case 'readAll':
              return <String, String>{};
            default:
              return null;
          }
        });
  });

  testWidgets('App shows chats screen title', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Чаты организации'), findsOneWidget);
  });
}
