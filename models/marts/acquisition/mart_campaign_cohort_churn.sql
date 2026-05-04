{{
  config(materialized='table')
}}

with last_touch as (
    select organization_id, marketing_campaign_id
    from (
        select *,
            row_number() over (
                partition by organization_id
                order by touchpoint_at desc
            ) as rn
        from {{ source('payments_demo', 'campaign_attributions') }}
        where attribution_model = 'last_touch'
    )
    where rn = 1
),

org_data as (
    select org_id, account_status, churned_at, org_created_at
    from {{ ref('mart_org_summary') }}
),

sub_data as (
    select org_id, mrr_usd
    from {{ ref('mart_org_summary') }}
)

select
    c.campaign_id,
    c.campaign_name,
    c.campaign_type,
    c.channel,
    c.started_at                            as campaign_start_date,
    c.ended_at                              as campaign_end_date,
    c.spend_usd,
    c.is_bad_fit_campaign,

    count(distinct lt.organization_id)      as attributed_orgs,

    countif(o.account_status in ('active','past_due','churned','suspended'))
                                            as activated_orgs,

    countif(o.account_status = 'churned')  as churned_orgs,

    countif(
        o.account_status = 'churned'
        and timestamp_diff(
            safe_cast(o.churned_at as timestamp),
            o.org_created_at, day
        ) <= 90
    )                                       as churned_within_90d,

    round(
        countif(
            o.account_status = 'churned'
            and timestamp_diff(
                safe_cast(o.churned_at as timestamp),
                o.org_created_at, day
            ) <= 90
        )
        / nullif(count(distinct lt.organization_id), 0), 4
    )                                       as churn_rate_90d,

    round(avg(s.mrr_usd), 2)              as avg_org_mrr_usd,

    round(
        c.spend_usd
        / nullif(
            countif(o.account_status in ('active','past_due','churned','suspended')),
            0
        ), 2
    )                                       as cac_usd

from {{ ref('stg_marketing_campaigns') }}   c
left join last_touch                        lt on c.campaign_id      = lt.marketing_campaign_id
left join org_data                          o  on lt.organization_id = o.org_id
left join sub_data                          s  on lt.organization_id = s.org_id
group by
    c.campaign_id, c.campaign_name, c.campaign_type,
    c.channel, c.started_at, c.ended_at, c.spend_usd, c.is_bad_fit_campaign
