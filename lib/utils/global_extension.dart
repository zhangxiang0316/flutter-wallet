import 'package:flutter/material.dart';

extension GestureExtension on Widget {
  GestureDetector onTab(GestureTapCallback tapCallback) {
    return GestureDetector(onTap: tapCallback, child: this);
  }
}
