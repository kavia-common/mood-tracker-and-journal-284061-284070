-- 000_extensions.sql
-- Ensure required PostgreSQL extensions exist prior to schema creation
-- This migration is idempotent and safe to run without superuser privileges.

-- CITEXT extension provides case-insensitive text which we use for emails.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'citext') THEN
        BEGIN
            CREATE EXTENSION IF NOT EXISTS citext;
            RAISE NOTICE 'citext extension created.';
        EXCEPTION WHEN insufficient_privilege THEN
            RAISE NOTICE 'Could not create citext extension due to insufficient privileges. Email column will fall back to TEXT with LOWER(email) unique index.';
        WHEN duplicate_object THEN
            -- Already exists
            NULL;
        END;
    ELSE
        RAISE NOTICE 'citext extension already present.';
    END IF;
END$$;

-- PGCRYPTO provides gen_random_uuid(); attempt to create but continue if not permitted.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto') THEN
        BEGIN
            CREATE EXTENSION IF NOT EXISTS pgcrypto;
            RAISE NOTICE 'pgcrypto extension created.';
        EXCEPTION WHEN insufficient_privilege THEN
            RAISE NOTICE 'Could not create pgcrypto extension; ensure UUIDs are provided by application/seed.';
        WHEN duplicate_object THEN
            NULL;
        END;
    ELSE
        RAISE NOTICE 'pgcrypto extension already present.';
    END IF;
END$$;
