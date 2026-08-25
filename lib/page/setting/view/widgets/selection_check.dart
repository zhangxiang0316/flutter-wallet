import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Stable selection indicator that does not depend on optional icon fonts.
class SelectionCheck extends StatelessWidget {
  const SelectionCheck({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final size = 22.w;
    return Semantics(
      selected: selected,
      child: SizedBox.square(
        dimension: size,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: selected
              ? Icon(
                  Icons.check_rounded,
                  key: const ValueKey('selected'),
                  size: 20.w,
                  color: Theme.of(context).colorScheme.primary,
                )
              : const SizedBox(key: ValueKey('unselected')),
        ),
      ),
    );
  }
}
