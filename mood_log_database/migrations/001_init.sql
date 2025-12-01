-- 001_init.sql
-- Initial schema for MoodLog database
-- Creates users and moods tables with required fields and constraints

-- Ensure migration schema table exists
CREATE TABLE IF NOT EXISTS schema_migrations (
    id SERIAL PRIMARY KEY,
    filename TEXT NOT NULL UNIQUE,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    email CITEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Moods table
CREATE TABLE IF NOT EXISTS moods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    mood_type TEXT NOT NULL CHECK (mood_type IN ('happy','sad','neutral','anxious','excited','angry','tired','stressed','grateful','calm')),
    note TEXT,
    date DATE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, date)
);

-- Extensions required
-- Try to create extensions if not already present
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'citext') THEN
        CREATE EXTENSION citext;
    END IF;
EXCEPTION WHEN insufficient_privilege THEN
    -- Fallback: ignore if not permitted; email will still be unique but case-sensitive
    RAISE NOTICE 'Could not create citext extension due to insufficient privileges';
END$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto') THEN
        CREATE EXTENSION pgcrypto;
    END IF;
EXCEPTION WHEN insufficient_privilege THEN
    -- If pgcrypto not available, UUID default gen_random_uuid() will fail; we rely on application to provide UUIDs
    RAISE NOTICE 'Could not create pgcrypto extension; ensure UUIDs are provided by application/seed';
END$$;
