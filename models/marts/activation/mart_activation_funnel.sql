{{
  config(
    materialized='table',
    cluster_by=['partner_short_code', 'signup_source', 'plan_tier']
  )
}}

-- Reconstruction of the registration → first completed payment funnel.
-- One row per org. Exclude orgs created within the last 30 days (incomplete cohort).

with orgs as (
    select
        org_id,
        legal_name,
        account_status,
        signup_source,
        is_bad_fit_campaign_org,
        plan_tier,
        partner_short_code,
        org_created_at,
        activated_at
    from {{ ref('mart_org_summary') }}
    where date(org_created_at) <= date_sub(current_date(), interval 30 day)
),

kyc_results as (
    select
        c.organization_id                   as org_id,
        -- Pass flags per step (any attempt)
        max(case when s.step_name = 'personal_details'
                  and s.passed then 1 else 0 end) as passed_personal_details,
        max(case when s.step_name = 'company_details'
                  and s.passed then 1 else 0 end) as passed_company_details,
        max(case when s.step_name = 'legal_details'
                  and s.passed then 1 else 0 end) as passed_legal_details,
        max(case when s.step_name = 'industry'
                  and s.passed then 1 else 0 end) as passed_industry,
        min(case when s.step_name = 'legal_details'
                  and s.failed then s.failure_reason end)
                                            as legal_details_failure_reason,
        -- Number of attempts at legal_details
        countif(s.step_name = 'legal_details')
                                            as legal_details_attempts
    from {{ source('payments_demo', 'kyc_kyb_checks') }} c
    join {{ ref('stg_kyc_check_steps') }}                s on c.id = s.check_id
    group by c.organization_id
),

first_payment_method as (
    select
        organization_id                     as org_id,
        min(safe_cast(created_at as timestamp)) as first_pm_added_at
    from {{ source('payments_demo', 'payment_methods') }}
    group by organization_id
),

first_payment as (
    select
        org_id,
        min(initiated_at)                   as first_payment_initiated_at,
        min(case when is_completed
                 then completed_at end)     as first_payment_completed_at
    from {{ ref('stg_payments') }}
    where is_outbound
    group by org_id
)

select
    o.org_id,
    o.legal_name,
    o.account_status,
    o.signup_source,
    o.plan_tier,
    o.partner_short_code,
    o.is_bad_fit_campaign_org,
    o.org_created_at,
    o.activated_at,

    -- KYC step results
    k.passed_personal_details,
    k.passed_company_details,
    k.passed_legal_details,
    k.passed_industry,
    k.legal_details_failure_reason,
    k.legal_details_attempts,
    k.legal_details_attempts > 1            as had_legal_details_retry,

    -- Activation milestones
    pm.first_pm_added_at,
    p.first_payment_initiated_at,
    p.first_payment_completed_at,

    -- Funnel boolean flags
    k.passed_legal_details = 1              as reached_legal_details_pass,
    pm.first_pm_added_at is not null        as added_payment_method,
    p.first_payment_completed_at is not null as completed_first_payment,

    -- Time between stages (days)
    timestamp_diff(
        safe_cast(o.activated_at as timestamp),
        o.org_created_at, day
    )                                       as days_reg_to_activation,

    timestamp_diff(
        pm.first_pm_added_at,
        o.org_created_at, day
    )                                       as days_reg_to_first_pm,

    timestamp_diff(
        p.first_payment_completed_at,
        o.org_created_at, day
    )                                       as days_reg_to_first_payment,

    timestamp_diff(
        p.first_payment_completed_at,
        pm.first_pm_added_at, day
    )                                       as days_pm_to_first_payment,

    -- Cohort helper
    date_trunc(date(o.org_created_at), month) as cohort_month

from orgs                                   o
left join kyc_results                       k  on o.org_id = k.org_id
left join first_payment_method              pm on o.org_id = pm.org_id
left join first_payment                     p  on o.org_id = p.org_id