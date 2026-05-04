-- ── stg_subscriptions ──────────────────────────────────────────────
-- models/staging/stg_subscriptions.sql

{{
  config(materialized='view')
}}

with source as (
    select * from {{ source('payments_demo', 'subscriptions') }}
),

renamed as (
    select
        id                                                      as subscription_id,
        organization_id                                         as org_id,
        plan_id,
        safe_cast(upgraded_from_subscription_id as int64)       as upgraded_from_subscription_id,

        status,
        mrr_usd,
        arr_usd,
        discount_percent,
        auto_renew,
        renewal_count,
        cancel_reason,
        custom_pricing_json,

        -- Timestamps
        safe_cast(started_at as timestamp)          as started_at,
        safe_cast(canceled_at as timestamp)         as canceled_at,
        safe_cast(converted_to_paid_at as timestamp) as converted_to_paid_at,
        safe_cast(trial_started_at as timestamp)    as trial_started_at,
        safe_cast(trial_ended_at as timestamp)      as trial_ended_at,

        -- Derived
        status = 'active'                           as is_active,
        status = 'canceled'                         as is_canceled,
        upgraded_from_subscription_id is not null   as is_migrated,

        -- Story #11 — grandfathered orgs
        custom_pricing_json like '%"unlimited_usage": true%'
                                                    as is_grandfathered,

        -- Date helpers
        date_trunc(date(safe_cast(started_at as timestamp)), month)
                                                    as started_month

    from source
)

select * from renamed
