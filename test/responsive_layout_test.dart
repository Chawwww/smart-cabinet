import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_cabinet/utils/responsive_layout.dart';

void main() {
  Future<void> expectLayout(
    WidgetTester tester, {
    required double width,
    required AppLayout layout,
    required int columns,
  }) async {
    late AppLayout actualLayout;
    late int actualColumns;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: Builder(
            builder: (context) {
              actualLayout = Responsive.layoutOf(context);
              actualColumns = Responsive.gridCols(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(actualLayout, layout);
    expect(actualColumns, columns);
  }

  testWidgets('compact phone uses one grid column', (tester) async {
    await expectLayout(
      tester,
      width: 320,
      layout: AppLayout.mobile,
      columns: 1,
    );
  });

  testWidgets('standard phone uses two grid columns', (tester) async {
    await expectLayout(
      tester,
      width: 390,
      layout: AppLayout.mobile,
      columns: 2,
    );
  });

  testWidgets('tablet uses three grid columns', (tester) async {
    await expectLayout(
      tester,
      width: 800,
      layout: AppLayout.tablet,
      columns: 3,
    );
  });

  testWidgets('desktop uses four grid columns', (tester) async {
    await expectLayout(
      tester,
      width: 1400,
      layout: AppLayout.desktop,
      columns: 4,
    );
  });
}
