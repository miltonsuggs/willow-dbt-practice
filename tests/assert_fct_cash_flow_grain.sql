-- SINGULAR test: a bespoke assertion written as a SELECT that must return ZERO
-- rows to pass. Here we assert the declared grain of fct_cash_flow — one row per
-- transaction_id — holds after all the joins (guards against accidental fan-out).
-- (Generic tests like unique/not_null live in the .yml files; singular tests are
--  for one-off business rules that don't fit a generic.)
select
    transaction_id,
    count(*) as n
from {{ ref('fct_cash_flow') }}
group by transaction_id
having count(*) > 1
