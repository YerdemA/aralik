"""Rounding for the import scripts: halves go up, as people expect.

Python's round() rounds halves to even and works on the binary value, so
round(58.5) is 58 and round(5.935, 2) is 5.93. Answers and fun facts must
read like the published figure rounded by hand: 59 and 5.94.
"""

from __future__ import annotations

from decimal import ROUND_HALF_UP, Decimal


def half_up(value: float, decimals: int = 0) -> int | float:
    result = Decimal(repr(value)).quantize(Decimal(1).scaleb(-decimals), rounding=ROUND_HALF_UP)
    return int(result) if decimals == 0 else float(result)


def turkish_decimal(value: float, decimals: int, *, strip: bool = False, grouping: bool = False) -> str:
    """12345.678, 1 → "12345,7"; with grouping "12.345,7"; strip drops ",0"."""
    text = f"{half_up(value, decimals):{',' if grouping else ''}.{decimals}f}"
    if strip and "." in text:
        text = text.rstrip("0").rstrip(".")
    whole, _, fraction = text.partition(".")
    whole = whole.replace(",", ".")
    return f"{whole},{fraction}" if fraction else whole
