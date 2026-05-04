-- tests/assert_subbox_cb_rate_ramp.sql
-- Story #3: Subscription Box chargeback rate must be higher in H1 2026
-- than in H1 2025. If this test fails the data generation went wrong.

with early as (
    select avg(chargeback_rate) as avg_rate
    from {{ ref('mart_chargeback_rate_by_industry_month') }}
    where is_subscription_box
      and txn_month between '2025-01-01' and '2025-06-01'
),

late as (
    select avg(chargeback_rate) as avg_rate
    from {{ ref('mart_chargeback_rate_by_industry_month') }}
    where is_subscription_box
      and txn_month between '2026-01-01' and '2026-06-01'
)

-- Returns a row (test failure) if the rate did NOT increase
select 1
from early, late
where late.avg_rate <= early.avg_rate
