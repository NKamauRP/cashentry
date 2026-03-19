/// Layout helpers that adapt to device navigation insets.
library;
import 'package:flutter/material.dart';

double screenBottomPadding(BuildContext context, {double base = 140}) {
  return base + MediaQuery.of(context).viewPadding.bottom;
}
