-- 001_init.sql
-- Initial schema for MoodLog database
-- Creates users and moods tables with required fields and constraints

-- Ensure migration schema table exists
CREATE TABLE IF NOT EXISTS schema_migrations (
    id SERIAL PRIMARY KEY,
    filename TEXT NOT NULL UNIQUE,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Users table with fallback when citext is unavailable.
-- Also tolerate missing gen_random_uuid() by falling back to no default.
DO $$
DECLARE
    has_citext boolean := EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'citext');
    has_pgcrypto boolean := EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto');
BEGIN
    IF has_citext THEN
        IF has_pgcrypto THEN
            CREATE TABLE IF NOT EXISTS users (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                name TEXT NOT NULL,
                email CITEXT NOT NULL UNIQUE,
                password_hash TEXT NOT NULL,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            );
        ELSE
            RAISE NOTICE 'pgcrypto not available; creating users without UUID default.';
            CREATE TABLE IF NOT EXISTS users (
                id UUID PRIMARY KEY,
                name TEXT NOT NULL,
                email CITEXT NOT NULL UNIQUE,
                password_hash TEXT NOT NULL,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            );
        END IF;
    ELSE
        IF has_pgcrypto THEN
            CREATE TABLE IF NOT EXISTS users (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                name TEXT NOT NULL,
                email TEXT NOT NULL,
                password_hash TEXT NOT NULL,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            );
        ELSE
            RAISE NOTICE 'pgcrypto not available; creating users without UUID default.';
            CREATE TABLE IF NOT EXISTS users (
                id UUID PRIMARY KEY,
                name TEXT NOT NULL,
                email TEXT NOT NULL,
                password_hash TEXT NOT NULL,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            );
        END IF;

        -- Ensure a case-insensitive unique index exists on lower(email)
        IF NOT EXISTS (
            SELECT 1
            FROM pg_indexes
            WHERE schemaname = 'public' AND indexname = 'users_email_lower_unique_idx'
        ) THEN
            CREATE UNIQUE INDEX users_email_lower_unique_idx ON users (LOWER(email));
        END IF;
    END IF;
END$$;

-- Moods table
DO $$
DECLARE
    has_pgcrypto boolean := EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto');
BEGIN
    IF has_pgcrypto THEN
        CREATE TABLE IF NOT EXISTS moods (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            mood_type TEXT NOT NULL CHECK (mood_type IN ('happy','sad','neutral','anxious','excited','angry','tired','stressed','grateful','calm')),
            note TEXT,
            date DATE NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            UNIQUE (user_id, date)
        );
    ELSE
        RAISE NOTICE 'pgcrypto not available; creating moods without UUID default.';
        CREATE TABLE IF NOT EXISTS moods (
            id UUID PRIMARY KEY,
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            mood_type TEXT NOT NULL CHECK (mood_type IN ('happy','sad','neutral','anxious','excited','angry','tired','stressed','grateful','calm')),
            note TEXT,
            date DATE NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            UNIQUE (user_id, date)
        );
    END IF;
END$$;
