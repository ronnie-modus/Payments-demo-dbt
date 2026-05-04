with source as (
    select * from {{ source('payments_demo', 'organizations') }}
),

renamed as (
    select
        id                                      as org_id,
        legal_name,
        display_name,
        partner_id,
        current_plan_id,
        industry_id,
        country_id,
        account_status,
        signup_source,
        signup_campaign_id,
        city,
        state,
        default_currency_code,
        nps_score_latest,
        landing_visitor_id,
        churn_reason,
        internal_notes,

        -- Timestamps
        created_at                              as org_created_at,
        safe_cast(activated_at as timestamp)    as activated_at,
        safe_cast(trial_ended_at as timestamp)  as trial_ended_at,
        safe_cast(churned_at as timestamp)      as churned_at,
        safe_cast(deleted_at as timestamp)      as deleted_at,

        -- Derived flags
        display_name not like '[Internal]%'     as is_customer_org,
        account_status = 'churned'              as is_churned,
        account_status = 'active'               as is_active,
        account_status = 'kyc_stalled'          as is_kyc_stalled,

        -- Derived durations
        timestamp_diff(
            coalesce(safe_cast(churned_at as timestamp), current_timestamp()),
            created_at, day
        )                                       as days_as_customer,

        -- Story #14 — bad-fit campaign marker
        signup_campaign_id = {{ var('bad_fit_campaign_id') }}
                                                as is_bad_fit_campaign_org

    from source
)

select * from renamed
