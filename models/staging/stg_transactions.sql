with source as (select * from {{ ref('transactions') }})
select
    cast(transaction_id as integer) as transaction_id,
    cast(investor_id as integer)    as investor_id,
    cast(fund_id as integer)        as fund_id,
    cast(txn_date as date)          as txn_date,
    txn_type,
    cast(amount as bigint)          as amount
from source
