with source as (
    select * from {{ source('payments_demo', 'sanctions_screenings') }}
),

renamed as (
    select
        id                                          as screening_id,
        target_type,
        safe_cast(target_id as int64)               as target_id,
        organization_id                             as org_id,
        safe_cast(reviewer_user_id as int64)        as reviewer_user_id,

        screening_list_version,
        outcome,
        match_score,
        matched_list,
        review_outcome,
        caused_payment_delay,
        delay_seconds,

        -- Timestamps
        safe_cast(screened_at as timestamp)         as screened_at,
        safe_cast(reviewed_at as timestamp)         as reviewed_at,

        -- Derived
        outcome = 'clear'                           as is_clear,
        outcome = 'potential_match'                 as is_false_positive,
        outcome = 'confirmed_match'                 as is_true_positive,
        caused_payment_delay = true                 as caused_delay,

        -- Story #9 — refresh version flag
        screening_list_version = 'v2026.03'         as is_problematic_list_version,

        -- Date helpers
        date_trunc(date(safe_cast(screened_at as timestamp)), month)
                                                    as screened_month

    from source
)

select * from renamed
