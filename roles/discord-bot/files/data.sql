-- data.sql - Discord Bot seed data
-- Idempotent: ON CONFLICT DO NOTHING
-- Config names MUST match the code in src/database/config.ts

-- ═══════════════════════════════════════════════════════════════════════
-- members_info_type
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO public.members_info_type (id, type) VALUES (1, 'join') ON CONFLICT DO NOTHING;
INSERT INTO public.members_info_type (id, type) VALUES (2, 'leave') ON CONFLICT DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════
-- commands (must match logCommand() calls in src/commands/*.ts)
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO public.commands (name) VALUES ('annonce') ON CONFLICT (name) DO NOTHING;
INSERT INTO public.commands (name) VALUES ('brainstorming') ON CONFLICT (name) DO NOTHING;
INSERT INTO public.commands (name) VALUES ('config') ON CONFLICT (name) DO NOTHING;
INSERT INTO public.commands (name) VALUES ('help') ON CONFLICT (name) DO NOTHING;
INSERT INTO public.commands (name) VALUES ('ping') ON CONFLICT (name) DO NOTHING;
INSERT INTO public.commands (name) VALUES ('poll') ON CONFLICT (name) DO NOTHING;
INSERT INTO public.commands (name) VALUES ('stats') ON CONFLICT (name) DO NOTHING;
INSERT INTO public.commands (name) VALUES ('serverinfo') ON CONFLICT (name) DO NOTHING;
INSERT INTO public.commands (name) VALUES ('setstatus') ON CONFLICT (name) DO NOTHING;
INSERT INTO public.commands (name) VALUES ('anniv') ON CONFLICT (name) DO NOTHING;
INSERT INTO public.commands (name) VALUES ('getanniv') ON CONFLICT (name) DO NOTHING;
INSERT INTO public.commands (name) VALUES ('giveaway') ON CONFLICT (name) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════
-- config: guild
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO public.config (name, value, type, user_id_last_edit)
VALUES ('GUILD_ID_MAIN', '1180826203544899627', 'string', 'default_system')
ON CONFLICT (name) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════
-- config: roles
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO public.config (name, value, type, user_id_last_edit)
VALUES ('ROLE_ADMIN', '1306743400854196275', 'string', 'default_system')
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.config (name, value, type, user_id_last_edit)
VALUES ('ROLE_SUPER_ADMIN', '1306751770332106825', 'string', 'default_system')
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.config (name, value, type, user_id_last_edit)
VALUES ('ROLE_MEMBRE', '', 'string', 'default_system')
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.config (name, value, type, user_id_last_edit)
VALUES ('ROLE_ADHERENT_1', '', 'string', 'default_system')
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.config (name, value, type, user_id_last_edit)
VALUES ('ROLE_ADHERENT_PLUS', '', 'string', 'default_system')
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.config (name, value, type, user_id_last_edit)
VALUES ('ROLE_ADHERENT_MAX', '', 'string', 'default_system')
ON CONFLICT (name) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════
-- config: channels
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO public.config (name, value, type, user_id_last_edit)
VALUES ('CHANNEL_LOGGER', '1307498720618741770', 'string', 'default_system')
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.config (name, value, type, user_id_last_edit)
VALUES ('CHANNEL_TWITTER', '625012532998045707', 'string', 'default_system')
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.config (name, value, type, user_id_last_edit)
VALUES ('CHANNEL_WELCOME', '', 'string', 'default_system')
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.config (name, value, type, user_id_last_edit)
VALUES ('CHANNEL_PUBLIC_LOG', '', 'string', 'default_system')
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.config (name, value, type, user_id_last_edit)
VALUES ('CHANNEL_ANNIV', '', 'string', 'default_system')
ON CONFLICT (name) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════
-- config: features
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO public.config (name, value, type, user_id_last_edit)
VALUES ('NEW_MEMBER_ACTIVATED', 'false', 'boolean', 'default_system')
ON CONFLICT (name) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════
-- config: RSS / Twitter
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO public.config (name, value, type, user_id_last_edit)
VALUES ('RSS_FEED_URL', 'https://rss.app/feeds/r9Fw35WIl7KMif8P.xml', 'string', 'default_system')
ON CONFLICT (name) DO NOTHING;
