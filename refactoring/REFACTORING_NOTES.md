# Refactoring the legacy report — narrate your reasoning

The JD says "refactoring dbt models." In an interview you'll be handed something
like `LEGACY_investor_report.sql` and asked to improve it *out loud*. Here's the
reasoning to narrate, mapped to how the `willow/` dbt project already does it.

## 1. Diagnose (say what's wrong before touching it)
- **Repeated correlated subqueries** re-scan `transactions` once per investor per
  metric — slow and duplicative.
- **Business logic is inlined and copied** (the cash-flow sign convention appears
  twice here and would drift over time). No single source of truth.
- **Mixed concerns**: source cleaning, business rules, and presentation are all in
  one query.
- **No grain, no tests, no docs, no reuse.** Any edit is high-risk.

## 2. Establish the grain
The report's grain is **one row per investor**. State that first — it dictates
where every metric must be aggregated to.

## 3. Decompose into layers (staging -> intermediate -> marts)
- **Staging** (`stg_transactions`, `stg_investors`, `stg_funds`,
  `stg_investor_status_updates`): do the casting/cleaning ONCE (the `upper(trim())`,
  type casts, renames). Downstream never re-cleans.
- **Intermediate** (`int_transactions_signed`): compute the signed `cash_flow`
  ONCE using the `signed_cash_flow` macro — kills the duplicated sign logic and
  the magic strings live in one place.
- **Marts**: replace the pile of correlated subqueries with a single
  `GROUP BY investor_id` aggregation (one pass over the data), then join the
  current status from the deduped status model. See `mart_investor_summary.sql`
  in this folder for the rewritten version.

## 4. Make it trustworthy
- Add **tests**: `unique`/`not_null` on `investor_id` (grain), `accepted_values`
  on `txn_type`, `relationships` from transactions to the dims. (Already in the
  staging/marts `.yml` files.)
- Add **docs**: column descriptions + the grain statement, so the model is
  self-explaining and shows up in the dbt docs lineage graph.

## 5. Prove equivalence
Refactoring must not change the numbers. Before/after, compare row counts and a
few investor totals. Only then delete the legacy script.

## The payoff (what to say)
"I turned one 40-line, 8-subquery script into a layered, tested, documented model:
the cleaning happens once in staging, the sign convention lives in one macro, the
metrics are a single grouped pass instead of repeated correlated subqueries, and
the grain is enforced by a uniqueness test. It's faster, and the next person can
change one metric without fear."

---

See `mart_investor_summary.sql` (this folder) for the concrete rewrite. In a real
project it would live under `models/marts/` and `ref()` the staging/intermediate
models; it's placed here next to the legacy file only so the before/after sit
together for study.
