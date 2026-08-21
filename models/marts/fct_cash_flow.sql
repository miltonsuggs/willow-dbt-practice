-- TRANSACTIONAL fact table.
-- GRAIN: one row per transaction (transaction_id).  <- declare grain FIRST.
-- Measures: amount, cash_flow are FULLY ADDITIVE (safe to SUM across any dim).
-- Foreign keys reference conformed dimensions (investor, fund, date).
select
    t.transaction_id,                                   -- degenerate dimension (id kept on the fact)
    di.investor_key,
    df.fund_key,
    dd.date_key,
    t.txn_date,
    t.txn_type,
    t.amount,
    t.cash_flow
from {{ ref('int_transactions_signed') }} t
left join {{ ref('dim_investor') }} di on di.investor_id = t.investor_id
left join {{ ref('dim_fund') }}     df on df.fund_id     = t.fund_id
left join {{ ref('dim_date') }}     dd on dd.date_day    = t.txn_date
