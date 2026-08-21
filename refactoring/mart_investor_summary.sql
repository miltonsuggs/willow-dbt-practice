-- ============================================================================
-- mart_investor_summary.sql — the REFACTORED version of the legacy report.
-- Grain: one row per investor. Single grouped pass instead of 8 correlated
-- subqueries; sign logic from the macro; current status from the deduped model.
-- (Shown here for before/after study; in the project this belongs in models/marts/.)
-- ============================================================================
with tx as (
    select * from {{ ref('int_transactions_signed') }}
),
metrics as (                       -- one pass, conditional aggregation
    select
        investor_id,
        sum(case when txn_type = 'subscription' then amount else 0 end) as committed,
        sum(case when txn_type = 'capital_call' then amount else 0 end) as called,
        sum(case when txn_type = 'distribution' then amount else 0 end) as distributed,
        sum(case when txn_type = 'fee'          then amount else 0 end) as fees,
        sum(cash_flow)                                                   as net_cash,
        count(distinct fund_id)                                         as fund_count
    from tx
    group by investor_id
),
current_status as (                -- reuse the deduped/latest logic, don't re-derive
    select investor_id, status as current_status
    from {{ ref('int_investor_status_deduped') }}
    qualify row_number() over (partition by investor_id order by updated_at desc, update_id desc) = 1
)
select
    i.investor_id,
    i.full_name        as investor,
    i.state,
    m.committed, m.called, m.distributed, m.fees, m.net_cash, m.fund_count,
    cs.current_status
from {{ ref('stg_investors') }} i
join metrics m         on m.investor_id = i.investor_id
left join current_status cs on cs.investor_id = i.investor_id
where m.committed > 0
order by m.committed desc
