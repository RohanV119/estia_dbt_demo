with source as (
    select * from {{ source('raw', 'raw_incidents') }}
)

select
    incident_id,
    resident_id,
    incident_date,
    incident_type,
    severity,
    severity = 'High'   as is_high_severity,
    severity = 'Low'    as is_low_severity
from source
