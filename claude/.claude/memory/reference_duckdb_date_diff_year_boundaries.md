---
name: duckdb date_diff('year') counts calendar boundaries, not elapsed years
description: "DuckDB date_diff('year', birth, d) returns the number of year boundaries crossed, so an age computed with it is overstated for anyone whose birthday has not yet come in d's year; use date_sub('year', ...) or year(age(d, birth)) for elapsed years"
metadata:
  type: reference
---

`date_diff('year', a, b)` in DuckDB counts the calendar-year boundaries between the two dates, not the years elapsed between them.
`date_diff('year', DATE '2007-12-31', DATE '2025-01-01')` is 18 for a person who is 17 years and 2 days old.
Any age or "is a minor" derived this way overstates the age, silently, with no warning and a plausible-looking result.

**How to apply:** use `date_sub('year', birth, d)` (complete elapsed periods, 17 in the case above) or `year(age(d, birth))`, or `(d - birth) / 365.25` where a fractional age is wanted.
The same holds for `'month'` and the other parts: `date_diff` counts boundaries, `date_sub` counts complete periods.
When an age threshold decides a count (a minor, an adult inclusion), compute it by two of these forms and compare before publishing a figure.

**Why:** measured 2026-11-13 in `eds-prise` on the 3,562 patients with a typed shoulder consultation over 2021 to 2025.
`date_diff('year', DATENAIS, first_consultation)` gave 37 minors overall (24 among the 54 patients absent from the collected `pat` table, 13 among the 3,508 present) and 30 adults among the absent; the elapsed-year age gave 57 minors overall (28 absent, 29 present) and 26 adults among the absent.
A fresh reread of the written note by an independent verifier caught the discrepancy; the figures had been given to the user in conversation first.
Checked on DuckDB 2.0.0.
