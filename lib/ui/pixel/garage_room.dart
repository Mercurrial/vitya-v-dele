import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Во что превратился гараж.
///
/// Плейтест поймал главную претензию к сцене: «комната не отражает масштаб».
/// Аппараты росли от банки до коллайдера, а стена за ними всё это время
/// оставалась той же. Стадия — это ответ: помещение перестраивается вместе с
/// делом, и по одному взгляду на стену понятно, как далеко Витя зашёл.
enum GarageStage {
  /// Кирпич, календарь, канистра в углу, одна лампочка на проводе.
  garage,

  /// Крашеная панель по низу стены, трубы под потолком, щиток, плакат по ТБ.
  shop,

  /// Стальные панели, окно в ночь, приборы, жёлто-чёрная разметка.
  plant,
}

/// Стадия по самому старшему купленному аппарату.
///
/// Считаем именно по старшему, а не по количеству: помещение перестраивают,
/// когда появляется техника, которая в прежнее уже не влезает.
GarageStage stageForTier(int highestTier) {
  if (highestTier >= 9) return GarageStage.plant;
  if (highestTier >= 5) return GarageStage.shop;
  return GarageStage.garage;
}

/// Название стадии — для объявления о переезде.
String stageName(GarageStage stage) => switch (stage) {
      GarageStage.garage => 'ГАРАЖ',
      GarageStage.shop => 'ЦЕХ',
      GarageStage.plant => 'ПРОИЗВОДСТВО',
    };

/// Высота полосы пола. Задана в пикселях, а не в долях высоты: нижний ряд
/// аппаратов должен стоять ровно на полу, а сцена меняет размер вместе с
/// экраном — от долей ряд бы «всплывал» на больших телефонах.
const double kFloorHeight = 26;

/// Размер пикселя обстановки. Кирпич, календарь и трубы рисуются той же
/// «зернистостью», что и аппараты на полках — иначе гладкая векторная стена
/// за пиксельными спрайтами выглядела бы фоном из другой игры.
///
/// Всё в комнате и в лампе стоит на этой сетке, включая круги, провода и
/// свет: лампа-кружок, пятна сырости и градиенты когда-то рисовались гладко,
/// и их полутона посреди пиксельной стены бросались в глаза. Сетку стережёт
/// `test/pixel_style_test.dart`.
const double _u = 2;

/// Ступени затемнения пола вглубь.
const int _kFloorSteps = 4;

/// Ступени затемнения углов. Переход между ними — узором [_kBayer].
const int _kVignetteSteps = 4;

/// Порог упорядоченного дизеринга 4×4 (матрица Байера): в какой доле
/// клеток перехода уже лежит следующая ступень.
///
/// Углы сначала темнели сплошными кольцами — и на гладкой стали цеха и
/// производства кольца читались нарисованными дугами поперёк стены.
/// Шахматка на границе колец не помогла: на диагональном краю она
/// складывалась в косые полосы. Узор Байера размазывает переход на всю
/// ступень, и дуг не видно.
const _kBayer = [
  [0 / 16, 8 / 16, 2 / 16, 10 / 16],
  [12 / 16, 4 / 16, 14 / 16, 6 / 16],
  [3 / 16, 11 / 16, 1 / 16, 9 / 16],
  [15 / 16, 7 / 16, 13 / 16, 5 / 16],
];

/// Прямоугольники по клеткам сетки, из которых складывается пиксельный
/// эллипс или круг.
///
/// Строка — одна полоса во всю хорду: так круг выходит лесенкой, как у
/// аппаратов, а не сглаженным краем. Одинаковые соседние строки сливаются в
/// одну полосу — у большого круга их десятки, а рисовать их надо дёшево.
///
/// [center] и радиусы — в точках; центр на середине клетки даёт круг
/// нечётной ширины, симметричный вокруг неё.
List<Rect> _pixelEllipse(Offset center, double rx, double ry, {double? clipTop, double? clipBottom}) {
  final rects = <Rect>[];
  final cx = center.dx / _u, cy = center.dy / _u;
  final rxc = rx / _u, ryc = ry / _u;
  var top = (cy - ryc).floor();
  var bottom = (cy + ryc).ceil();
  if (clipTop != null) top = math.max(top, (clipTop / _u).floor());
  if (clipBottom != null) bottom = math.min(bottom, (clipBottom / _u).ceil());
  Rect? run;
  for (var j = top; j < bottom; j++) {
    final dy = (j + 0.5 - cy) / ryc;
    if (dy.abs() >= 1) continue;
    final half = rxc * math.sqrt(1 - dy * dy);
    final l = (cx - half).round();
    final r = (cx + half).round();
    if (r <= l) continue;
    final row = Rect.fromLTRB(l * _u, j * _u, r * _u, (j + 1) * _u);
    if (run != null && run.left == row.left && run.right == row.right && run.bottom == row.top) {
      run = Rect.fromLTRB(run.left, run.top, run.right, row.bottom);
    } else {
      if (run != null) rects.add(run);
      run = row;
    }
  }
  if (run != null) rects.add(run);
  return rects;
}

/// Клетки ступенчатой линии между двумя клетками (Брезенхэм).
///
/// Линия толщиной в одну клетку и без двойных углов: шнур лампы и стрелка
/// манометра выглядят лесенкой, как контур аппарата, а не сглаженным штрихом.
Iterable<(int, int)> _pixelLine(int x0, int y0, int x1, int y1) sync* {
  final dx = (x1 - x0).abs(), sx = x0 < x1 ? 1 : -1;
  final dy = -(y1 - y0).abs(), sy = y0 < y1 ? 1 : -1;
  var err = dx + dy;
  var x = x0, y = y0;
  while (true) {
    yield (x, y);
    if (x == x1 && y == y1) return;
    final e2 = 2 * err;
    if (e2 >= dy) {
      err += dy;
      x += sx;
    }
    if (e2 <= dx) {
      err += dx;
      y += sy;
    }
  }
}

/// Где висит лампа, в долях ширины сцены. Не по центру: там висит портрет, а
/// лампа перед ним смотрелась бы нимбом.
///
/// Одна на лампу и комнату: над лампой на стене коробка, и к ней приходит
/// провод от выключателя.
const double _kLampPivotX = 0.8;

/// Прямоугольник в клетках сетки.
typedef CellBox = ({int col, int row, int cols, int rows});

/// Коробка под потолком, из которой висит лампа. Цвета — как у выключателя:
/// видно, что это одна проводка. `s` — винт крышки.
const _kBox = [
  'lllll',
  'llsll',
  'lllll',
  'ddddd',
];

const _kBoxPalette = {
  'l': Color(0xFFB8AE9C),
  'd': Color(0xFF8E8578),
  's': Color(0xFF5E5750),
};

/// Клетка под серединой коробки: отсюда висит шнур лампы.
@visibleForTesting
(int, int) lampHook(double width) => ((width * _kLampPivotX / _u).floor(), 1 + _kBox.length);

/// Коробка над лампой — в клетках, на клетку ниже потолка.
CellBox _lampBox(double width) {
  final (hookCol, hookRow) = lampHook(width);
  return (
    col: hookCol - _kBox.first.length ~/ 2,
    row: hookRow - _kBox.length,
    cols: _kBox.first.length,
    rows: _kBox.length,
  );
}

/// Ряд клеток, по которому провод идёт под потолком. Провис — на ряд ниже,
/// и он обязан кончаться выше портрета (рама — с десятой точки сцены,
/// `portraitTop` в garage_scene.dart): рядом ниже провод лёг бы на раму.
const int _kWireRow = 2;

/// Через сколько клеток провод прибит к стене скобой.
const int _kClipStep = 16;

/// Проводка гаража в клетках сетки: выключатель, коробка над лампой и провод
/// между ними, со скобами.
///
/// Провод раньше висел дугой от выключателя к середине стены и там кончался:
/// он шёл ниоткуда и никуда. Теперь он ведёт от выключателя вверх, под
/// потолком — к коробке, из которой висит лампа. Проводку делал сам хозяин:
/// провод прибит скобами и между ними провисает на клетку.
///
/// Считается отдельно от рисования — тест проверяет, что провод не рвётся и
/// приходит туда, где висит лампа.
@visibleForTesting
({CellBox plate, CellBox box, List<(int, int)> wire, List<(int, int)> clips}) garageWiring(
  double width,
) {
  final plate = (col: (width * 0.3 / _u).floor(), row: 6, cols: 5, rows: 6);
  final box = _lampBox(width);

  // Из выключателя — над рычажком — вверх до потолка.
  final x0 = plate.col + plate.cols ~/ 2;
  final wire = <(int, int)>[
    for (var y = plate.row - 1; y > _kWireRow; y--) (x0, y),
  ];

  // Под потолком — вправо до коробки: держится на повороте, на скобах через
  // равные промежутки и на коробке. Последний пролёт не короче половины,
  // иначе у коробки торчала бы скоба впритык.
  final x1 = box.col - 1;
  final supports = [
    x0,
    for (var x = x0 + _kClipStep; x <= x1 - _kClipStep ~/ 2; x += _kClipStep) x,
    if (x1 > x0) x1,
  ];
  for (var i = 0; i + 1 < supports.length; i++) {
    final a = supports[i], b = supports[i + 1];
    // Провисает средняя треть пролёта. Не меньше клетки от опоры: у
    // короткого пролёта ноль опустил бы провод и под самой скобой.
    final sag = math.max(1, (b - a) ~/ 3);
    for (var x = i == 0 ? a : a + 1; x <= b; x++) {
      wire.add((x, x - a >= sag && b - x >= sag ? _kWireRow + 1 : _kWireRow));
    }
  }
  if (supports.length == 1) wire.add((x0, _kWireRow));

  return (
    plate: plate,
    box: box,
    wire: wire,
    // Скобы — между поворотом и коробкой: на повороте скоба легла бы на
    // провод, идущий вверх.
    clips: [
      for (var i = 1; i < supports.length - 1; i++) (supports[i], _kWireRow),
    ],
  );
}

/// Неподвижный слой: стена, пол, обстановка.
///
/// Вынесен отдельно от света намеренно. Сцена перерисовывается каждый кадр
/// ради качающейся лампы, и гонять по кирпичам 60 раз в секунду незачем —
/// здесь `shouldRepaint` срабатывает только при смене стадии.
///
/// Одного `shouldRepaint` для этого мало, нужен свой слой. Без
/// [RepaintBoundary] лампа, которая просит перерисовки каждый кадр, тянула
/// за собой весь слой сцены — и комнату в нём: `paint` комнаты звался
/// шестьдесят раз в секунду, хотя `shouldRepaint` честно отвечал «нет».
/// Замер: комната — 600 мкс на кадр, лампа — 25.
class RoomBackground extends StatelessWidget {
  final GarageStage stage;

  const RoomBackground({super.key, required this.stage});

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          painter: _RoomPainter(stage),
          size: Size.infinite,
          // Слой не меняется, пока не сменится стадия: движку можно
          // сразу держать его готовой картинкой.
          isComplex: true,
        ),
      );
}

class _RoomPainter extends CustomPainter {
  final GarageStage stage;

  _RoomPainter(this.stage);

  final Paint _p = Paint()..isAntiAlias = false;

  /// Прямоугольник в клетках пиксельной сетки.
  void _px(Canvas c, double x, double y, double w, double h, Color color) {
    _p.color = color;
    c.drawRect(
      Rect.fromLTWH(
        (x / _u).floorToDouble() * _u,
        (y / _u).floorToDouble() * _u,
        (w / _u).ceilToDouble() * _u,
        (h / _u).ceilToDouble() * _u,
      ),
      _p,
    );
  }

  /// Готовые полосы из [_pixelEllipse] — они уже лежат на сетке.
  void _rects(Canvas c, Iterable<Rect> rects, Color color) {
    _p.color = color;
    for (final r in rects) {
      c.drawRect(r, _p);
    }
  }

  /// Клетки из [_pixelLine] и [garageWiring].
  void _cells(Canvas c, Iterable<(int, int)> cells, Color color) {
    _p.color = color;
    for (final (x, y) in cells) {
      c.drawRect(Rect.fromLTWH(x * _u, y * _u, _u, _u), _p);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final floorY = ((size.height - kFloorHeight) / _u).floorToDouble() * _u;
    _paintWall(canvas, size, floorY);
    switch (stage) {
      case GarageStage.garage:
        _paintGarageProps(canvas, size, floorY);
      case GarageStage.shop:
        _paintShopProps(canvas, size, floorY);
      case GarageStage.plant:
        _paintPlantProps(canvas, size, floorY);
    }
    _paintLampBox(canvas, size);
    _paintFloor(canvas, size, floorY);
    _paintVignette(canvas, size);
  }

  // --- Стена -------------------------------------------------------------

  void _paintWall(Canvas canvas, Size size, double floorY) {
    switch (stage) {
      case GarageStage.garage:
        _paintBricks(canvas, size.width, floorY, const [
          Color(0xFF3B2A1F),
          Color(0xFF412E22),
          Color(0xFF36271D),
          Color(0xFF45301F),
          Color(0xFF3E2B21),
        ], const Color(0xFF231911));
      case GarageStage.shop:
        // Кирпич побелен сверху, по низу — крашеная панель, как во всех
        // мастерских. Панель мгновенно читается как «помещение обжитое».
        _paintBricks(canvas, size.width, floorY, const [
          Color(0xFF4A4238),
          Color(0xFF4F463B),
          Color(0xFF453D34),
          Color(0xFF524839),
        ], const Color(0xFF2E2923));
        final top = floorY - 58;
        _px(canvas, 0, top, size.width, floorY - top, const Color(0xFF2F3B2C));
        _px(canvas, 0, top, size.width, _u, const Color(0xFF465842));
        _px(canvas, 0, top + _u, size.width, _u, const Color(0xFF1E261C));
        // Облупившаяся краска.
        final chip = math.Random(3);
        for (var i = 0; i < 9; i++) {
          _px(
            canvas,
            chip.nextDouble() * size.width,
            top + 6 + chip.nextDouble() * 40,
            _u * (1 + chip.nextInt(3)),
            _u,
            const Color(0xFF3C4A38),
          );
        }
      case GarageStage.plant:
        _paintPanels(canvas, size.width, floorY);
    }
  }

  void _paintBricks(
    Canvas canvas,
    double width,
    double floorY,
    List<Color> tones,
    Color mortar,
  ) {
    _px(canvas, 0, 0, width, floorY, mortar);

    const bw = 24.0, bh = 10.0;
    final rnd = math.Random(5);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, width, floorY));
    for (var y = 0.0, row = 0; y < floorY; y += bh, row++) {
      final offset = row.isEven ? 0.0 : -bw / 2;
      for (var x = offset; x < width; x += bw) {
        final tone = tones[rnd.nextInt(tones.length)];
        // Кирпич без шва: шов — это просвет подложки между ними.
        _px(canvas, x, y, bw - _u, bh - _u, tone);
        // Верхняя грань ловит свет лампы, нижняя уходит в тень — и кладка
        // становится рельефной, а не нарисованной.
        _px(canvas, x, y, bw - _u, _u, Color.lerp(tone, const Color(0xFFFFE0B0), 0.10)!);
        _px(canvas, x, y + bh - 2 * _u, bw - _u, _u, Color.lerp(tone, const Color(0xFF000000), 0.18)!);
        // Скол на каждом десятом.
        if (rnd.nextInt(10) == 0) {
          _px(canvas, x + _u * (1 + rnd.nextInt(8)), y + _u, _u * 2, _u, mortar);
        }
      }
    }
    canvas.restore();

    // Сырость: пятна всегда на одних и тех же местах — генератор с постоянным
    // зерном, поэтому стена не «дышит» между кадрами. Пятно — пиксельный
    // круг: гладкий край расплывался по кирпичу полутоном.
    final damp = math.Random(11);
    for (var i = 0; i < 5; i++) {
      final center = Offset(damp.nextDouble() * width, damp.nextDouble() * floorY * 0.8);
      final r = 18 + damp.nextDouble() * 26;
      _rects(canvas, _pixelEllipse(center, r, r, clipTop: 0, clipBottom: floorY), const Color(0x16000000));
    }
  }

  void _paintPanels(Canvas canvas, double width, double floorY) {
    _px(canvas, 0, 0, width, floorY, const Color(0xFF232830));
    const ph = 40.0;
    for (var y = 0.0; y < floorY; y += ph) {
      // Лист чуть светлее сверху: свет падает из-под потолка.
      _px(canvas, 0, y, width, _u, const Color(0xFF30363F));
      _px(canvas, 0, y + ph - _u, width, _u, const Color(0xFF15181D));
      for (var x = 10.0; x < width; x += 36) {
        _px(canvas, x, y + 4, _u, _u, const Color(0xFF48505B));
        _px(canvas, x, y + ph - 8, _u, _u, const Color(0xFF48505B));
      }
    }
    for (final jx in [width * 0.31, width * 0.69]) {
      _px(canvas, jx, 0, _u, floorY, const Color(0xFF15181D));
      _px(canvas, jx + _u, 0, _u, floorY, const Color(0xFF30363F));
    }
  }

  // --- Пол -----------------------------------------------------------------

  void _paintFloor(Canvas canvas, Size size, double floorY) {
    final base = switch (stage) {
      GarageStage.garage => const Color(0xFF1A140F),
      GarageStage.shop => const Color(0xFF1C1A16),
      GarageStage.plant => const Color(0xFF15181C),
    };
    _px(canvas, 0, floorY, size.width, size.height - floorY, base);

    // Плинтус-тень в углу и светлая кромка: без них пол читался продолжением
    // стены, и аппараты висели в воздухе.
    _px(canvas, 0, floorY, size.width, _u, const Color(0xFF0C0907));
    _px(canvas, 0, floorY + _u, size.width, _u, const Color(0x33FFD089));

    switch (stage) {
      case GarageStage.garage:
        // Бетон: крошка и масляное пятно, которое никто не оттёр.
        final grit = math.Random(17);
        for (var i = 0; i < 40; i++) {
          _px(
            canvas,
            grit.nextDouble() * size.width,
            floorY + 6 + grit.nextDouble() * (size.height - floorY - 6),
            _u,
            _u,
            const Color(0xFF231B14),
          );
        }
        _rects(
          canvas,
          _pixelEllipse(Offset(size.width * 0.3, floorY + 15), 23, 4),
          const Color(0x40000000),
        );
      case GarageStage.shop:
        // Метлахская плитка.
        for (var x = 0.0; x < size.width; x += 16) {
          _px(canvas, x, floorY + 4, _u / 2, size.height, const Color(0xFF26231E));
        }
        _px(canvas, 0, floorY + 14, size.width, _u / 2, const Color(0xFF26231E));
      case GarageStage.plant:
        // Жёлто-чёрная разметка вдоль стены и решётка.
        for (var x = 0.0; x < size.width; x += 12) {
          _px(canvas, x, floorY + 4, 6, 4, const Color(0xFFB8922E));
          _px(canvas, x + 6, floorY + 4, 6, 4, const Color(0xFF1A1A1A));
        }
        for (var x = 4.0; x < size.width; x += 10) {
          _px(canvas, x, floorY + 10, _u / 2, size.height, const Color(0xFF20252B));
        }
    }

    // Затемнение вглубь — последним, поверх фактуры. Полосами по клеткам, а
    // не градиентом: плавная тень размывала крошку и плитку в полутон.
    // Черноты — как у прежнего градиента: от нуля у кромки до 40 % внизу.
    final top = floorY + 2 * _u;
    final rows = ((size.height - top) / _u).ceil();
    for (var i = 0; i < _kFloorSteps; i++) {
      final from = top + (rows * i / _kFloorSteps).floor() * _u;
      final to = top + (rows * (i + 1) / _kFloorSteps).floor() * _u;
      _px(canvas, 0, from, size.width, to - from,
          Color.fromARGB((0x66 * (i + 0.5) / _kFloorSteps).round(), 0, 0, 0));
    }
  }

  /// Углы темнее середины: свет от одной лампочки до них не добивает.
  ///
  /// Сеткой (упорядоченный дизеринг), а не градиентом: каждая клетка берёт
  /// одну из ступеней черноты, а переход между ступенями — узором Байера.
  /// Геометрия прежняя: центр чуть выше середины, темнеть начинает с 55 %
  /// радиуса и доходит до 55 % черноты у края.
  void _paintVignette(Canvas canvas, Size size) {
    final cx = size.width / 2 / _u, cy = size.height * 0.35 / _u;
    final radius = 0.95 * size.shortestSide / _u;
    final clear = 0.55 * radius;
    final cols = (size.width / _u).ceil(), rows = (size.height / _u).ceil();
    const darkest = 0x8C / 0xFF;
    final shades = [
      for (var k = 0; k <= _kVignetteSteps; k++)
        Color.fromARGB((darkest * k / _kVignetteSteps * 0xFF).round(), 0, 0, 0),
    ];
    for (var j = 0; j < rows; j++) {
      // Подряд идущие клетки одной ступени — одной полосой.
      var start = 0, level = 0;
      void flush(int end) {
        if (level == 0) return;
        _p.color = shades[level];
        canvas.drawRect(Rect.fromLTWH(start * _u, j * _u, (end - start) * _u, _u), _p);
      }

      final dy = j + 0.5 - cy;
      for (var i = 0; i < cols; i++) {
        final dx = i + 0.5 - cx;
        final d2 = dx * dx + dy * dy;
        // Середина светлая целиком — корень там считать незачем.
        final t = d2 <= clear * clear ? 0.0 : ((math.sqrt(d2) / radius - 0.55) / 0.45).clamp(0.0, 1.0);
        final l = math.min(_kVignetteSteps, (t * _kVignetteSteps + _kBayer[j % 4][i % 4]).floor());
        if (l != level) {
          flush(i);
          start = i;
          level = l;
        }
      }
      flush(cols);
    }
  }

  // --- Обстановка по стадиям ---------------------------------------------

  void _paintGarageProps(Canvas canvas, Size size, double floorY) {
    // Отрывной календарь на гвозде — время тут идёт, но медленно.
    _calendar(canvas, 12, 12);

    // Выключатель и провод от него к коробке над лампой.
    final wiring = garageWiring(size.width);
    // Провод светлый — плоская «лапша», какой гаражи и проводили. Тёмный
    // провод сливался с тенью под кирпичом, и провисы читались пунктиром.
    _cells(canvas, wiring.wire, const Color(0xFF8E8578));
    // Скоба — над проводом и под ним, а не на нём: тёмная клетка поперёк
    // тонкого провода читалась обрывом.
    _cells(canvas, [for (final (x, y) in wiring.clips) ...[(x, y - 1), (x, y + 1)]],
        const Color(0xFF5E5750));
    final plate = wiring.plate;
    final sx = plate.col * _u, sy = plate.row * _u;
    _px(canvas, sx, sy, plate.cols * _u, plate.rows * _u, const Color(0xFFB8AE9C));
    _px(canvas, sx, sy + (plate.rows - 1) * _u, plate.cols * _u, _u, const Color(0xFF8E8578));
    _px(canvas, sx + plate.cols ~/ 2 * _u, sy + _u, _u, 3 * _u, const Color(0xFF5E5750));

    // Канистра в правом углу и ящик в левом.
    _jerrycan(canvas, size.width - 30, floorY - 22);
    _crate(canvas, 6, floorY - 18, 30, 18);
  }

  void _paintShopProps(Canvas canvas, Size size, double floorY) {
    // Трубы под потолком с хомутами.
    for (final y in [4.0, 12.0]) {
      _px(canvas, 0, y, size.width, 6, const Color(0xFF4E453C));
      _px(canvas, 0, y, size.width, _u, const Color(0xFF6E655A));
      _px(canvas, 0, y + 4, size.width, _u, const Color(0xFF2E2822));
    }
    for (var x = 24.0; x < size.width; x += 64) {
      _px(canvas, x, 2, 4, 18, const Color(0xFF2E2822));
    }

    // Плакат по технике безопасности.
    _px(canvas, 12, 28, 30, 38, const Color(0xFFD9CFB8));
    _px(canvas, 12, 28, 30, 8, const Color(0xFFA8402A));
    for (var y = 40.0; y < 62; y += 4) {
      _px(canvas, 16, y, 22, _u, const Color(0xFF8E8578));
    }

    // Электрощиток.
    _px(canvas, size.width - 34, floorY - 100, 24, 30, const Color(0xFF3E4A3A));
    _px(canvas, size.width - 34, floorY - 100, 24, _u, const Color(0xFF55664F));
    _px(canvas, size.width - 26, floorY - 88, 8, 8, const Color(0xFFE8C020));
    _px(canvas, size.width - 24, floorY - 86, 4, 4, const Color(0xFF1A1A1A));

    _crate(canvas, 6, floorY - 22, 36, 22);
    _jerrycan(canvas, size.width - 30, floorY - 22);
  }

  void _paintPlantProps(Canvas canvas, Size size, double floorY) {
    // Окно в ночь. Единственное место, где в сцене есть холодный цвет —
    // поэтому оно и работает: снаружи холодно, внутри тепло.
    const win = Rect.fromLTWH(14, 14, 62, 40);
    _px(canvas, win.left - 4, win.top - 4, win.width + 8, win.height + 8, const Color(0xFF3A3F47));
    _px(canvas, win.left, win.top, win.width, win.height, const Color(0xFF0B1220));
    final stars = math.Random(23);
    for (var i = 0; i < 14; i++) {
      final x = win.left + stars.nextDouble() * win.width;
      final y = win.top + stars.nextDouble() * win.height;
      // Три яркости, а не сотня: так звёзды остаются в палитре, а не
      // рассыпаются на случайные оттенки. Жребий прежний — звёзды на местах.
      const shine = [0x60, 0xA0, 0xE0];
      _px(canvas, x, y, _u, _u,
          Color.fromARGB(shine[stars.nextInt(0x90) * shine.length ~/ 0x90], 0xFF, 0xFF, 0xFF));
    }
    // Луна.
    _px(canvas, win.right - 16, win.top + 6, 8, 8, const Color(0xFFE8E0C8));
    _px(canvas, win.right - 12, win.top + 6, 4, 4, const Color(0xFF0B1220));
    _px(canvas, win.center.dx - 1, win.top, _u, win.height, const Color(0xFF3A3F47));
    _px(canvas, win.left, win.center.dy - 1, win.width, _u, const Color(0xFF3A3F47));

    // Манометры: пиксельный круг нечётной ширины — у стрелки есть центральная
    // клетка, из которой она растёт.
    for (var i = 0; i < 3; i++) {
      final col = ((size.width - 26.0 - i * 24) / _u).floor();
      final row = ((floorY - 96) / _u).floor();
      final c = Offset((col + 0.5) * _u, (row + 0.5) * _u);
      _rects(canvas, _pixelEllipse(c, 4.5 * _u, 4.5 * _u), const Color(0xFF6E6459));
      _rects(canvas, _pixelEllipse(c, 3.5 * _u, 3.5 * _u), const Color(0xFFEDE5D2));
      final angle = -2.3 + i * 0.8;
      _cells(
        canvas,
        _pixelLine(col, row, col + (3 * math.cos(angle)).round(), row + (3 * math.sin(angle)).round()),
        const Color(0xFFA8402A),
      );
    }
    // Труба вдоль стены к приборам.
    _px(canvas, size.width - 80, floorY - 86, 70, 6, const Color(0xFF5E5750));
    _px(canvas, size.width - 80, floorY - 86, 70, _u, const Color(0xFF8E8578));
  }

  /// Коробка под потолком, из которой висит лампа, — на всех стадиях: шнур
  /// выходит из неё, а не из края сцены.
  void _paintLampBox(Canvas canvas, Size size) {
    final box = _lampBox(size.width);
    for (var y = 0; y < _kBox.length; y++) {
      for (var x = 0; x < _kBox[y].length; x++) {
        _px(canvas, (box.col + x) * _u, (box.row + y) * _u, _u, _u, _kBoxPalette[_kBox[y][x]]!);
      }
    }
  }

  // --- Предметы ----------------------------------------------------------

  void _calendar(Canvas canvas, double x, double y) {
    _px(canvas, x + 12, y - 4, _u, 4, const Color(0xFF6E6459)); // гвоздь
    _px(canvas, x, y, 26, 30, const Color(0xFFD9CFB8));
    _px(canvas, x, y, 26, 8, const Color(0xFFA8402A));
    _px(canvas, x + 6, y + 2, 14, 4, const Color(0xFFEDE5D2));
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 5; c++) {
        _px(canvas, x + 3 + c * 4.4, y + 12 + r * 4.4, _u, _u,
            r == 2 && c == 3 ? const Color(0xFFA8402A) : const Color(0xFF8E8578));
      }
    }
    // Тень от листа.
    _px(canvas, x + 26, y + 2, _u, 30, const Color(0x40000000));
  }

  void _jerrycan(Canvas canvas, double x, double y) {
    _px(canvas, x, y + 4, 22, 18, const Color(0xFFA8402A));
    _px(canvas, x, y + 4, 22, _u, const Color(0xFFC85A3E));
    _px(canvas, x + 20, y + 4, _u, 18, const Color(0xFF6E2A1C));
    _px(canvas, x + 4, y, 10, 4, const Color(0xFF6E2A1C)); // ручка
    _px(canvas, x + 16, y, 4, 4, const Color(0xFF5E5750)); // горловина
    _px(canvas, x + 4, y + 10, 14, _u, const Color(0xFF6E2A1C)); // выштамповка
  }

  void _crate(Canvas canvas, double x, double y, double w, double h) {
    _px(canvas, x, y, w, h, const Color(0xFF5A3D25));
    _px(canvas, x, y, w, _u, const Color(0xFF7A5634));
    for (var yy = y + h / 3; yy < y + h - 1; yy += h / 3) {
      _px(canvas, x, yy, w, _u, const Color(0xFF3A2616));
    }
    _px(canvas, x, y, _u, h, const Color(0xFF3A2616));
    _px(canvas, x + w - _u, y, _u, h, const Color(0xFF3A2616));
  }

  @override
  bool shouldRepaint(_RoomPainter old) => old.stage != stage;
}

/// Лампочка на проводе и её свет.
///
/// Свет здесь — не украшение, а способ сделать сцену живой: пока лампа
/// покачивается, вся комната чуть дышит вместе с ней. Амплитуда растёт с
/// жаром — под аппаратами гудит огонь, воздух ходит.
class SwingingLamp extends StatelessWidget {
  final double time;
  final double heat;

  const SwingingLamp({super.key, required this.time, required this.heat});

  /// Смещение лампы от точки подвеса. Вынесено, чтобы свет и сама лампочка
  /// считали одно и то же число, а не разъехались.
  static double swing(double time, double heat) {
    final amplitude = 4 + 6 * heat.clamp(0.0, 1.0);
    // Два периода вместо одного: маятник перестаёт выглядеть механическим.
    return amplitude * math.sin(time * 0.72) + amplitude * 0.3 * math.sin(time * 1.9);
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _LampPainter(time: time, heat: heat),
        size: Size.infinite,
      );
}

/// Лампочка по клеткам: патрон и колба, как в баннере игры (`web/og.png`,
/// `tools/make_banner.py`).
///
/// `k`, `m` — патрон в тени и на свету, `b` — колба, `B` — её тёплый край,
/// `w` — блик. Столбец 3 — середина: к нему сверху приходит шнур.
const _kBulb = [
  '..mkk..',
  '..mkk..',
  '.bbbbb.',
  'bwwbbbB',
  'bwbbbbB',
  'bbbbbbB',
  '.bbbbB.',
  '..BBB..',
];

const _kBulbPalette = {
  'k': Color(0xFF2E2822),
  'm': Color(0xFF4E453C),
  'b': Color(0xFFFFE9BC),
  'B': Color(0xFFFFD089),
  'w': Color(0xFFFFFFFF),
};

/// Верх патрона в точках — там же, где был у гладкой лампы.
const double _kBulbTop = 28;

/// Середина колбы в клетках от левого верхнего угла спрайта: отсюда светит.
const double _kGlowCol = 3.5, _kGlowRow = 5;

/// Ступени света — доли яркости середины, на которых кончается кольцо.
///
/// Плавный градиент поверх кирпича давал полутона, которых нет ни у одного
/// аппарата; кольца по клеткам — это тот же свет в пиксель-арте. Кольца
/// нарезаны по яркости, а не по радиусу: при равных радиусах у лампы, где
/// свет падает быстрее всего, скачок между соседними кольцами выходил
/// большим, и на кирпиче читался нарисованный круг. Равные доли — и у лампы
/// кольца идут чаще, а к краю, где свет почти сошёл, реже.
const _kLightLevels = [0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.13, 0.07, 0.03];

/// Где свет опускается до доли [share] яркости середины — в долях радиуса.
///
/// Ровно как у прежнего градиента, чтобы ступени повторяли его, а не
/// выдумывали свет заново: до трети радиуса яркость падает до 22 %
/// по прямой, дальше гаснет вместе с цветом, то есть по квадрату.
double _lightEdge(double share) => share >= 0.22
    ? 0.3 * (1 - share) / 0.78
    : 0.3 + 0.7 * (1 - math.sqrt(share / 0.22));

/// Сколько ступеней у яркости лампы по жару, не считая нулевой. Плавная
/// яркость перекрашивала бы стену каждый кадр на неразличимую долю; три
/// ступени читаются как «разгорелась».
const int _kHeatSteps = 3;

class _LampPainter extends CustomPainter {
  final double time;
  final double heat;

  _LampPainter({required this.time, required this.heat});

  /// Готовый свет, записанный один раз на размер и ступень жара.
  ///
  /// Кольца света — сотни полос, и собирать их каждый кадр незачем: свет не
  /// меняет форму, он только ездит вместе с лампой. Значит, запись можно
  /// сделать однажды и рисовать со сдвигом на целые клетки.
  static ui.Picture? _cachedLight;
  static Size? _cachedSize;
  static int? _cachedLevel;

  static ui.Picture _light(Size size, int level) {
    if (_cachedLight != null && _cachedSize == size && _cachedLevel == level) {
      return _cachedLight!;
    }
    final warmth = 0.22 + 0.14 * level / _kHeatSteps;
    // Радиус — как у прежнего градиента: 1.1 короткой стороны сцены.
    final radius = 1.1 * size.shortestSide;
    const center = Offset(_kGlowCol * _u, _kGlowRow * _u);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..isAntiAlias = false
      ..blendMode = BlendMode.plus;
    // Яркость кольца — середина между долями на его краях; за последним
    // кольцом света нет.
    final shares = [
      for (var i = 0; i < _kLightLevels.length; i++)
        ((i > 0 ? _kLightLevels[i - 1] : 1.0) + _kLightLevels[i]) / 2,
      0.0,
    ];
    // Круги лежат друг на друге и складываются: каждый добавляет разницу
    // между своим кольцом и следующим.
    for (var i = 0; i < _kLightLevels.length; i++) {
      final edge = _lightEdge(_kLightLevels[i]) * radius;
      paint.color = const Color(0xFFFFD089).withOpacity(warmth * (shares[i] - shares[i + 1]));
      // Запись лежит от верха патрона. Выше потолка и ниже пола свет не
      // виден — строки там не нужны.
      final rows = _pixelEllipse(center, edge, edge,
          clipTop: -_kBulbTop, clipBottom: size.height - _kBulbTop);
      for (final r in rows) {
        canvas.drawRect(r, paint);
      }
    }
    _cachedLight = recorder.endRecording();
    _cachedSize = size;
    _cachedLevel = level;
    return _cachedLight!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final level = (heat.clamp(0.0, 1.0) * _kHeatSteps).round();

    // Лампа ходит целыми клетками: между клетками пиксели размазались бы.
    final (pivotCol, hookRow) = lampHook(size.width);
    final swingCols = (SwingingLamp.swing(time, heat) / _u).round();
    final topRow = (_kBulbTop / _u).floor();
    final left = (pivotCol + swingCols - 3) * _u;

    // Свет. Форма постоянна, меняется только положение — поэтому двигаем
    // холст, а не пересобираем кольца.
    canvas.save();
    canvas.translate(left, topRow * _u);
    canvas.drawPicture(_light(size, level));
    canvas.restore();

    final paint = Paint()..isAntiAlias = false;

    // Шнур — из коробки под потолком до патрона, лесенкой в клетку
    // толщиной. Коробка нарисована в комнате: она не качается.
    paint.color = const Color(0xFF17110C);
    for (final (x, y) in _pixelLine(pivotCol, hookRow, pivotCol + swingCols, topRow - 1)) {
      canvas.drawRect(Rect.fromLTWH(x * _u, y * _u, _u, _u), paint);
    }

    // Ореол — две ступени вокруг колбы. Мягче самой колбы — иначе
    // получается солнце.
    final glow = Offset(left + _kGlowCol * _u, topRow * _u + _kGlowRow * _u);
    paint.color = const Color(0xFFFFD089).withOpacity((0.10 + 0.12 * level / _kHeatSteps) / 2);
    for (final radius in const [7 * _u, 5 * _u]) {
      for (final r in _pixelEllipse(glow, radius, radius)) {
        canvas.drawRect(r, paint);
      }
    }

    // Колба: подряд идущие клетки одного цвета — одной полосой.
    for (var y = 0; y < _kBulb.length; y++) {
      final row = _kBulb[y];
      var x = 0;
      while (x < row.length) {
        final colour = _kBulbPalette[row[x]];
        var end = x + 1;
        while (end < row.length && row[end] == row[x]) {
          end++;
        }
        if (colour != null) {
          paint.color = colour;
          canvas.drawRect(
            Rect.fromLTWH(left + x * _u, (topRow + y) * _u, (end - x) * _u, _u),
            paint,
          );
        }
        x = end;
      }
    }

    _paintDust(canvas, size, glow);
  }

  /// Пыль в луче. Её почти не видно — и именно поэтому комната перестаёт быть
  /// плоской картинкой.
  void _paintDust(Canvas canvas, Size size, Offset bulb) {
    final rnd = math.Random(41);
    final paint = Paint()..isAntiAlias = false;
    for (var i = 0; i < 18; i++) {
      final baseX = rnd.nextDouble() * size.width;
      final speed = 6 + rnd.nextDouble() * 10;
      final phase = rnd.nextDouble() * 100;
      // Пылинка медленно оседает и сносится вбок, потом появляется сверху.
      final y = (phase + time * speed) % (size.height + 20) - 10;
      final x = baseX + math.sin(time * 0.5 + phase) * 6;

      final distance = (Offset(x, y) - bulb).distance;
      final lit = (1 - distance / (size.height * 0.9)).clamp(0.0, 1.0);
      // Три ступени яркости, как у света, и клетка сетки: пылинка гаснет
      // ступеньками и перескакивает по клеткам, а не плывёт между ними.
      final step = (lit * lit * 3).round();
      if (step == 0) continue;
      paint.color = const Color(0xFFFFE9BC).withOpacity(0.28 * step / 3);
      canvas.drawRect(
        Rect.fromLTWH((x / _u).floorToDouble() * _u, (y / _u).floorToDouble() * _u, _u, _u),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LampPainter old) => old.time != time || old.heat != heat;
}
