with source as (
    select * from {{ source('payments_demo', 'customer_health_scores') }}
),

renamed as (
    select
        id                                          as health_score_id,
        organization_id                             as org_id,

        safe_cast(score_date as date)               as score_date,
        health_score,
        health_band,
        churn_risk_score,
        primary_risk_signal,

        login_count_7d,
        login_count_30d,
        payments_count_30d,
        payment_volume_30d_usd,
        support_ticket_count_30d,
        nps_latest,
        days_since_last_payment,
        days_since_last_login,

        -- Derived
        health_band = 'red'                         as is_red_band,
        primary_risk_signal = 'sleeping'            as is_sleeping,
        churn_risk_score >= 0.70                    as is_high_churn_risk,

        -- Story #13 — pre-churn login decline
        login_count_30d < 5
            and days_since_last_login > 14          as shows_login_decline

    from source
)

select * from renamed
