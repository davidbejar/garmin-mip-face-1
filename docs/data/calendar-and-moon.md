# Calendar and moon maths

Connect IQ provides the date but not an ISO week number or a moon phase. Both are computed on the watch with integer
and float arithmetic, without tables of dates.

## ISO 8601 week number

ISO weeks start on Monday, and week 1 is the week that contains the year's first Thursday. So 29–31 December can be
in week 1 of the next year, and 1–3 January can be in week 52 or 53 of the previous one.

### Weekday conversion

`Gregorian.info().day_of_week` runs 1 = Sunday … 7 = Saturday. ISO runs 1 = Monday … 7 = Sunday:

\[
\text{iso} = ((g + 5) \bmod 7) + 1
\]

### Week of the year

\[
w = \left\lfloor \frac{\text{dayOfYear} - \text{isoWeekday} + 10}{7} \right\rfloor
\]

- If \(w < 1\), the date belongs to the last week of the previous year, so return `weeksInYear(year - 1)`.
- If \(w > \) `weeksInYear(year)`, it belongs to week 1 of the next year.

### Weeks in a year (52 or 53)

A year has 53 ISO weeks if **31 December falls on a Thursday**, or if the previous year's 31 December fell on a
Wednesday (that is, the year is a leap year that started on Thursday). The weekday of 31 December comes from a
closed form, with no date objects:

\[
\text{dow}(31\ \text{Dec}\ y) = \left(y + \left\lfloor \tfrac{y}{4} \right\rfloor - \left\lfloor \tfrac{y}{100} \right\rfloor + \left\lfloor \tfrac{y}{400} \right\rfloor\right) \bmod 7 \qquad (0 = \text{Sunday})
\]

```js
function weeksInYear(year as Number) as Number {
    return (yearEndWeekday(year) == 4 || yearEndWeekday(year - 1) == 3) ? 53 : 52;
}
```

### Day of the year

A 12-entry table of days before each month plus one for leap years after February. `isLeapYear` is the full
Gregorian rule (divisible by 4, except centuries, except every 400 years).

!!! example "Boundary cases the algorithm handles"
    | Date | ISO week |
    |------|---------|
    | Thu 1 Jan 2026 | 2026-W01 |
    | Thu 31 Dec 2026 | 2026-W53 (2026 ends on a Thursday) |
    | Fri 1 Jan 2027 | 2026-W53 |
    | Mon 4 Jan 2027 | 2027-W01 |
    | Mon 16 Nov 2026 | 2026-W47 (the mockup's date) |

A line-for-line Python port of `DateUtil` was checked against Python's `date.isocalendar()` for every day from
1990 to 2099 (40,177 days) with no mismatches.

The week text is rebuilt only when the calendar day changes (see
[change keys](../architecture/rendering.md#change-keys)). The midnight rollover (MON 16 → TUE 17, still WK 47) was
checked in the simulator.

## Moon phase

### Phase from a reference new moon

The phase is computed from the **mean synodic month** (29.530588 days) counted from a known new moon, 6 January 2000
18:14 UTC:

\[
\varphi = \operatorname{frac}\!\left(\frac{t - t_0}{86400 \times 29.530588}\right) \in [0, 1)
\]

where 0 is new, 0.25 is first quarter, 0.5 is full and 0.75 is last quarter. The real lunation varies by several hours
around the mean, so this is accurate to within about a day. That is enough for a whole percent and an eight-step
label.

### Percent lit

The illuminated fraction of the disc follows the cosine of the phase angle:

\[
\text{lit} = \frac{1 - \cos(2\pi\varphi)}{2}
\]

### Label

Eight labels centred on the principal phases (`NEW`, `WAX CRES`, `1ST QTR`, `WAX GIB`, `FULL`, `WAN GIB`, `LAST QTR`,
`WAN CRES`), chosen by rounding: `index = round(8φ) mod 8`. "New" therefore covers φ ∈ [0.9375, 0.0625), so the
label changes at the midpoints between principal phases rather than exactly at them.

### Drawing the terminator

The moon icon is drawn as a circle outline in the text colour, with the **unlit** part filled. It is drawn row by row
with no polygon or bitmap. For each pixel row at vertical offset \(dy\) from the centre, the half-width of the disc is
\(w = \sqrt{r^2 - dy^2}\), and the terminator, an ellipse seen edge-on, sits at \(x = w\cos(2\pi\varphi)\):

```js
var k = Math.cos(phase * 2 * Math.PI);
var waxing = phase < 0.5;
for (var y = y0; y < y1; y++) {
    var dy = y + 0.5 - cy;
    var w2 = r * r - dy * dy;
    if (w2 <= 0) { continue; }
    var w = Math.sqrt(w2);
    var x0 = waxing ? cx - w : cx - w * k;     // unlit part: left while waxing,
    var x1 = waxing ? cx + w * k : cx + w;     // right while waning
    dc.fillRectangle(round(x0), y, round(x1) - round(x0), 1);
}
```

This gives a correct crescent, quarter and gibbous shape at any phase, using one `fillRectangle` per row (12 rows at
this size) and no allocation.
