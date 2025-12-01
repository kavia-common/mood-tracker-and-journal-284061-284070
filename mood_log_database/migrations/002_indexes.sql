-- 002_indexes.sql
-- Adds useful indexes to the MoodLog database

-- Users: If citext is present and users.email is CITEXT (unique already), we can add a named index for lookups.
-- If citext is absent and users.email is TEXT, a unique index on lower(email) should already exist from 001; only add a plain index if not present and not conflicting.
DO $$
DECLARE
    email_data_type text;
    has_citext boolean := EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'citext');
BEGIN
    SELECT data_type INTO email_data_type
    FROM information_schema.columns
    WHERE table_name = 'users' AND column_name = 'email';

    IF has_citext AND email_data_type ILIKE '%citext%' THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_indexes
            WHERE schemaname = 'public' AND indexname = 'users_email_idx'
        ) THEN
            CREATE INDEX users_email_idx ON users (email);
        END IF;
    ELSE
        -- When using TEXT fallback, ensure we don't duplicate the unique LOWER(email) index; add a non-unique lookup index if needed.
        IF NOT EXISTS (
            SELECT 1 FROM pg_indexes
            WHERE schemaname = 'public' AND indexname = 'users_email_lookup_idx'
        ) THEN
            CREATE INDEX users_email_lookup_idx ON users (LOWER(email));
        END IF;
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
