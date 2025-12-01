# MoodLog Database (PostgreSQL)

This container stores users and their daily mood entries for the MoodLog application. It includes schema migrations, indexes, and seed data for a demo user with a realistic streak.

## Features

- PostgreSQL schema: `users` and `moods` tables
- Idempotent migrations (001_init.sql, 002_indexes.sql)
- Seed script to create a demo user and multi-day mood streak
- Startup script applies migrations and optional seed
- .env.example with required configuration variables

## Schema Overview

- users
  - id (UUID, PK)
  - name (text)
  - email (citext unique; falls back to text if extension not available)
  - password_hash (text; use bcrypt in apps)
  - created_at (timestamp with time zone, default now)
- moods
  - id (UUID, PK)
  - user_id (UUID, FK -> users.id, ON DELETE CASCADE)
  - mood_type (text, constrained to allowed values: happy, sad, neutral, anxious, excited, angry, tired, stressed, grateful, calm)
  - note (text, optional)
  - date (date, required)
  - created_at (timestamp with time zone, default now)
  - unique(user_id, date) to ensure one mood per user per day

## Getting Started

1) Copy environment file
- Create a .env at this directory based on .env.example and adjust if needed.

2) Start or connect to PostgreSQL and run migrations
- Use the provided startup script:

```bash
bash startup.sh
```

This script:
- Starts a local PostgreSQL server when possible (or assumes an external server)
- Ensures the database and user exist
- Applies all migrations in migrations/ idempotently
- Optionally runs the seed script when `SEED=true`

3) Seeding
- Seed inserts:
  - Demo user: email demo@example.com, password "password123" (bcrypt hash stored)
  - 21 days of mood entries including today to simulate streaks
- To enable seeding, set `SEED=true` in your .env (or export it in your shell) before running `startup.sh`.

## Environment Variables

See .env.example; key variables:
- POSTGRES_HOST
- POSTGRES_PORT
- POSTGRES_DB
- POSTGRES_USER
- POSTGRES_PASSWORD
- DATABASE_URL (postgresql://USER:PASSWORD@HOST:PORT/DB)
- SEED (true/false)

The startup script writes a connection helper to `db_connection.txt` and generates `db_visualizer/postgres.env` for the included simple DB viewer.

## Migrations

- 001_init.sql: creates tables and extensions (citext, pgcrypto) when permitted, plus schema_migrations table.
- 002_indexes.sql: adds useful indexes `users_email_idx` and `moods_user_date_idx`.

Migrations are tracked in `schema_migrations` to ensure idempotency.

## Notes

- If pgcrypto or citext extensions cannot be created due to permissions, notices are logged; the application will still function (email uniqueness remains but may be case-sensitive if citext is unavailable).
- UUID defaults rely on pgcrypto's gen_random_uuid(). If unavailable, the application/seed uses explicit gen_random_uuid() calls; if the function is missing it will log a notice. For production, ensure `CREATE EXTENSION pgcrypto;`.

## Useful Commands

- Run startup/migrations/seed:
  - `bash startup.sh`
- Connect to DB:
  - `cat db_connection.txt` (then run the printed psql command)
- View tables using the simple viewer (optional):
  - `cd db_visualizer && npm install && npm start`
  - `source postgres.env` before starting to point to your DB

## License

Internal project component. See root project license if applicable.
