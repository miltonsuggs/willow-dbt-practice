# Willow dbt — dimensional modeling, tests, snapshots & SCD deep dive

A runnable **dbt** project on the same synthetic private-markets dataset as the
SQL and Python practice repos. It turns the Kimball theory from the interview
prep into working models, and pairs a dbt **SCD2 snapshot** with a hand-rolled
**SCD deep dive** in pure SQL so you understand what the snapshot does under the
hood.

Runs entirely locally via **dbt-duckdb** — no cloud warehouse, no credentials.

Each model's header comments name the dimensional-modeling concept it embodies
(grain, conformed dimension, additivity, surrogate vs natural key, etc.), so the
code doubles as study notes.

---

## Quick start

```bash
git clone <your-repo-url> && cd willow-dbt
python -m venv .venv && source .venv/bin/activate      # optional
pip install -r requirements.txt

# build everything: load seeds -> run models -> run tests -> build snapshot
dbt build --profiles-dir .
```

`dbt build` runs seeds, models, tests, and snapshots in dependency order. To run
pieces individually:

```bash
dbt seed     --profiles-dir .     # load the CSVs into DuckDB
dbt run      --profiles-dir .     # build staging/intermediate/marts
dbt test     --profiles-dir .     # run all data tests
dbt snapshot --profiles-dir .     # build/refresh the SCD2 snapshot
dbt docs generate --profiles-dir . && dbt docs serve --profiles-dir .   # lineage graph + docs
```

> The `--profiles-dir .` flag tells dbt to use the `profiles.yml` in this repo
> (which points at a local DuckDB file). In a real job that file lives in
> `~/.dbt/` and holds credentials from env vars.

Inspect results with DuckDB:

```bash
duckdb willow_dbt.duckdb
-- e.g.  select * from snapshots.investor_status_snapshot order by investor_id limit 5;
```

---

## Project layout & what each piece teaches

```
seeds/                     the CSVs, loaded by `dbt seed` (stand-ins for sources)
models/
  staging/                 1:1 with sources; cast/clean/rename; materialized VIEW
    stg_*.sql
    _staging.yml           tests + a documented sources() example
  intermediate/            reusable building blocks; materialized EPHEMERAL
    int_transactions_signed.sql          (signed cash flow via a macro)
    int_investor_status_deduped.sql      (removes the duplicate feed rows)
  marts/                   the STAR SCHEMA; materialized TABLE
    dim_date.sql           conformed, role-playing date dimension
    dim_investor.sql       surrogate + natural key
    dim_fund.sql
    fct_cash_flow.sql      transactional fact; grain = 1 row/transaction; additive
    fct_position_monthly.sql  periodic-snapshot fact; NAV is SEMI-additive
    _marts.yml             tests + docs (grain, relationships)
snapshots/
  investor_status_snapshot.sql   SCD Type 2, automated by dbt
macros/
  signed_cash_flow.sql     Jinja macro: the cash-flow sign convention, DRY
  dbt_surrogate_key.sql    local surrogate-key hasher (dbt_utils equivalent)
tests/
  assert_fct_cash_flow_grain.sql   a SINGULAR test (grain guard)
refactoring/               the "refactoring dbt models" exercise
  LEGACY_investor_report.sql   tangled before
  mart_investor_summary.sql    layered after
  REFACTORING_NOTES.md         what to say while you refactor
scd_deep_dive/             pure-SQL SCD from scratch (see its own README)
```

### Materialization choices (a common interview question)
- **staging = view**: cheap, always current, just a clean passthrough.
- **intermediate = ephemeral**: compiled inline as CTEs; no object created; keeps
  logic DRY without cluttering the warehouse.
- **marts = table**: queried often by BI, so pay the build cost once and read fast.
- **incremental** (not needed at this data size) is what you'd use for large,
  append-heavy facts — see the note below.

### How dbt fits ELT
Data is Extracted + Loaded raw (here, `dbt seed`; in prod, an EL tool or your
Python ingestion repo), then dbt **Transforms it in the warehouse** — staging
cleans, intermediate applies logic, marts model the star. `ref()` wires the DAG
so dbt builds things in the right order and gives you lineage + safe rebuilds.

### Incremental models (concept)
For a large `fct_cash_flow` you'd add:
```sql
{{ config(materialized='incremental', unique_key='transaction_id') }}
select ... from {{ ref('int_transactions_signed') }}
{% if is_incremental() %}
  where txn_date > (select max(txn_date) from {{ this }})   -- only new rows
{% endif %}
```
`unique_key` makes dbt MERGE (update-or-insert) so re-runs don't duplicate —
the same idempotency idea as the Python repo's watermark/upsert.

---

## The SCD story (why both a snapshot and the deep dive)
- `snapshots/investor_status_snapshot.sql` — dbt builds and maintains SCD2
  history for you (`dbt_valid_from` / `dbt_valid_to` / `dbt_scd_id`).
- `scd_deep_dive/` — the SAME idea implemented by hand in SQL for **every SCD
  type (0,1,2,3,4,6)** plus an incremental merge, so you can explain the
  mechanics, not just click the button. Start there if SCD is the concept you
  most want to master.

## Notes
- `dbt 1.12` prints a harmless deprecation warning about generic-test argument
  syntax; the tests still pass. Safe to ignore.
- `target/`, `dbt_packages/`, and `*.duckdb` are gitignored — rebuilt by
  `dbt build`.
