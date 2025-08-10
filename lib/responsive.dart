import 'package:flutter/material.dart';

class AppBreakpoints {
  static const double compact = 600; // phones
  static const double medium = 900;  // tablets
  static const double expanded = 1200; // desktops
}

bool isCompactWidth(BuildContext context) => MediaQuery.of(context).size.width < AppBreakpoints.compact;
bool isMediumWidth(BuildContext context) => MediaQuery.of(context).size.width >= AppBreakpoints.compact && MediaQuery.of(context).size.width < AppBreakpoints.medium;
bool isWideWidth(BuildContext context) => MediaQuery.of(context).size.width >= AppBreakpoints.medium;
