// Генератор иконки приложения — на все платформы из одного рисунка.
//
// Иконка нарисована здесь же, пикселями, как и всё остальное искусство в игре —
// так она остаётся в репозитории текстом, её видно в диффе и можно поправить
// одним символом. Никаких бинарных ассетов, которые никто не решается тронуть.
//
// Запуск:  dart run tools/make_icons.dart
//
// Пишет иконки Android (обычные, адаптивные и монохромные), iOS, macOS,
// Windows (.ico), веба (с маскируемыми) и заставку Android.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Витя в деле: пиджак, галстук, стрижка под машинку.
///
/// Раньше на иконке была банка. Игра называется по Вите, а не по самогону, и
/// дальше по плану другие миры — ПК, стримы, — где банки уже не будет. Витя
/// останется.
///
/// Черты — с портрета в игре: высокий купол, торчащие уши, тяжёлые веки,
/// щетина на подбородке. Лицо рисуется половиной и отражается, а свет сверху
/// слева кладётся поверх отдельными тонами. Первый Витя был нарисован целиком
/// от руки, и это было видно: левое ухо больше и светлее правого, стрижка
/// пятнами, рот со щетиной — одним мазком. Симметрию силуэта, контура, глаз и
/// бровей теперь проверяет [_checkSymmetry].
///
/// Поле 48×48, а обычная иконка — только его середина 32×32 (от 8 до 40).
/// Запас нужен адаптивной иконке Android и маскируемой веба: система сама
/// режет их кругом, каплей или квадратом и показывает то больше, то меньше
/// краёв. Плечи поэтому уходят до самого низа поля, а голова целиком сидит в
/// безопасной зоне — середине 32×32. Ужатая в квадрат обычная иконка вместо
/// рисунка с запасом дала бы висящий в воздухе обрубок плеч.
///
/// Каждая строка обязана быть ровно [_field] символов; проверка ниже ловит
/// опечатку сразу, а не через три этапа сборки.
const List<String> _art = [
  '................................................', // 0
  '................................................',
  '................................................',
  '................................................',
  '................................................',
  '................................................',
  '................................................',
  '................................................',
  '................................................', // 8  край обычной иконки
  '................................................',
  '...................kkkkkkkkkk...................', // 10 макушка: стрижка под машинку
  '.................kkGGGHHHHHHhkk.................',
  '................kGGGGGHHHHHHhhhk................',
  '...............kGGGGGGHHHHHHhhhhk...............',
  '...............kHHSSSSSSSSSSSShhk...............', // 14 лоб
  '...............kHSLLSSSSSSSSSSShk...............',
  '.............kkkSSLSSSSSSSSSSSSskkk.............',
  '............kssZSSSSSSSSSSSSSSSsZssk............', // 17 уши
  '............kszZSEEEEESSSSEEEEEsZzsk............', // 18 брови
  '............kszZSSEEEESSSSEEEESsZzsk............',
  '............kszZSSWeeWSSSSWeeWSsZzsk............', // 20 глаза из-под тяжёлых век
  '............kssZSSSssSSSsSSssSSsZssk............',
  '.............kkkSSSSSSSSsSSSSSSskkk.............',
  '...............kSSSSSSSSsSSSSSSsk...............',
  '...............kSSSSSSSLSsSSSSSsk...............', // 24 нос
  '................kSSSSSzsszSSSSsk................',
  '................kSSSSSSSSSSSSSsk................',
  '.................kSSSmmmmmmSSsk.................', // 27 рот
  '..................kSSSppppSssk..................',
  '...................kSbbbbbbsk...................', // 29 щетина на подбородке
  '...................kkZZZZZZkk...................',
  '....................kszzzzsk....................',
  '................kkkwwszzzzswwkkk................', // 32 воротник
  '...............kkkIwwwwTrvvvvIkkk...............', // 33 узел галстука
  '............kkkJJJIwwwwTrvvvvIjjjkkk............',
  '.........kkkjjjjJJJIwwwrRvvvIjjjiiiikkk.........',
  '......kkkjjjjjjjJJJIwwwrRvvvIjjjiiiiiiikkk......',
  '...kkkjjjjjjjjjjjJJJIwwrRvvIjjjiiiiiiiiiiikkk...',
  '.kkkjjjjjjjjjjjjjJJJIwwrRvvIjjjiiiiiiiiiiiiikkk.',
  'kkkjjjjjjjjjjjjjjjJJJIwrRvIjjjiiiiiiiiiiiiiiikkk', // 39 край обычной иконки
  'jjjjjjjjjjjjjjjjjjJJJIwrRvIjjjiiiiiiiiiiiiiiiiii',
  'jjjjjjjjjjjjjjjjjjjJJJIrRIjjjiiiiiiiiiiiiiiiiiii',
  'jjjjjjjjjjjjjjjjjjjJJJIrRIjjjiiiiiiiiiiiiiiiiiii',
  'jjjjjjjjjjjjjjjjjjjJJJIrRIjjjiiiiiiiiiiiiiiiiiii',
  'jjjjjjjjjjjjjjjjjjjJJJIrRIjjjiiiiiiiiiiiiiiiiiii',
  'jjjjjjjjjjjjjjjjjjjJJJIrRIjjjiiiiiiiiiiiiiiiiiii',
  'jjjjjjjjjjjjjjjjjjjJJJIrRIjjjiiiiiiiiiiiiiiiiiii',
  'jjjjjjjjjjjjjjjjjjjJJJIrRIjjjiiiiiiiiiiiiiiiiiii', // 47
];

const int _field = 48;
const int _inset = 8;
const int _side = _field - 2 * _inset;

/// Палитра. Кожа — та же тёплая лестница, что у портрета в игре
/// (`kSkinRamp` в `lib/ui/pixel/pixel_portrait.dart`), контур — как у
/// аппаратов. Фон (`.`) не цвет, а свет — см. [_background].
const Map<String, int> _palette = {
  'k': 0xFF1A1410, // контур
  'Z': 0xFF5A3A1E, // кожа: глубокая тень — складка уха, тень под подбородком
  'z': 0xFF8A5A2F, // кожа в тени
  's': 0xFFB27B45, // кожа
  'S': 0xFFD6A063, // кожа на свету
  'L': 0xFFF0C88C, // блик лампы
  'W': 0xFFEAD9BE, // белки — взгляд живой, а не две дырки
  'e': 0xFF171009, // зрачки
  'E': 0xFF2E1E10, // брови и веки
  'm': 0xFF7A3F2C, // верхняя губа
  'p': 0xFFB8705A, // нижняя губа
  'b': 0xFF9C7250, // щетина
  'G': 0xFF7A5A3C, // стрижка на свету
  'H': 0xFF5C412B, // стрижка
  'h': 0xFF3E2A1B, // стрижка в тени
  'J': 0xFF36435A, // пиджак на свету
  'j': 0xFF232C3C, // пиджак
  'i': 0xFF161B26, // пиджак в тени
  'I': 0xFF4C5C78, // кромка лацкана
  'w': 0xFFEDE5D2, // рубашка
  'v': 0xFFC9BFA8, // рубашка в тени
  'T': 0xFFC85A3E, // галстук: узел на свету
  'r': 0xFFA8402A, // галстук
  'R': 0xFF6E2A1C, // галстук в тени
};

/// Прозрачность каждого тона в монохромной иконке Android 13+.
///
/// Система красит такую иконку в цвет темы и смотрит только на альфу. Если
/// оставить силуэт сплошным, выйдет пятно: лицо держится на «дырках» —
/// контуре, зрачках, бровях, губе — и на том, что пиджак бледнее головы.
const Map<String, double> _mono = {
  'k': 0, 'e': 0, 'E': 0, 'm': 0, 'w': 0, 'v': 0, 'I': 0,
  'Z': 1, 'z': 1, 's': 1, 'S': 1, 'L': 1, 'W': 1, 'p': 1,
  'b': 0.7,
  'G': 0.55, 'H': 0.55, 'h': 0.55,
  'J': 0.7, 'j': 0.7, 'i': 0.7,
  'T': 1, 'r': 1, 'R': 1,
};

/// Янтарь кнопки «Продать» ступенями: ореол лампы за головой.
///
/// Тёмный фон, как у старой иконки, на тёмной теме телефона сливался с
/// экраном — от иконки оставалась плавающая банка. Гладкий градиент, который
/// его сменил, под пиксельной фигурой выглядел чужим; ступени — тот же
/// пиксель, что и у Вити. Копия — `icon_background` в `make_banner.py`.
int _background(int x, int y) {
  final d = math.sqrt(math.pow(x - 23.5, 2) + math.pow(y - 21.5, 2));
  if (d < 14) return 0xFFF5BE62;
  if (d < 19) return 0xFFECA744;
  return 0xFFDC8E2E;
}

/// Силуэт, контур, зрачки и брови — зеркальны; свет и галстук — нет.
void _checkSymmetry() {
  const strict = {'.', 'k', 'e', 'E'};
  for (var y = 0; y < _field; y++) {
    for (var x = 0; x < _field ~/ 2; x++) {
      final left = _art[y][x];
      final right = _art[y][_field - 1 - x];
      if ((strict.contains(left) || strict.contains(right)) && left != right) {
        stderr.writeln('строка $y: «$left» в столбце $x, а зеркально — «$right»');
        exit(1);
      }
    }
  }
}

/// Что именно рисуется из поля.
enum _Layer {
  /// Обычная иконка: середина 32×32 с фоном.
  square,

  /// Всё поле с фоном — маскируемая иконка веба.
  full,

  /// Всё поле без фона — передний слой адаптивной иконки Android.
  foreground,

  /// Только фон — задний слой адаптивной иконки.
  background,

  /// Силуэт для тематической иконки Android 13+.
  monochrome,
}

class _Target {
  final String path;
  final int size;
  final _Layer layer;

  /// Скругление углов как доля стороны: 0 — квадрат.
  final double radius;

  /// Поля вокруг скруглённой плашки как доля стороны.
  final double margin;

  const _Target(this.path, this.size, this.layer, {this.radius = 0, this.margin = 0});
}

const _android = 'android/app/src/main/res';
const _ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
const _macos = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';

/// Плотности Android: имя папки → множитель к mdpi.
const Map<String, double> _densities = {
  'mdpi': 1,
  'hdpi': 1.5,
  'xhdpi': 2,
  'xxhdpi': 3,
  'xxxhdpi': 4,
};

List<_Target> _targets() => [
      for (final MapEntry(key: d, value: k) in _densities.entries) ...[
        // Обычная иконка — для Android 7 и старше.
        _Target('$_android/mipmap-$d/ic_launcher.png', (48 * k).round(), _Layer.square),
        // Адаптивная: слой 108dp, из них видно 72 — ровно середину поля.
        // Без неё Android 8+ сажает квадратную иконку в белый круг.
        for (final (name, layer) in [
          ('foreground', _Layer.foreground),
          ('background', _Layer.background),
          ('monochrome', _Layer.monochrome),
        ])
          _Target('$_android/mipmap-$d/ic_launcher_$name.png', (108 * k).round(), layer),
        // Заставка до Android 12. Плотности заданы явно, иначе Android
        // растянет один файл и пиксель-арт поплывёт.
        _Target('$_android/drawable-$d/launch_image.png', (72 * k).round(), _Layer.square,
            radius: 0.22),
      ],
      // iOS режет углы сам и требует непрозрачную иконку.
      for (final (name, size) in [
        ('20x20@1x', 20), ('20x20@2x', 40), ('20x20@3x', 60),
        ('29x29@1x', 29), ('29x29@2x', 58), ('29x29@3x', 87),
        ('40x40@1x', 40), ('40x40@2x', 80), ('40x40@3x', 120),
        ('60x60@2x', 120), ('60x60@3x', 180),
        ('76x76@1x', 76), ('76x76@2x', 152),
        ('83.5x83.5@2x', 167),
        ('1024x1024@1x', 1024),
      ])
        _Target('$_ios/Icon-App-$name.png', size, _Layer.square),
      // macOS, наоборот, рисует иконку как есть: плашку со скруглением и
      // полями задаёт сама картинка (сетка Apple: 824 из 1024).
      for (final size in [16, 32, 64, 128, 256, 512, 1024])
        _Target('$_macos/app_icon_$size.png', size, _Layer.square,
            radius: 0.225 * 824 / 1024, margin: 100 / 1024),
      const _Target('web/icons/Icon-192.png', 192, _Layer.square),
      const _Target('web/icons/Icon-512.png', 512, _Layer.square),
      const _Target('web/icons/Icon-maskable-192.png', 192, _Layer.full),
      const _Target('web/icons/Icon-maskable-512.png', 512, _Layer.full),
      const _Target('web/favicon.png', 32, _Layer.square),
    ];

/// Размеры внутри .ico для Windows: от значка в проводнике до плитки.
const List<int> _icoSizes = [16, 24, 32, 48, 64, 128, 256];
const String _icoPath = 'windows/runner/resources/app_icon.ico';

void main() {
  if (_art.length != _field) {
    stderr.writeln('строк ${_art.length}, а нужно $_field');
    exit(1);
  }
  for (var y = 0; y < _art.length; y++) {
    if (_art[y].length != _field) {
      stderr.writeln('строка $y длиной ${_art[y].length}, а нужно $_field');
      exit(1);
    }
    for (final symbol in _art[y].split('')) {
      if (symbol != '.' && (!_palette.containsKey(symbol) || !_mono.containsKey(symbol))) {
        stderr.writeln('неизвестный символ «$symbol» в строке $y');
        exit(1);
      }
    }
  }

  _checkSymmetry();

  for (final t in _targets()) {
    _write(t.path, _encodePng(_render(t), t.size, t.size));
    stdout.writeln('${t.path}  ${t.size}x${t.size}');
  }

  final ico = _encodeIco([
    for (final size in _icoSizes)
      (size, _encodePng(_render(_Target('', size, _Layer.square, radius: 0.18)), size, size)),
  ]);
  _write(_icoPath, ico);
  stdout.writeln('$_icoPath  ${_icoSizes.join(', ')}');
}

void _write(String path, List<int> bytes) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes);
}

// --- рисование ----------------------------------------------------------

/// Картинка слоя в разрешении поля — один пиксель на символ.
(Uint32List, int) _source(_Layer layer) {
  final n = layer == _Layer.square ? _side : _field;
  final offset = layer == _Layer.square ? _inset : 0;
  final out = Uint32List(n * n);
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      final fx = x + offset;
      final fy = y + offset;
      final symbol = _art[fy][fx];
      final isBackground = symbol == '.';
      out[y * n + x] = switch (layer) {
        _Layer.square || _Layer.full =>
          isBackground ? _background(fx, fy) : _palette[symbol]!,
        _Layer.foreground => isBackground ? 0 : _palette[symbol]!,
        _Layer.background => _background(fx, fy),
        _Layer.monochrome =>
          isBackground ? 0 : (((_mono[symbol]! * 255).round() << 24) | 0xFFFFFF),
      };
    }
  }
  return (out, n);
}

Uint32List _render(_Target t) {
  final (pixels, n) = _source(t.layer);
  final body = (t.size * (1 - 2 * t.margin)).round();
  final scaled = _resample(pixels, n, body);
  if (t.radius == 0 && t.margin == 0) return scaled;

  // Плашка со скруглёнными углами, край сглажен подвыборкой 4×4: лесенка
  // на скруглении — не пиксель-арт, а брак.
  final out = Uint32List(t.size * t.size);
  final start = (t.size - body) ~/ 2;
  final r = t.radius * t.size;
  for (var y = 0; y < body; y++) {
    for (var x = 0; x < body; x++) {
      var inside = 0;
      for (var sy = 0; sy < 4; sy++) {
        for (var sx = 0; sx < 4; sx++) {
          if (_inRoundRect(x + (sx + 0.5) / 4, y + (sy + 0.5) / 4, body.toDouble(), r)) {
            inside++;
          }
        }
      }
      final argb = scaled[y * body + x];
      final alpha = ((argb >> 24) & 0xFF) * inside ~/ 16;
      out[(y + start) * t.size + x + start] = (alpha << 24) | (argb & 0xFFFFFF);
    }
  }
  return out;
}

bool _inRoundRect(double x, double y, double side, double r) {
  final cx = x < r ? r : (x > side - r ? side - r : x);
  final cy = y < r ? r : (y > side - r ? side - r : y);
  final dx = x - cx;
  final dy = y - cy;
  return dx * dx + dy * dy <= r * r;
}

/// Масштаб для пиксель-арта в любой размер.
///
/// Сначала «ближайшим соседом» в целое число раз — не меньше нужного, —
/// потом усреднением вниз до размера. Пиксель остаётся пикселем: при кратном
/// размере это чистое увеличение, при некратном у пикселей мягкий край в
/// одну точку, а не разная ширина. Голое увеличение соседом при 29 или 87
/// точках делало одни пиксели вдвое толще других, а при уменьшении до 16
/// выбрасывало глаза целиком.
Uint32List _resample(Uint32List src, int n, int size) {
  final k = math.max(1, (size / n).ceil());
  final m = n * k;
  if (m == size) {
    final out = Uint32List(size * size);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        out[y * size + x] = src[(y ~/ k) * n + x ~/ k];
      }
    }
    return out;
  }

  // Доли каждого увеличенного пикселя в пикселе результата — по оси.
  List<List<(int, double)>> weights() => [
        for (var o = 0; o < size; o++)
          () {
            final from = o * m / size;
            final to = (o + 1) * m / size;
            return [
              for (var i = from.floor(); i < to.ceil() && i < m; i++)
                (i, math.min(to, i + 1.0) - math.max(from, i.toDouble())),
            ];
          }(),
      ];
  final w = weights();
  final out = Uint32List(size * size);
  for (var oy = 0; oy < size; oy++) {
    for (var ox = 0; ox < size; ox++) {
      // Цвет копится с учётом прозрачности, иначе край переднего слоя
      // адаптивной иконки потемнеет от прозрачного чёрного вокруг.
      var a = 0.0, r = 0.0, g = 0.0, b = 0.0, total = 0.0;
      for (final (iy, wy) in w[oy]) {
        for (final (ix, wx) in w[ox]) {
          final p = src[(iy ~/ k) * n + ix ~/ k];
          final weight = wx * wy;
          final alpha = ((p >> 24) & 0xFF) / 255 * weight;
          a += alpha;
          r += ((p >> 16) & 0xFF) * alpha;
          g += ((p >> 8) & 0xFF) * alpha;
          b += (p & 0xFF) * alpha;
          total += weight;
        }
      }
      if (a == 0) continue;
      int c(double v) => (v / a).round().clamp(0, 255);
      final alpha = (a / total * 255).round().clamp(0, 255);
      out[oy * size + ox] = (alpha << 24) | (c(r) << 16) | (c(g) << 8) | c(b);
    }
  }
  return out;
}

// --- ICO ---------------------------------------------------------------
// Внутри .ico лежат обычные PNG — Windows понимает такие с Vista. Файл
// шаблона Flutter был синим логотипом Flutter, его никто не менял.

Uint8List _encodeIco(List<(int, Uint8List)> images) {
  final out = BytesBuilder();
  final header = ByteData(6)
    ..setUint16(0, 0, Endian.little)
    ..setUint16(2, 1, Endian.little) // тип: иконка
    ..setUint16(4, images.length, Endian.little);
  out.add(header.buffer.asUint8List());

  var offset = 6 + 16 * images.length;
  for (final (size, png) in images) {
    final entry = ByteData(16)
      ..setUint8(0, size >= 256 ? 0 : size) // 0 значит 256
      ..setUint8(1, size >= 256 ? 0 : size)
      ..setUint8(2, 0)
      ..setUint8(3, 0)
      ..setUint16(4, 1, Endian.little)
      ..setUint16(6, 32, Endian.little)
      ..setUint32(8, png.length, Endian.little)
      ..setUint32(12, offset, Endian.little);
    out.add(entry.buffer.asUint8List());
    offset += png.length;
  }
  for (final (_, png) in images) {
    out.add(png);
  }
  return out.takeBytes();
}

// --- PNG ---------------------------------------------------------------
// Минимальный кодировщик: цвет 8 бит RGBA, фильтр 0. Пакета `image` в
// зависимостях нет и ради генератора иконок тянуть его в проект незачем.

Uint8List _encodePng(Uint32List pixels, int width, int height) {
  final raw = Uint8List(height * (1 + width * 4));
  var i = 0;
  for (var y = 0; y < height; y++) {
    raw[i++] = 0; // фильтр строки: None
    for (var x = 0; x < width; x++) {
      final argb = pixels[y * width + x];
      raw[i++] = (argb >> 16) & 0xFF;
      raw[i++] = (argb >> 8) & 0xFF;
      raw[i++] = argb & 0xFF;
      raw[i++] = (argb >> 24) & 0xFF;
    }
  }

  final out = BytesBuilder();
  out.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

  final header = BytesBuilder()
    ..add(_uint32(width))
    ..add(_uint32(height))
    ..add([8, 6, 0, 0, 0]);
  out.add(_chunk('IHDR', header.takeBytes()));
  out.add(_chunk('IDAT', ZLibCodec(level: 9).encode(raw) as Uint8List));
  out.add(_chunk('IEND', Uint8List(0)));
  return out.takeBytes();
}

Uint8List _chunk(String type, Uint8List data) {
  final name = ascii.encode(type);
  final body = Uint8List(name.length + data.length)
    ..setAll(0, name)
    ..setAll(name.length, data);
  return Uint8List.fromList([
    ..._uint32(data.length),
    ...body,
    ..._uint32(_crc32(body)),
  ]);
}

List<int> _uint32(int value) =>
    [(value >> 24) & 0xFF, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF];

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
