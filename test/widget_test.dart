import 'package:flutter_test/flutter_test.dart';
import 'package:genki_sns/main.dart';

void main() {
  testWidgets('shows onboarding entry point', (tester) async {
    await tester.pumpWidget(const GenkiSnsApp());

    expect(find.text('只属于你的虚拟 SNS'), findsOneWidget);
    expect(find.text('开始设置'), findsOneWidget);
  });
}
