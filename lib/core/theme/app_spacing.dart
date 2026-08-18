import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  // Spacing Tokens
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // EdgeInsets Helper constants
  static const EdgeInsets pAllXs = EdgeInsets.all(xs);
  static const EdgeInsets pAllSm = EdgeInsets.all(sm);
  static const EdgeInsets pAllMd = EdgeInsets.all(md);
  static const EdgeInsets pAllLg = EdgeInsets.all(lg);
  static const EdgeInsets pAllXl = EdgeInsets.all(xl);

  static const EdgeInsets pHorizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets pHorizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets pHorizontalLg = EdgeInsets.symmetric(horizontal: lg);

  static const EdgeInsets pVerticalXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets pVerticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets pVerticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets pVerticalLg = EdgeInsets.symmetric(vertical: lg);

  // SizedBox Helper constants for vertical spacing
  static const SizedBox vSpacerXs = SizedBox(height: xs);
  static const SizedBox vSpacerSm = SizedBox(height: sm);
  static const SizedBox vSpacerMd = SizedBox(height: md);
  static const SizedBox vSpacerLg = SizedBox(height: lg);
  static const SizedBox vSpacerXl = SizedBox(height: xl);

  // SizedBox Helper constants for horizontal spacing
  static const SizedBox hSpacerXs = SizedBox(width: xs);
  static const SizedBox hSpacerSm = SizedBox(width: sm);
  static const SizedBox hSpacerMd = SizedBox(width: md);
  static const SizedBox hSpacerLg = SizedBox(width: lg);
}
