with facilities as (
    select * from {{ ref('stg_facilities') }}
),

residents as (
    select * from {{ ref('stg_residents') }}
),

assessments as (
    select * from {{ ref('stg_care_assessments') }}
),

incidents as (
    select * from {{ ref('stg_incidents') }}
),

invoices as (
    select * from {{ ref('stg_invoices') }}
),

-- Latest assessment per resident
latest_resident_assessment as (
    select
        resident_id,
        score,
        risk_band,
        row_number() over (partition by resident_id order by assessed_date desc) as rn
    from assessments
    qualify rn = 1
),

-- Resident-level aggregates
resident_agg as (
    select
        r.facility_id,
        count_if(r.is_active)                                   as active_resident_count,
        sum(r.care_days)                                        as total_bed_days,
        avg(a.score)                                            as avg_care_score,
        count_if(a.risk_band = 'High')                         as high_risk_resident_count,
        count_if(a.risk_band = 'Moderate')                     as moderate_risk_resident_count
    from residents r
    left join latest_resident_assessment a on r.resident_id = a.resident_id
    group by 1
),

-- Incident aggregates linked through residents
incident_agg as (
    select
        r.facility_id,
        count(i.incident_id)                                    as total_incidents,
        count_if(i.is_high_severity)                           as high_severity_incidents
    from incidents i
    inner join residents r on i.resident_id = r.resident_id
    group by 1
),

-- Invoice aggregates linked through residents
invoice_agg as (
    select
        r.facility_id,
        sum(v.amount_aud)                                       as total_billed_aud,
        sum(v.amount_paid_aud)                                  as total_paid_aud,
        sum(v.amount_outstanding_aud)                          as total_outstanding_aud,
        count_if(v.is_overdue)                                 as overdue_invoice_count
    from invoices v
    inner join residents r on v.resident_id = r.resident_id
    group by 1
)

select
    f.facility_id,
    f.facility_name,
    f.city,
    f.state,
    f.capacity,
    f.opened_date,
    coalesce(ra.active_resident_count, 0)           as active_resident_count,
    round(
        coalesce(ra.active_resident_count, 0)
        / nullif(f.capacity, 0) * 100, 1
    )                                               as occupancy_pct,
    coalesce(ra.high_risk_resident_count, 0)        as high_risk_resident_count,
    coalesce(ra.moderate_risk_resident_count, 0)    as moderate_risk_resident_count,
    round(coalesce(ra.avg_care_score, 0), 1)        as avg_care_score,
    coalesce(ia.total_incidents, 0)                 as total_incidents,
    coalesce(ia.high_severity_incidents, 0)         as high_severity_incidents,
    -- Incident rate: incidents per 100 bed-days
    round(
        coalesce(ia.total_incidents, 0)
        / nullif(ra.total_bed_days, 0) * 100, 4
    )                                               as incidents_per_100_bed_days,
    coalesce(va.total_billed_aud, 0)                as total_billed_aud,
    coalesce(va.total_paid_aud, 0)                  as total_paid_aud,
    coalesce(va.total_outstanding_aud, 0)           as total_outstanding_aud,
    coalesce(va.overdue_invoice_count, 0)           as overdue_invoice_count
from facilities f
left join resident_agg ra  on f.facility_id = ra.facility_id
left join incident_agg ia  on f.facility_id = ia.facility_id
left join invoice_agg va   on f.facility_id = va.facility_id
