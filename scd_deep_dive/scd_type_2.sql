-- ============================================================================
-- SCD TYPE 2  (full history: a new row per change)
-- Prereq: .read scd_deep_dive/00_setup.sql
-- This is the most important one — and exactly what a dbt snapshot automates.
-- ============================================================================
-- Idea: for each investor, every time a TRACKED attribute changes, close the
-- prior row (set valid_to) and open a new one (valid_from = change date,
-- valid_to = the next change, or 'infinity' for the current row). Add an
-- is_current flag and a surrogate key per version.
--
-- Steps:
--   1) collapse consecutive-identical versions (gaps & islands) so we only keep
--      rows where something actually changed,
--   2) use LEAD() to find each version's end date,
--   3) derive valid_to, is_current, and a surrogate key.
-- ----------------------------------------------------------------------------

-- We track changes in (email, state, accreditation). If a feed row repeats the
-- same tracked values as the previous one, it's not a real change -> drop it.
CREATE OR REPLACE TABLE dim_investor_scd2 AS
WITH ordered AS (
    SELECT
        investor_id, full_name, email, state, accreditation, changed_at,
        LAG(email)         OVER w AS prev_email,
        LAG(state)         OVER w AS prev_state,
        LAG(accreditation) OVER w AS prev_accr
    FROM stg_investor_feed
    WINDOW w AS (PARTITION BY investor_id ORDER BY changed_at)
),
changes_only AS (          -- keep first row per investor + rows where tracked cols changed
    SELECT investor_id, full_name, email, state, accreditation, changed_at
    FROM ordered
    WHERE prev_email IS NULL                                   -- first version
       OR email <> prev_email
       OR state <> prev_state
       OR accreditation <> prev_accr
),
versioned AS (
    SELECT
        investor_id, full_name, email, state, accreditation,
        changed_at AS valid_from,
        LEAD(changed_at) OVER (PARTITION BY investor_id ORDER BY changed_at) AS valid_to_raw
    FROM changes_only
)
SELECT
    md5(cast(investor_id AS VARCHAR) || '-' || cast(valid_from AS VARCHAR)) AS investor_version_key, -- surrogate
    investor_id,                                                            -- natural key
    full_name, email, state, accreditation,
    valid_from,
    COALESCE(valid_to_raw, DATE '9999-12-31')            AS valid_to,       -- open-ended = current
    (valid_to_raw IS NULL)                                AS is_current
FROM versioned;

SELECT 'TYPE 2 (full history)' AS scd_type;
SELECT investor_id, state, accreditation, email, valid_from, valid_to, is_current
FROM dim_investor_scd2
ORDER BY investor_id, valid_from;


-- ---- Using a Type-2 dimension: two canonical queries --------------------

-- (a) CURRENT view (equivalent to a Type-1 dim): just filter is_current.
SELECT 'current rows only' AS view;
SELECT investor_id, state, accreditation, email
FROM dim_investor_scd2
WHERE is_current
ORDER BY investor_id;

-- (b) AS-OF (point-in-time) query: what was each investor's state on a date?
--     This is the whole reason Type 2 exists.
SELECT 'as-of 2023-09-01' AS view;
SELECT investor_id, state, accreditation, email
FROM dim_investor_scd2
WHERE DATE '2023-09-01' >= valid_from
  AND DATE '2023-09-01' <  valid_to
ORDER BY investor_id;
