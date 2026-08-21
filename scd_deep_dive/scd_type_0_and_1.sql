-- ============================================================================
-- SCD TYPE 0  (retain original)  and  TYPE 1  (overwrite, no history)
-- Prereq: .read scd_deep_dive/00_setup.sql
-- ============================================================================


-- ----------------------------------------------------------------------------
-- TYPE 0 — Retain the ORIGINAL value; later changes are ignored.
-- Use for immutable facts about the entity (e.g., original signup cohort).
-- Implementation: take the EARLIEST record per investor and keep it forever.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE dim_investor_scd0 AS
SELECT
    investor_id,
    full_name,
    email          AS original_email,
    state          AS original_state,
    accreditation  AS original_accreditation,
    changed_at     AS first_seen_date
FROM stg_investor_feed
QUALIFY ROW_NUMBER() OVER (PARTITION BY investor_id ORDER BY changed_at) = 1;

SELECT 'TYPE 0 (original, immutable)' AS scd_type;
SELECT * FROM dim_investor_scd0 ORDER BY investor_id;


-- ----------------------------------------------------------------------------
-- TYPE 1 — OVERWRITE with the latest value; NO history kept.
-- Use when only the current value matters and history is noise (e.g., fixing a
-- typo in a name). One row per investor, always reflecting the newest record.
-- Implementation: take the LATEST record per investor.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE dim_investor_scd1 AS
SELECT
    investor_id,
    full_name,
    email,
    state,
    accreditation,
    changed_at AS last_updated
FROM stg_investor_feed
QUALIFY ROW_NUMBER() OVER (PARTITION BY investor_id ORDER BY changed_at DESC) = 1;

SELECT 'TYPE 1 (overwrite, current only)' AS scd_type;
SELECT * FROM dim_investor_scd1 ORDER BY investor_id;

-- Note the trade-off: querying dim_investor_scd1 you can NEVER answer
-- "what was investor 1's state in 2023?" — that history was overwritten.
-- That question is exactly what Type 2 (next) exists to answer.
