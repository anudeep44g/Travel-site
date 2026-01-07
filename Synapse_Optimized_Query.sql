-- ============================================================================
-- Azure Synapse Analytics Optimized Query
-- Conversion from Recursive CTE to Window Functions
-- ============================================================================
-- 
-- PURPOSE: Determine Marketing Workable status for inquiries based on:
--   1. The inquiry must be workable (WORKABLE_FLAG = 1)
--   2. At least 30 days must pass since the last marketing workable inquiry
--
-- PERFORMANCE OPTIMIZATIONS FOR SYNAPSE:
--   - Eliminates recursive CTE (not performant in distributed systems)
--   - Uses window functions for parallel processing
--   - Leverages Synapse's MPP architecture
--   - Reduces data shuffling with proper partitioning
-- ============================================================================

-- Step 1: Create base dataset with cumulative workable inquiry tracking
-- This uses window functions to avoid recursion
WITH base_with_windows AS (
    SELECT
        CONTACTID,
        INQUIRY_DATE,
        INQUIRY_ORDER_NUM,
        WORKABLE_FLAG,
        -- Identify workable inquiries and assign group numbers
        -- This creates "islands" of workable inquiries
        SUM(CASE WHEN WORKABLE_FLAG = 1 THEN 1 ELSE 0 END) 
            OVER (PARTITION BY CONTACTID 
                  ORDER BY INQUIRY_ORDER_NUM 
                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS workable_inquiry_count,
        -- Get the most recent workable inquiry date before current row
        MAX(CASE WHEN WORKABLE_FLAG = 1 THEN INQUIRY_DATE ELSE NULL END)
            OVER (PARTITION BY CONTACTID 
                  ORDER BY INQUIRY_ORDER_NUM 
                  ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS prev_workable_date
    FROM #all_inquiries
),

-- Step 2: Calculate Marketing Workable status using window results
mkt_workable_calculated AS (
    SELECT
        CONTACTID,
        INQUIRY_DATE,
        INQUIRY_ORDER_NUM,
        WORKABLE_FLAG,
        prev_workable_date,
        -- Determine MKT_WORKABLE_FLAG
        CASE
            WHEN INQUIRY_ORDER_NUM = 1 THEN WORKABLE_FLAG  -- First inquiry uses its own flag
            WHEN WORKABLE_FLAG = 0 THEN 0                   -- Not workable = not mkt workable
            WHEN prev_workable_date IS NULL THEN WORKABLE_FLAG  -- No previous workable, use current
            WHEN DATEADD(DAY, 30, prev_workable_date) < INQUIRY_DATE THEN 1  -- 30+ days passed
            ELSE 0  -- Less than 30 days
        END AS MKT_WORKABLE_FLAG
    FROM base_with_windows
),

-- Step 3: Calculate LAST_MKT_WORKABLE_DATE using cumulative logic
mkt_workable_with_dates AS (
    SELECT
        CONTACTID,
        INQUIRY_DATE,
        INQUIRY_ORDER_NUM,
        WORKABLE_FLAG,
        MKT_WORKABLE_FLAG,
        -- Calculate LAST_MKT_WORKABLE_DATE: the most recent date where MKT_WORKABLE_FLAG was 1
        MAX(CASE WHEN MKT_WORKABLE_FLAG = 1 THEN INQUIRY_DATE ELSE NULL END)
            OVER (PARTITION BY CONTACTID 
                  ORDER BY INQUIRY_ORDER_NUM 
                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS LAST_MKT_WORKABLE_DATE
    FROM mkt_workable_calculated
)

-- Final output: Create the result table
SELECT
    CONTACTID,
    INQUIRY_DATE,
    INQUIRY_ORDER_NUM,
    WORKABLE_FLAG,
    MKT_WORKABLE_FLAG,
    LAST_MKT_WORKABLE_DATE
INTO #MKT_WORKABLE
FROM mkt_workable_with_dates;


-- ============================================================================
-- ALTERNATIVE APPROACH: Using LAG for More Efficient Processing
-- This version may perform better on very large datasets
-- ============================================================================

/*
WITH inquiry_with_lag AS (
    SELECT
        CONTACTID,
        INQUIRY_DATE,
        INQUIRY_ORDER_NUM,
        WORKABLE_FLAG,
        -- Get previous inquiry's date and workable status
        LAG(INQUIRY_DATE) OVER (PARTITION BY CONTACTID ORDER BY INQUIRY_ORDER_NUM) AS prev_inquiry_date,
        LAG(WORKABLE_FLAG) OVER (PARTITION BY CONTACTID ORDER BY INQUIRY_ORDER_NUM) AS prev_workable_flag
    FROM #all_inquiries
),

mkt_workable_step AS (
    SELECT
        CONTACTID,
        INQUIRY_DATE,
        INQUIRY_ORDER_NUM,
        WORKABLE_FLAG,
        -- Initial MKT_WORKABLE_FLAG calculation
        CASE
            WHEN INQUIRY_ORDER_NUM = 1 THEN WORKABLE_FLAG
            WHEN WORKABLE_FLAG = 0 THEN 0
            ELSE WORKABLE_FLAG  -- Temporary, will be refined in next step
        END AS MKT_WORKABLE_FLAG_TEMP,
        -- Track workable dates
        CASE
            WHEN WORKABLE_FLAG = 1 THEN INQUIRY_DATE
            ELSE NULL
        END AS current_workable_date
    FROM inquiry_with_lag
),

mkt_workable_refined AS (
    SELECT
        CONTACTID,
        INQUIRY_DATE,
        INQUIRY_ORDER_NUM,
        WORKABLE_FLAG,
        -- Get the most recent marketing workable date
        MAX(CASE WHEN MKT_WORKABLE_FLAG_TEMP = 1 THEN current_workable_date ELSE NULL END)
            OVER (PARTITION BY CONTACTID 
                  ORDER BY INQUIRY_ORDER_NUM 
                  ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS prev_mkt_workable_date,
        MKT_WORKABLE_FLAG_TEMP
    FROM mkt_workable_step
)

SELECT
    CONTACTID,
    INQUIRY_DATE,
    INQUIRY_ORDER_NUM,
    WORKABLE_FLAG,
    -- Final MKT_WORKABLE_FLAG with 30-day rule
    CASE
        WHEN INQUIRY_ORDER_NUM = 1 THEN WORKABLE_FLAG
        WHEN WORKABLE_FLAG = 0 THEN 0
        WHEN prev_mkt_workable_date IS NULL THEN WORKABLE_FLAG
        WHEN DATEADD(DAY, 30, prev_mkt_workable_date) < INQUIRY_DATE THEN WORKABLE_FLAG
        ELSE 0
    END AS MKT_WORKABLE_FLAG,
    -- LAST_MKT_WORKABLE_DATE
    MAX(CASE 
        WHEN CASE
            WHEN INQUIRY_ORDER_NUM = 1 THEN WORKABLE_FLAG
            WHEN WORKABLE_FLAG = 0 THEN 0
            WHEN prev_mkt_workable_date IS NULL THEN WORKABLE_FLAG
            WHEN DATEADD(DAY, 30, prev_mkt_workable_date) < INQUIRY_DATE THEN WORKABLE_FLAG
            ELSE 0
        END = 1 THEN INQUIRY_DATE 
        ELSE NULL 
    END)
        OVER (PARTITION BY CONTACTID 
              ORDER BY INQUIRY_ORDER_NUM 
              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS LAST_MKT_WORKABLE_DATE
INTO #MKT_WORKABLE
FROM mkt_workable_refined;
*/


-- ============================================================================
-- PERFORMANCE TUNING RECOMMENDATIONS FOR SYNAPSE
-- ============================================================================

-- 1. TABLE DISTRIBUTION
-- Consider hash distribution on CONTACTID for the source table:
-- CREATE TABLE #all_inquiries WITH (DISTRIBUTION = HASH(CONTACTID)) AS ...

-- 2. STATISTICS
-- Ensure statistics exist on key columns:
-- CREATE STATISTICS stat_contactid ON #all_inquiries(CONTACTID);
-- CREATE STATISTICS stat_inquiry_order ON #all_inquiries(INQUIRY_ORDER_NUM);
-- CREATE STATISTICS stat_inquiry_date ON #all_inquiries(INQUIRY_DATE);

-- 3. INDEXING (for permanent tables, not temp tables)
-- CREATE CLUSTERED COLUMNSTORE INDEX idx_all_inquiries ON all_inquiries;

-- 4. QUERY OPTIMIZATION
-- - Avoid MAXRECURSION in Synapse (not needed with window functions)
-- - Use appropriate data types (DATE vs DATETIME for INQUIRY_DATE)
-- - Consider partitioning source table by date ranges if dataset is very large

-- 5. MONITORING
-- Use these queries to monitor performance:
-- SELECT * FROM sys.dm_pdw_exec_requests WHERE [label] = 'YourQueryLabel';
-- SELECT * FROM sys.dm_pdw_request_steps WHERE request_id = 'QID####';


-- ============================================================================
-- VALIDATION QUERIES
-- ============================================================================

-- Compare results between old recursive CTE and new window function approach
-- Run both queries and use this to validate:
/*
SELECT 
    'Recursive' AS method,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN MKT_WORKABLE_FLAG = 1 THEN 1 ELSE 0 END) AS mkt_workable_count
FROM #MKT_WORKABLE_RECURSIVE

UNION ALL

SELECT 
    'Window_Func' AS method,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN MKT_WORKABLE_FLAG = 1 THEN 1 ELSE 0 END) AS mkt_workable_count
FROM #MKT_WORKABLE;

-- Detailed row-by-row comparison
SELECT 
    r.CONTACTID,
    r.INQUIRY_ORDER_NUM,
    r.MKT_WORKABLE_FLAG AS recursive_flag,
    w.MKT_WORKABLE_FLAG AS window_flag,
    CASE WHEN r.MKT_WORKABLE_FLAG = w.MKT_WORKABLE_FLAG THEN 'MATCH' ELSE 'MISMATCH' END AS comparison
FROM #MKT_WORKABLE_RECURSIVE r
FULL OUTER JOIN #MKT_WORKABLE w
    ON r.CONTACTID = w.CONTACTID 
    AND r.INQUIRY_ORDER_NUM = w.INQUIRY_ORDER_NUM
WHERE r.MKT_WORKABLE_FLAG != w.MKT_WORKABLE_FLAG
    OR r.CONTACTID IS NULL 
    OR w.CONTACTID IS NULL;
*/
