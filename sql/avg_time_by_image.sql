-- Average time spent per artwork inside the works.html viewer, in seconds.
-- Each row is one image-viewing segment (see the "duration" event design in
-- epwebsite/js/analytics.js: the clock resets every time Next/Previous
-- navigates to a different image).
CREATE OR REPLACE VIEW avg_time_by_image AS
SELECT
    collection_id,
    target_label AS image_name,
    COUNT(*) AS samples,
    AVG(duration_ms) / 1000.0 AS avg_seconds
FROM epwebsite_analytics.events
WHERE event_type = 'duration' AND target_label IS NOT NULL
GROUP BY collection_id, target_label
ORDER BY avg_seconds DESC
