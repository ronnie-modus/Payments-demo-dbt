with source as (
    select * from {{ source('payments_demo', 'kyc_kyb_check_steps') }}
),

renamed as (
    select
        id                                          as step_id,
        kyc_kyb_check_id                            as check_id,
        safe_cast(user_id as int64)                 as user_id,

        step_number,
        step_name,
        status,
        failure_reason,
        duration_seconds,

        -- Timestamps
        safe_cast(started_at as timestamp)          as started_at,
        safe_cast(completed_at as timestamp)        as completed_at,

        -- Derived
        status = 'passed'                           as passed,
        status = 'failed'                           as failed,
        step_name = 'legal_details'                 as is_legal_details_step,

        -- Step ordering helper
        case step_name
            when 'personal_details' then 1
            when 'company_details'  then 2
            when 'legal_details'    then 3
            when 'industry'         then 4
        end                                         as step_order

    from source
)

select * from renamed
