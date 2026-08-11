-- Average time-on-page, in seconds. target_label IS NULL excludes the
-- per-image duration segments that only exist on work_detail (see
-- avg_time_by_image.sql for those) so this stays a clean page-level metric.
CREATE OR REPLACE VIEW avg_time_by_page AS
SELECT
    page,
    COUNT(*) AS samples,
    AVG(duration_ms) / 1000.0 AS avg_seconds
FROM epwebsite_analytics.events
WHERE event_type = 'duration' AND target_label IS NULL
GROUP BY page
ORDER BY avg_seconds DESC
