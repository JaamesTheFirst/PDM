import 'package:flutter/material.dart';

/// [PageRoute] personalizada que apresenta um widget como bottom sheet
/// animado, ocupando uma fração configurável da altura do ecrã.
///
/// Uso típico:
/// ```dart
/// Navigator.of(context).push(
///   BottomSheetPageRoute(
///     child: MyBottomSheetContent(),
///     heightFactor: 0.7, // 70% da altura
///   ),
/// );
/// ```
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

  /// Conteúdo do bottom sheet.
  final Widget child;

  /// Fração da altura do ecrã ocupada pelo sheet (0–1).
  final double _heightFactor;

  /// Cor do fundo semitransparente por trás do sheet.
  final Color? _barrierColor;

  /// Indica se o utilizador pode fechar o sheet ao tocar fora dele.
  final bool _barrierDismissible;

  /// Duração da animação de entrada/saída.
  final Duration duration;

  /// Curva de animação principal para o slide/fade.
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

  /// Constrói a página base (sem animação), alinhada ao fundo.
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

  /// Constrói as transições de animação para o bottom sheet.
  ///
  /// - Aparece a partir de baixo com leve deslocamento vertical.
  /// - Aplica também um fade-in/out.
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
      position: Tween<Offset>(
        begin: const Offset(0, 0.10),
        end: Offset.zero,
      ).animate(a),
      child: FadeTransition(
        opacity: a,
        child: child,
      ),
    );
  }
}
