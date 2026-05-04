with source as (
    select * from {{ source('payments_demo', 'payments') }}
),

renamed as (
    select
        id                                          as payment_id,
        organization_id                             as org_id,
        counterparty_id,
        payment_method_id,
        delivery_method_id,
        safe_cast(processor_id as int64)            as processor_id,
        safe_cast(created_by_user_id as int64)      as created_by_user_id,
        safe_cast(approved_by_user_id as int64)     as approved_by_user_id,
        safe_cast(sanctions_screening_id as int64)  as sanctions_screening_id,

        direction,
        status,
        currency_code,
        amount,
        amount_usd,
        platform_fee_amount,
        safe_cast(third_party_fee_amount as float64)
                                                    as third_party_fee_amount,
        platform_fee_amount
            - coalesce(safe_cast(third_party_fee_amount as float64), 0)
                                                    as gross_profit_usd,
        memo,
        risk_review_required,
        risk_decision,

        -- Timestamps
        initiated_at,
        safe_cast(completed_at as timestamp)        as completed_at,
        safe_cast(failed_at as timestamp)           as failed_at,
        safe_cast(scheduled_for as timestamp)       as scheduled_for,

        -- Derived
        status = 'completed'                        as is_completed,
        status in ('failed', 'returned')            as is_failed,
        direction = 'outbound'                      as is_outbound,
        direction = 'inbound'                       as is_inbound,
        sanctions_screening_id is not null          as was_sanctions_screened,

        timestamp_diff(
            safe_cast(completed_at as timestamp),
            initiated_at, hour
        )                                           as hours_to_complete,

        -- Date helpers
        date(initiated_at)                          as initiated_date,
        date_trunc(date(initiated_at), week)        as initiated_week,
        date_trunc(date(initiated_at), month)       as initiated_month

    from source
)

select * from renamed
