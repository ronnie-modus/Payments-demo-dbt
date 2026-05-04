{{
  config(
    materialized='table',
    partition_by={'field': 'org_created_month', 'data_type': 'date'},
    cluster_by=['account_status', 'plan_tier', 'partner_short_code']
  )
}}

with orgs as (
    select * from {{ ref('stg_organizations') }}
    where is_customer_org
),

plans as (
    select id as plan_id, tier, base_price_usd, included_payments_count
    from {{ source('payments_demo', 'plans') }}
),

partnerships as (
    select id as partner_id, name as partner_name, partner_short_code, partnership_type
    from {{ source('payments_demo', 'partnerships') }}
),

industries as (
    select id as industry_id, name as industry_name, sector, typical_chargeback_rate
    from {{ source('payments_demo', 'industries') }}
),

latest_sub as (
    select *
    from (
        select *,
            row_number() over (
                partition by org_id
                order by started_at desc
            ) as rn
        from {{ ref('stg_subscriptions') }}
        where is_active or status = 'past_due'
    )
    where rn = 1
),

latest_health as (
    select *
    from (
        select *,
            row_number() over (
                partition by org_id
                order by score_date desc
            ) as rn
        from {{ ref('stg_customer_health_scores') }}
    )
    where rn = 1
)

select
    o.org_id,
    o.legal_name,
    o.display_name,
    o.account_status,
    o.signup_source,
    o.city,
    o.state_or_region,
    o.default_currency_code,
    o.nps_score_latest,
    o.churn_reason,
    o.is_churned,
    o.is_active,
    o.is_kyc_stalled,
    o.days_as_customer,
    o.is_bad_fit_campaign_org,

    -- Plan
    p.tier                                  as plan_tier,
    p.base_price_usd                        as plan_base_price_usd,
    p.included_payments_count,

    -- Subscription
    coalesce(s.mrr_usd, 0)                 as mrr_usd,
    coalesce(s.arr_usd, 0)                 as arr_usd,
    s.is_migrated                           as is_migrated_plan,
    s.is_grandfathered,

    -- Partner
    pt.partner_name,
    pt.partner_short_code,
    pt.partnership_type,

    -- Industry
    i.industry_name,
    i.sector                                as industry_sector,
    i.typical_chargeback_rate               as industry_typical_cb_rate,

    -- Timestamps
    o.org_created_at,
    o.activated_at,
    o.trial_ended_at,
    o.churned_at,
    date_trunc(date(o.org_created_at), month) as org_created_month,

    -- Health (latest)
    h.score_date                            as health_score_date,
    h.health_score,
    h.health_band,
    h.churn_risk_score,
    h.primary_risk_signal,
    h.login_count_30d,
    h.payments_count_30d,
    h.payment_volume_30d_usd,
    h.is_sleeping,
    h.is_high_churn_risk,
    h.shows_login_decline

from orgs                                   o
left join plans                             p  on o.current_plan_id = p.plan_id
left join partnerships                      pt on o.partner_id      = pt.partner_id
left join industries                        i  on o.industry_id     = i.industry_id
left join latest_sub                        s  on o.org_id          = s.org_id
left join latest_health                     h  on o.org_id          = h.org_id