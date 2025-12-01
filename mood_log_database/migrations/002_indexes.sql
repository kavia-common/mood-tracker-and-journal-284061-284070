-- 002_indexes.sql
-- Adds useful indexes to the MoodLog database

-- Users: email unique index (already enforced by UNIQUE on column, but add explicit named index)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = 'public' AND indexname = 'users_email_idx'
    ) THEN
        CREATE INDEX users_email_idx ON users (email);
    END IF;
END$$;

-- Moods: composite index for user_id and date (also unique constraint exists)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = 'public' AND indexname = 'moods_user_date_idx'
    ) THEN
        CREATE INDEX moods_user_date_idx ON moods (user_id, date);
    END IF;
END$$;
