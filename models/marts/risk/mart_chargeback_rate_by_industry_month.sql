{{
  config(
    materialized='table',
    partition_by={'field': 'txn_month', 'data_type': 'date'},
    cluster_by=['industry_name']
  )
}}

with monthly_sales as (
    select
        ct.txn_month,
        i.id                                as industry_id,
        i.name                              as industry_name,
        i.sector,
        i.typical_chargeback_rate           as industry_baseline_cb_rate,
        count(*)                            as approved_sale_count,
        sum(ct.amount_usd)                  as sale_volume_usd
    from {{ ref('stg_card_transactions') }}             ct
    join {{ source('payments_demo', 'organizations') }}  o   on ct.org_id     = o.id
    join {{ source('payments_demo', 'industries') }}     i   on o.industry_id = i.id
    where ct.is_sale and ct.is_approved
    group by 1, 2, 3, 4, 5
),

monthly_cbs as (
    select
        cb.received_month                   as cb_month,
        o.industry_id,
        count(*)                            as chargeback_count,
        sum(cb.dispute_amount)              as disputed_amount_usd,
        sum(cb.lost_amount)                 as lost_amount_usd
    from {{ ref('stg_chargebacks') }}                   cb
    join {{ source('payments_demo', 'organizations') }}  o  on cb.org_id = o.id
    group by 1, 2
)

select
    ms.txn_month,
    ms.industry_name,
    ms.sector,
    ms.industry_baseline_cb_rate,
    ms.approved_sale_count,
    ms.sale_volume_usd,

    coalesce(mc.chargeback_count, 0)        as chargeback_count,
    coalesce(mc.disputed_amount_usd, 0)    as disputed_amount_usd,
    coalesce(mc.lost_amount_usd, 0)        as lost_amount_usd,

    round(
        coalesce(mc.chargeback_count, 0)
        / nullif(ms.approved_sale_count, 0), 6
    )                                       as chargeback_rate,

    round(
        coalesce(mc.chargeback_count, 0)
        / nullif(ms.approved_sale_count, 0)
        - ms.industry_baseline_cb_rate, 6
    )                                       as cb_rate_vs_baseline,

    ms.industry_name = 'Subscription Box / DTC Recurring'
                                            as is_subscription_box

from monthly_sales                          ms
left join monthly_cbs                       mc
    on ms.txn_month = mc.cb_month
    and ms.industry_id = mc.industry_id
