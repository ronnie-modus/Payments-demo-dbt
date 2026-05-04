-- tests/assert_bad_fit_campaign_elevated_churn.sql
-- Story #14: The bad-fit campaign (310000017) must have >= 1.5x the
-- baseline 90-day churn rate of all other campaigns.

with bad_fit as (
    select churn_rate_90d
    from {{ ref('mart_campaign_cohort_churn') }}
    where is_bad_fit_campaign
),

baseline as (
    select avg(churn_rate_90d) as avg_churn_rate
    from {{ ref('mart_campaign_cohort_churn') }}
    where not is_bad_fit_campaign
      and attributed_orgs >= 20   -- exclude micro-campaigns
)

-- Returns a row (test failure) if bad-fit rate is NOT 1.5x baseline
select 1
from bad_fit, baseline
where bad_fit.churn_rate_90d < baseline.avg_churn_rate * 1.5
