-- ============================================================================
-- SCD DEEP DIVE — SETUP
-- ============================================================================
-- A hands-on, pure-SQL walkthrough of Slowly Changing Dimensions, so you
-- understand what a dbt snapshot does under the hood. Runs on DuckDB:
--
--     duckdb scd.db
--     .read scd_deep_dive/00_setup.sql
--     .read scd_deep_dive/scd_type_2.sql     (etc.)
--
-- We model ONE investor dimension whose attributes change over time. The raw
-- feed below is what an upstream system sends: the SAME investor_id appearing
-- multiple times as their `state`, `accreditation`, and `email` change.
-- ============================================================================

CREATE OR REPLACE TABLE stg_investor_feed (
    investor_id   INTEGER,
    full_name     VARCHAR,
    email         VARCHAR,
    state         VARCHAR,
    accreditation VARCHAR,     -- Pending -> Accredited -> Suspended, etc.
    changed_at    DATE         -- when the source observed this version
);

INSERT INTO stg_investor_feed VALUES
-- investor 1: moves NY->NJ, gets accredited, changes email
(1, 'Ava Suggs',  'ava@old.com',  'NY', 'Pending',        DATE '2023-01-10'),
(1, 'Ava Suggs',  'ava@old.com',  'NY', 'Accredited',     DATE '2023-06-01'),
(1, 'Ava Suggs',  'ava@new.com',  'NJ', 'Accredited',     DATE '2024-02-15'),
-- investor 2: accredited then suspended then reinstated
(2, 'Liam Nguyen','liam@x.com',   'CA', 'Accredited',     DATE '2023-03-05'),
(2, 'Liam Nguyen','liam@x.com',   'CA', 'Suspended',      DATE '2024-01-20'),
(2, 'Liam Nguyen','liam@x.com',   'CA', 'Accredited',     DATE '2024-09-09'),
-- investor 3: single record, never changes
(3, 'Mia Patel',  'mia@x.com',    'TX', 'Accredited',     DATE '2023-11-11');

-- The "new batch" that arrives LATER (used by the incremental/merge examples):
CREATE OR REPLACE TABLE incoming_batch (
    investor_id   INTEGER,
    full_name     VARCHAR,
    email         VARCHAR,
    state         VARCHAR,
    accreditation VARCHAR,
    changed_at    DATE
);
INSERT INTO incoming_batch VALUES
(1, 'Ava Suggs',   'ava@new.com', 'NJ', 'Suspended',  DATE '2025-01-05'),  -- investor 1 changes again
(3, 'Mia Patel',   'mia@x.com',   'TX', 'Accredited', DATE '2025-01-05'),  -- investor 3 unchanged
(4, 'Noah Kim',    'noah@x.com',  'FL', 'Pending',    DATE '2025-01-05');  -- brand-new investor

SELECT 'setup complete' AS status,
       (SELECT COUNT(*) FROM stg_investor_feed) AS feed_rows,
       (SELECT COUNT(*) FROM incoming_batch)    AS incoming_rows;
