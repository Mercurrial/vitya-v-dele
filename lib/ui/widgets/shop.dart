import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../content/game_content.dart' show kGeneratorNames;
import '../../core/formatters.dart';
import '../../engine/production.dart';
import '../../models/upgrade.dart';
import '../pixel/pixel_sprite.dart';
import '../pixel/still_sprites.dart';
import '../theme/garage.dart';
import 'fill_bar.dart';

/// Кнопка покупки. Янтарная — только когда денег хватает: янтарь в игре значит
/// ровно одно — «можно взять».
class BuyButton extends StatefulWidget {
  final String label;

  /// Мелкая строка над ценой: «×10» при покупке пачкой.
  final String? caption;
  final bool affordable;
  final VoidCallback onTap;

  const BuyButton({
    super.key,
    required this.label,
    required this.affordable,
    required this.onTap,
    this.caption,
  });

  /// Уже кнопка не бывает: под палец и под короткую цену.
  static const double minWidth = 84;

  static const double _padX = GS.s3;

  static TextStyle _labelStyle(Color color) =>
      GType.num(size: 13, weight: FontWeight.w700, color: color);

  /// Ширина кнопки с самой длинной ценой — «8.88квд ₽»: три значащие цифры с
  /// точкой, суффикс из трёх букв и рубль (Fmt.money). Шрифт моноширинный,
  /// так что любая цена той же длины не шире. Мерится вместе с разрядкой из
  /// темы: без неё выходило на две точки уже настоящей кнопки.
  static double widest(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(
        text: '8.88квд ₽',
        style: DefaultTextStyle.of(context).style.merge(_labelStyle(GColors.onAmber)),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final w = painter.width;
    painter.dispose();
    return math.max(minWidth, w + 2 * _padX);
  }

  @override
  State<BuyButton> createState() => _BuyButtonState();
}

class _BuyButtonState extends State<BuyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.affordable;
    final caption = widget.caption;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: on ? (_) => setState(() => _down = true) : null,
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      // Отдача — внутри самой покупки: денег может не хватить, и щёлкать в
      // ответ на несостоявшееся действие нечестно.
      onTap: on ? widget.onTap : null,
      child: AnimatedScale(
        scale: _down ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          constraints: const BoxConstraints(minWidth: BuyButton.minWidth, minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: BuyButton._padX, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GR.button - 4),
            gradient: on
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [GColors.amber, GColors.amberDim],
                  )
                : null,
            color: on ? null : GColors.wellBg,
            border: on ? null : Border.all(color: GColors.border),
            boxShadow: on
                ? const [BoxShadow(color: GColors.amberGlow, blurRadius: 14, offset: Offset(0, 4))]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (caption != null)
                Text(
                  caption,
                  style: GType.num(
                    size: 9,
                    weight: FontWeight.w700,
                    color: on ? const Color(0xB32B1A06) : GColors.textLo,
                  ),
                ),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BuyButton._labelStyle(on ? GColors.onAmber : GColors.textMid),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Строка аппарата в списке.
///
/// Слева — тот же спрайт, что стоит в гараже: игрок узнаёт в списке то, что
/// видит на полу, и магазин перестаёт быть ведомостью.
class StillRow extends StatelessWidget {
  final String id;
  final String name;
  final int owned;
  final double output;
  final double cost;
  final bool affordable;
  final bool locked;

  /// Как называется ступень, после которой откроется эта.
  final String? unlockAfter;

  /// Сколько штук уйдёт за одно нажатие. Больше единицы — показываем это на
  /// кнопке, иначе непонятно, за что списали.
  final int buyCount;

  final VoidCallback onBuy;

  const StillRow({
    super.key,
    required this.id,
    required this.name,
    required this.owned,
    required this.output,
    required this.cost,
    required this.affordable,
    required this.locked,
    required this.onBuy,
    this.unlockAfter,
    this.buyCount = 1,
  });

  // Поля и зазоры строки — ими же считается место под название.
  static const double _padLeft = GS.s2;
  static const double _padRight = GS.s3;
  static const double _gapIcon = GS.s3;
  static const double _gapButton = GS.s2;

  /// Место под подписью «ещё 3 → ×2» у кнопки: зазор и сама строка.
  static const double _noteSpace = 12;

  @override
  Widget build(BuildContext context) {
    if (locked) return _LockedRow(id: id, after: unlockAfter);
    final milestone = _Milestone.of(owned);

    return LayoutBuilder(
      builder: (context, c) {
        // Место под название — рядом с самой широкой ценой, а не с этой:
        // тогда оно одно на все строки списка, а с ним и кегль. Рамка — по
        // точке с боков.
        final room = c.maxWidth -
            2 -
            _padLeft -
            _padRight -
            _kStillIcon -
            _gapIcon -
            _gapButton -
            BuyButton.widest(context);

        return Container(
          // Поля по вертикали на точку тоньше, чем у остальных карточек: две
          // купленные строки с названиями в две строки должны целиком влезать
          // в магазин на 320×640 — с полями в 8 точек они вставали впритык.
          padding: const EdgeInsets.fromLTRB(_padLeft, 7, _padRight, 7),
          decoration: BoxDecoration(
            color: GColors.surface2,
            borderRadius: BorderRadius.circular(GR.button),
            border: Border.all(color: affordable ? const Color(0x55E8A33D) : GColors.border),
          ),
          child: Row(
            children: [
              _StillIcon(id: id, owned: owned),
              const SizedBox(width: _gapIcon),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Название — главное в строке, и кегль у всех одинаковый:
                    // длинное переносится, а не ужимается и не режется (см.
                    // stillNameStyle).
                    //
                    // Было иначе: название ужималось каждое само по себе, и на
                    // 320 точках «Бидон эмалированный» выходил мельче соседней
                    // «Трёхлитровой банки» — список выглядел набранным разными
                    // шрифтами. А многоточие ещё раньше делало из
                    // «Трёхлитровой банки» загадку «Трёхлитровая …».
                    //
                    // Строк три, хоть почти всем хватает двух: «Завод
                    // «Кристалл-Витя»» на узком экране рвётся только по
                    // дефису и может встать в три. Его строка выше остальных,
                    // но он и не из первых двух, что обязаны влезать в
                    // магазин целиком.
                    Text(
                      name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: stillNameStyle(context, room),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      owned > 0 ? 'гонит ${Fmt.rate(output)}' : 'ещё не куплен',
                      style: GType.num(
                        size: 11,
                        color: owned > 0 ? GColors.copper : GColors.textLo,
                      ).copyWith(height: 1.25),
                    ),
                    if (owned > 0) ...[
                      const SizedBox(height: 4),
                      FillBar(value: milestone.progress, height: 4, color: GColors.copper),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: _gapButton),
              // Подпись «ещё 3 → ×2» — под кнопкой, а не у полоски. Строке
              // аппарата положено не расти, когда название в две строки: на
              // 320×640 магазину отведены ровно две строки (docs/DECISIONS.md,
              // «Главный экран»), и лишние точки он забрал бы у сцены. У
              // полоски подпись была четвёртой строкой колонки, а под
              // кнопкой, ниже значка, место и так пустовало. И по смыслу она
              // там: «купи ещё три — будет вдвое».
              //
              // Подпись висит под кнопкой и ширины колонке не прибавляет:
              // колонка шириной с кнопку, и место под название от подписи не
              // зависит.
              Padding(
                padding: EdgeInsets.only(bottom: owned > 0 ? _noteSpace : 0),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    BuyButton(
                      label: Fmt.money(cost),
                      caption: buyCount > 1 ? '+$buyCount шт.' : null,
                      affordable: affordable,
                      onTap: onBuy,
                    ),
                    if (owned > 0)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: -_noteSpace,
                        height: _noteSpace - 2,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            milestone.note,
                            maxLines: 1,
                            style: GType.num(size: 10, color: GColors.textMid)
                                .copyWith(height: 1.0),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Сторона значка аппарата в строке списка.
const double _kStillIcon = 52;

/// Кегль названий в списке аппаратов — один на весь список.
///
/// Длинное название переносится, но переносу нужны места между словами:
/// слово шире строки Skia рвёт посреди — «Бидон эмалиро / ванный». На 320
/// точках «эмалированный» в кегле 14 шире места под название. Поэтому кегль
/// — наибольший до 14, при котором самое длинное слово лестницы влезает в
/// [room] целиком, и он один на все строки: названия одной величины.
TextStyle stillNameStyle(BuildContext context, double room) {
  final scaler = MediaQuery.textScalerOf(context);
  // Разрядка приходит из темы, и мерить слово надо вместе с ней.
  final base = DefaultTextStyle.of(context).style;
  final size = _nameSizes.putIfAbsent((room, scaler, base.letterSpacing), () {
    double widest(double size) {
      var w = 0.0;
      for (final word in _kNameWords) {
        final painter = TextPainter(
          text: TextSpan(text: word, style: base.merge(_nameStyle(size))),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        w = math.max(w, painter.width);
        painter.dispose();
      }
      return w;
    }

    var size = _kNameSize;
    while (size > _kMinNameSize && widest(size) > room) {
      size -= 0.5;
    }
    return size;
  });
  return _nameStyle(size);
}

TextStyle _nameStyle(double size) =>
    GType.ui(size: size, weight: FontWeight.w600, height: 1.12);

const double _kNameSize = 14;
const double _kMinNameSize = 10;

/// Посчитанные кегли: список строится на каждом тике игры, а мерить слова
/// каждый раз незачем — место под название меняется вместе с экраном.
final _nameSizes = <(double, TextScaler, double?), double>{};

/// Куски названий, между которыми бывает перенос: пробелы и дефис перед
/// буквой. «Дружба-2» по дефису не рвётся: перед цифрой он держит.
final List<String> _kNameWords = [
  for (final g in kGeneratorNames)
    for (final word in g.name.split(' ')) ...word.split(RegExp(r'(?<=-)(?=\D)')),
];

/// Значок аппарата: колодец со спрайтом и счётчиком в углу.
class _StillIcon extends StatelessWidget {
  final String id;
  final int owned;
  const _StillIcon({required this.id, required this.owned});

  @override
  Widget build(BuildContext context) {
    final sprite = stillSpriteFor(id);
    // Целый пиксель, чтобы спрайт в списке был таким же чётким, как на полу.
    final pixel = pixelToFit(sprite, 46, max: 3);

    return SizedBox(
      width: _kStillIcon,
      height: _kStillIcon,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A140F),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: GColors.hairline),
              ),
              alignment: Alignment.center,
              child: PixelImage.scaled(
                sprite: sprite,
                pixel: pixel,
                palette: kStillPalette,
              ),
            ),
          ),
          if (owned > 0)
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: GColors.copper,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: GColors.surface2, width: 2),
                ),
                child: Text(
                  '$owned',
                  style: GType.num(size: 10, weight: FontWeight.w700, color: GColors.textHi),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ещё не открытый аппарат: силуэт и условие.
///
/// Силуэт — самая дешёвая интрига в жанре: видно, что там что-то большое, и
/// не видно, что именно.
class _LockedRow extends StatelessWidget {
  final String id;
  final String? after;
  const _LockedRow({required this.id, required this.after});

  @override
  Widget build(BuildContext context) {
    final sprite = stillSpriteFor(id);
    final pixel = pixelToFit(sprite, 34, max: 2);
    return Container(
      padding: const EdgeInsets.fromLTRB(GS.s2, GS.s2, GS.s3, GS.s2),
      decoration: BoxDecoration(
        color: GColors.surface1,
        borderRadius: BorderRadius.circular(GR.button),
        border: Border.all(color: GColors.hairline),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 36,
            child: Center(
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(Color(0xFF3A2E24), BlendMode.srcIn),
                child: PixelImage.scaled(sprite: sprite, pixel: pixel, palette: kStillPalette),
              ),
            ),
          ),
          const SizedBox(width: GS.s3),
          Expanded(
            child: Text(
              after == null ? 'Следующая ступень' : 'Откроется, когда купишь «$after»',
              maxLines: 2,
              style: GType.ui(size: 12, color: GColors.textLo, height: 1.25),
            ),
          ),
        ],
      ),
    );
  }
}

/// Путь до следующего удвоения — показывает, что скачок близко.
class _Milestone {
  /// Доля пути от прошлого удвоения до следующего.
  final double progress;

  /// «ещё 3 → ×2» или «×64 · предел».
  final String note;

  const _Milestone._(this.progress, this.note);

  factory _Milestone.of(int owned) {
    final steps = Production.milestoneSteps(owned);
    final mult = Production.milestoneMultiplier(owned).toInt();
    if (steps >= Production.milestones.length) return _Milestone._(1, '×$mult · предел');
    final next = Production.milestones[steps];
    final prev = steps > 0 ? Production.milestones[steps - 1] : 0;
    return _Milestone._((owned - prev) / (next - prev), 'ещё ${next - owned} → ×${mult * 2}');
  }
}

/// Ось улучшения: что именно оно двигает.
///
/// Улучшения конкурируют между собой — объём против цены против бака, — и
/// различать их надо до чтения описания. Цвет и короткое слово дают это за
/// долю секунды.
({String label, Color color}) upgradeAxis(UpgradeTarget t) => switch (t) {
      UpgradeTarget.heatControl => (label: 'ЖАР', color: GColors.green),
      UpgradeTarget.tankCapacity => (label: 'БАК', color: GColors.cold),
      UpgradeTarget.quality => (label: 'ЦЕНА', color: GColors.amber),
      UpgradeTarget.generatorOutput => (label: 'ОБЪЁМ', color: GColors.copper),
      UpgradeTarget.allGenerators => (label: 'ОБЪЁМ', color: GColors.copper),
      UpgradeTarget.synergyCoupling => (label: 'СВЯЗКА', color: GColors.lamp),
      UpgradeTarget.synergyResonance => (label: 'СВЯЗКА', color: GColors.lamp),
    };

/// Строка улучшения.
///
/// Список, а не сетка: русские названия длинные, в две колонки они
/// превращаются в кашу из переносов.
class UpgradeRow extends StatelessWidget {
  final String name;
  final String effect;
  final UpgradeTarget target;
  final double cost;
  final bool affordable;
  final bool purchased;
  final VoidCallback onBuy;

  const UpgradeRow({
    super.key,
    required this.name,
    required this.effect,
    required this.target,
    required this.cost,
    required this.affordable,
    required this.purchased,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final axis = upgradeAxis(target);
    return Opacity(
      opacity: purchased ? 0.5 : 1.0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(GS.s3, GS.s2 + 2, GS.s3, GS.s2 + 2),
        decoration: BoxDecoration(
          color: GColors.surface2,
          borderRadius: BorderRadius.circular(GR.button),
          border: Border.all(
            color: affordable && !purchased ? const Color(0x55E8A33D) : GColors.border,
          ),
        ),
        child: Row(
          children: [
            // Полоса цвета оси слева — видно ещё до того, как прочитал.
            Container(
              width: 4,
              height: 38,
              decoration: BoxDecoration(
                color: axis.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: GS.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GType.ui(size: 14, weight: FontWeight.w600, height: 1.2),
                  ),
                  const SizedBox(height: 3),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: '${axis.label}  ',
                        style: GType.ui(
                          size: 10,
                          weight: FontWeight.w700,
                          color: axis.color,
                          letterSpacing: 0.8,
                        ),
                      ),
                      TextSpan(text: effect, style: GType.ui(size: 12, color: GColors.textMid)),
                    ]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: GS.s2),
            if (purchased)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: GS.s2),
                child: Text('ЕСТЬ', style: GType.label().copyWith(color: GColors.green)),
              )
            else
              BuyButton(label: Fmt.money(cost), affordable: affordable, onTap: onBuy),
          ],
        ),
      ),
    );
  }
}
