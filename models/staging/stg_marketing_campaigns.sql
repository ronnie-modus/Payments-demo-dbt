with source as (
    select * from {{ source('payments_demo', 'marketing_campaigns') }}
),

renamed as (
    select
        id                                          as campaign_id,
        name                                        as campaign_name,
        campaign_type,
        channel,
        target_segment,
        utm_source,
        utm_medium,
        utm_campaign,

        safe_cast(budget_usd as float64)            as budget_usd,
        safe_cast(spend_usd as float64)             as spend_usd,
        safe_cast(signups_count as int64)           as signups_count,
        safe_cast(activated_count as int64)         as activated_count,
        safe_cast(churned_within_90d_count as int64) as churned_within_90d_count,
        safe_cast(cac_usd as float64)               as cac_usd,

        safe_cast(started_at as date)               as started_at,
        safe_cast(ended_at as date)                 as ended_at,

        -- Derived
        safe_cast(churned_within_90d_count as float64)
            / nullif(signups_count, 0)              as churn_rate_90d,

        -- Story #14
        id = {{ var('bad_fit_campaign_id') }}       as is_bad_fit_campaign

    from source
)

select * from renamed
