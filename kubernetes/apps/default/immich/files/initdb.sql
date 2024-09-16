ALTER DATABASE immich SET search_path TO "$user", public, vectors;
CREATE EXTENSION IF NOT EXISTS vectors;
CREATE EXTENSION IF NOT EXISTS earthdistance CASCADE;
ALTER SCHEMA vectors OWNER TO pg_database_owner;
