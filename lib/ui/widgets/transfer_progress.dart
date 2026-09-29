/// Перенос прогресса: выгрузить кодом и принять кодом.
///
/// Нужен потому, что на iPhone игра живёт как сайт, а сейв — в хранилище
/// браузера. Хранилище браузера теряется: при очистке данных сайта, при смене
/// телефона, иногда само. Код — это запасной выход, и он должен быть на виду
/// ДО того, как понадобится, а не после.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/save_code.dart';
import '../../core/sfx.dart';
import '../../providers/feedback_provider.dart';
import '../../providers/game_provider.dart';
import '../theme/garage.dart';

class TransferProgress extends ConsumerStatefulWidget {
  const TransferProgress({super.key});

  @override
  ConsumerState<TransferProgress> createState() => _TransferProgressState();
}

class _TransferProgressState extends ConsumerState<TransferProgress> {
  String? _note;

  // Буфер обмена в браузере — не гарантия, а просьба. Встроенные браузеры
  // мессенджеров, вкладка без фокуса, запрет в настройках, страница не по
  // https — и браузер отказывает. Раньше отказ улетал необработанным
  // исключением: игрок жал «СКОПИРОВАТЬ», не видел ничего и уходил в
  // уверенности, что код у него. Поэтому у обеих кнопок есть ручной путь:
  // код стоит в поле, откуда его копируют, и в поле же его вставляют.
  //
  // К буферу обращаемся первым делом, прямо в нажатии, без единого окна до
  // него: Safari даёт буфер только в ответ на касание.

  Future<void> _copy() async {
    final code = ref.read(gameProvider.notifier).exportCode();
    final copied = await _writeClipboard(code);
    if (!mounted) return;
    if (copied) {
      setState(() => _note = 'Код скопирован. Отправь его себе в сообщения.');
      return;
    }
    setState(() => _note = null);
    await showDialog<void>(
      context: context,
      builder: (context) => _ManualCopyDialog(code: code),
    );
  }

  Future<void> _paste() async {
    // В 1.0.0 сначала спрашивали «Заменить прогресс?», а буфер читали после
    // ответа — уже не в самом касании. И не код в буфере был тупиком: игрок
    // читал «это не похоже на код», а вставить руками было некуда. Теперь
    // любой отказ ведёт в поле, и сказано, почему.
    final clip = await _readClipboard();
    if (!mounted) return;

    String? code;
    final String reason;
    if (clip == null) {
      reason = 'Браузер не дал прочитать буфер обмена.';
    } else if (clip.trim().isEmpty) {
      reason = 'Буфер обмена пуст.';
    } else {
      final parsed = decodeSaveCode(clip);
      code = parsed.isOk ? clip : null;
      reason = 'В буфере обмена: ${_lowerFirst(parsed.message)}.';
    }
    code ??= await showDialog<String>(
      context: context,
      builder: (context) => _CodeDialog(reason: reason),
    );
    if (code == null || !mounted) return;

    final confirmed = await _confirmOverwrite();
    if (!confirmed || !mounted) return;

    final error = await ref.read(gameProvider.notifier).importCode(code);
    if (!mounted) return;
    setState(() {
      // Объяснения живут рядом с самим форматом кода — здесь их не дублируем.
      _note = error == null
          ? 'Прогресс принят.'
          : SaveCodeResult.failed(error).message;
    });
  }

  /// Положить код в буфер. `false` — браузер не дал.
  Future<bool> _writeClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Текст из буфера. `null` — браузер не дал или не умеет читать буфер
  /// (Firefox), пустая строка — в буфере пусто.
  Future<String?> _readClipboard() async {
    try {
      return (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    } catch (_) {
      return null;
    }
  }

  /// Нажатие кнопки: отдача — через общий фасад, чтобы выключатель вибрации
  /// в настройках действовал и здесь.
  void _tap(Future<void> Function() action) {
    ref.read(feedbackProvider).buzz(Buzz.select);
    action();
  }

  /// Приём кода стирает текущий гараж. Спрашиваем прямо: это единственное
  /// место в игре, где одно нажатие может обнулить чужой прогресс.
  Future<bool> _confirmOverwrite() async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GColors.surface1,
        title: Text('Заменить прогресс?',
            style: GType.ui(size: 17, weight: FontWeight.w600)),
        content: Text(
          'Текущий гараж будет стёрт и заменён тем, что в коде. '
          'Если нынешний прогресс дорог — сперва скопируй его.',
          style: GType.body(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Отмена', style: GType.body()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Заменить',
              style: GType.ui(size: 14, weight: FontWeight.w600, color: GColors.hot),
            ),
          ),
        ],
      ),
    );
    return answer ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(GS.s4),
      decoration: BoxDecoration(
        color: GColors.surface1,
        borderRadius: BorderRadius.circular(GR.card),
        border: Border.all(color: GColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ПЕРЕНОС ПРОГРЕССА', style: GType.label()),
          const SizedBox(height: GS.s2),
          Text(
            'Гараж хранится на этом устройстве. Чтобы не потерять его при '
            'смене телефона или очистке браузера — скопируй код и отправь '
            'себе в сообщения.',
            style: GType.body(),
          ),
          const SizedBox(height: GS.s3),
          Row(
            children: [
              Expanded(
                child: _Action(label: 'СКОПИРОВАТЬ', onTap: () => _tap(_copy)),
              ),
              const SizedBox(width: GS.s2),
              Expanded(
                child: _Action(
                  label: 'ВСТАВИТЬ',
                  onTap: () => _tap(_paste),
                  quiet: true,
                ),
              ),
            ],
          ),
          if (_note != null) ...[
            const SizedBox(height: GS.s2),
            Text(_note!, style: GType.num(size: 11, color: GColors.textMid)),
          ],
        ],
      ),
    );
  }
}

String _lowerFirst(String s) =>
    s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

class _Action extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool quiet;

  const _Action({required this.label, required this.onTap, this.quiet = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: quiet ? GColors.wellBg : GColors.copper,
          borderRadius: BorderRadius.circular(GR.pill),
          border: quiet ? Border.all(color: GColors.border) : null,
        ),
        child: Text(
          label,
          style: GType.ui(
            size: 12,
            weight: FontWeight.w700,
            color: quiet ? GColors.textMid : GColors.textHi,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

/// Рамка поля с кодом — одна на оба окна.
InputDecoration _codeBox({String? hint}) => InputDecoration(
      hintText: hint,
      hintStyle: GType.num(size: 11, color: GColors.textLo),
      filled: true,
      fillColor: GColors.wellBg,
      border: const OutlineInputBorder(),
    );

/// Код целиком — скопировать руками, когда браузер не дал сам.
///
/// Поле, а не `SelectableText`: в браузере под полем Flutter лежит настоящий
/// textarea, и «Выбрать все» и «Скопировать» даёт сам телефон. У
/// `SelectableText` копирование шло бы через тот же буфер обмена, который
/// браузер только что не дал. Отдельный виджет — по той же причине, что и
/// [_CodeDialog]: контроллер живёт до конца анимации закрытия.
class _ManualCopyDialog extends StatefulWidget {
  final String code;
  const _ManualCopyDialog({required this.code});

  @override
  State<_ManualCopyDialog> createState() => _ManualCopyDialogState();
}

class _ManualCopyDialogState extends State<_ManualCopyDialog> {
  late final _field = TextEditingController(text: widget.code);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  /// Касание выделяет код целиком: по кусочку его не скопируют, а обрезанный
  /// код игра не примет.
  void _selectAll() => _field.selection =
      TextSelection(baseOffset: 0, extentOffset: _field.text.length);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: GColors.surface1,
      scrollable: true,
      title: Text('Скопируй вручную',
          style: GType.ui(size: 17, weight: FontWeight.w600)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Браузер не дал скопировать сам. Зажми код, выбери «Выбрать все», '
            'затем «Скопировать» — и отправь себе в сообщения.',
            style: GType.body(),
          ),
          const SizedBox(height: GS.s3),
          TextField(
            controller: _field,
            readOnly: true,
            onTap: _selectAll,
            maxLines: 5,
            minLines: 3,
            style: GType.num(size: 11, color: GColors.textMid),
            decoration: _codeBox(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Готово', style: GType.body()),
        ),
      ],
    );
  }
}

/// Диалог с полем для кода: когда буфер не дал код сам.
///
/// [reason] — почему не вышло через буфер; игрок должен понимать, что
/// случилось, а не просто видеть пустое поле. Код проверяется здесь же, и
/// окно не закрывается на ошибке: исправить проще, чем начинать заново.
/// Наружу выходит только годный код, `null` — игрок передумал.
///
/// Отдельный виджет, а не `TextEditingController` в методе экрана: диалог
/// ещё доигрывает анимацию закрытия, когда ответ уже получен, и контроллер,
/// уничтоженный сразу после ответа, ронял поле посреди этой анимации.
class _CodeDialog extends StatefulWidget {
  final String reason;
  const _CodeDialog({required this.reason});

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _field = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _accept() {
    final parsed = decodeSaveCode(_field.text);
    if (parsed.isOk) {
      Navigator.pop(context, _field.text);
    } else {
      setState(() => _error = parsed.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: GColors.surface1,
      // С клавиатурой на телефоне места мало: кнопки не должны уехать.
      scrollable: true,
      title: Text('Вставь код', style: GType.ui(size: 17, weight: FontWeight.w600)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.reason,
              style: GType.body().copyWith(color: GColors.amber)),
          const SizedBox(height: GS.s2),
          Text('Вставь код сюда: зажми поле и выбери «Вставить».',
              style: GType.body()),
          const SizedBox(height: GS.s3),
          TextField(
            controller: _field,
            autofocus: true,
            maxLines: 4,
            minLines: 2,
            style: GType.num(size: 11, color: GColors.textHi),
            decoration: _codeBox(hint: '$kSaveCodePrefix…'),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: GS.s2),
            Text(_error!, style: GType.body().copyWith(color: GColors.hot)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Отмена', style: GType.body()),
        ),
        TextButton(
          onPressed: _accept,
          child: Text(
            'Принять',
            style: GType.ui(size: 14, weight: FontWeight.w600, color: GColors.amber),
          ),
        ),
      ],
    );
  }
}
