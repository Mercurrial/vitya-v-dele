#!/usr/bin/env python3
"""Значки целей: двадцать штук, каждый нарисован по пикселю.

Первый набор раздавал девять значков на двадцать целей. Второй собирался
примитивами `sprite_lab.py` — прямоугольники и эллипсы, а сверху общие
`shade()` и `outline()`. Аппаратам это подходит, а значки 16×16 выдавало как
сгенерированные: у всех одна чёрная обводка, один блик в левом верхнем углу
и светотень вдоль края силуэта — «подушка», которая лепит объём не по форме
предмета, а по его контуру. Часть без подписи не читалась вовсе: полная
бочка, пачка купюр, кулак, три каски, озеро.

Поэтому значки рисуются здесь строками — так, как рисует человек, — и
правила стиля держатся рисунком, а не общей функцией:

- одна мысль, и она про условие цели (`lib/content/achievements.dart`);
  силуэт, залитый одним цветом, узнаётся;
- свет один — сверху слева; блик и тень кладутся по форме: у стекла — полоса
  вдоль стенки, у дерева блика нет вовсе, у монеты — светлый обод;
- контур выборочный: снаружи тёмный `k`, внутри — тёмный тон своего
  материала (шов между банкой и бидоном — тёмное стекло, а не чёрная линия);
- палитра аппаратов, 3–4 тона на материал, пиксель у всех один.

Глазом легко пропустить два правила — их проверяет `check()`: силуэт
обведён снаружи и нет одиночных крапин посреди ровной заливки.

    python tools/goal_icons_lab.py          — проверить
    python tools/goal_icons_lab.py --dart   — переписать lib/ui/pixel/goal_icons_gen.dart
    python tools/goal_icons_lab.py --png f  — превью: крупно, в натуральную
                                              величину, приглушённо, силуэтом

Смотреть обязательно и в натуральную величину: в сетке целей значок стоит
в 32 точки, а крупное превью прощает то, что на экране сливается.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sprite_lab import PALETTE, T, write_png  # noqa: E402

S = 16

# Огонь светится сам, обводка его бы притушила — у аппаратов так же.
GLOW = set("1234")

# --------------------------------------------------------------------------
# Значки. Порядок — как в сетке целей: пять рядов по четыре.
# --------------------------------------------------------------------------

GOALS = [
    # Первая капля — «подкинуть дров»: полено с торцом и язык пламени.
    ("a_first_tap", [
        "................",
        ".......1........",
        "......11........",
        "......121.......",
        ".....1221.......",
        ".....12321..1...",
        "....123321..11..",
        "....1233321.121.",
        "...12344321.221.",
        "...123444322321.",
        "..kkkkkkkkkkkk..",
        ".kOOoeoooooooek.",
        ".kOeOeeeeeEEeEk.",
        ".kOeoeeEEeeeeEk.",
        ".kooeEEEEEEEEEk.",
        "..kkkkkkkkkkkk..",
    ]),
    # Начало дела: трёхлитровая банка с брагой под капроновой крышкой.
    ("a_first_still", [
        "................",
        "...kkkkkkkkkk...",
        "...kNnnnnnnmk...",
        "...kmmmmmmmmk...",
        "....kGhGGGgk....",
        "...kGHhGGGGgk...",
        "..kGHhGGGGGGgk..",
        "..kGHBBBBBBBgk..",
        "..kGHbbbbbbxgk..",
        "..kGHbbbbbbxgk..",
        "..kGHbbbbbbxgk..",
        "..kGHbbbbbbxgk..",
        "..kGHbbbbbbxgk..",
        "..kGhbbbbbbxgk..",
        "...kGgxxxxxgk...",
        "....kkkkkkkk....",
    ]),
    # Первый рубль: монета со знаком рубля.
    ("a_first_sale", [
        "................",
        ".....kkkkkk.....",
        "...kkddddddkk...",
        "..kddCCCCCCCck..",
        "..kdCCccccCCck..",
        ".kdCCCcCCCcCCck.",
        ".kdCCCcCCCcCCck.",
        ".kdCCCccccCCCck.",
        ".kdCCCcCCCCCCck.",
        ".kdCCccccCCCCck.",
        ".kdCCCcCCCCCCck.",
        "..kCCCcCCCCcck..",
        "..kcCCCCCCccck..",
        "...kkcccccckk...",
        ".....kkkkkk.....",
        "................",
    ]),
    # Целый литр: бутылка с этикеткой.
    ("a_litre", [
        "......kkkk......",
        "......ktrk......",
        "......kRRk......",
        "......kHgk......",
        "......kHgk......",
        ".....kGHGgk.....",
        "....kGHGGGgk....",
        "....kHBBBBxk....",
        "....kHbbbbxk....",
        "....kQqqqqPk....",
        "....kQrrrrPk....",
        "....kQqqqqPk....",
        "....kHbbbbxk....",
        "....kHbbbbxk....",
        "....kgxxxxgk....",
        ".....kkkkkk.....",
    ]),
    # Десяток: ящик, из которого торчат горлышки.
    ("a_ten", [
        "................",
        ".......kk.......",
        "......ktrk......",
        "...kk.kRRk.kk...",
        "..kMmkkHgkktrk..",
        "..kHgkkHgkkHgk..",
        "..kHgkkHgkkHgk..",
        ".kkEEEEEEEEEEkk.",
        ".kOOOOOOOOOOOok.",
        ".kooooooooooeek.",
        ".keeeeeeeeeeeEk.",
        ".kEEEEEEEEEEEEk.",
        ".kOOOOOOOOOOOok.",
        ".kooooooooooeek.",
        ".keeeeeeeeeeeEk.",
        ".kkkkkkkkkkkkkk.",
    ]),
    # Ассортимент: три разных аппарата — банка, бидон, армейская фляга.
    ("a_assortment", [
        "................",
        "......kkkk......",
        ".....kNnnmk.....",
        ".....kmmmmk.....",
        "......kqPk......",
        ".....kQqpPk.kk..",
        "....kQqqppPkMmk.",
        "....kuuuuuUkzvk.",
        ".kkkkQqqppPkZzvk",
        "kNnnmgqqppVZzzvk",
        "kHGGggqqppVZzzvk",
        "kHbbxgqqppVZzzvk",
        "kHbbxgqqppVvvvVk",
        "kHbbxgqqppVZzzvk",
        "kgxxggPPPPVvzvVk",
        ".kkkkkkkkkkkkkk.",
    ]),
    # Под завязку: бочка налита выше края, по бокам бежит через край.
    # Бак в игре — канистры и цистерны, а «полон» лучше всего видно по
    # переливу. Манометр со стрелкой в красном читался как гриб и тарелка.
    ("a_full_tank", [
        "................",
        "....kkkkkkkk....",
        "..kkbBwwBbbbkk..",
        ".kbBBBbbbbbbbxk.",
        ".kobbbbbbbbbxek.",
        "kBkOOoooooeeEkBk",
        "kbkjjjjjjjjjikbk",
        "kbkOooooeeeeEkxk",
        ".kkOoooeeeeeEkk.",
        ".kOooooeeeeeeEk.",
        ".kjjjjjjjjjjjik.",
        ".kOooooeeeeeeEk.",
        "..kOoooeeeeeEk..",
        "..kjjjjjjjjjik..",
        "...kkkkkkkkkk...",
        "................",
    ]),
    # Первая тысяча: пачка купюр в банковской ленте, торец пачки внизу.
    ("a_thousand", [
        "................",
        "................",
        "................",
        ".kkkkkkkkkkkkkk.",
        "kZZZZZqQZZZZZZzk",
        "kZvvvvqpvvvvvZzk",
        "kZvZZZqpZZZZvZzk",
        "kZvZZZqpZZZZvZzk",
        "kZvZZZqpZZZZvZzk",
        "kZvvvvqpvvvvvZzk",
        "kzzzzzqpzzzzzzvk",
        "kZZZZZqpZZZZZZzk",
        "kvvvvvpPvvvvvvVk",
        "kZZZZZqpZZZZZZzk",
        "kvvvvvpPvvvvvvVk",
        ".kkkkkkkkkkkkkk.",
    ]),
    # Не бодяжим: розетка качества с галочкой.
    ("a_quality", [
        "....kkkkkkk.....",
        "...ktttttrrk....",
        "..ktTQQQQQrrk...",
        ".ktTQqqqqqqPrk..",
        ".ktQqqqqqqqvPrk.",
        ".ktQqqqqqqvvPrk.",
        ".ktQvqqqqvvqPrk.",
        ".ktQvvqqvvqqPrk.",
        ".krqqvvvvqqqPrk.",
        ".krqqqvvqqqPPRk.",
        "..krPqqqqPPPRk..",
        "...kRrPPPPRRk...",
        "...krRkkkkrRk...",
        "..krRk....krRk..",
        "..krRk....krRk..",
        "..kkk......kkk..",
    ]),
    # Тара нашлась: канистра — первое улучшение бака так и зовётся.
    ("a_tank_up", [
        "................",
        "....kkk..kkkkk..",
        "...kMNmkktttttk.",
        "...kmmmktkkkktk.",
        "..kkRRRRtrrrrtk.",
        ".ktttttttttttrk.",
        ".ktTrrrrrrrrtRk.",
        ".ktrtrrrrrrtrRk.",
        ".ktrrtrrrrtrrRk.",
        ".ktrrrtrrtrrrRk.",
        ".ktrrrrttrrrrRk.",
        ".ktrrrtRRtrrrRk.",
        ".ktrrtRrrRtrrRk.",
        ".ktrtRrrrrRtrRk.",
        ".krRRRRRRRRRRRk.",
        "..kkkkkkkkkkkk..",
    ]),
    # Рука набита — пятьсот раз подкинуть дров: топор в колоде. Кулак
    # прошлого набора читался булкой.
    ("a_hands", [
        "................",
        "..............k.",
        ".............kOk",
        "............kOek",
        "...........kOek.",
        "..........kOek..",
        "...kkkkk.kOek...",
        "..kNNnnnkOek....",
        "..knnnnmOek.....",
        ".kkkmmmmekkkkkk.",
        "kOOOOOmmOOOOOOek",
        "kOoooeeeeoooOOek",
        "keOOooooooOOeeEk",
        "koooEeeeeEeeeEEk",
        "keooEeeeeEeeEEEk",
        ".kkkkkkkkkkkkkk.",
    ]),
    # Дедово наследство: медный куб, отвод и приёмная банка — как «Дедов»
    # на полке.
    ("a_dedov", [
        "................",
        "................",
        "...kkkk.........",
        "..kdDdCkkkkkkk..",
        "..kCddCdCCCCCck.",
        "...kkCkkkkkkkck.",
        "..kkdCckk...kck.",
        ".kdDdCCCck..kck.",
        "kdDdCCCCcck.kck.",
        "kdDCCCCCcckkkkkk",
        "kddCCCCCcckHHGgk",
        "kcccccccccckbbxk",
        "kdDCCCCCcckHbbxk",
        "kdCCCCCCcckHbbxk",
        ".kcccccccckgxxgk",
        "..kkkkkkkk.kkkk.",
    ]),
    # Сотня: штабель ящиков. Десяток — один ящик, сотня — гора.
    ("a_hundred", [
        "................",
        "................",
        "................",
        ".....kkkkk......",
        ".....kOOok......",
        ".....kEEEk......",
        ".....koeek......",
        "...kkkkkkkkk....",
        "...kOOokOOok....",
        "...kEEEkEEEk....",
        "...koeekoeek....",
        ".kkkkkkkkkkkkk..",
        ".kOOokOOokOOok..",
        ".kEEEkEEEkEEEk..",
        ".koeekoeekoeek..",
        ".kkkkkkkkkkkkk..",
    ]),
    # Миллион: мешок с рублём.
    ("a_million", [
        "................",
        ".....kk..kk.....",
        "....kqpkkqPk....",
        ".....kqppPk.....",
        "......kEEk......",
        ".....kqqpPk.....",
        "....kqQqppPk....",
        "...kqQqeeepPk...",
        "..kqQqqepqepPk..",
        "..kqQqqepqepPk..",
        "..kqQqqeeepPPk..",
        "..kqqqqepppPPk..",
        "..kqqqeeeepPPk..",
        "..kpqqqepppPPk..",
        "...kPpppPPPPk...",
        "....kkkkkkkk....",
    ]),
    # Бригада: бригадир в каске. Три каски пирамидой читались кочками.
    ("a_brigade", [
        "................",
        "......kkkk......",
        "....kk4433kk....",
        "...k44333332k...",
        "...k43333322k...",
        "..k4333333222k..",
        ".k333333333222k.",
        ".kk2222222222kk.",
        "..kCCCCCCCCcck..",
        "..kdkkddddkkck..",
        "..kdDddddddcck..",
        "..kddEEEEEEcck..",
        "...kdEddddEck...",
        "..kkkcccccckkk..",
        ".kluukkkkkkuuUk.",
        "kluuuuu22uuuuUUk",
    ]),
    # Всё по науке: раскрытая книга с закладкой.
    ("a_synergy", [
        "................",
        "................",
        "..kkkk....kkkk..",
        ".kQQqqkkkkqqqPk.",
        ".kQPPPqPPqPPPPk.",
        ".kQqqqqPPqqqqPk.",
        ".kQPPPPPPqPPPPk.",
        ".kQqqqqPPqqqqPk.",
        ".kQPPPqPPqPPPPk.",
        ".kQqqqqPPqqqqPk.",
        ".kqqqqqPPqqqqPk.",
        "kkkkkkkkkkkkkkkk",
        "kuluuuuuruuuuuUk",
        ".kkkkkkkrkkkkkk.",
        ".......krk......",
        "........k.......",
    ]),
    # Утро добрым не бывает — лечь проспаться: Витя под одеялом, «Z».
    ("a_first_hangover", [
        "..........LLLLL.",
        ".............L..",
        ".....llll...L...",
        ".......l...L....",
        "......l...LLLLL.",
        ".....llll.......",
        ".kk.............",
        "kekkkkk.........",
        "kekQkEEk........",
        "kekqkdDdkkkkkkk.",
        "kekqkdddkLlllluk",
        "kekkkkkkuuuuuuUk",
        "keOOOOOOOOOOOOok",
        "kEEEEEEEEEEEEEEk",
        "kekkkkkkkkkkkkek",
        "kkk..........kkk",
    ]),
    # Мудрость приходит: сова.
    ("a_wise", [
        "................",
        "..kk........kk..",
        "..kOk......kok..",
        "..kOOkkkkkkoek..",
        ".kOOOoooooooeek.",
        ".kOoqqooooqqoek.",
        ".kOQkkqooqkkqek.",
        ".kOqkkq32qkkPek.",
        ".kOoqPo21oqPoek.",
        ".kOoooooooooeek.",
        ".koeOOOOOOOoeEk.",
        ".koeoOoOoOooeEk.",
        ".koeOoOOOoOoeEk.",
        "..keoOOOOOooEk..",
        "...kk22kk22kk...",
        ".....kk..kk.....",
    ]),
    # И снова здравствуйте — третье похмелье: будильник.
    ("a_again", [
        "..kk........kk..",
        ".kNnk......knmk.",
        "kNnmk.kkkk.knmmk",
        "kmmkkkttrrkkkmmk",
        ".kkktQQQQqrrkkk.",
        "...ktQqqiqqqrk..",
        "..ktQqqqiqqqqrk.",
        "..ktqqqqiqqqqrk.",
        "..ktqqqqiiiqqRk.",
        "..krqqqqqqqqqRk.",
        "..krqqqqqqqqPRk.",
        "...krqqqqqqPRk..",
        "...kRrPPPPPRRk..",
        "....kkRRRRRkk...",
        "...kk.kkkkk.kk..",
        "..kk.........kk.",
    ]),
    # Своё озеро: пруд с рогозом. Прошлое «озеро» было цвета самогона и
    # читалось сыром; вода синяя — иначе это не озеро.
    ("a_legacy", [
        "................",
        "..kk............",
        ".keEk...........",
        ".keEk..kk.......",
        ".keEk.keEk......",
        "..kzk.keEk......",
        "..kzk.keEk......",
        "..kzk..kzk......",
        "..kzkkkkzkkkkk..",
        ".kZzlllllllllzk.",
        "kZzuuLLLuuuuuuzk",
        "kzuuuuuuuulllUzk",
        "kzuullluuuuuuUzk",
        ".kzuuuuuuuuUUzk.",
        "..kkzzzzzzzzkk..",
        "....kkkkkkkk....",
    ]),
]


# --------------------------------------------------------------------------
# Проверки
# --------------------------------------------------------------------------


def _parts(rows):
    """Связные куски рисунка (соседи по стороне), каждый — множество клеток."""
    seen = set()
    parts = []
    for y in range(S):
        for x in range(S):
            if rows[y][x] == T or (x, y) in seen:
                continue
            part, stack = set(), [(x, y)]
            while stack:
                cx, cy = stack.pop()
                if (cx, cy) in seen or not (0 <= cx < S and 0 <= cy < S) or rows[cy][cx] == T:
                    continue
                seen.add((cx, cy))
                part.add((cx, cy))
                stack += [(cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)]
            parts.append(part)
    return parts


def check_icon(gid, rows):
    problems = []
    if len(rows) != S or any(len(r) != S for r in rows):
        return [f"{gid}: не {S}×{S}"]
    unknown = {ch for r in rows for ch in r if ch != T and ch not in PALETTE}
    if unknown:
        problems.append(f"{gid}: нет в палитре {''.join(sorted(unknown))}")

    # Силуэт обведён снаружи. Без обводки значок на тёмной ячейке теряет
    # край, а с ней в разных местах выходит «то обведено, то нет». Кроме огня
    # и отдельных знаков без контура вовсе — «Z» над кроватью.
    loose = set()
    for part in _parts(rows):
        if all(rows[y][x] != "k" for x, y in part):
            loose |= part
    for y in range(S):
        for x in range(S):
            ch = rows[y][x]
            if ch in (T, "k") or ch in GLOW or (x, y) in loose:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < S and 0 <= ny < S and rows[ny][nx] == T:
                    problems.append(f"{gid}: ({x},{y}) «{ch}» на краю силуэта без контура")
                    break

    # Одиночная крапина посреди ровной заливки. Диагональ — не крапина:
    # у неё есть сосед того же цвета по углу.
    for y in range(1, S - 1):
        for x in range(1, S - 1):
            ch = rows[y][x]
            if ch in (T, "k"):
                continue
            around = {rows[y - 1][x], rows[y + 1][x], rows[y][x - 1], rows[y][x + 1]}
            corners = {rows[y - 1][x - 1], rows[y - 1][x + 1], rows[y + 1][x - 1], rows[y + 1][x + 1]}
            if len(around) == 1 and ch not in around and ch not in corners:
                problems.append(f"{gid}: ({x},{y}) «{ch}» — одиночная крапина")
    return problems


def check():
    problems = []
    for gid, rows in GOALS:
        problems += check_icon(gid, rows)
    drawn = ["|".join(rows) for _, rows in GOALS]
    if len(set(drawn)) != len(drawn):
        problems.append("два значка одинаковые")
    return problems


# --------------------------------------------------------------------------
# Превью
# --------------------------------------------------------------------------


def _rgb(ch):
    v = PALETTE[ch]
    alpha = ((v >> 24) & 0xFF) / 255 if v > 0xFFFFFF else 1.0
    return ((v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF), alpha


def preview(path, big=6, per_row=4):
    """Крупно, а под каждым — натуральная величина трижды.

    Натуральная — 32 точки, как в сетке целей: на ячейке взятой цели, на
    невзятой (там значок приглушён до 0.3) и силуэтом одного цвета — узнаётся
    ли предмет по одной форме.
    """
    small = 2
    cell_w = max(S * big, 3 * (S * small + 8)) + 12
    cell_h = S * big + 8 + S * small + 8 + 12
    rows_n = (len(GOALS) + per_row - 1) // per_row
    W, H = per_row * cell_w + 12, rows_n * cell_h + 12
    px = [[(0x1E, 0x18, 0x11)] * W for _ in range(H)]

    def fill(x0, y0, w, h, c):
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                px[y][x] = c

    def draw(rows, x0, y0, s, alpha=1.0, flat=None):
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch == T:
                    continue
                c, a = _rgb(ch)
                c, a = (flat or c), a * alpha
                for sy in range(s):
                    for sx in range(s):
                        X, Y = x0 + x * s + sx, y0 + y * s + sy
                        o = px[Y][X]
                        px[Y][X] = tuple(round(oo + (cc - oo) * a) for oo, cc in zip(o, c))

    for i, (_, rows) in enumerate(GOALS):
        cx = 12 + (i % per_row) * cell_w
        cy = 12 + (i // per_row) * cell_h
        fill(cx, cy, S * big, S * big, (0x2A, 0x21, 0x18))
        draw(rows, cx, cy, big)
        sy = cy + S * big + 8
        for k, (bg, alpha, flat) in enumerate((
            ((0x3A, 0x2A, 0x1B), 1.0, None),
            ((0x18, 0x13, 0x0E), 0.3, None),
            ((0x3A, 0x2A, 0x1B), 1.0, (0xE8, 0xA3, 0x3D)),
        )):
            sx = cx + k * (S * small + 8)
            fill(sx, sy, S * small + 4, S * small + 4, bg)
            draw(rows, sx + 2, sy + 2, small, alpha, flat)

    buf = bytearray()
    for row in px:
        for c in row:
            buf += bytes((*c, 255))
    write_png(path, buf, W, H)


# --------------------------------------------------------------------------
# Dart
# --------------------------------------------------------------------------

HEADER = """// СГЕНЕРИРОВАНО tools/goal_icons_lab.py — руками не править.
//
// Поправить значок: изменить его строки в goal_icons_lab.py и запустить
//   python tools/goal_icons_lab.py --dart

part of 'goal_icons.dart';

/// Значки целей по идентификатору достижения, 16×16, палитра аппаратов.
const Map<String, PixelSprite> _kGoalIcons = {"""


def to_dart():
    out = [HEADER]
    for gid, rows in GOALS:
        out.append(f"  '{gid}': PixelSprite([")
        for r in rows:
            out.append(f"    '{r}',")
        out.append("  ]),")
    out.append("};")
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    problems = check()
    if problems:
        print("\n".join(problems))
        sys.exit(1)
    if "--dart" in sys.argv:
        here = os.path.dirname(os.path.abspath(__file__))
        path = os.path.join(here, "..", "lib", "ui", "pixel", "goal_icons_gen.dart")
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(to_dart())
        print("записан", os.path.normpath(path))
    if "--png" in sys.argv:
        out = sys.argv[sys.argv.index("--png") + 1]
        preview(out)
        print("превью", out)
