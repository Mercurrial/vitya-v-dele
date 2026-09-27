import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/ui/pixel/garage_room.dart';

/// Сцена гаража — только пиксели (docs/DECISIONS.md, «Только пиксель-стиль»).
///
/// Аппараты были честным пиксель-артом, а комната вокруг них местами —
/// гладкими фигурами: лампа-кружок с размытым ореолом, провод кривой Безье,
/// манометры кругами, пятна и тени овалами, свет и тень градиентами. На
/// кирпиче это бросалось в глаза: полутона сглаживания, каких нет ни у
/// одного аппарата. Всё это переложено на сетку, а здесь — сторож, чтобы
/// гладкое не вернулось с очередной правкой.
///
/// Две проверки, и нужны обе. Исходники ловят гладкое в любом файле сцены,
/// даже если его сейчас не видно на снимке. Отрисовка ловит то, чего в
/// исходниках словом не найти: фигуру, поставленную между клетками.
void main() {
  group('Исходники сцены', () {
    test('в сцене нет гладких фигур, градиентов и размытия', () {
      final found = <String>[];
      final used = <_Allowed, int>{};
      for (final file in _sceneFiles()) {
        final name = file.uri.pathSegments.last;
        final lines = _code(file.readAsStringSync()).split('\n');
        for (final (what, pattern) in _smooth) {
          final hits = [
            for (var i = 0; i < lines.length; i++)
              for (final _ in pattern.allMatches(lines[i])) i + 1,
          ];
          if (hits.isEmpty) continue;
          final allowed = _allowed.where((a) => a.file == name && a.token == what).firstOrNull;
          if (allowed != null) {
            used[allowed] = hits.length;
            if (hits.length <= allowed.count) continue;
          }
          found.add('$name: $what — строки ${hits.join(', ')}');
        }
      }

      expect(found, isEmpty,
          reason: 'в сцене появилось гладкое. Круг — пиксельным кругом, '
              'линия — лесенкой, свет — ступенями (см. garage_room.dart). '
              'Если без него никак — в _allowed с причиной');

      // Исключение, которое больше не нужно, надо убрать: иначе оно тихо
      // разрешит то, от чего уже избавились.
      final stale = [
        for (final a in _allowed)
          if ((used[a] ?? 0) < a.count) '${a.file}: ${a.token} — разрешено ${a.count}, есть ${used[a] ?? 0}',
      ];
      expect(stale, isEmpty, reason: 'исключение устарело — поправь _allowed');
    });

    test('каждая кисть сцены рисует без сглаживания', () {
      // У Paint() сглаживание включено по умолчанию. На целой клетке его не
      // видно, но стоит фигуре встать между клетками — край расплывается.
      final found = <String>[];
      for (final file in _sceneFiles()) {
        final code = _code(file.readAsStringSync());
        for (final m in RegExp(r'Paint\(\)(?!\s*\.\.isAntiAlias\s*=\s*false)').allMatches(code)) {
          final line = '\n'.allMatches(code.substring(0, m.start)).length + 1;
          found.add('${file.uri.pathSegments.last}:$line');
        }
      }
      expect(found, isEmpty,
          reason: 'кисть без `..isAntiAlias = false` первой строкой каскада');
    });

    test('проверка видит файлы сцены', () {
      // Сторож, который ничего не читает, всегда зелёный.
      final names = _sceneFiles().map((f) => f.uri.pathSegments.last).toSet();
      expect(names, containsAll(['garage_room.dart', 'garage_scene.dart', 'pixel_sprite.dart']));
    });
  });

  group('Отрисовка комнаты', () {
    // Размер из снимков комнаты и нечётный — где половина клетки уходит за
    // край и дробное деление проявило бы себя.
    const sizes = [Size(342, 300), Size(341, 263)];
    // Моменты и жар — чтобы лампа была отклонена в обе стороны и светила
    // на разных ступенях.
    const moments = [(2.1, 0.7), (3.7, 0.0), (5.3, 1.0)];

    for (final stage in GarageStage.values) {
      testWidgets('${stage.name}: каждая клетка сетки — один цвет', (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        for (final size in sizes) {
          tester.view.physicalSize = size;
          for (final (time, heat) in moments) {
            final image = await _render(tester, size, stage, time, heat);
            // Пустой холст прошёл бы проверку клеток и ничего не доказал.
            final colours =
                image.buffer.asUint32List(image.offsetInBytes, image.length ~/ 4).toSet();
            expect(colours.length, greaterThan(20), reason: 'комната не нарисовалась');
            final torn = _tornCells(image, size.width.toInt(), size.height.toInt());
            expect(torn, isEmpty,
                reason: '${size.width.toInt()}×${size.height.toInt()}, t=$time, жар $heat: '
                    'клетка 2×2 разного цвета — фигура стоит между клетками '
                    'или нарисована гладко. Первые: ${torn.take(8).join(' ')}');
          }
        }
      });
    }
  });
}

/// Гладкое, которого в сцене быть не должно.
final _smooth = <(String, RegExp)>[
  ('круг, овал, дуга', RegExp(r'\bdraw(Circle|Oval|Arc)\b|\badd(Oval|Arc)\b')),
  ('скруглённый прямоугольник', RegExp(r'\bdraw(RRect|DRRect)\b|\baddRRect\b|\bRRect\b')),
  ('кривая', RegExp(r'[qQ]uadraticBezierTo|[cC]ubicTo|[cC]onicTo|[aA]rcTo')),
  ('линия штрихом', RegExp(r'\bdraw(Line|Points)\b|\bstrokeWidth\b|PaintingStyle\.stroke')),
  ('градиент', RegExp(r'Gradient')),
  ('размытие и тень', RegExp(r'MaskFilter|ImageFilter|BackdropFilter|blurRadius|BoxShadow|\bShadow\(|drawShadow')),
  ('скругление', RegExp(r'BorderRadius|Radius\.(circular|elliptical)|RoundedRectangleBorder|StadiumBorder|CircleBorder|BoxShape\.circle')),
  ('обрезка по кривой', RegExp(r'\bClip(RRect|Oval|Path)\b')),
  ('поворот', RegExp(r'\brotate\b|RotationTransition')),
  ('сглаженное масштабирование', RegExp(r'FilterQuality\.(low|medium|high)')),
  ('сглаживание', RegExp(r'isAntiAlias\s*=\s*true')),
];

/// Где гладкое оставлено намеренно.
typedef _Allowed = ({String file, String token, int count, String why});

const _allowed = <_Allowed>[
  (
    file: 'garage_scene.dart',
    token: 'скругление',
    count: 2,
    why: 'углы карточки сцены и бирка с количеством — оформление '
        'интерфейса, как у всех карточек и надписей, а не комната',
  ),
  (
    file: 'garage_scene.dart',
    token: 'обрезка по кривой',
    count: 1,
    why: 'скруглённые углы карточки сцены — та же рамка интерфейса',
  ),
];

/// Файлы, из которых рисуется сцена.
///
/// Портрет (`pixel_portrait.dart`) не проверяется: по его виду решает
/// владелец, и сторож не должен решать за него. Рамка портрета живёт в
/// `lib/ui/game/vitya_portrait.dart` — туда же.
Iterable<File> _sceneFiles() => Directory('lib/ui/pixel')
    .listSync()
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .where((f) => !f.path.endsWith('pixel_portrait.dart'));

/// Код без комментариев: в них гладкое упоминается — объясняется, почему
/// его нет. Строки сохраняются, чтобы номера в сообщении совпадали.
String _code(String source) => source
    .replaceAllMapped(RegExp(r'/\*[\s\S]*?\*/'), (m) => '\n' * '\n'.allMatches(m[0]!).length)
    .replaceAll(RegExp(r'//.*'), '');

/// Комната с лампой на холсте ровно в размер, пиксель в пиксель.
Future<Uint8List> _render(
  WidgetTester tester,
  Size size,
  GarageStage stage,
  double time,
  double heat,
) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: Stack(
              children: [
                Positioned.fill(child: RoomBackground(stage: stage)),
                Positioned.fill(child: SwingingLamp(time: time, heat: heat)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

/// Клетки 2×2, у которых не все четыре пикселя одного цвета.
///
/// Сетка сцены — две точки (`_u` в garage_room.dart). Всё, что стоит на
/// ней, закрашивает клетку целиком; сглаженный край, градиент или фигура
/// между клетками дают в клетке разные пиксели. Неполные клетки у правого
/// и нижнего края не проверяются — их обрезает край холста.
List<String> _tornCells(Uint8List rgba, int width, int height) {
  int at(int x, int y) {
    final i = (y * width + x) * 4;
    return rgba[i] << 24 | rgba[i + 1] << 16 | rgba[i + 2] << 8 | rgba[i + 3];
  }

  return [
    for (var y = 0; y + 1 < height; y += 2)
      for (var x = 0; x + 1 < width; x += 2)
        if (at(x, y) != at(x + 1, y) || at(x, y) != at(x, y + 1) || at(x, y) != at(x + 1, y + 1))
          '($x,$y)',
  ];
}
