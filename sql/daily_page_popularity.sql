-- Page views per calendar day, with a proper DATE column so QuickSight can
-- natively group by day/week/month/quarter/year without any extra config.
CREATE OR REPLACE VIEW daily_page_popularity AS
SELECT
    date(concat(year, '-', month, '-', day)) AS visit_date,
    page,
    COUNT(*) AS page_views,
    COUNT(DISTINCT visitor_id) AS unique_visitors
FROM epwebsite_analytics.events
WHERE event_type = 'page_view'
GROUP BY year, month, day, page
