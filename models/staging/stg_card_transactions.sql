with source as (
    select * from {{ source('payments_demo', 'card_transactions') }}
),

renamed as (
    select
        id                                          as card_transaction_id,
        organization_id                             as org_id,
        safe_cast(payment_id as int64)              as payment_id,
        safe_cast(invoice_id as int64)              as invoice_id,
        safe_cast(counterparty_id as int64)         as counterparty_id,
        mcc_id,
        processor_id,
        safe_cast(parent_transaction_id as int64)   as parent_transaction_id,

        transaction_type,
        outcome,
        currency_code,
        amount,
        amount_usd,
        card_brand,
        card_last4,
        card_country,
        card_funding_type,

        -- Interchange (story #10)
        interchange_amount,
        interchange_rate_bps,
        platform_fee_amount,
        net_settlement_amount,

        -- Risk
        risk_score,
        risk_decision,
        three_ds_status,
        avs_result,
        cvv_result,

        -- Timestamps
        safe_cast(created_at as timestamp)          as created_at,
        safe_cast(settled_at as timestamp)          as settled_at,

        -- Derived flags
        transaction_type = 'sale'                   as is_sale,
        outcome = 'approved'                        as is_approved,
        outcome = 'declined'                        as is_declined,
        transaction_type = 'refund'                 as is_refund,

        -- Story #2 — Q4 flag
        extract(month from safe_cast(created_at as timestamp))
            in (11, 12)                             as is_q4,

        -- Date helpers
        date(safe_cast(created_at as timestamp))    as txn_date,
        date_trunc(date(safe_cast(created_at as timestamp)), month)
                                                    as txn_month

    from source
)

select * from renamed
