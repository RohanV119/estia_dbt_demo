with source as (
    select * from {{ source('raw', 'raw_invoices') }}
),

transformed as (
    select
        invoice_id,
        resident_id,
        invoice_date,
        amount_aud,
        payer_type,
        is_paid,
        paid_date,
        case
            when is_paid = true  then 'Paid'
            when is_paid = false
             and invoice_date < dateadd('day', -30, current_date()) then 'Overdue'
            else 'Pending'
        end                                     as payment_status,
        is_paid = false
        and invoice_date < dateadd('day', -30,
                           current_date())      as is_overdue,
        iff(is_paid, amount_aud, 0)             as amount_paid_aud,
        iff(not is_paid, amount_aud, 0)         as amount_outstanding_aud
    from source
)

select * from transformed
