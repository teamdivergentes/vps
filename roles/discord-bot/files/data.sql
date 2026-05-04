-- data.sql - Discord Bot seed data
-- Idempotent: ON CONFLICT DO NOTHING
-- Config names MUST match the code in src/database/config.ts

-- ═══════════════════════════════════════════════════════════════════════
-- members_info_type
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO public.members_info_type (id, type) VALUES (1, 'join') ON CONFLICT DO NOTHING;
INSERT INTO public.members_info_type (id, type) VALUES (2, 'leave') ON CONFLICT DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════
-- commands (auto-registered by logCommand() in app.ts, seeds for initial setup)
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
INSERT INTO public.commands (name) VALUES ('meeting') ON CONFLICT (name) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════
-- config: guild
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO public.config (name, value, type, user_id_last_edit)
VALUES ('GUILD_ID_MAIN', '352882225970282519', 'string', 'default_system')
ON CONFLICT (name) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════
-- config: roles
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO public.config (name, value, type, user_id_last_edit)
VALUES ('ROLE_MEMBRE', '592342937912999972', 'string', 'default_system')
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.config (name, value, type, user_id_last_edit)
VALUES ('ROLE_ADHERENT_1', '656152737045676044', 'string', 'default_system')
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.config (name, value, type, user_id_last_edit)
VALUES ('ROLE_ADHERENT_PLUS', '656152526348877824', 'string', 'default_system')
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.config (name, value, type, user_id_last_edit)
VALUES ('ROLE_ADHERENT_MAX', '656153160020131853', 'string', 'default_system')
ON CONFLICT (name) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════
-- config: channels
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO public.config (name, value, type, user_id_last_edit)
VALUES ('CHANNEL_TWITTER', '625012532998045707', 'string', 'default_system')
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.config (name, value, type, user_id_last_edit)
VALUES ('CHANNEL_ANNIV', '352882225970282520', 'string', 'default_system')
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.config (name, value, type, user_id_last_edit)
VALUES ('CHANNEL_MEMBER_LOGGER', '535872942320648203', 'string', 'default_system')
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.config (name, value, type, user_id_last_edit)
VALUES ('CHANNEL_NEW_MEMBER', '654345662401609728', 'string', 'default_system')
ON CONFLICT (name) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════
-- config: features
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO public.config (name, value, type, user_id_last_edit)
VALUES ('NEW_MEMBER_ACTIVATED', 'true', 'boolean', 'default_system')
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.config (name, value, type, user_id_last_edit)
VALUES ('MEMBERS_LOG_RETENTION_DAYS', '180', 'int', 'default_system')
ON CONFLICT (name) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════
-- config: RSS / Twitter
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO public.config (name, value, type, user_id_last_edit)
VALUES ('RSS_FEED_URL', 'https://rss.app/feeds/r9Fw35WIl7KMif8P.xml', 'string', 'default_system')
ON CONFLICT (name) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════
-- config: association
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO public.config (name, value, type, user_id_last_edit)
VALUES ('ASSOCIATION_CONTEXT', 'Team Divergentes (DVG) est une association loi 1901 fondee en 2017 a Paris, structuree autour de l''esport inclusif et humain. Ses valeurs sont l''inclusion, le respect et l''innovation. L''association compte une quarantaine de membres actifs (joueurs, staff, coachs) et evolue sur plusieurs jeux competitifs : Rocket League, Valorant, Trackmania, Rainbow Six Siege. Ses activites incluent la formation de joueurs, l''organisation de tournois locaux et d''evenements communautaires. Les reunions portent generalement sur la gestion de l''association (bureau, CA), le recrutement, la strategie esportive, la communication, et les evenements.', 'string', 'default_system')
ON CONFLICT (name) DO NOTHING;
