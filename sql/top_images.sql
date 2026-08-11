-- Most-viewed artworks: thumbnail clicks in the collections grid, works
-- sidebar clicks, and next/previous navigation inside the image viewer all
-- roll up here since they're all event_type = 'view_image'.
CREATE OR REPLACE VIEW top_images AS
SELECT
    collection_id,
    target_label AS image_name,
    COUNT(*) AS views,
    COUNT(DISTINCT visitor_id) AS unique_visitors
FROM epwebsite_analytics.events
WHERE event_type = 'view_image' AND target_label IS NOT NULL
GROUP BY collection_id, target_label
ORDER BY views DESC
