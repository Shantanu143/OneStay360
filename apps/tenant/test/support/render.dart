// Dev tool: render widgets to PNG with the real fonts so a screen can be
// compared against the design mock-ups. Used by test/preview (skipped unless
// RENDER_DIR is set).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Where renders go; null means "don't render".
String? get renderDir => Platform.environment['RENDER_DIR'];

Future<void> loadDesignFonts() async {
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter';
  final sources = {
    'Inter': 'assets/fonts/Inter-Variable.ttf',
    'MaterialIcons':
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  };
  for (final e in sources.entries) {
    final bytes = File(e.value).readAsBytesSync();
    final loader = FontLoader(e.key)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

/// iPhone-like 390x844 view at 2x so output matches the @2x mock-ups.
void useIphoneView(WidgetTester tester, {double top = 47, double bottom = 34}) {
  tester.view.physicalSize = const Size(390 * 2, 844 * 2);
  tester.view.devicePixelRatio = 2;
  final pad = FakeViewPadding(top: top * 2, bottom: bottom * 2);
  tester.view.padding = pad;
  tester.view.viewPadding = pad;
  addTearDown(tester.view.reset);
}

Future<void> snapshot(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile(Uri.file('${renderDir!}/$name.png')),
  );
}
