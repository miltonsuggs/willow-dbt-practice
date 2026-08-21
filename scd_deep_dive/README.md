# SCD Deep Dive — Slowly Changing Dimensions by hand, in pure SQL

The single best way to *understand* SCDs (and what a dbt snapshot automates) is
to build each type yourself. These files run on DuckDB, standalone — you don't
need dbt for this folder.

## Run it

```bash
duckdb scd.db
.read scd_deep_dive/00_setup.sql            -- build the changing-dimension feed
.read scd_deep_dive/scd_type_0_and_1.sql
.read scd_deep_dive/scd_type_2.sql
.read scd_deep_dive/scd_type_3_4_6.sql
.read scd_deep_dive/scd_type_2_incremental_merge.sql   -- needs scd_type_2 first
```

(No CLI? From the repo root: `python` + duckdb, or reuse the SQL repo's
`scripts/run.py` pattern. But the DuckDB CLI is the smoothest here.)

## What each file teaches

| File | Type | One-line idea |
|---|---|---|
| `scd_type_0_and_1.sql` | 0 | keep the ORIGINAL value forever (immutable) |
| | 1 | OVERWRITE to the latest; no history |
| `scd_type_2.sql` | 2 | new row per change; `valid_from`/`valid_to`/`is_current`; as-of queries |
| `scd_type_3_4_6.sql` | 3 | current + one previous value in extra columns |
| | 4 | small current dim + separate history table |
| | 6 | hybrid 1+2+3: history rows that also carry the current value |
| `scd_type_2_incremental_merge.sql` | 2 | apply a NEW batch: close the open row, insert the new one (what a snapshot does each run) |

## The mental model to carry into the interview

- **Grain of a Type-2 row** = one row per entity per *version* (per validity
  interval). The natural key (`investor_id`) repeats; a surrogate key
  (`investor_version_key`) is unique per row.
- **The core trick** is gaps-and-islands: compare each incoming record to the
  previous one (`LAG`) and only open a new version when a *tracked* attribute
  changed. `LEAD` then supplies each version's `valid_to`.
- **`valid_to` conventions**: either `NULL` or a sentinel like `9999-12-31` marks
  the current row. As-of queries use `date >= valid_from AND date < valid_to`.
- **Choosing a type**: Type 1 when only "now" matters; Type 2 when you must
  report history "as it was" (accreditation, address — regulated attributes);
  Type 3 when you only need the immediately prior value; Type 4 to keep the
  current dim lean; Type 6 when you want as-of history *and* easy grouping by the
  current value.
- **A dbt snapshot = Type 2, automated.** It runs the incremental-merge logic
  from the last file every time it executes, maintaining
  `dbt_valid_from`/`dbt_valid_to` for you.
