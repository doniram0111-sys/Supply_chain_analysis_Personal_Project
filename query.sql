-- =====================================================================
-- ASUMSI YANG DIPAKAI (silakan ubah sesuai kebijakan/tingkat layanan bisnis):
--   Z_SCORE            : 1.65  -> service level ~95% (peluang stockout ~5%)
--                         (1.28 = 90%, 1.65 = 95%, 2.05 = 98%, 2.33 = 99%)
--   DEMAND_CV          : 0.25  -> Coefficient of Variation permintaan harian.
--                         Data ini TIDAK punya std dev demand asli (hanya 1
--                         angka/SKU), jadi CV di sini adalah proxy/asumsi
--                         (0.25 = variabilitas moderat, dipakai kalau data
--                         historis harian tidak tersedia).
-- =====================================================================
--CREATE TABLE exer AS
WITH params AS (
    SELECT
        1.65  AS z_score,
        0.25  AS demand_cv,
        2.5   AS overstock_multiplier
),
base AS (
    SELECT
        "SKU"                         AS sku,
        "Product type"                AS product_type,
        "Price"                       AS price,
        "Availability"                AS availability,
        "Number of products sold"     AS number_of_products_sold,
        ("Number of products sold" * "Price") AS revenue_generated,
        "Customer demographics"       AS customer_demographics,
        "Stock levels"                AS stock_levels,
        "Lead times"                  AS order_lead_time,
        "Order quantities"            AS order_quantity,
        "Shipping times"              AS shipping_time,
        "Shipping carriers"           AS shipping_carrier,
        "Shipping costs"              AS shipping_cost,
        "Supplier name"               AS supplier_name,
        "Location"                    AS location,
        "Lead time"                   AS supplier_lead_time,
        "Production volumes"          AS production_volume,
        "Manufacturing lead time"     AS manufacturing_lead_time,
        "Manufacturing costs"         AS manufacturing_cost,
        "Inspection results"          AS inspection_result,
        "Defect rates"                AS defect_rate,
        "Transportation modes"        AS transportation_mode,
        "Routes"                      AS route,
        "Costs"                       AS transportation_cost,
        ("Manufacturing costs" + "Shipping costs" + "Costs") AS total_operational_cost,
        ("Number of products sold" * "Price" - ("Manufacturing costs" + "Shipping costs" + "Costs")) AS net_profit,

        -- Total lead time replenishment (bukan cuma 1 komponen)
        ("Lead time" + "Manufacturing lead time" ) AS total_lead_time,

        -- Demand harian, asumsi "Number of products sold" = total tahunan
        ("Number of products sold" / 365.0) AS daily_demand
    FROM supply_c
)
SELECT
    b.*,

    -- SAFETY STOCK = Z * CV * Demand_harian * SQRT(Total Lead Time)
    CEILING(
        p.z_score * p.demand_cv * b.daily_demand * SQRT(b.total_lead_time)
    ) AS safety_stock,

    -- ROP = (Demand_harian * Total Lead Time) + Safety Stock
    CEILING(
        (b.daily_demand * b.total_lead_time)
        + (p.z_score * p.demand_cv * b.daily_demand * SQRT(b.total_lead_time))
    ) AS rop,

    CASE
        WHEN b.stock_levels <= CEILING(
            p.z_score * p.demand_cv * b.daily_demand * SQRT(b.total_lead_time)
        ) THEN 'Critical / Out of Stock Risk'

        WHEN b.stock_levels <= CEILING(
            (b.daily_demand * b.total_lead_time)
            + (p.z_score * p.demand_cv * b.daily_demand * SQRT(b.total_lead_time))
        ) THEN 'Understock (Reorder)'

        WHEN b.stock_levels > (
            CEILING(
                (b.daily_demand * b.total_lead_time)
                + (p.z_score * p.demand_cv * b.daily_demand * SQRT(b.total_lead_time))
            ) * p.overstock_multiplier
        ) THEN 'Overstock'

        ELSE 'Normal'
    END AS stock_status

FROM base b
CROSS JOIN params p;