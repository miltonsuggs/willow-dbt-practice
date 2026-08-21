{#
  SCD TYPE 2 via a dbt SNAPSHOT.
  This is dbt's built-in way to track history: each time an investor's `status`
  changes, dbt closes the old row (sets dbt_valid_to) and inserts a new current
  row (dbt_valid_to = null). That's exactly an SCD2 dimension — automated.

  Strategy 'check' compares the columns in check_cols between runs. (The other
  strategy, 'timestamp', uses an updated_at column.) unique_key identifies the
  entity whose history we track: investor_id.

  Run it with:  dbt snapshot --profiles-dir .
  Then inspect:  select * from investor_status_snapshot where investor_id = 2
                 order by dbt_valid_from;
  You'll see dbt_valid_from / dbt_valid_to / dbt_scd_id maintained for you.

  See scd_deep_dive/ for the SAME idea implemented by hand in pure SQL, so you
  understand what this snapshot is doing under the covers.
#}
{% snapshot investor_status_snapshot %}
{{
    config(
      target_schema='snapshots',
      unique_key='investor_id',
      strategy='check',
      check_cols=['status']
    )
}}

-- We snapshot the LATEST status per investor at each run. Because our source is
-- a full history feed, we collapse it to "current status" first; the snapshot
-- then accumulates changes over successive runs into SCD2 history.
select
    investor_id,
    status,
    updated_at
from {{ ref('int_investor_status_deduped') }}
qualify row_number() over (
    partition by investor_id order by updated_at desc, update_id desc
) = 1

{% endsnapshot %}
