{{
  config(
    materialized='table',
    partition_by={'field': 'txn_month', 'data_type': 'date'},
    cluster_by=['processor_name', 'mcc_category']
  )
}}

select
    ct.txn_month,
    pr.name                                 as processor_name,
    pr.processor_type,
    mcc.category                            as mcc_category,
    mcc.risk_band                           as mcc_risk_band,
    p.tier                                  as plan_tier,
    pt.partner_short_code,

    count(*)                                as txn_count,
    sum(ct.amount_usd)                      as volume_usd,
    sum(ct.interchange_amount)              as total_interchange_usd,
    round(avg(ct.interchange_rate_bps), 2)  as avg_interchange_bps,

    round(
        sum(ct.interchange_amount)
        / nullif(sum(ct.amount_usd), 0), 6
    )                                       as effective_interchange_rate,

    -- Story #10 — Helios share
    round(
        sum(case when pr.name = 'Helios Acquiring'
                 then ct.amount_usd else 0 end)
        / nullif(sum(ct.amount_usd), 0), 4
    )                                       as helios_volume_share,

    round(avg(ct.risk_score), 4)           as avg_risk_score,
    round(
        countif(ct.is_declined) / nullif(count(*), 0), 4
    )                                       as decline_rate

from {{ ref('stg_card_transactions') }}                 ct
join {{ source('payments_demo', 'processors') }}         pr  on ct.processor_id   = pr.id
left join {{ source('payments_demo', 'mcc_codes') }}     mcc on ct.mcc_id         = mcc.id
join {{ source('payments_demo', 'organizations') }}      o   on ct.org_id         = o.id
left join {{ source('payments_demo', 'plans') }}         p   on o.current_plan_id = p.id
left join {{ source('payments_demo', 'partnerships') }}  pt  on o.partner_id      = pt.id
where ct.is_sale
group by 1, 2, 3, 4, 5, 6, 7
