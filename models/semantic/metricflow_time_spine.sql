-- MetricFlow requires a time spine model: a continuous sequence of dates
-- used as the reference axis for all time-based metric calculations.
-- BigQuery's GENERATE_DATE_ARRAY is the cleanest way to produce this.

select
    cast(date_day as date) as date_day
from
    unnest(
        generate_date_array('2020-01-01', current_date(), interval 1 day)
    ) as date_day
