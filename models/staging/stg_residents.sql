with source as (
    select * from {{ source('raw', 'raw_residents') }}
),

transformed as (
    select
        resident_id,
        facility_id,
        first_name,
        last_name,
        first_name || ' ' || last_name                                     as full_name,
        date_of_birth,
        datediff('year', date_of_birth, current_date())                    as age_years,
        admission_date,
        discharge_date,
        coalesce(discharge_date, current_date())                           as effective_end_date,
        datediff('day', admission_date,
                 coalesce(discharge_date, current_date()))                 as care_days,
        status,
        status = 'Active'                                                  as is_active,
        status = 'Deceased'                                                as is_deceased
    from source
)

select * from transformed
