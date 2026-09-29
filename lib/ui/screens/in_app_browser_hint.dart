/// «Открой игру в Safari» — плашка во встроенном браузере мессенджера.
///
/// Кому — в `core/home_screen.dart` ([InAppBrowser]). Показывается на каждом
/// запуске, а не один раз, как подсказка «на экран Домой»: здесь игре не
/// место, и каждый раз, что игрок сюда попадает, он рискует прогрессом.
/// Уйти или остаться решает он сам — кнопка «Играть здесь» есть.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/home_screen.dart';
import '../theme/garage.dart';
import '../widgets/panel.dart';

/// [link] — адрес игры, который открыть в браузере. Отдельным аргументом,
/// а не `Uri.base` внутри: в снимке экрана адрес должен быть один и тот же.
Future<void> showInAppBrowserHint(
  BuildContext context, {
  required InAppBrowser where,
  required Uri link,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xCC0B0806),
    builder: (context) => InAppBrowserHint(where: where, link: link),
  );
}

/// Адрес страницы без хвостов: мессенджеры дописывают к ссылке метки,
/// переходу они не нужны, а набирать их руками — тем более.
Uri gameLink(Uri page) => Uri(
      scheme: page.scheme,
      host: page.host,
      port: page.hasPort ? page.port : null,
      path: page.path,
    );

class InAppBrowserHint extends StatefulWidget {
  final InAppBrowser where;
  final Uri link;

  const InAppBrowserHint({super.key, required this.where, required this.link});

  @override
  State<InAppBrowserHint> createState() => _InAppBrowserHintState();
}

class _InAppBrowserHintState extends State<InAppBrowserHint> {
  String? _note;

  bool get _ios => widget.where == InAppBrowser.ios;
  String get _browser => _ios ? 'Safari' : 'Chrome';

  /// Адрес для глаз: без «https://» и косой черты в конце — его, может
  /// быть, придётся набрать.
  String get _shownLink {
    final s = widget.link.toString().replaceFirst(RegExp('^https?://'), '');
    return s.endsWith('/') ? s.substring(0, s.length - 1) : s;
  }

  Future<void> _copyLink() async {
    // Встроенный браузер как раз может не дать буфер — тогда адрес на
    // экране, его можно набрать.
    String note;
    try {
      await Clipboard.setData(ClipboardData(text: widget.link.toString()));
      note = 'Ссылка скопирована. Вставь её в адресную строку $_browser.';
    } catch (_) {
      note = 'Браузер не дал скопировать. Набери адрес в $_browser сам.';
    }
    if (mounted) setState(() => _note = note);
  }

  @override
  Widget build(BuildContext context) {
    final strong = GType.body().copyWith(
      color: GColors.textHi,
      fontWeight: FontWeight.w600,
    );
    // Словами, без «⋯», «⋮» и стрелок: их нет в шрифтах игры.
    final open = _ios
        ? 'В меню этого окна — три точки или значок компаса — выбери '
            '«Открыть в Safari».'
        : 'В меню этого окна — три точки — выбери «Открыть в Chrome» или '
            '«Открыть в браузере».';
    final why = _ios
        ? 'Здесь игру не поставить на экран «Домой», а прогресс хранится '
            'отдельно от Safari и сам туда не переедет. В Safari игра '
            'подскажет, как поставить иконку.'
        : 'Здесь игру не установить на телефон, а прогресс хранится отдельно '
            'от Chrome и сам туда не переедет. В Chrome: меню, затем '
            '«Установить приложение» или «Добавить на главный экран».';
    return AlertDialog(
      backgroundColor: GColors.surface1,
      // Крупный шрифт в настройках телефона не должен уносить кнопки за
      // край экрана.
      scrollable: true,
      title: Text('Открой игру в $_browser',
          style: GType.ui(size: 17, weight: FontWeight.w600)),
      // Ширина — как у колонки игры, см. test_save_notice.dart.
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(open, style: strong),
            const SizedBox(height: GS.s3),
            Text(why, style: GType.body()),
            const SizedBox(height: GS.s3),
            Text('Пункта нет — открой в $_browser этот адрес:',
                style: GType.body()),
            const SizedBox(height: GS.s1),
            Text(_shownLink,
                style: GType.num(size: 13, color: GColors.amber)),
            if (_note != null) ...[
              const SizedBox(height: GS.s2),
              Text(_note!, style: GType.num(size: 11, color: GColors.textMid)),
            ],
          ],
        ),
      ),
      // Янтарная кнопка во всю ширину — главное действие, как в подсказке
      // «на экран Домой». Остаться — тихой надписью: можно, но не советуем.
      actions: [
        SizedBox(
          width: double.infinity,
          child: WideButton(
            label: 'СКОПИРОВАТЬ ССЫЛКУ',
            enabled: true,
            onTap: _copyLink,
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Играть здесь', style: GType.body()),
          ),
        ),
      ],
    );
  }
}
