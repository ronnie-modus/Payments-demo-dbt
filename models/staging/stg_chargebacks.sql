with source as (
    select * from {{ source('payments_demo', 'chargebacks') }}
),

renamed as (
    select
        id                                          as chargeback_id,
        card_transaction_id,
        organization_id                             as org_id,
        safe_cast(counterparty_id as int64)         as counterparty_id,
        safe_cast(dispute_case_id as int64)         as dispute_case_id,

        reason_code,
        reason_category,
        status,
        network,
        dispute_amount,
        currency_code,
        won_amount,
        lost_amount,

        -- Timestamps
        safe_cast(received_at as timestamp)         as received_at,
        safe_cast(respond_by as timestamp)          as respond_by,
        safe_cast(responded_at as timestamp)        as responded_at,
        safe_cast(resolved_at as timestamp)         as resolved_at,

        -- Derived
        status = 'won'                              as merchant_won,
        status in ('lost', 'accepted')             as merchant_lost,
        lost_amount > 0                             as has_financial_loss,

        -- Date helpers
        date_trunc(date(safe_cast(received_at as timestamp)), month)
                                                    as received_month

    from source
)

select * from renamed
