// lib/features/map/nav/bottom_sheet_route.dart
import 'package:flutter/material.dart';

class BottomSheetPageRoute<T> extends PageRoute<T> {
  BottomSheetPageRoute({
    required this.child,
    double heightFactor = 1.0,
    Color? barrierColor,
    bool barrierDismissible = false,
    this.duration = const Duration(milliseconds: 250),
    this.curve = Curves.easeOutCubic,
  })  : _heightFactor = heightFactor,
        _barrierColor = barrierColor,
        _barrierDismissible = barrierDismissible;

  final Widget child;
  final double _heightFactor;

  final Color? _barrierColor;
  final bool _barrierDismissible;

  final Duration duration;
  final Curve curve;

  @override
  bool get opaque => false;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => _barrierColor;

  @override
  String? get barrierLabel => null;

  @override
  bool get barrierDismissible => _barrierDismissible;

  @override
  bool get barrierSemanticsDismissible => _barrierDismissible;

  @override
  Duration get transitionDuration => duration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: _heightFactor,
        widthFactor: 1,
        child: child,
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final a = CurvedAnimation(
      parent: animation,
      curve: curve,
      reverseCurve: Curves.easeInCubic,
    );

    return SlideTransition(
      position:
          Tween<Offset>(begin: const Offset(0, 0.10), end: Offset.zero).animate(a),
      child: FadeTransition(opacity: a, child: child),
    );
  }
}
