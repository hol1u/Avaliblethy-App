import 'package:flutter/material.dart';

const double kWideLayoutBreakpoint = 840;
const double kMaxContentWidth = 820;

ThemeData buildTheme(Brightness brightness) {
  return ThemeData(
    useMaterial3: true,
    colorSchemeSeed: Colors.indigo,
    brightness: brightness,
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}
