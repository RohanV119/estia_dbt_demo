-- =============================================================================
-- Estia Health dbt Demo — Snowflake Task DAG (3-task, stored procedure backed)
--
--   TASK_ROOT   (every 1 hour)
--       |
--   TASK_SILVER  → calls SP_REFRESH_SILVER (all 5 staging views)
--       |
--   TASK_GOLD    → calls SP_REFRESH_GOLD   (both mart tables)
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE SCHEMA ESTIA_DEMO.ORCHESTRATION;

-- ===========================================================================
-- STORED PROCEDURE: Silver layer
-- ===========================================================================
CREATE OR REPLACE PROCEDURE ESTIA_DEMO.ORCHESTRATION.SP_REFRESH_SILVER()
    RETURNS VARCHAR
    LANGUAGE SQL
AS
$$
BEGIN
    CREATE OR REPLACE VIEW ESTIA_DEMO.SILVER.stg_facilities AS
    SELECT
        facility_id,
        facility_name,
        city,
        UPPER(state)  AS state,
        capacity,
        opened_date
    FROM ESTIA_DEMO.RAW.raw_facilities;

    CREATE OR REPLACE VIEW ESTIA_DEMO.SILVER.stg_residents AS
    SELECT
        resident_id,
        facility_id,
        first_name,
        last_name,
        first_name || ' ' || last_name                                     AS full_name,
        date_of_birth,
        DATEDIFF('year', date_of_birth, CURRENT_DATE())                    AS age_years,
        admission_date,
        discharge_date,
        COALESCE(discharge_date, CURRENT_DATE())                           AS effective_end_date,
        DATEDIFF('day', admission_date,
                 COALESCE(discharge_date, CURRENT_DATE()))                 AS care_days,
        status,
        status = 'Active'    AS is_active,
        status = 'Deceased'  AS is_deceased
    FROM ESTIA_DEMO.RAW.raw_residents;

    CREATE OR REPLACE VIEW ESTIA_DEMO.SILVER.stg_care_assessments AS
    SELECT
        assessment_id,
        resident_id,
        assessed_date,
        assessment_type,
        score,
        CASE
            WHEN score >= 70 THEN 'High'
            WHEN score >= 40 THEN 'Moderate'
            ELSE 'Low'
        END             AS risk_band,
        score >= 70     AS is_high_complexity
    FROM ESTIA_DEMO.RAW.raw_care_assessments;

    CREATE OR REPLACE VIEW ESTIA_DEMO.SILVER.stg_incidents AS
    SELECT
        incident_id,
        resident_id,
        incident_date,
        incident_type,
        severity,
        severity = 'High' AS is_high_severity,
        severity = 'Low'  AS is_low_severity
    FROM ESTIA_DEMO.RAW.raw_incidents;

    CREATE OR REPLACE VIEW ESTIA_DEMO.SILVER.stg_invoices AS
    SELECT
        invoice_id,
        resident_id,
        invoice_date,
        amount_aud,
        payer_type,
        is_paid,
        paid_date,
        CASE
            WHEN is_paid = TRUE  THEN 'Paid'
            WHEN is_paid = FALSE
             AND invoice_date < DATEADD('day', -30, CURRENT_DATE()) THEN 'Overdue'
            ELSE 'Pending'
        END                                                         AS payment_status,
        is_paid = FALSE
        AND invoice_date < DATEADD('day', -30, CURRENT_DATE())      AS is_overdue,
        IFF(is_paid, amount_aud, 0)                                 AS amount_paid_aud,
        IFF(NOT is_paid, amount_aud, 0)                             AS amount_outstanding_aud
    FROM ESTIA_DEMO.RAW.raw_invoices;

    RETURN 'Silver layer refreshed: 5 views updated';
END
$$;

-- ===========================================================================
-- STORED PROCEDURE: Gold layer
-- ===========================================================================
CREATE OR REPLACE PROCEDURE ESTIA_DEMO.ORCHESTRATION.SP_REFRESH_GOLD()
    RETURNS VARCHAR
    LANGUAGE SQL
AS
$$
BEGIN
    CREATE OR REPLACE TABLE ESTIA_DEMO.GOLD.mart_resident_care_summary AS
    WITH residents AS (
        SELECT * FROM ESTIA_DEMO.SILVER.stg_residents
    ),
    facilities AS (
        SELECT * FROM ESTIA_DEMO.SILVER.stg_facilities
    ),
    latest_assessments AS (
        SELECT
            resident_id,
            LAST_VALUE(score)         OVER (PARTITION BY resident_id ORDER BY assessed_date
                                           ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS latest_score,
            LAST_VALUE(risk_band)     OVER (PARTITION BY resident_id ORDER BY assessed_date
                                           ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS latest_risk_band,
            LAST_VALUE(assessed_date) OVER (PARTITION BY resident_id ORDER BY assessed_date
                                           ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS latest_assessed_date,
            ROW_NUMBER()              OVER (PARTITION BY resident_id ORDER BY assessed_date DESC)    AS rn
        FROM ESTIA_DEMO.SILVER.stg_care_assessments
        QUALIFY rn = 1
    ),
    incident_summary AS (
        SELECT
            resident_id,
            COUNT(*)                             AS incident_count,
            SUM(IFF(is_high_severity, 1, 0))     AS high_severity_incident_count
        FROM ESTIA_DEMO.SILVER.stg_incidents
        GROUP BY 1
    ),
    invoice_summary AS (
        SELECT
            resident_id,
            SUM(amount_aud)             AS total_billed_aud,
            SUM(amount_paid_aud)        AS total_paid_aud,
            SUM(amount_outstanding_aud) AS total_outstanding_aud,
            COUNT_IF(is_overdue)        AS overdue_invoice_count
        FROM ESTIA_DEMO.SILVER.stg_invoices
        GROUP BY 1
    )
    SELECT
        r.resident_id,
        r.full_name,
        r.age_years,
        r.date_of_birth,
        r.status                                     AS care_status,
        r.is_active,
        r.admission_date,
        r.discharge_date,
        r.care_days,
        f.facility_name,
        f.state,
        a.latest_assessed_date,
        a.latest_score                               AS latest_assessment_score,
        a.latest_risk_band                           AS risk_band,
        COALESCE(i.incident_count, 0)               AS incident_count,
        COALESCE(i.high_severity_incident_count, 0) AS high_severity_incident_count,
        COALESCE(v.total_billed_aud, 0)             AS total_billed_aud,
        COALESCE(v.total_paid_aud, 0)               AS total_paid_aud,
        COALESCE(v.total_outstanding_aud, 0)        AS total_outstanding_aud,
        COALESCE(v.overdue_invoice_count, 0)        AS overdue_invoice_count
    FROM residents r
    LEFT JOIN facilities f         ON r.facility_id = f.facility_id
    LEFT JOIN latest_assessments a ON r.resident_id = a.resident_id
    LEFT JOIN incident_summary i   ON r.resident_id = i.resident_id
    LEFT JOIN invoice_summary v    ON r.resident_id = v.resident_id;

    CREATE OR REPLACE TABLE ESTIA_DEMO.GOLD.mart_facility_kpis AS
    WITH facilities AS (
        SELECT * FROM ESTIA_DEMO.SILVER.stg_facilities
    ),
    residents AS (
        SELECT * FROM ESTIA_DEMO.SILVER.stg_residents
    ),
    latest_resident_assessment AS (
        SELECT
            resident_id,
            score,
            risk_band,
            ROW_NUMBER() OVER (PARTITION BY resident_id ORDER BY assessed_date DESC) AS rn
        FROM ESTIA_DEMO.SILVER.stg_care_assessments
        QUALIFY rn = 1
    ),
    resident_agg AS (
        SELECT
            r.facility_id,
            COUNT_IF(r.is_active)              AS active_resident_count,
            SUM(r.care_days)                   AS total_bed_days,
            AVG(a.score)                       AS avg_care_score,
            COUNT_IF(a.risk_band = 'High')     AS high_risk_resident_count,
            COUNT_IF(a.risk_band = 'Moderate') AS moderate_risk_resident_count
        FROM residents r
        LEFT JOIN latest_resident_assessment a ON r.resident_id = a.resident_id
        GROUP BY 1
    ),
    incident_agg AS (
        SELECT
            r.facility_id,
            COUNT(i.incident_id)         AS total_incidents,
            COUNT_IF(i.is_high_severity) AS high_severity_incidents
        FROM ESTIA_DEMO.SILVER.stg_incidents i
        INNER JOIN residents r ON i.resident_id = r.resident_id
        GROUP BY 1
    ),
    invoice_agg AS (
        SELECT
            r.facility_id,
            SUM(v.amount_aud)             AS total_billed_aud,
            SUM(v.amount_paid_aud)        AS total_paid_aud,
            SUM(v.amount_outstanding_aud) AS total_outstanding_aud,
            COUNT_IF(v.is_overdue)        AS overdue_invoice_count
        FROM ESTIA_DEMO.SILVER.stg_invoices v
        INNER JOIN residents r ON v.resident_id = r.resident_id
        GROUP BY 1
    )
    SELECT
        f.facility_id,
        f.facility_name,
        f.city,
        f.state,
        f.capacity,
        f.opened_date,
        COALESCE(ra.active_resident_count, 0)        AS active_resident_count,
        ROUND(COALESCE(ra.active_resident_count, 0)
              / NULLIF(f.capacity, 0) * 100, 1)      AS occupancy_pct,
        COALESCE(ra.high_risk_resident_count, 0)     AS high_risk_resident_count,
        COALESCE(ra.moderate_risk_resident_count, 0) AS moderate_risk_resident_count,
        ROUND(COALESCE(ra.avg_care_score, 0), 1)     AS avg_care_score,
        COALESCE(ia.total_incidents, 0)              AS total_incidents,
        COALESCE(ia.high_severity_incidents, 0)      AS high_severity_incidents,
        ROUND(COALESCE(ia.total_incidents, 0)
              / NULLIF(ra.total_bed_days, 0) * 100, 4) AS incidents_per_100_bed_days,
        COALESCE(va.total_billed_aud, 0)             AS total_billed_aud,
        COALESCE(va.total_paid_aud, 0)               AS total_paid_aud,
        COALESCE(va.total_outstanding_aud, 0)        AS total_outstanding_aud,
        COALESCE(va.overdue_invoice_count, 0)        AS overdue_invoice_count
    FROM facilities f
    LEFT JOIN resident_agg ra ON f.facility_id = ra.facility_id
    LEFT JOIN incident_agg ia ON f.facility_id = ia.facility_id
    LEFT JOIN invoice_agg va  ON f.facility_id = va.facility_id;

    RETURN 'Gold layer refreshed: 2 mart tables rebuilt';
END
$$;

-- ===========================================================================
-- TASKS  — root → silver → gold
-- ===========================================================================
CREATE OR REPLACE TASK ESTIA_DEMO.ORCHESTRATION.TASK_ROOT
    SCHEDULE = '60 MINUTE'
    COMMENT = 'Root trigger: fires every hour to refresh the Estia Health pipeline'
AS
    SELECT 'Pipeline triggered at ' || CURRENT_TIMESTAMP() AS status;

CREATE OR REPLACE TASK ESTIA_DEMO.ORCHESTRATION.TASK_SILVER
    COMMENT = 'Silver layer: refresh all 5 staging views from RAW tables'
    AFTER ESTIA_DEMO.ORCHESTRATION.TASK_ROOT
AS
    CALL ESTIA_DEMO.ORCHESTRATION.SP_REFRESH_SILVER();

CREATE OR REPLACE TASK ESTIA_DEMO.ORCHESTRATION.TASK_GOLD
    COMMENT = 'Gold layer: rebuild both mart tables from Silver views'
    AFTER ESTIA_DEMO.ORCHESTRATION.TASK_SILVER
AS
    CALL ESTIA_DEMO.ORCHESTRATION.SP_REFRESH_GOLD();

-- ===========================================================================
-- RESUME  — children first, root last
-- ===========================================================================
ALTER TASK ESTIA_DEMO.ORCHESTRATION.TASK_GOLD   RESUME;
ALTER TASK ESTIA_DEMO.ORCHESTRATION.TASK_SILVER RESUME;
ALTER TASK ESTIA_DEMO.ORCHESTRATION.TASK_ROOT   RESUME;
