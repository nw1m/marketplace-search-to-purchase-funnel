-- PostgreSQL. Импортируйте sessions.csv в таблицу sessions,
-- events.csv в таблицу events. В events должны быть event_time TIMESTAMP.

-- 1. Быстрая проверка событий
SELECT event_name, COUNT(DISTINCT session_id) AS sessions
FROM events GROUP BY event_name ORDER BY sessions DESC;

-- 2. Воронка: число сессий на каждом шаге
SELECT event_name, COUNT(DISTINCT session_id) AS sessions
FROM events
WHERE event_name IN ('search_submitted', 'product_viewed', 'add_to_cart',
                     'checkout_started', 'purchase_completed')
GROUP BY event_name
ORDER BY CASE event_name
    WHEN 'search_submitted' THEN 1
    WHEN 'product_viewed' THEN 2
    WHEN 'add_to_cart' THEN 3
    WHEN 'checkout_started' THEN 4
    WHEN 'purchase_completed' THEN 5 END;

-- 3. Конверсия в покупку по устройству
WITH session_flags AS (
    SELECT s.session_id, s.device,
           BOOL_OR(e.event_name = 'purchase_completed') AS purchased
    FROM sessions s
    LEFT JOIN events e USING (session_id)
    GROUP BY s.session_id, s.device
)
SELECT device, COUNT(*) AS sessions,
       COUNT(*) FILTER (WHERE purchased) AS purchased_sessions,
       ROUND(COUNT(*) FILTER (WHERE purchased)::numeric / COUNT(*), 4) AS purchase_conversion
FROM session_flags
GROUP BY device ORDER BY purchase_conversion DESC;

-- 4. Конверсия в покупку по каналу привлечения
WITH session_flags AS (
    SELECT s.session_id, s.acquisition_channel,
           BOOL_OR(e.event_name = 'purchase_completed') AS purchased
    FROM sessions s LEFT JOIN events e USING (session_id)
    GROUP BY s.session_id, s.acquisition_channel
)
SELECT acquisition_channel, COUNT(*) AS sessions,
       ROUND(COUNT(*) FILTER (WHERE purchased)::numeric / COUNT(*), 4) AS purchase_conversion
FROM session_flags
GROUP BY acquisition_channel ORDER BY purchase_conversion DESC;

-- 5. Переход от просмотра товара к корзине
WITH session_flags AS (
    SELECT session_id,
           BOOL_OR(event_name = 'product_viewed') AS viewed,
           BOOL_OR(event_name = 'add_to_cart') AS added_to_cart
    FROM events GROUP BY session_id
)
SELECT COUNT(*) FILTER (WHERE viewed) AS viewed_sessions,
       COUNT(*) FILTER (WHERE added_to_cart) AS cart_sessions,
       ROUND(COUNT(*) FILTER (WHERE added_to_cart)::numeric /
             NULLIF(COUNT(*) FILTER (WHERE viewed), 0), 4) AS view_to_cart_conversion
FROM session_flags;
