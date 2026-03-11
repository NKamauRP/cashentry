import 'package:flutter/material.dart';

double screenBottomPadding(BuildContext context, {double base = 140}) {
  return base + MediaQuery.of(context).viewPadding.bottom;
}
