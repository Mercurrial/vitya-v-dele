import 'package:flutter/widgets.dart';

/// Затухание краёв листаемого вбок ряда: за затухшим краем есть ещё.
///
/// Ряд, обрезанный ровно по краю, выглядит законченным — на 320 точках
/// строка вкладок так и прятала «ЦЕЛИ» и «ВИТЮ». Затухание — привычный знак
/// «дальше есть».
///
/// Маска стоит всегда, даже когда затухать нечему, — непрозрачной. Если
/// вставлять её только при затухании, у ряда под ней меняется место в
/// дереве, он строится заново, и прокрутка прыгает в начало.
class EdgeFade extends StatelessWidget {
  /// Затухает ли левый край.
  final bool start;

  /// Затухает ли правый край.
  final bool end;

  /// Ширина затухания.
  final double size;

  final Widget child;

  const EdgeFade({
    super.key,
    required this.start,
    required this.end,
    required this.child,
    this.size = 24,
  });

  static const _solid = Color(0xFF000000);
  static const _clear = Color(0x00000000);

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        final f = rect.width > 0 ? (size / rect.width).clamp(0.0, 0.5) : 0.0;
        return LinearGradient(
          colors: [start ? _clear : _solid, _solid, _solid, end ? _clear : _solid],
          stops: [0, f, 1 - f, 1],
        ).createShader(rect);
      },
      child: child,
    );
  }
}
