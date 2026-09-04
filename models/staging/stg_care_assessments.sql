with source as (
    select * from {{ source('raw', 'raw_care_assessments') }}
),

transformed as (
    select
        assessment_id,
        resident_id,
        assessed_date,
        assessment_type,
        score,
        case
            when score >= 70 then 'High'
            when score >= 40 then 'Moderate'
            else 'Low'
        end                     as risk_band,
        score >= 70             as is_high_complexity
    from source
)

select * from transformed
