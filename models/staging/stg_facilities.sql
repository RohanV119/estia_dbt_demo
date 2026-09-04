with source as (
    select * from {{ source('raw', 'raw_facilities') }}
)

select
    facility_id,
    facility_name,
    city,
    upper(state)  as state,
    capacity,
    opened_date
from source
