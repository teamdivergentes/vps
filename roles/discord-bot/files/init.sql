-- init.sql - Discord Bot database schema
-- Idempotent: CREATE TABLE IF NOT EXISTS + migrations for existing tables

-- ═══════════════════════════════════════════════════════════════════════
-- Schema
-- ═══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.commands (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS public.config (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    value TEXT NOT NULL,
    type VARCHAR(10) NOT NULL,
    user_id_last_edit VARCHAR(20) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.command_logs (
    id SERIAL PRIMARY KEY,
    command_id VARCHAR(20) NOT NULL,
    author_id VARCHAR(20) NOT NULL,
    channel_id VARCHAR(20) NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.brainstorming (
    id SERIAL PRIMARY KEY,
    author_id VARCHAR(20) NOT NULL,
    message_id VARCHAR(20) NOT NULL,
    channel_id VARCHAR(20) NOT NULL,
    max_user integer NOT NULL,
    subject VARCHAR(200) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expired boolean NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS members (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    guild_id VARCHAR(255) NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    id_info_type INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS members_info_type (
    id SERIAL PRIMARY KEY,
    type VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS birthdays (
    id SERIAL PRIMARY KEY,
    discord_id TEXT NOT NULL UNIQUE,
    birthdate DATE NOT NULL
);

CREATE TABLE IF NOT EXISTS giveaways (
    id SERIAL PRIMARY KEY,
    message_id VARCHAR(20) NOT NULL UNIQUE,
    channel_id VARCHAR(20) NOT NULL,
    guild_id VARCHAR(20) NOT NULL,
    author_id VARCHAR(20) NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    image_url TEXT,
    winners_count INTEGER NOT NULL DEFAULT 1,
    has_weighting BOOLEAN NOT NULL DEFAULT false,
    end_date TIMESTAMP NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS giveaway_participants (
    id SERIAL PRIMARY KEY,
    giveaway_id INTEGER REFERENCES giveaways(id) ON DELETE CASCADE,
    user_id VARCHAR(20) NOT NULL,
    weight INTEGER NOT NULL DEFAULT 1,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(giveaway_id, user_id)
);

CREATE TABLE IF NOT EXISTS giveaway_winners (
    id SERIAL PRIMARY KEY,
    giveaway_id INTEGER REFERENCES giveaways(id) ON DELETE CASCADE,
    user_id VARCHAR(20) NOT NULL,
    winner_position INTEGER NOT NULL,
    announced_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.announcements (
    id SERIAL PRIMARY KEY,
    author_id VARCHAR(20) NOT NULL,
    channel_id VARCHAR(20) NOT NULL,
    guild_id VARCHAR(20) NOT NULL,
    message_id VARCHAR(20),
    content TEXT,
    mention VARCHAR(100),
    attachment_url TEXT,
    repeat_interval VARCHAR(20),
    repeat_time VARCHAR(5),
    next_send_at TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN NOT NULL DEFAULT true,
    sent_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- meetings
CREATE TABLE IF NOT EXISTS meetings (
    id SERIAL PRIMARY KEY,
    guild_id VARCHAR(20) NOT NULL,
    channel_id VARCHAR(20) NOT NULL,
    voice_channel_id VARCHAR(20) NOT NULL,
    author_id VARCHAR(20) NOT NULL,
    title VARCHAR(200) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'recording',
    max_duration_minutes INTEGER NOT NULL DEFAULT 120,
    status_message_id VARCHAR(20),
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP,
    transcript_length INTEGER,
    recovered_from_crash BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- meeting participants
CREATE TABLE IF NOT EXISTS meeting_participants (
    id SERIAL PRIMARY KEY,
    meeting_id INTEGER REFERENCES meetings(id) ON DELETE CASCADE,
    user_id VARCHAR(20) NOT NULL,
    username VARCHAR(100) NOT NULL,
    roles TEXT,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    left_at TIMESTAMP,
    UNIQUE(meeting_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_meetings_guild_status ON meetings(guild_id, status);

-- ═══════════════════════════════════════════════════════════════════════
-- Migrations for existing databases
-- ═══════════════════════════════════════════════════════════════════════

-- 1. Add UNIQUE constraint on commands.name if missing
DO $$
BEGIN
  -- Remove duplicates first (keep lowest id)
  DELETE FROM public.commands a USING public.commands b
  WHERE a.id > b.id AND a.name = b.name;

  -- Add UNIQUE constraint if not exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'commands_name_key'
      AND conrelid = 'public.commands'::regclass
  ) THEN
    ALTER TABLE public.commands ADD CONSTRAINT commands_name_key UNIQUE (name);
  END IF;
END$$;

-- 2. Add UNIQUE constraint on members_info_type.type if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'members_info_type_type_key'
      AND conrelid = 'public.members_info_type'::regclass
  ) THEN
    ALTER TABLE public.members_info_type ADD CONSTRAINT members_info_type_type_key UNIQUE (type);
  END IF;
END$$;

-- 3. Add FOREIGN KEY on members.id_info_type if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'members_id_info_type_fk'
      AND conrelid = 'public.members'::regclass
  ) THEN
    ALTER TABLE public.members
      ADD CONSTRAINT members_id_info_type_fk
      FOREIGN KEY (id_info_type) REFERENCES public.members_info_type(id);
  END IF;
END$$;

-- 4. Migrate config.value from VARCHAR(100) to TEXT if needed (was migration 3)
DO $$
DECLARE
  col_type text;
BEGIN
  SELECT data_type || COALESCE('(' || character_maximum_length || ')', '')
  INTO col_type
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'config' AND column_name = 'value';

  IF col_type IS DISTINCT FROM 'text' THEN
    ALTER TABLE public.config ALTER COLUMN value TYPE TEXT;
  END IF;
END$$;

-- 5. Rename old config keys to new naming convention (code expects UPPER_CASE)
UPDATE public.config SET name = 'GUILD_ID_MAIN'       WHERE name = 'main_id_guild';
UPDATE public.config SET name = 'ROLE_MEMBRE'          WHERE name = 'guild_id_role_MEMBRE';
UPDATE public.config SET name = 'ROLE_ADHERENT_1'      WHERE name = 'guild_id_role_ADHERENT_1';
UPDATE public.config SET name = 'ROLE_ADHERENT_PLUS'   WHERE name = 'guild_id_role_ADHERENT_PLUS';
UPDATE public.config SET name = 'ROLE_ADHERENT_MAX'    WHERE name = 'guild_id_role_ADHERENT_MAX';
UPDATE public.config SET name = 'CHANNEL_TWITTER'      WHERE name = 'twitter_channel_id';
UPDATE public.config SET name = 'CHANNEL_MEMBER_LOGGER' WHERE name = 'guild_channel_member_logger_id';
UPDATE public.config SET name = 'CHANNEL_NEW_MEMBER'    WHERE name = 'guild_channel_new_member_id';
UPDATE public.config SET name = 'RSS_FEED_URL'         WHERE name = 'rss_feed_url';

-- 6. Clean up dead config keys (removed features)
DELETE FROM public.config WHERE name IN ('ROLE_ADMIN', 'ROLE_SUPER_ADMIN', 'CHANNEL_LOGGER', 'CHANNEL_PUBLIC_LOG', 'CHANNEL_WELCOME', 'BRAINSTORMING_EXPIRATION_TIME', 'POLL_DEFAULT_EXPIRATION_TIME');

-- 7. Enforce meeting title max length 200 (truncate any legacy rows then add CHECK constraint)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'meetings' AND column_name = 'title'
  ) THEN
    UPDATE public.meetings SET title = LEFT(title, 200) WHERE char_length(title) > 200;

    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint
      WHERE conname = 'meetings_title_length_check'
        AND conrelid = 'public.meetings'::regclass
    ) THEN
      ALTER TABLE public.meetings
        ADD CONSTRAINT meetings_title_length_check CHECK (char_length(title) <= 200);
    END IF;
  END IF;
END$$;

-- 8. Add recovered_from_crash flag on meetings (for crash-recovery flow)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'meetings' AND column_name = 'recovered_from_crash'
  ) THEN
    ALTER TABLE public.meetings
      ADD COLUMN recovered_from_crash BOOLEAN NOT NULL DEFAULT FALSE;
  END IF;
END$$;
