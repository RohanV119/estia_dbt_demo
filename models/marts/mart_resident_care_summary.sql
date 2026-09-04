with residents as (
    select * from {{ ref('stg_residents') }}
),

facilities as (
    select * from {{ ref('stg_facilities') }}
),

latest_assessments as (
    select
        resident_id,
        last_value(score)       over (partition by resident_id order by assessed_date
                                      rows between unbounded preceding and unbounded following) as latest_score,
        last_value(risk_band)   over (partition by resident_id order by assessed_date
                                      rows between unbounded preceding and unbounded following) as latest_risk_band,
        last_value(assessed_date) over (partition by resident_id order by assessed_date
                                      rows between unbounded preceding and unbounded following) as latest_assessed_date,
        row_number()            over (partition by resident_id order by assessed_date desc)     as rn
    from {{ ref('stg_care_assessments') }}
    qualify rn = 1
),

incident_summary as (
    select
        resident_id,
        count(*)                                    as incident_count,
        sum(iff(is_high_severity, 1, 0))            as high_severity_incident_count
    from {{ ref('stg_incidents') }}
    group by 1
),

invoice_summary as (
    select
        resident_id,
        sum(amount_aud)                             as total_billed_aud,
        sum(amount_paid_aud)                        as total_paid_aud,
        sum(amount_outstanding_aud)                 as total_outstanding_aud,
        count_if(is_overdue)                        as overdue_invoice_count
    from {{ ref('stg_invoices') }}
    group by 1
)

select
    r.resident_id,
    r.full_name,
    r.age_years,
    r.date_of_birth,
    r.status                                        as care_status,
    r.is_active,
    r.admission_date,
    r.discharge_date,
    r.care_days,
    f.facility_name,
    f.state,
    a.latest_assessed_date,
    a.latest_score                                  as latest_assessment_score,
    a.latest_risk_band                              as risk_band,
    coalesce(i.incident_count, 0)                  as incident_count,
    coalesce(i.high_severity_incident_count, 0)    as high_severity_incident_count,
    coalesce(v.total_billed_aud, 0)                as total_billed_aud,
    coalesce(v.total_paid_aud, 0)                  as total_paid_aud,
    coalesce(v.total_outstanding_aud, 0)           as total_outstanding_aud,
    coalesce(v.overdue_invoice_count, 0)           as overdue_invoice_count
from residents r
left join facilities f          on r.facility_id = f.facility_id
left join latest_assessments a  on r.resident_id = a.resident_id
left join incident_summary i    on r.resident_id = i.resident_id
left join invoice_summary v     on r.resident_id = v.resident_id
