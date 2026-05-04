{{
  config(
    materialized='table',
    partition_by={'field': 'ticket_week', 'data_type': 'date'},
    cluster_by=['feature_area', 'category']
  )
}}

select
    st.ticket_week,
    st.feature_area,
    st.category,
    st.sub_category,
    st.priority,
    st.channel,

    count(*)                                as ticket_count,
    countif(st.is_resolved)                as resolved_count,
    countif(st.sla_breached)               as sla_breached_count,
    countif(st.is_negative)                as negative_sentiment_count,
    countif(st.escalated)                  as escalated_count,
    countif(st.is_v418_spike_ticket)       as spike_window_ticket_count,

    round(avg(st.time_to_resolution_seconds) / 3600, 2)
                                            as avg_hours_to_resolve,
    round(avg(
        case when st.csat_score is not null
             then safe_cast(st.csat_score as float64) end
    ), 2)                                   as avg_csat,

    countif(st.linked_release_id = {{ var('release_v418_id') }})
                                            as linked_to_v418,

    -- Story #8 window flag
    st.ticket_week between '2025-08-11' and '2025-08-25'
                                            as in_spike_window

from {{ ref('stg_support_tickets') }}       st
group by 1, 2, 3, 4, 5, 6
