-- seed.sql
-- Insert a demo user and a realistic streak of mood entries

-- Ensure required extensions exist when possible
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto') THEN
        CREATE EXTENSION pgcrypto;
    END IF;
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'pgcrypto extension not created in seed';
END$$;

WITH upsert_user AS (
    INSERT INTO users (id, name, email, password_hash)
    VALUES (
        COALESCE(
            (SELECT id FROM users WHERE email = 'demo@example.com'::citext),
            gen_random_uuid()
        ),
        'Demo User',
        'demo@example.com',
        -- bcrypt hash for password: "password123"
        '$2b$12$yXxj9zF3GxvQrq1gH3mIpe0TtQ3x6uJb7n2nUQkq9GgFqv7s8C4f6'
    )
    ON CONFLICT (email) DO UPDATE
        SET name = EXCLUDED.name
    RETURNING id
)
-- Generate moods for the last 21 days
INSERT INTO moods (id, user_id, mood_type, note, date)
SELECT
    gen_random_uuid(),
    (SELECT id FROM upsert_user),
    -- rotate through a set of mood types for variety
    (ARRAY['happy','neutral','excited','calm','tired','stressed','grateful','anxious','happy','neutral','happy','excited','calm','happy','neutral','happy','grateful','happy','calm','happy','neutral'])[(g.n % 21) + 1],
    CASE
        WHEN (g.n % 5) = 0 THEN 'Went for a walk and felt refreshed'
        WHEN (g.n % 5) = 1 THEN 'Work was a bit stressful but manageable'
        WHEN (g.n % 5) = 2 THEN 'Had a great chat with a friend'
        WHEN (g.n % 5) = 3 THEN 'Slept late, a bit tired'
        ELSE 'Cooked a nice meal and relaxed'
    END,
    (CURRENT_DATE - (20 - g.n))
FROM generate_series(0, 20) AS g(n)
ON CONFLICT (user_id, date) DO UPDATE
SET
    mood_type = EXCLUDED.mood_type,
    note = EXCLUDED.note;

-- Ensure at least one mood for today for streak continuity
INSERT INTO moods (id, user_id, mood_type, note, date)
SELECT
    gen_random_uuid(),
    (SELECT id FROM users WHERE email = 'demo@example.com'),
    'happy',
    'Feeling productive and upbeat today!',
    CURRENT_DATE
ON CONFLICT (user_id, date) DO NOTHING;
