-- 001_init.sql
-- Initial schema for MoodLog database
-- Creates users and moods tables with required fields and constraints

-- Ensure migration schema table exists
CREATE TABLE IF NOT EXISTS schema_migrations (
    id SERIAL PRIMARY KEY,
    filename TEXT NOT NULL UNIQUE,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Detect extension availability
DO $$
BEGIN
    -- noop block to ensure extensions table is already attempted in 000_extensions.sql
    PERFORM 1;
END$$;

-- Users table with fallback when citext is unavailable
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'citext') THEN
        -- Preferred: CITEXT for case-insensitive unique email
        CREATE TABLE IF NOT EXISTS users (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            name TEXT NOT NULL,
            email CITEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
    ELSE
        -- Fallback: TEXT email plus unique index on lower(email) to simulate case-insensitivity
        CREATE TABLE IF NOT EXISTS users (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            name TEXT NOT NULL,
            email TEXT NOT NULL,
            password_hash TEXT NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );

        -- Create a unique index on lower(email) only if it doesn't exist
        IF NOT EXISTS (
            SELECT 1
            FROM pg_indexes
            WHERE schemaname = 'public' AND indexname = 'users_email_lower_unique_idx'
        ) THEN
            CREATE UNIQUE INDEX users_email_lower_unique_idx ON users (LOWER(email));
        END IF;
    END IF;
EXCEPTION WHEN undefined_function THEN
    -- If gen_random_uuid() not available (pgcrypto missing), create without default and apps must supply UUIDs
    RAISE NOTICE 'gen_random_uuid() missing; creating users without default.';
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'citext') THEN
        CREATE TABLE IF NOT EXISTS users (
            id UUID PRIMARY KEY,
            name TEXT NOT NULL,
            email CITEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
    ELSE
        CREATE TABLE IF NOT EXISTS users (
            id UUID PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT NOT NULL,
            password_hash TEXT NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
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
BEGIN
    CREATE TABLE IF NOT EXISTS moods (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        mood_type TEXT NOT NULL CHECK (mood_type IN ('happy','sad','neutral','anxious','excited','angry','tired','stressed','grateful','calm')),
        note TEXT,
        date DATE NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        UNIQUE (user_id, date)
    );
EXCEPTION WHEN undefined_function THEN
    RAISE NOTICE 'gen_random_uuid() missing; creating moods without default.';
    CREATE TABLE IF NOT EXISTS moods (
        id UUID PRIMARY KEY,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        mood_type TEXT NOT NULL CHECK (mood_type IN ('happy','sad','neutral','anxious','excited','angry','tired','stressed','grateful','calm')),
        note TEXT,
        date DATE NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        UNIQUE (user_id, date)
    );
END$$;
