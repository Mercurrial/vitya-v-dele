import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/main.dart';

/// Строка копирайта из таблицы `name` файла шрифта (запись 0, Windows).
///
/// Сверяется с самим файлом, а не с памятью: копирайт в лицензии обязан
/// совпадать с тем, что написано в шрифте, и замена шрифта без замены
/// лицензии должна ронять тест.
String fontCopyright(String path) {
  final data = ByteData.sublistView(File(path).readAsBytesSync());
  final tables = data.getUint16(4);
  for (var i = 0; i < tables; i++) {
    final rec = 12 + 16 * i;
    final tag = ascii.decode(data.buffer.asUint8List(rec, 4));
    if (tag != 'name') continue;
    final off = data.getUint32(rec + 8);
    final count = data.getUint16(off + 2);
    final strings = off + data.getUint16(off + 4);
    for (var j = 0; j < count; j++) {
      final r = off + 6 + 12 * j;
      if (data.getUint16(r) != 3 || data.getUint16(r + 6) != 0) continue;
      final len = data.getUint16(r + 8);
      final at = strings + data.getUint16(r + 10);
      final units = [
        for (var k = 0; k < len; k += 2) data.getUint16(at + k),
      ];
      return String.fromCharCodes(units);
    }
  }
  throw StateError('В $path нет копирайта');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('лицензии шрифтов зарегистрированы и несут их копирайт', () async {
    registerFontLicenses();
    final entries = await LicenseRegistry.licenses.toList();

    String textOf(String font) => entries
        .where((e) => e.packages.contains(font))
        .expand((e) => e.paragraphs)
        .map((p) => p.text)
        .join('\n');

    const fonts = {
      'Rubik': ['assets/fonts/Rubik-Variable.ttf'],
      'IBM Plex Mono': [
        'assets/fonts/IBMPlexMono-Regular.ttf',
        'assets/fonts/IBMPlexMono-Medium.ttf',
        'assets/fonts/IBMPlexMono-SemiBold.ttf',
        'assets/fonts/IBMPlexMono-Bold.ttf',
      ],
    };
    for (final MapEntry(key: font, value: files) in fonts.entries) {
      final text = textOf(font);
      expect(text, contains('SIL OPEN FONT LICENSE Version 1.1'), reason: font);
      for (final file in files) {
        expect(text, contains(fontCopyright(file)), reason: file);
      }
    }
  });

  test('каждый шрифт из assets/fonts покрыт лицензией', () {
    // Новый шрифт без лицензии раздавать нельзя — пусть это заметит тест.
    final fonts = Directory('assets/fonts')
        .listSync()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.endsWith('.ttf') || n.endsWith('.otf'));
    for (final name in fonts) {
      expect(
        name.startsWith('Rubik-') || name.startsWith('IBMPlexMono-'),
        isTrue,
        reason: '$name: добавить его лицензию в registerFontLicenses',
      );
    }
  });
}
