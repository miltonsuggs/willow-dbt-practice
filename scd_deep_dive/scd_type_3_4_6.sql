-- ============================================================================
-- SCD TYPE 3 (previous value column), TYPE 4 (history table), TYPE 6 (hybrid)
-- Prereq: .read scd_deep_dive/00_setup.sql
-- ============================================================================


-- ----------------------------------------------------------------------------
-- TYPE 3 — Keep only the CURRENT and the PREVIOUS value in extra columns.
-- Use when you need "what was it just before?" but not the full timeline
-- (e.g., current_state + prior_state). Limited: only one step of history.
-- Implementation: latest row = current; second-latest tracked value = previous.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE dim_investor_scd3 AS
WITH ranked AS (
    SELECT
        investor_id, full_name, state, accreditation, changed_at,
        ROW_NUMBER() OVER (PARTITION BY investor_id ORDER BY changed_at DESC) AS rn,
        LEAD(state)         OVER (PARTITION BY investor_id ORDER BY changed_at DESC) AS prior_state,
        LEAD(accreditation) OVER (PARTITION BY investor_id ORDER BY changed_at DESC) AS prior_accreditation
    FROM stg_investor_feed
)
SELECT
    investor_id, full_name,
    state          AS current_state,
    prior_state,
    accreditation  AS current_accreditation,
    prior_accreditation,
    changed_at     AS last_updated
FROM ranked
WHERE rn = 1;

SELECT 'TYPE 3 (current + previous)' AS scd_type;
SELECT * FROM dim_investor_scd3 ORDER BY investor_id;


-- ----------------------------------------------------------------------------
-- TYPE 4 — Split into a CURRENT dimension + a separate HISTORY table.
-- Use when the dimension is queried mostly for current values (keep it small
-- and fast) but you still need full history somewhere. Common in practice.
-- ----------------------------------------------------------------------------
-- current dim (one row per investor, latest)
CREATE OR REPLACE TABLE dim_investor_current AS
SELECT investor_id, full_name, email, state, accreditation, changed_at AS last_updated
FROM stg_investor_feed
QUALIFY ROW_NUMBER() OVER (PARTITION BY investor_id ORDER BY changed_at DESC) = 1;

-- history table (every version, append-only)
CREATE OR REPLACE TABLE dim_investor_history AS
SELECT investor_id, full_name, email, state, accreditation, changed_at AS version_date
FROM stg_investor_feed;

SELECT 'TYPE 4 (current dim)' AS scd_type;
SELECT * FROM dim_investor_current ORDER BY investor_id;
SELECT 'TYPE 4 (history table)' AS scd_type;
SELECT * FROM dim_investor_history ORDER BY investor_id, version_date;


-- ----------------------------------------------------------------------------
-- TYPE 6 — Hybrid "1+2+3": a Type-2 history row that ALSO carries the current
-- value on every row (so you can group all of an investor's history by their
-- CURRENT attribute without a self-join). The name = 1+2+3.
-- Implementation: build Type 2, then join the current value back onto every row.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE dim_investor_scd6 AS
WITH ordered AS (
    SELECT investor_id, state, accreditation, email, changed_at,
           LAG(state)         OVER w AS prev_state,
           LAG(accreditation) OVER w AS prev_accr,
           LAG(email)         OVER w AS prev_email
    FROM stg_investor_feed
    WINDOW w AS (PARTITION BY investor_id ORDER BY changed_at)
),
changes_only AS (
    SELECT investor_id, state, accreditation, email, changed_at
    FROM ordered
    WHERE prev_state IS NULL OR state<>prev_state OR accreditation<>prev_accr OR email<>prev_email
),
versioned AS (
    SELECT investor_id, state, accreditation, email,
           changed_at AS valid_from,
           LEAD(changed_at) OVER (PARTITION BY investor_id ORDER BY changed_at) AS valid_to_raw
    FROM changes_only
),
current_vals AS (
    SELECT investor_id, state AS current_state, accreditation AS current_accreditation
    FROM stg_investor_feed
    QUALIFY ROW_NUMBER() OVER (PARTITION BY investor_id ORDER BY changed_at DESC) = 1
)
SELECT
    v.investor_id,
    v.state          AS historical_state,        -- Type 2: the value during this interval
    c.current_state,                             -- Type 3/1: the value NOW, on every row
    v.accreditation  AS historical_accreditation,
    c.current_accreditation,
    v.valid_from,
    COALESCE(v.valid_to_raw, DATE '9999-12-31') AS valid_to,
    (v.valid_to_raw IS NULL)                     AS is_current
FROM versioned v
JOIN current_vals c USING (investor_id);

SELECT 'TYPE 6 (hybrid 1+2+3)' AS scd_type;
SELECT investor_id, historical_state, current_state, valid_from, valid_to, is_current
FROM dim_investor_scd6
ORDER BY investor_id, valid_from;
