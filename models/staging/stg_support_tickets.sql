with source as (
    select * from {{ source('payments_demo', 'support_tickets') }}
),

renamed as (
    select
        id                                          as ticket_id,
        organization_id                             as org_id,
        safe_cast(created_by_user_id as int64)      as created_by_user_id,
        safe_cast(assigned_user_id as int64)        as assigned_user_id,
        safe_cast(linked_release_id as int64)       as linked_release_id,

        channel,
        subject,
        category,
        sub_category,
        feature_area,
        priority,
        status,
        sentiment,
        csat_score,
        message_count,
        reopened_count,
        escalated,
        time_to_first_response_seconds,
        time_to_resolution_seconds,
        sla_breached,

        -- Timestamps
        safe_cast(created_at as timestamp)          as created_at,
        safe_cast(first_response_at as timestamp)   as first_response_at,
        safe_cast(resolved_at as timestamp)         as resolved_at,
        safe_cast(closed_at as timestamp)           as closed_at,

        -- Derived
        status in ('resolved', 'closed')            as is_resolved,
        sentiment = 'negative'                      as is_negative,

        -- Story #8 — spike window flag
        safe_cast(created_at as timestamp)
            between '2025-08-15' and '2025-08-25'
            and feature_area = 'ocr_upload'         as is_v418_spike_ticket,

        -- Date helpers
        date_trunc(date(safe_cast(created_at as timestamp)), week)
                                                    as ticket_week,
        date_trunc(date(safe_cast(created_at as timestamp)), month)
                                                    as ticket_month

    from source
)

select * from renamed
