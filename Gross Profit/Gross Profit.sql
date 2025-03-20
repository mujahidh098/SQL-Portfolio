WITH LatestStock AS ( -- Finding the latest transaction date for each stock item
    SELECT
        st.stockItemStockCode,
        MAX(DATE(st.dateOfCapture)) AS LastTransactionDate
    FROM
        StockTransactions st
    GROUP BY
        st.stockItemStockCode
),
LatestOpeningStock AS ( -- Finding the opening stock, which is the sum of all transactions before the earliest date
    SELECT
        st_sub.stockItemStockCode,
        COALESCE(SUM(st_sub.txTransactionCost), 0) AS OpeningStock
    FROM
        StockTransactions st_sub
    WHERE
        DATE(st_sub.dateOfCapture) < '2025-02-22' -- Replace with earliest date
    GROUP BY
        st_sub.stockItemStockCode
),
LatestClosingStock AS ( -- Finding the closing stock, which is the sum of all transactions before the latest date
    SELECT
        st_sub.stockItemStockCode,
        COALESCE(SUM(st_sub.txTransactionCost), 0) AS ClosingStock
    FROM
        StockTransactions st_sub
    WHERE
        DATE(st_sub.dateOfCapture) <= '2025-02-22' -- Replace with latest date
    GROUP BY
        st_sub.stockItemStockCode
)
SELECT *, -- Selecting everything in the query below along with the calculated difference
       COALESCE(TheoreticalGrossProfit - ActualGrossProfit, 0) AS Difference -- Calculation between the Theoretical and Actual Gross Profit values
FROM (
    SELECT
        si.stockCode AS Code,
        si.description AS Description,
        sc.name AS Category,
        COALESCE(MIN(DATE(st.dateOfCapture)), '2025-02-22') AS StartDate, -- Replace with earliest date
        COALESCE(MAX(DATE(st.dateOfCapture)), '2025-02-22') AS EndDate, -- Replace with latest date
        COALESCE(los.OpeningStock, 0) AS OpeningStock,
        COALESCE(SUM(CASE
            WHEN st.sourceType IN ('DELIVERY_INCREASE', 'DELIVERY_DECREASE', 'CREDIT_NOTE_INCREASE', 'CREDIT_NOTE_DECREASE', 'STOCK_RETURN')
            THEN st.txTransactionCost ELSE 0 END), 0) AS Purchases,
        COALESCE(SUM(CASE
            WHEN st.sourceType IN ('TRANSFER_INCREASE', 'TRANSFER_DECREASE', 'PRODUCTION_INCREASE', 'PRODUCTION_DECREASE', 'WASTE', 'REVERSE_TRANSFER_INCREASE', 'REVERSE_TRANSFER_DECREASE', 'REVERSE_WASTE')
            THEN st.txTransactionCost ELSE 0 END), 0) AS NetStockMovement,
        COALESCE(lcs.ClosingStock, 0) AS ClosingStock,
        COALESCE(-(
            SUM(CASE WHEN st.sourceType = 'ORDER' THEN st.txTransactionCost ELSE 0 END) +
            SUM(CASE WHEN st.sourceType = 'VOID_ORDER' THEN st.txTransactionCost ELSE 0 END)
        ), 0) AS TheoreticalGrossProfit,
        COALESCE((
            COALESCE(los.OpeningStock, 0) +
            COALESCE(SUM(CASE WHEN st.sourceType IN ('DELIVERY_INCREASE', 'DELIVERY_DECREASE', 'CREDIT_NOTE_INCREASE', 'CREDIT_NOTE_DECREASE', 'STOCK_RETURN')
                THEN st.txTransactionCost ELSE 0 END), 0) +
            COALESCE(SUM(CASE WHEN st.sourceType IN ('TRANSFER_INCREASE', 'TRANSFER_DECREASE', 'PRODUCTION_INCREASE', 'PRODUCTION_DECREASE', 'WASTE', 'REVERSE_TRANSFER_INCREASE', 'REVERSE_TRANSFER_DECREASE', 'REVERSE_WASTE')
                THEN st.txTransactionCost ELSE 0 END), 0) -
            COALESCE(lcs.ClosingStock, 0)
        ), 0) AS ActualGrossProfit
    FROM
        StockItems si
    LEFT JOIN
    	StockItemOverrides soi ON si.stockItemExternalId = soi.stockItemExternalId    
    LEFT JOIN
        StockTransactions st ON st.stockItemStockCode = si.stockCode
        AND DATE(st.dateOfCapture) BETWEEN '2025-02-22' AND '2025-02-22' -- Replace with actual date range