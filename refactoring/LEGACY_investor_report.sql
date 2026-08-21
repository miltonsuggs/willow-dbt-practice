-- ============================================================================
-- LEGACY_investor_report.sql  — the "before" picture (intentionally BAD)
-- ============================================================================
-- This is the kind of tangled, one-file analyst script the JD means when it
-- says "refactoring dbt models." It works, but it's unmaintainable: no layering,
-- repeated logic, mixed grains, magic strings, casts everywhere, one giant query
-- that nobody dares touch. Your job (see REFACTORING_NOTES.md) is to decompose
-- it into staging -> intermediate -> marts dbt models that are modular, tested,
-- and documented — WITHOUT changing the numbers it produces.
--
-- Read it, spot the problems, then see how the willow/ dbt project already
-- solves each one.
-- ============================================================================

select
    i.investor_id,
    i.first_name || ' ' || i.last_name as investor,
    upper(trim(i.state)) as st,
    -- committed
    (select sum(t.amount) from raw.transactions t
       where t.investor_id = i.investor_id and t.txn_type = 'subscription') as committed,
    -- called (repeats the same correlated-subquery pattern)
    (select sum(t.amount) from raw.transactions t
       where t.investor_id = i.investor_id and t.txn_type = 'capital_call') as called,
    -- distributed
    (select sum(t.amount) from raw.transactions t
       where t.investor_id = i.investor_id and t.txn_type = 'distribution') as distributed,
    -- fees
    (select sum(t.amount) from raw.transactions t
       where t.investor_id = i.investor_id and t.txn_type = 'fee') as fees,
    -- net cash flow: sign logic hardcoded inline (again)
    (select sum(case when t.txn_type in ('capital_call','fee') then -t.amount
                     when t.txn_type in ('distribution','redemption') then t.amount
                     else 0 end)
       from raw.transactions t where t.investor_id = i.investor_id) as net_cash,
    -- current accreditation: latest status, computed with a correlated subquery
    (select s.status from raw.investor_status_updates s
       where s.investor_id = i.investor_id
       order by s.updated_at desc limit 1) as current_status,
    -- fund count
    (select count(distinct t.fund_id) from raw.transactions t
       where t.investor_id = i.investor_id) as fund_count,
    -- biggest single asset class by distribution (join + agg jammed inline)
    (select f.asset_class
       from raw.transactions t join raw.funds f on f.fund_id = t.fund_id
       where t.investor_id = i.investor_id and t.txn_type = 'distribution'
       group by f.asset_class order by sum(t.amount) desc limit 1) as top_asset_class
from raw.investors i
where (select sum(t.amount) from raw.transactions t
        where t.investor_id = i.investor_id and t.txn_type = 'subscription') > 0
order by committed desc nulls last;

-- Problems baked in above:
--   * 8+ correlated subqueries re-scan transactions per investor (slow, repeated).
--   * The sign convention is written inline (here AND wherever else this logic
--     is copied) -> no single source of truth.
--   * Mixed concerns: cleaning (upper/trim), business logic (net cash), and
--     presentation (ordering) all in one 40-line query.
--   * Magic strings ('subscription', etc.) with no validation.
--   * No grain statement, no tests, no docs, no reuse. One change = risk.
