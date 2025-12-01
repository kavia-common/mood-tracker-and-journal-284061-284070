-- 000_extensions.sql
-- Ensure required PostgreSQL extensions exist prior to schema creation

-- CITEXT extension provides case-insensitive text which we use for emails.
-- Use IF NOT EXISTS to be idempotent, and guard with DO block to handle insufficient privileges gracefully.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'citext') THEN
        CREATE EXTENSION IF NOT EXISTS citext;
    END IF;
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'Could not create citext extension due to insufficient privileges. Email column will fall back to TEXT.';
END$$;

-- PGCRYPTO provides gen_random_uuid(); attempt to create but continue if not permitted.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto') THEN
        CREATE EXTENSION IF NOT EXISTS pgcrypto;
    END IF;
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'Could not create pgcrypto extension; ensure UUIDs are provided by application/seed.';
END$$;
