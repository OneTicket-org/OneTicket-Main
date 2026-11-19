#!/bin/sh
set -eu

create_service_database() {
  database="$1"
  role="$2"
  password="$3"

  psql \
    --set=ON_ERROR_STOP=1 \
    --username "$POSTGRES_USER" \
    --dbname "$POSTGRES_DB" \
    --set=db_name="$database" \
    --set=db_role="$role" \
    --set=db_password="$password" <<'SQL'
CREATE ROLE :"db_role" LOGIN PASSWORD :'db_password';
CREATE DATABASE :"db_name" OWNER :"db_role";
SQL
}

create_service_database keycloak_db keycloak "$KEYCLOAK_DB_PASSWORD"
create_service_database catalogue_db catalogue "$CATALOGUE_DB_PASSWORD"
create_service_database inventory_db inventory "$INVENTORY_DB_PASSWORD"
create_service_database payments_db payments "$PAYMENTS_DB_PASSWORD"
create_service_database ticketing_db ticketing "$TICKETING_DB_PASSWORD"
create_service_database notifications_db notifications "$NOTIFICATIONS_DB_PASSWORD"
