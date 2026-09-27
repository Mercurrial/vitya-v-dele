import 'package:flutter/services.dart';
import 'package:idle_game/ui/theme/garage.dart';

/// Файлы шрифтов игры по семействам.
const kFontFiles = {
  GType.uiFamily: ['Rubik-Variable.ttf'],
  GType.numFamily: [
    'IBMPlexMono-Regular.ttf',
    'IBMPlexMono-Medium.ttf',
    'IBMPlexMono-SemiBold.ttf',
    'IBMPlexMono-Bold.ttf',
  ],
};

/// Загрузить настоящие шрифты игры вместо Ahem.
///
/// Ahem рисует каждый знак квадратом в кегль, и вопрос «влезает ли» он
/// решает неверно: кириллица выходит вдвое шире настоящей. Шрифт, раз
/// загруженный, остаётся на весь файл тестов.
Future<void> loadRealFonts() async {
  for (final MapEntry(key: family, value: files) in kFontFiles.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      loader.addFont(rootBundle.load('assets/fonts/$file'));
    }
    await loader.load();
  }
}

/// Какие знаки есть в семействе шрифтов — по таблице cmap его файлов.
///
/// Знака нет в шрифте — браузер подставит его из запасного, которого CanvasKit
/// скачивает из сети, а без сети нарисует пустой квадрат. На глаз это не
/// проверить: на компьютере разработчика запасной шрифт обычно есть.
Future<Set<int>> fontCodePoints(String family) async {
  Set<int>? common;
  for (final file in kFontFiles[family]!) {
    final points = cmapOf(await rootBundle.load('assets/fonts/$file'));
    common = common == null ? points : common.intersection(points);
  }
  return common!;
}

/// Знаки из таблицы cmap файла TrueType/OpenType: подтаблицы формата 4 и 12.
Set<int> cmapOf(ByteData font) {
  final tables = font.getUint16(4);
  int? cmap;
  for (var i = 0; i < tables; i++) {
    final record = 12 + 16 * i;
    final tag = String.fromCharCodes([for (var k = 0; k < 4; k++) font.getUint8(record + k)]);
    if (tag == 'cmap') cmap = font.getUint32(record + 8);
  }
  if (cmap == null) throw StateError('в шрифте нет таблицы cmap');

  final points = <int>{};
  final subtables = font.getUint16(cmap + 2);
  for (var i = 0; i < subtables; i++) {
    final at = cmap + font.getUint32(cmap + 4 + 8 * i + 4);
    switch (font.getUint16(at)) {
      case 4:
        final segments = font.getUint16(at + 6) ~/ 2;
        final ends = at + 14;
        final starts = ends + segments * 2 + 2;
        for (var s = 0; s < segments; s++) {
          final end = font.getUint16(ends + s * 2);
          for (var c = font.getUint16(starts + s * 2); c <= end && c != 0xFFFF; c++) {
            points.add(c);
          }
        }
      case 12:
        final groups = font.getUint32(at + 12);
        for (var g = 0; g < groups; g++) {
          final group = at + 16 + g * 12;
          final end = font.getUint32(group + 4);
          for (var c = font.getUint32(group); c <= end; c++) {
            points.add(c);
          }
        }
    }
  }
  return points;
}
