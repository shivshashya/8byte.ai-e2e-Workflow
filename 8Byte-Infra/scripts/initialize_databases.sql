-- Run with psql -X and ON_ERROR_STOP enabled, connected as the RDS administrator.
-- The secure runner must load admin_user, staging_password and production_password
-- via protected stdin before this file. Do not pass passwords in CLI -v arguments,
-- enable psql echo, or save a file containing resolved passwords.
-- Passwords must come from the matching application secrets. Existing users are
-- preserved: this script does not rotate their passwords or drop existing data.
\set ON_ERROR_STOP on

-- Refuse unexpected existing owners before creating users or changing grants.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_database
    WHERE (datname = 'app_staging' AND pg_get_userbyid(datdba) <> 'staging_user')
       OR (datname = 'app_production' AND pg_get_userbyid(datdba) <> 'production_user')
  ) THEN
    RAISE EXCEPTION 'Unexpected application database owner; review before continuing';
  END IF;
END
$$;


SELECT format(
  'CREATE ROLE staging_user LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD %L',
  :'staging_password'
)
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'staging_user')
\gexec

SELECT format(
  'CREATE ROLE production_user LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD %L',
  :'production_password'
)
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'production_user')
\gexec

-- The administrator needs SET ROLE permission to create/manage the owned DBs.
GRANT staging_user TO :"admin_user" WITH ADMIN OPTION;
GRANT production_user TO :"admin_user" WITH ADMIN OPTION;

SELECT 'CREATE DATABASE app_staging OWNER staging_user'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'app_staging')
\gexec
SELECT 'CREATE DATABASE app_production OWNER production_user'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'app_production')
\gexec

REVOKE ALL ON DATABASE app_staging FROM PUBLIC;
REVOKE ALL ON DATABASE app_production FROM PUBLIC;
REVOKE ALL ON DATABASE app_staging FROM production_user;
REVOKE ALL ON DATABASE app_production FROM staging_user;

\connect app_staging
SET ROLE staging_user;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
RESET ROLE;

\connect app_production
SET ROLE production_user;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
RESET ROLE;

-- Each DB owner can initialize PetClinic tables in its own public schema.
-- Verify matching-user login, forbidden cross-login, and persistence separately.
